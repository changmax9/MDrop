import AppKit
import MDropCore
import SwiftUI

struct DropReceiverView: NSViewRepresentable {
    let onTargeted: (Bool) -> Void
    let onDrop: ([DropRepresentation]) -> Void
    var onImportingChanged: ((Bool) -> Void)?
    var onError: ((Error) -> Void)?

    func makeNSView(context: Context) -> DropReceiverNSView {
        let view = DropReceiverNSView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: DropReceiverNSView, context: Context) {
        view.onTargeted = onTargeted
        view.onDrop = onDrop
        view.onImportingChanged = onImportingChanged
        view.onError = onError
    }
}

/// The same drag lifecycle is used by the shelf, menu bar, and top drop zone.
class DropReceiverNSView: NSView {
    var onTargeted: ((Bool) -> Void)?
    var onTargetedItemCount: ((Int) -> Void)?
    var onDrop: (([DropRepresentation]) -> Void)?
    var onImportingChanged: ((Bool) -> Void)?
    var onError: ((Error) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(DragPasteboardReceiver.supportedTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(DragPasteboardReceiver.supportedTypes)
    }

    func accepts(_ sender: NSDraggingInfo) -> Bool { true }

    private func operation(for sender: NSDraggingInfo) -> NSDragOperation {
        guard accepts(sender) else { return [] }
        return DragPasteboardReceiver.operation(
            for: sender.draggingPasteboard,
            sourceMask: sender.draggingSourceOperationMask
        )
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateTarget(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateTarget(sender)
    }

    private func updateTarget(_ sender: NSDraggingInfo) -> NSDragOperation {
        let operation = operation(for: sender)
        onTargetedItemCount?(operation.isEmpty ? 0 : max(1, sender.draggingPasteboard.pasteboardItems?.count ?? 1))
        onTargeted?(!operation.isEmpty)
        return operation
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { clearTarget() }
    override func draggingEnded(_ sender: NSDraggingInfo) { clearTarget() }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard !operation(for: sender).isEmpty else { return false }
        sender.animatesToDestination = !AppPreferences.reduceMotion() && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { clearTarget() }
        guard !operation(for: sender).isEmpty else { return false }
        let accepted = DragPasteboardReceiver.perform(
            sender,
            onDrop: onDrop,
            onImportingChanged: onImportingChanged,
            onError: onError
        )
        if accepted && sender.animatesToDestination {
            let side = min(44, min(bounds.width, bounds.height) * 0.45)
            sender.enumerateDraggingItems(options: [], for: self, classes: [NSPasteboardItem.self], searchOptions: [:]) { item, index, _ in
                let offset = CGFloat(min(index, 2)) * 3
                item.draggingFrame = NSRect(x: self.bounds.midX - side / 2 + offset, y: self.bounds.midY - side / 2 + offset, width: side, height: side)
            }
        }
        return accepted
    }

    private func clearTarget() {
        onTargeted?(false)
        onTargetedItemCount?(0)
    }
}

@MainActor
enum DragPasteboardReceiver {
    static let supportedTypes: [NSPasteboard.PasteboardType] =
        [.fileURL, .URL, .string, .png, .tiff] +
        NSFilePromiseReceiver.readableDraggedTypes.map {
            NSPasteboard.PasteboardType(rawValue: $0)
        }

    static func operation(
        for pasteboard: NSPasteboard,
        sourceMask: NSDragOperation
    ) -> NSDragOperation {
        guard pasteboard.availableType(from: supportedTypes) != nil else { return [] }
        // A shelf stores references. Never advertise move or delete to the source.
        if sourceMask.contains(.copy) { return .copy }
        if sourceMask.contains(.generic) { return .generic }
        if sourceMask.contains(.link) { return .link }
        return []
    }

    static func perform(
        _ sender: NSDraggingInfo,
        onDrop: (([DropRepresentation]) -> Void)?,
        onImportingChanged: ((Bool) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> Bool {
        guard let onDrop else { return false }
        let pasteboard = sender.draggingPasteboard
        let promises = pasteboard.readObjects(
            forClasses: [NSFilePromiseReceiver.self]
        ) as? [NSFilePromiseReceiver] ?? []
        guard !promises.isEmpty else {
            let representations = PasteboardReader.representations(from: pasteboard)
            guard !representations.isEmpty else { return false }
            onDrop(representations)
            return true
        }

        let reportError: (Error) -> Void = onError ?? { error in
            NSAlert(error: error).runModal()
        }
        let batchDirectory = AppPaths.staging.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let destinations = promises.indices.map {
            batchDirectory.appending(path: String($0), directoryHint: .isDirectory)
        }
        do {
            for destination in destinations {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            }
        } catch {
            reportError(error)
            return false
        }

        let batch = PromisedDropBatch(
            fileCounts: promises.map { max(1, $0.fileNames.count) }
        ) { representations, error in
            // Start ingest before ending the transfer so the busy indicator stays continuous.
            if !representations.isEmpty { onDrop(representations) }
            onImportingChanged?(false)
            if let error { reportError(error) }
        }
        onImportingChanged?(true)
        for (index, promise) in promises.enumerated() {
            promise.receivePromisedFiles(
                atDestination: destinations[index], options: [:], operationQueue: .main
            ) { fileURL, error in
                Task { @MainActor in
                    batch.receive(fileURL, error: error, at: index)
                }
            }
        }
        return true
    }
}

/// Deliver one batch, even when providers complete out of order or partially fail.
@MainActor
final class PromisedDropBatch {
    private var remaining: [Int]
    private var files: [[URL]]
    private var firstError: Error?
    private var completion: (([DropRepresentation], Error?) -> Void)?

    init(fileCounts: [Int], completion: @escaping ([DropRepresentation], Error?) -> Void) {
        remaining = fileCounts.map { max(1, $0) }
        files = Array(repeating: [], count: fileCounts.count)
        self.completion = completion
    }

    func receive(_ url: URL, error: Error?, at index: Int) {
        guard completion != nil, remaining.indices.contains(index), remaining[index] > 0 else { return }
        remaining[index] -= 1
        if let error {
            if firstError == nil { firstError = error }
        } else {
            files[index].append(url)
        }
        guard remaining.allSatisfy({ $0 == 0 }) else { return }
        let callback = completion
        completion = nil
        callback?(files.flatMap { $0 }.map(DropRepresentation.file), firstError)
    }
}

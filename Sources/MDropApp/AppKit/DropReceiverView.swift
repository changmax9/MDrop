import AppKit
import MDropCore
import SwiftUI

struct DropReceiverView: NSViewRepresentable {
    let onTargeted: (Bool) -> Void
    let onDrop: ([DropRepresentation]) -> Void

    func makeNSView(context: Context) -> DropReceiverNSView {
        let view = DropReceiverNSView()
        view.onTargeted = onTargeted
        view.onDrop = onDrop
        return view
    }

    func updateNSView(_ nsView: DropReceiverNSView, context: Context) {
        nsView.onTargeted = onTargeted
        nsView.onDrop = onDrop
    }
}

final class DropReceiverNSView: NSView {
    var onTargeted: ((Bool) -> Void)?
    var onDrop: (([DropRepresentation]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerTypes()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerTypes()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onTargeted?(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargeted?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onTargeted?(false)
        return DragPasteboardReceiver.perform(sender, onDrop: onDrop)
    }

    private func registerTypes() {
        registerForDraggedTypes(
            [.fileURL, .URL, .string, .png, .tiff] +
            NSFilePromiseReceiver.readableDraggedTypes.map {
                NSPasteboard.PasteboardType(rawValue: $0)
            }
        )
    }
}

@MainActor
enum DragPasteboardReceiver {
    static func perform(
        _ sender: NSDraggingInfo,
        onDrop: (([DropRepresentation]) -> Void)?
    ) -> Bool {
        let promises = sender.draggingPasteboard.readObjects(
            forClasses: [NSFilePromiseReceiver.self]
        ) as? [NSFilePromiseReceiver] ?? []
        if !promises.isEmpty {
            try? FileManager.default.createDirectory(
                at: AppPaths.staging,
                withIntermediateDirectories: true
            )
            for promise in promises {
                promise.receivePromisedFiles(
                    atDestination: AppPaths.staging,
                    options: [:],
                    operationQueue: .main
                ) { fileURL, error in
                    guard error == nil else { return }
                    onDrop?([.file(fileURL)])
                }
            }
            return true
        }

        let representations = PasteboardReader.representations(from: sender.draggingPasteboard)
        guard !representations.isEmpty else { return false }
        onDrop?(representations)
        return true
    }
}

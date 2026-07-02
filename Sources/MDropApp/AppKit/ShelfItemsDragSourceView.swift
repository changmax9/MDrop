import AppKit
import MDropCore
import SwiftUI

@MainActor
struct ShelfItemsDragSourceView: NSViewRepresentable {
    let items: [ShelfItemRecord]
    let onDraggingChanged: (Bool) -> Void

    func makeNSView(context: Context) -> ShelfItemsDragSourceNSView {
        let view = ShelfItemsDragSourceNSView()
        view.items = items
        view.onDraggingChanged = onDraggingChanged
        return view
    }

    func updateNSView(
        _ nsView: ShelfItemsDragSourceNSView,
        context: Context
    ) {
        nsView.items = items
        nsView.onDraggingChanged = onDraggingChanged
    }

    static func dismantleNSView(
        _ nsView: ShelfItemsDragSourceNSView,
        coordinator: Void
    ) {
        nsView.cancelDragAppearance()
    }
}

@MainActor
final class ShelfItemsDragSourceNSView: NSView, NSDraggingSource {
    var items: [ShelfItemRecord] = []
    var onDraggingChanged: (Bool) -> Void = { _ in }
    private var isDragging = false
    private var appearanceResetTask: Task<Void, Never>?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        switch NSApp.currentEvent?.type {
        case .rightMouseDown, .rightMouseUp:
            return nil
        default:
            return self
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDragging else { return }
        let draggingItems = makeDraggingItems(for: event)
        guard !draggingItems.isEmpty else { return }

        isDragging = true
        onDraggingChanged(true)
        let session = beginDraggingSession(
            with: draggingItems,
            event: event,
            source: self
        )
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .stack
        session.draggingLeaderIndex = draggingItems.count - 1
        scheduleAppearanceResetAfterMouseUp()
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging {
            onDraggingChanged(false)
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        cancelDragAppearance()
    }

    func ignoreModifierKeys(
        for session: NSDraggingSession
    ) -> Bool {
        true
    }

    func cancelDragAppearance() {
        appearanceResetTask?.cancel()
        appearanceResetTask = nil
        guard isDragging else { return }
        isDragging = false
        onDraggingChanged(false)
    }

    private func scheduleAppearanceResetAfterMouseUp() {
        appearanceResetTask?.cancel()
        appearanceResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(90))
            while !Task.isCancelled,
                  NSEvent.pressedMouseButtons & 1 != 0 {
                try? await Task.sleep(for: .milliseconds(34))
            }
            guard !Task.isCancelled else { return }
            self?.cancelDragAppearance()
        }
    }

    private func makeDraggingItems(
        for event: NSEvent
    ) -> [NSDraggingItem] {
        let point = convert(event.locationInWindow, from: nil)
        return makeDraggingItems(at: point)
    }

    func makeDraggingItems(
        at point: NSPoint
    ) -> [NSDraggingItem] {
        return items.enumerated().compactMap { index, item in
            guard let writer = pasteboardWriter(for: item) else {
                return nil
            }

            let draggingItem = NSDraggingItem(
                pasteboardWriter: writer
            )
            let offset = CGFloat(min(index, 4)) * 3
            draggingItem.setDraggingFrame(
                CGRect(
                    x: point.x - 28 + offset,
                    y: point.y - 28 - offset,
                    width: 56,
                    height: 56
                ),
                contents: previewImage(for: item)
            )
            return draggingItem
        }
    }

    private func pasteboardWriter(
        for item: ShelfItemRecord
    ) -> (any NSPasteboardWriting)? {
        switch item.payload {
        case .file:
            return item.fileURL.map { $0 as NSURL }
        case let .text(value):
            return value as NSString
        case let .url(url):
            return url as NSURL
        }
    }

    private func previewImage(
        for item: ShelfItemRecord
    ) -> NSImage {
        let image: NSImage
        switch item.payload {
        case .file:
            if let url = item.fileURL {
                image = NSWorkspace.shared.icon(forFile: url.path)
            } else {
                image = symbol("questionmark.square.dashed")
            }
        case .text:
            image = symbol("text.quote")
        case .url:
            image = symbol("link")
        }

        let copy = image.copy() as? NSImage ?? image
        copy.size = NSSize(width: 56, height: 56)
        return copy
    }

    private func symbol(_ name: String) -> NSImage {
        NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        ) ?? NSImage()
    }
}

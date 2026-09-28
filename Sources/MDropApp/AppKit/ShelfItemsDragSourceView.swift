import AppKit
import MDropCore
import SwiftUI

struct ShelfItemsDragCompletion {
    let draggedItemIDs: Set<UUID>
    let operation: NSDragOperation
    let modifierFlags: NSEvent.ModifierFlags
}

enum ShelfItemsDragCompletionAction: Equatable {
    case none
    case remove(itemIDs: Set<UUID>)
    case close(itemIDs: Set<UUID>)
}

enum ShelfItemsDragBehavior {
    static func sourceOperationMask(
        alwaysCopyDraggedItems: Bool
    ) -> NSDragOperation {
        alwaysCopyDraggedItems ? .copy : [.copy, .move]
    }

    static func ignoresModifierKeys(
        alwaysCopyDraggedItems: Bool
    ) -> Bool {
        alwaysCopyDraggedItems
    }

    static func completionAction(
        shelfItemIDs: [UUID],
        completion: ShelfItemsDragCompletion
    ) -> ShelfItemsDragCompletionAction {
        guard !completion.operation.isEmpty,
              !completion.modifierFlags.contains(.shift) else {
            return .none
        }

        let shelfItemIDs = Set(shelfItemIDs)
        let removedItemIDs = completion.draggedItemIDs
            .intersection(shelfItemIDs)
        guard !removedItemIDs.isEmpty else {
            return .none
        }

        if shelfItemIDs.subtracting(removedItemIDs).isEmpty {
            return .close(itemIDs: removedItemIDs)
        }
        return .remove(itemIDs: removedItemIDs)
    }
}

@MainActor
struct ShelfItemsDragSourceView: NSViewRepresentable {
    let items: [ShelfItemRecord]
    let onDraggingChanged: (Bool) -> Void
    let onDragCompleted: (ShelfItemsDragCompletion) -> Void
    var onClick: (NSEvent.ModifierFlags) -> Void
    var onDoubleClick: () -> Void

    init(
        items: [ShelfItemRecord],
        onDraggingChanged: @escaping (Bool) -> Void,
        onDragCompleted: @escaping (
            ShelfItemsDragCompletion
        ) -> Void = { _ in },
        onClick: @escaping (NSEvent.ModifierFlags) -> Void = { _ in },
        onDoubleClick: @escaping () -> Void = {}
    ) {
        self.items = items
        self.onDraggingChanged = onDraggingChanged
        self.onDragCompleted = onDragCompleted
        self.onClick = onClick
        self.onDoubleClick = onDoubleClick
    }

    func makeNSView(context: Context) -> ShelfItemsDragSourceNSView {
        let view = ShelfItemsDragSourceNSView()
        view.items = items
        view.onDraggingChanged = onDraggingChanged
        view.onDragCompleted = onDragCompleted
        view.onClick = onClick
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(
        _ nsView: ShelfItemsDragSourceNSView,
        context: Context
    ) {
        nsView.items = items
        nsView.onDraggingChanged = onDraggingChanged
        nsView.onDragCompleted = onDragCompleted
        nsView.onClick = onClick
        nsView.onDoubleClick = onDoubleClick
    }

    static func dismantleNSView(
        _ nsView: ShelfItemsDragSourceNSView,
        coordinator: Void
    ) {
        nsView.discardPendingDrag()
    }
}

@MainActor
final class ShelfItemsDragSourceNSView: NSView, NSDraggingSource {
    var items: [ShelfItemRecord] = []
    var onDraggingChanged: (Bool) -> Void = { _ in }
    var onDragCompleted: (ShelfItemsDragCompletion) -> Void = { _ in }
    var onClick: (NSEvent.ModifierFlags) -> Void = { _ in }
    var onDoubleClick: () -> Void = {}
    private var isDragging = false
    private var mouseDownLocation: NSPoint?
    private var didBeginDrag = false
    private var activeDraggedItemIDs: Set<UUID> = []
    private var appearanceResetTask: Task<Void, Never>?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden,
              bounds.contains(convert(point, from: superview))
        else { return nil }
        switch NSApp?.currentEvent?.type {
        case .rightMouseDown, .rightMouseUp:
            return nil
        default:
            return self
        }
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        didBeginDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDragging, !didBeginDrag,
              let mouseDownLocation,
              hypot(
                event.locationInWindow.x - mouseDownLocation.x,
                event.locationInWindow.y - mouseDownLocation.y
              ) >= 3
        else { return }
        let draggingItems = makeDraggingItems(for: event)
        guard !draggingItems.isEmpty else { return }

        isDragging = true
        didBeginDrag = true
        activeDraggedItemIDs = Set(
            items.compactMap { item in
                pasteboardWriter(for: item) == nil ? nil : item.id
            }
        )
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
        let shouldClick = mouseDownLocation != nil && !didBeginDrag
            && bounds.contains(convert(event.locationInWindow, from: nil))
        mouseDownLocation = nil
        guard shouldClick else { return }
        if event.clickCount >= 2 {
            onDoubleClick()
        } else {
            onClick(event.modifierFlags)
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        ShelfItemsDragBehavior.sourceOperationMask(
            alwaysCopyDraggedItems:
                AppPreferences.alwaysCopyDraggedItems()
        )
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        let completion = ShelfItemsDragCompletion(
            draggedItemIDs: activeDraggedItemIDs,
            operation: operation,
            modifierFlags: NSEvent.modifierFlags
        )
        activeDraggedItemIDs.removeAll()
        cancelDragAppearance()
        onDragCompleted(completion)
    }

    func ignoreModifierKeys(
        for session: NSDraggingSession
    ) -> Bool {
        ShelfItemsDragBehavior.ignoresModifierKeys(
            alwaysCopyDraggedItems:
                AppPreferences.alwaysCopyDraggedItems()
        )
    }

    func discardPendingDrag() {
        mouseDownLocation = nil
        didBeginDrag = false
        activeDraggedItemIDs.removeAll()
        cancelDragAppearance()
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

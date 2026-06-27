import AppKit
import MDropCore
import SwiftUI

final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class ShelfPanelController {
    let panel: ShelfPanel
    let store: ShelfStore
    private let onChange: () -> Void
    private let actionController = ShelfActionController()
    private var keyMonitor: Any?
    private let compactSize = NSSize(width: 300, height: 146)
    private let detailSize = NSSize(width: 430, height: 440)
    private let dockedSize = NSSize(width: 92, height: 250)

    init(
        shelf: ShelfRecord,
        location: CGPoint?,
        onDrop: @escaping ([DropRepresentation]) -> Void,
        onChange: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        store = ShelfStore(shelf: shelf)
        self.onChange = onChange
        let size = Self.size(
            for: shelf.presentationState,
            compact: compactSize,
            detail: detailSize,
            docked: dockedSize
        )
        panel = ShelfPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        let view = ShelfView(
            store: store,
            onDrop: onDrop,
            onToggleDetail: {},
            onDock: {},
            onAction: { _ in },
            onChange: onChange,
            onClose: onClose
        )
        let hostingController = NSHostingController(rootView: view)
        panel.contentViewController = hostingController
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .utilityWindow
        position(at: location ?? NSEvent.mouseLocation)

        hostingController.rootView = ShelfView(
            store: store,
            onDrop: onDrop,
            onToggleDetail: { [weak self] in self?.toggleDetail() },
            onDock: { [weak self] in self?.toggleDock() },
            onAction: { [weak self] action in self?.run(action) },
            onChange: onChange,
            onClose: onClose
        )
        installKeyMonitor(onClose: onClose)
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func close() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        panel.orderOut(nil)
        panel.close()
    }

    func refreshSize() {
        resize(to: Self.size(
            for: store.shelf.presentationState,
            compact: compactSize,
            detail: detailSize,
            docked: dockedSize
        ))
    }

    private func toggleDetail() {
        store.shelf.presentationState =
            store.shelf.presentationState == .detail ? .compact : .detail
        refreshSize()
        onChange()
    }

    private func run(_ action: BuiltinActionID) {
        actionController.run(
            action,
            store: store,
            panel: panel,
            onChange: onChange
        )
    }

    private func installKeyMonitor(onClose: @escaping () -> Void) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard let self, event.window === panel else { return event }
            let command = event.modifierFlags.contains(.command)
            switch (event.charactersIgnoringModifiers, command) {
            case ("k", true):
                store.isCommandBarPresented.toggle()
                return nil
            case ("w", true):
                onClose()
                return nil
            case ("\u{1b}", _):
                store.isCommandBarPresented = false
                return nil
            case ("\t", _):
                toggleDetail()
                return nil
            default:
                return event
            }
        }
    }

    private func toggleDock() {
        if store.shelf.presentationState == .docked {
            store.shelf.presentationState = store.shelf.items.isEmpty ? .empty : .compact
            store.shelf.dockedEdge = nil
            refreshSize()
            return
        }

        let screen = panel.screen ?? NSScreen.main
        let midpoint = screen?.visibleFrame.midX ?? 0
        let edge: DockedEdge = panel.frame.midX < midpoint ? .left : .right
        store.shelf.dockedEdge = edge
        store.shelf.presentationState = .docked
        resize(to: dockedSize)
        guard let visible = screen?.visibleFrame else { return }
        let x = edge == .left ? visible.minX : visible.maxX - dockedSize.width
        panel.setFrameOrigin(NSPoint(x: x, y: min(max(panel.frame.minY, visible.minY), visible.maxY - dockedSize.height)))
        onChange()
    }

    private func resize(to size: NSSize) {
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        panel.setFrame(frame, display: true, animate: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    private func position(at point: CGPoint) {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let x = min(max(point.x - panel.frame.width / 2, visible.minX), visible.maxX - panel.frame.width)
        let desiredY = point.y - panel.frame.height - 18
        let y = min(max(desiredY, visible.minY), visible.maxY - panel.frame.height)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private static func size(
        for state: ShelfPresentationState,
        compact: NSSize,
        detail: NSSize,
        docked: NSSize
    ) -> NSSize {
        switch state {
        case .detail:
            detail
        case .docked:
            docked
        case .empty, .compact, .instantActions:
            compact
        }
    }
}

import AppKit
import MDropCore
import QuartzCore
import SwiftUI

final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class ShelfWindowDragSurfaceView: NSView {
    var layoutProvider: () -> ShelfDragLayout = {
        ShelfDragLayout(interactiveRegions: [])
    }
    var onDraggingChanged: (Bool) -> Void = { _ in }

    override func hitTest(_ point: NSPoint) -> NSView? {
        switch NSApp.currentEvent?.type {
        case .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp:
            return nil
        default:
            break
        }

        let localPoint = convert(point, from: superview)
        return layoutProvider().isInteractive(localPoint) ? nil : self
    }

    override func mouseDown(with event: NSEvent) {
        onDraggingChanged(true)
        window?.performDrag(with: event)
        onDraggingChanged(false)
    }
}

@MainActor
final class ShelfDropContainerView: NSView {
    var onDropTargeted: ((Bool) -> Void)?
    var onDrop: (([DropRepresentation]) -> Void)?
    var onHoverChanged: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureDropDestination()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureDropDestination()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [
                .mouseEnteredAndExited,
                .activeAlways,
                .inVisibleRect
            ],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    private func configureDropDestination() {
        registerForDraggedTypes(
            [.fileURL, .URL, .string, .png, .tiff] +
            NSFilePromiseReceiver.readableDraggedTypes.map {
                NSPasteboard.PasteboardType(rawValue: $0)
            }
        )
    }

    override func draggingEntered(
        _ sender: NSDraggingInfo
    ) -> NSDragOperation {
        guard !originatesFromThisShelf(sender) else {
            onDropTargeted?(false)
            return []
        }
        onDropTargeted?(true)
        return .copy
    }

    override func draggingUpdated(
        _ sender: NSDraggingInfo
    ) -> NSDragOperation {
        originatesFromThisShelf(sender) ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDropTargeted?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDropTargeted?(false)
        guard !originatesFromThisShelf(sender) else { return false }
        return DragPasteboardReceiver.perform(sender, onDrop: onDrop)
    }

    private func originatesFromThisShelf(
        _ sender: NSDraggingInfo
    ) -> Bool {
        if let sourceView = sender.draggingSource as? NSView {
            return sourceView.window === window
        }
        if let sourceWindow = sender.draggingSource as? NSWindow {
            return sourceWindow === window
        }
        return false
    }
}

@MainActor
final class ShelfPanelController {
    let panel: ShelfPanel
    let store: ShelfStore
    private let onChange: () -> Void
    private let onClose: () -> Void
    private let hostingView: NSHostingView<ShelfView>
    private let actionController = ShelfActionController()
    private let quickLookController = QuickLookController()
    private var keyMonitor: Any?
    private var closeWorkItem: DispatchWorkItem?
    private var morphTask: Task<Void, Never>?
    private let emptySize = NSSize(
        width: CGFloat(ShelfMotionProfile.reference.emptyPanel.width),
        height: CGFloat(ShelfMotionProfile.reference.emptyPanel.height)
    )
    private let detailSize = NSSize(width: 430, height: 180)
    private let dockedSize = NSSize(width: 92, height: 250)

    init(
        shelf: ShelfRecord,
        location: CGPoint?,
        animatesInitialAppearance: Bool,
        onDrop: @escaping ([DropRepresentation]) -> Void,
        onChange: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        store = ShelfStore(
            shelf: shelf,
            animatesInitialAppearance: animatesInitialAppearance
        )
        self.onChange = onChange
        self.onClose = onClose
        let size = Self.size(
            for: shelf.presentationState,
            empty: emptySize,
            compact: Self.compactSize(itemCount: shelf.items.count),
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
            onToggleDetail: {},
            onDock: {},
            onQuickLook: {},
            onAddClipboard: {},
            onAction: { _ in },
            onPreset: { _ in },
            onScript: { _ in },
            onChange: onChange,
            onClose: onClose
        )
        hostingView = NSHostingView(rootView: view)
        let dropContainer = ShelfDropContainerView(
            frame: NSRect(origin: .zero, size: size)
        )
        let dragSurface = ShelfWindowDragSurfaceView()
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        dropContainer.wantsLayer = true
        dropContainer.layer?.backgroundColor = NSColor.clear.cgColor
        dropContainer.layer?.isOpaque = false
        dropContainer.onDropTargeted = { [weak store] targeted in
            store?.isReceivingDrop = targeted
        }
        dropContainer.onHoverChanged = { [weak store] hovering in
            store?.isShelfHovered = hovering
        }
        dropContainer.onDrop = onDrop
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        dragSurface.translatesAutoresizingMaskIntoConstraints = false
        dragSurface.layoutProvider = { [weak store, weak dropContainer] in
            guard let store, let dropContainer else {
                return ShelfDragLayout(interactiveRegions: [])
            }
            return Self.dragLayout(
                for: store.shelf.presentationState,
                panelSize: dropContainer.bounds.size
            )
        }
        dragSurface.onDraggingChanged = { [weak store] dragging in
            store?.isWindowDragging = dragging
        }
        dropContainer.addSubview(hostingView)
        dropContainer.addSubview(
            dragSurface,
            positioned: .above,
            relativeTo: hostingView
        )
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: dropContainer.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: dropContainer.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: dropContainer.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: dropContainer.bottomAnchor),
            dragSurface.leadingAnchor.constraint(equalTo: dropContainer.leadingAnchor),
            dragSurface.trailingAnchor.constraint(equalTo: dropContainer.trailingAnchor),
            dragSurface.topAnchor.constraint(equalTo: dropContainer.topAnchor),
            dragSurface.bottomAnchor.constraint(equalTo: dropContainer.bottomAnchor)
        ])
        panel.contentView = dropContainer
        panel.appearance = nil
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.animationBehavior = .none
        position(at: location ?? NSEvent.mouseLocation)

        hostingView.rootView = ShelfView(
            store: store,
            onToggleDetail: { [weak self] in self?.toggleDetail() },
            onDock: { [weak self] in self?.toggleDock() },
            onQuickLook: { [weak self] in self?.quickLookSelectedItems() },
            onAddClipboard: {
                onDrop(PasteboardReader.representations(from: .general))
            },
            onAction: { [weak self] action in self?.run(action) },
            onPreset: { [weak self] preset in self?.run(preset) },
            onScript: { [weak self] script in self?.run(script) },
            onChange: onChange,
            onClose: { [weak self] in self?.requestClose() }
        )
        installKeyMonitor()
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func close() {
        closeWorkItem?.cancel()
        closeWorkItem = nil
        morphTask?.cancel()
        morphTask = nil
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
            empty: emptySize,
            compact: Self.compactSize(itemCount: store.shelf.items.count),
            detail: detailSize,
            docked: dockedSize
        ))
    }

    private func toggleDetail() {
        guard morphTask == nil else { return }
        let targetState: ShelfPresentationState =
            store.shelf.presentationState == .detail ? .compact : .detail
        let targetSize = Self.size(
            for: targetState,
            empty: emptySize,
            compact: Self.compactSize(
                itemCount: store.shelf.items.count
            ),
            detail: detailSize,
            docked: dockedSize
        )
        store.isLayoutContentVisible = false
        resize(to: targetSize)

        morphTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let fadeDuration = reduceMotion
                ? ShelfMotionProfile.reference.reducedMotionDuration
                : ShelfMotionProfile.reference.layoutFadeDuration
            do {
                try await Task.sleep(for: .seconds(fadeDuration))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            store.shelf.presentationState = targetState
            await Task.yield()
            guard !Task.isCancelled else { return }
            store.isLayoutContentVisible = true
            onChange()

            let remainingDuration = max(
                0,
                ShelfMotionProfile.reference.frameMorphDuration
                    - fadeDuration
            )
            do {
                try await Task.sleep(
                    for: .seconds(remainingDuration)
                )
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            morphTask = nil
        }
    }

    private func run(_ action: BuiltinActionID) {
        actionController.run(
            action,
            store: store,
            panel: panel,
            onChange: onChange,
            onClose: { [weak self] in self?.requestClose() }
        )
    }

    private func run(_ preset: CustomActionPreset) {
        actionController.run(
            preset,
            store: store,
            panel: panel,
            onChange: onChange,
            onClose: { [weak self] in self?.requestClose() }
        )
    }

    private func run(_ script: ScriptDefinition) {
        actionController.run(
            script,
            store: store,
            onChange: onChange,
            onClose: { [weak self] in self?.requestClose() }
        )
    }

    private func requestClose() {
        guard !store.isClosing else { return }
        store.isClosing = true

        let delay = reduceMotion
            ? 0
            : ShelfMotionProfile.reference.closeDuration
        let workItem = DispatchWorkItem { [weak self] in
            self?.onClose()
        }
        closeWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: workItem
        )
    }

    private func quickLookSelectedItems() {
        let items = store.selectedItemIDs.isEmpty
            ? store.shelf.items
            : store.shelf.items.filter {
                store.selectedItemIDs.contains($0.id)
            }
        quickLookController.show(items.compactMap(\.fileURL))
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard let self, event.window === panel else { return event }
            let command = event.modifierFlags.contains(.command)
            switch (event.charactersIgnoringModifiers, command) {
            case ("k", true):
                store.isCommandBarPresented.toggle()
                return nil
            case ("w", true):
                requestClose()
                return nil
            case ("\u{1b}", _):
                store.isCommandBarPresented = false
                return nil
            case ("\t", _):
                toggleDetail()
                return nil
            case (" ", _):
                let selected = store.selectedItemIDs.isEmpty
                    ? store.shelf.items
                    : store.shelf.items.filter { store.selectedItemIDs.contains($0.id) }
                quickLookController.show(selected.compactMap(\.fileURL))
                return nil
            case ("\u{7f}", _):
                let ids = store.selectedItemIDs.isEmpty
                    ? Set(store.shelf.items.map(\.id))
                    : store.selectedItemIDs
                store.remove(ids)
                onChange()
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
        guard panel.frame.size != size else { return }
        let visibleFrame = (panel.screen ?? NSScreen.main)?.visibleFrame
        let frame = ShelfPanelGeometry.centeredFrame(
            from: panel.frame,
            to: size,
            constrainedTo: visibleFrame
        )

        guard !reduceMotion else {
            panel.setFrame(frame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration =
                ShelfMotionProfile.reference.frameMorphDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    private var reduceMotion: Bool {
        UserDefaults.standard.bool(forKey: "reduceShelfMotion")
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
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
        empty: NSSize,
        compact: NSSize,
        detail: NSSize,
        docked: NSSize
    ) -> NSSize {
        switch state {
        case .empty:
            empty
        case .detail:
            detail
        case .docked:
            docked
        case .compact, .instantActions:
            compact
        }
    }

    private static func compactSize(itemCount: Int) -> NSSize {
        let metrics = CompactShelfLayout.panelMetrics(itemCount: itemCount)
        return NSSize(width: metrics.width, height: metrics.height)
    }

    private static func dragLayout(
        for state: ShelfPresentationState,
        panelSize: NSSize
    ) -> ShelfDragLayout {
        switch state {
        case .empty:
            ShelfDragLayout.empty(panelSize: panelSize)
        case .detail:
            ShelfDragLayout.detail(panelSize: panelSize)
        case .docked:
            ShelfDragLayout.docked(panelSize: panelSize)
        case .compact, .instantActions:
            ShelfDragLayout.compact(panelSize: panelSize)
        }
    }
}

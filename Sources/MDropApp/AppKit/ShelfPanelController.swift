import AppKit
import MDropCore
import QuartzCore
import SwiftUI

final class ShelfPanel: NSPanel {
    /// Shelves are composited as transparent, self-contained glass surfaces.
    /// Keep AppKit from restoring a window shadow while the panel is moved.
    override var hasShadow: Bool {
        get { false }
        set { super.hasShadow = false }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct ShelfGrabberPresentation: Equatable {
    let isVisible: Bool
    let width: CGFloat
    let height: CGFloat
    let shouldPulse: Bool
}

final class ShelfWindowDragSurfaceView: NSView {
    var onHoverChanged: (Bool) -> Void = { _ in }
    var alwaysShowsHandleProvider: () -> Bool = { false }
    var handleColorProvider: () -> NSColor = { .secondaryLabelColor }
    private static let activePulseAnimationKey =
        "MDrop.ShelfGrabber.activeOpacityPulse"
    private static let activePulseMinimumOpacity: Float = 0.72
    private static let activePulseHalfDuration: CFTimeInterval = 0.85

    var layoutProvider: () -> ShelfDragLayout = {
        ShelfDragLayout(interactiveRegions: [])
    }
    var showsHandleProvider: () -> Bool = { true }
    var reducesMotionProvider: () -> Bool = {
        AppPreferences.reduceMotion()
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    private var hoverTrackingArea: NSTrackingArea?
    private let handleLayer = CALayer()
    private var isHovered = false
    private var isDraggingWindow = false
    private var isWindowActive = false
    private var dragStartPointerLocation: CGPoint?
    private var dragStartWindowOrigin: CGPoint?
    private var handleTargetWidth: CGFloat = 0
    private var handleTargetOpacity: Float = 0

    var isActiveHandlePulseRunning: Bool {
        handleLayer.animation(forKey: Self.activePulseAnimationKey) != nil
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureHandle()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureHandle()
    }

    override func layout() {
        super.layout()
        updateHandle(animated: false)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateHandleColor()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            isWindowActive = false
            stopHandleAnimations()
        }
        super.viewWillMove(toWindow: newWindow)
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
        isHovered = true
        onHoverChanged(true)
        updateHandle(animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        onHoverChanged(false)
        updateHandle(animated: true)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        switch NSApp.currentEvent?.type {
        case .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp:
            return nil
        default:
            break
        }

        return layoutProvider().isInteractive(point) ? nil : self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStartPointerLocation = NSEvent.mouseLocation
        dragStartWindowOrigin = window.frame.origin
        isDraggingWindow = true
        updateHandle(animated: true)
        CATransaction.flush()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window,
              let dragStartPointerLocation,
              let dragStartWindowOrigin
        else { return }

        window.setFrameOrigin(
            ShelfPanelGeometry.draggedOrigin(
                from: dragStartWindowOrigin,
                pointerStart: dragStartPointerLocation,
                pointerCurrent: NSEvent.mouseLocation
            )
        )
    }

    override func mouseUp(with event: NSEvent) {
        finishWindowDrag()
    }

    func setWindowActive(_ isActive: Bool, animated: Bool) {
        isWindowActive = isActive
        updateHandle(animated: animated)
    }

    func refreshMotionPreference() {
        updateHandleColor()
        updateHandle(animated: false)
    }

    func stopHandleAnimations() {
        handleLayer.removeAnimation(forKey: Self.activePulseAnimationKey)
    }

    static func grabberPresentation(
        showsHandle: Bool,
        isHovered: Bool,
        isDraggingWindow: Bool,
        isWindowActive: Bool,
        reduceMotion: Bool,
        alwaysShow: Bool = false
    ) -> ShelfGrabberPresentation {
        let isVisible = showsHandle
            && (alwaysShow || isWindowActive || isHovered || isDraggingWindow)
        return ShelfGrabberPresentation(
            isVisible: isVisible,
            width: isDraggingWindow
                ? CGFloat(ShelfMotionProfile.reference.handleDraggingWidth)
                : CGFloat(ShelfMotionProfile.reference.handleHoverWidth),
            height: CGFloat(ShelfMotionProfile.reference.handleHeight),
            shouldPulse: isVisible && isWindowActive && !reduceMotion
        )
    }

    private func finishWindowDrag() {
        dragStartPointerLocation = nil
        dragStartWindowOrigin = nil
        guard isDraggingWindow else { return }
        isDraggingWindow = false
        updateHandle(animated: true)
    }

    private func configureHandle() {
        wantsLayer = true
        handleLayer.cornerRadius =
            CGFloat(ShelfMotionProfile.reference.handleHeight) / 2
        handleLayer.opacity = 0
        layer?.addSublayer(handleLayer)
        updateHandleColor()
    }

    private func updateHandleColor() {
        handleLayer.backgroundColor = handleColorProvider()
            .withAlphaComponent(0.55)
            .cgColor
    }

    private func updateHandle(animated: Bool) {
        let reduceMotion = reducesMotionProvider()
        let presentation = Self.grabberPresentation(
            showsHandle: showsHandleProvider(),
            isHovered: isHovered,
            isDraggingWindow: isDraggingWindow,
            isWindowActive: isWindowActive,
            reduceMotion: reduceMotion,
            alwaysShow: alwaysShowsHandleProvider()
        )
        let opacity: Float = presentation.isVisible ? 1 : 0

        handleLayer.position = CGPoint(
            x: bounds.midX,
            y: bounds.maxY - 10
        )
        let needsModelUpdate = presentation.width != handleTargetWidth
                || opacity != handleTargetOpacity
                || handleLayer.bounds.height != presentation.height
        if needsModelUpdate {
            handleTargetWidth = presentation.width
            handleTargetOpacity = opacity
            CATransaction.begin()
            CATransaction.setAnimationDuration(
                ShelfMotionProfile.reference.handleAnimationDuration(
                    requested: animated,
                    reduceMotion: reduceMotion
                )
            )
            CATransaction.setAnimationTimingFunction(
                CAMediaTimingFunction(name: .easeOut)
            )
            handleLayer.bounds = CGRect(
                x: 0,
                y: 0,
                width: presentation.width,
                height: presentation.height
            )
            handleLayer.opacity = opacity
            CATransaction.commit()
        }

        reconcileActivePulse(shouldPulse: presentation.shouldPulse)
    }

    private func reconcileActivePulse(shouldPulse: Bool) {
        guard shouldPulse else {
            stopHandleAnimations()
            return
        }
        guard !isActiveHandlePulseRunning else { return }

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1
        pulse.toValue = Self.activePulseMinimumOpacity
        pulse.duration = Self.activePulseHalfDuration
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulse.isRemovedOnCompletion = true
        handleLayer.add(pulse, forKey: Self.activePulseAnimationKey)
    }
}

private final class ShelfNotificationObservation: @unchecked Sendable {
    private let center: NotificationCenter
    private var token: NSObjectProtocol?

    init(center: NotificationCenter, token: NSObjectProtocol) {
        self.center = center
        self.token = token
    }

    func cancel() {
        guard let token else { return }
        center.removeObserver(token)
        self.token = nil
    }

    deinit {
        if let token {
            center.removeObserver(token)
        }
    }
}

@MainActor
final class ShelfDropContainerView: DropReceiverNSView {
    override var isOpaque: Bool { false }

    /// SwiftUI's glass backdrop is composited outside its ordinary drawing layer.
    /// Mask the native ancestor too, so no rectangular backdrop escapes the corner.
    func setGlassCornerRadius(_ radius: CGFloat, duration: TimeInterval = 0) {
        wantsLayer = true
        guard let layer else { return }
        let previous = layer.presentation()?.cornerRadius ?? layer.cornerRadius
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.backgroundColor = NSColor.clear.cgColor
        layer.isOpaque = false
        layer.masksToBounds = true
        layer.cornerCurve = .continuous
        layer.cornerRadius = radius
        CATransaction.commit()
        layer.removeAnimation(forKey: "glassCornerRadius")
        if duration > 0, previous != radius {
            let animation = CABasicAnimation(keyPath: "cornerRadius")
            animation.fromValue = previous
            animation.toValue = radius
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(animation, forKey: "glassCornerRadius")
        }
    }

    var onDropTargeted: ((Bool) -> Void)? {
        get { onTargeted }
        set { onTargeted = newValue }
    }

    override func accepts(_ sender: NSDraggingInfo) -> Bool {
        if let sourceView = sender.draggingSource as? NSView,
           let sourceWindow = sourceView.window, sourceWindow === window {
            return false
        }
        if let sourceWindow = sender.draggingSource as? NSWindow, sourceWindow === window {
            return false
        }
        return true
    }
}

@MainActor
final class ShelfPanelController {
    private final class ActiveLayoutTransition {
        let id: UUID
        let targetState: ShelfPresentationState
        let dockedEdge: DockedEdge?
        let targetFrame: CGRect
        var didCompleteFrame = false
        var didCompleteFadeIn = false

        init(
            id: UUID,
            targetState: ShelfPresentationState,
            dockedEdge: DockedEdge?,
            targetFrame: CGRect
        ) {
            self.id = id
            self.targetState = targetState
            self.dockedEdge = dockedEdge
            self.targetFrame = targetFrame
        }
    }

    static let frameMorphTimingFunctionName:
        CAMediaTimingFunctionName = .easeInEaseOut

    let panel: ShelfPanel
    let store: ShelfStore
    private let onDrop: ([DropRepresentation]) -> Void
    private let onChange: () -> Void
    private let onClose: () -> Void
    private let hostingView: NSHostingView<ShelfView>
    private let instantActionsGlassView = InstantActionGlassView(frame: .zero)
    private let instantActionsPanel: ShelfPanel
    private let instantActionsHostingView:
        NSHostingView<InstantActionsRailView>
    private let dropContainer: ShelfDropContainerView
    private let dragSurface: ShelfWindowDragSurfaceView
    private let actionController = ShelfActionController()
    private let quickLookController = QuickLookController()
    private let finderRevealController = FinderRevealController()
    private var keyMonitor: Any?
    private var globalOutsideMouseMonitor: Any?
    private var localOutsideMouseMonitor: Any?
    private var panelObservers: [ShelfNotificationObservation] = []
    private var closeWorkItem: DispatchWorkItem?
    private var layoutTransitionRecoveryWorkItem: DispatchWorkItem?
    private var activeLayoutTransition: ActiveLayoutTransition?
    private var compactFrameBeforeDetail: CGRect?
    private let emptySize = NSSize(
        width: CGFloat(ShelfMotionProfile.reference.emptyPanel.width),
        height: CGFloat(ShelfMotionProfile.reference.emptyPanel.height)
    )
    private var detailSize: NSSize {
        let metrics = ShelfDetailLayout.panelMetrics(
            itemCount: store.shelf.items.count
        )
        return NSSize(
            width: CGFloat(metrics.width),
            height: CGFloat(metrics.height)
        )
    }
    private let dockedSize = NSSize(width: 92, height: 250)
    private let instantActionsSize = NSSize(
        width: CGFloat(ShelfInstantActionLayout.panel.width),
        height: CGFloat(ShelfInstantActionLayout.panel.height)
    )

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
        self.onDrop = onDrop
        self.onChange = onChange
        self.onClose = onClose
        let size = Self.size(
            for: shelf.presentationState,
            empty: emptySize,
            compact: Self.compactSize(itemCount: shelf.items.count),
            detail: Self.detailSize(itemCount: shelf.items.count),
            docked: dockedSize
        )
        panel = ShelfPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        instantActionsPanel = ShelfPanel(
            contentRect: NSRect(
                origin: .zero,
                size: instantActionsSize
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        instantActionsHostingView = NSHostingView(
            rootView: InstantActionsRailView(
                store: store,
                onAction: { _ in }
            )
        )

        let view = ShelfView(
            store: store,
            onToggleDetail: {},
            onLayoutFadeOutCompleted: { _ in },
            onLayoutTargetMounted: { _ in },
            onLayoutFadeInCompleted: { _ in },
            onDock: {},
            onQuickLook: {},
            onAddClipboard: {},
            onRevealInFinder: { _ in },
            onAction: { _ in },
            onChange: onChange,
            onClose: onClose
        )
        hostingView = NSHostingView(rootView: view)
        let dropContainer = ShelfDropContainerView(
            frame: NSRect(origin: .zero, size: size)
        )
        self.dropContainer = dropContainer
        let dragSurface = ShelfWindowDragSurfaceView()
        self.dragSurface = dragSurface
        dragSurface.onHoverChanged = { [weak store] hovering in
            store?.isPointerInsideShelf = hovering
        }
        dragSurface.alwaysShowsHandleProvider = { [weak store] in
            store?.shelf.alwaysShowsIndicator ?? false
        }
        dragSurface.handleColorProvider = { [weak store] in
            guard let color = store?.shelf.colorTag, color != .none else {
                return .secondaryLabelColor
            }
            return color.indicatorNSColor
        }
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        dropContainer.wantsLayer = true
        dropContainer.layer?.backgroundColor = NSColor.clear.cgColor
        dropContainer.layer?.isOpaque = false
        dropContainer.layer?.masksToBounds = true
        dropContainer.setGlassCornerRadius(ShelfChromeStyle.cornerRadius(for: shelf.presentationState))
        dropContainer.onDropTargeted = { [weak store] targeted in
            store?.isReceivingDrop = targeted
        }
        dropContainer.onTargetedItemCount = { [weak store] count in
            store?.targetedItemCount = count
        }
        dropContainer.onImportingChanged = { [weak store] importing in
            if importing { store?.beginImport() } else { store?.endImport() }
        }
        dropContainer.onError = { [weak store] error in
            store?.errorMessage = error.localizedDescription
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
        dragSurface.showsHandleProvider = { [weak store] in
            guard let store else { return false }
            switch store.shelf.presentationState {
            case .empty, .compact, .instantActions:
                return true
            case .detail, .docked:
                return false
            }
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
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .none
        instantActionsHostingView.frame = NSRect(
            origin: .zero,
            size: instantActionsSize
        )
        instantActionsHostingView.autoresizingMask = [.width, .height]
        instantActionsHostingView.wantsLayer = true
        instantActionsHostingView.layer?.backgroundColor =
            NSColor.clear.cgColor
        instantActionsHostingView.layer?.isOpaque = false
        // The glass must be a real window-level sibling, not a representable
        // rasterized inside the SwiftUI accessory hosting view.
        let accessoryRoot = NSView(frame: NSRect(origin: .zero, size: instantActionsSize))
        instantActionsGlassView.frame = NSRect(
            x: 0, y: 0,
            width: instantActionsSize.width,
            height: ShelfInstantActionLayout.entryHitDiameter
        )
        instantActionsGlassView.autoresizingMask = [.width, .maxYMargin]
        accessoryRoot.addSubview(instantActionsGlassView)
        accessoryRoot.addSubview(instantActionsHostingView)
        instantActionsPanel.contentView = accessoryRoot
        instantActionsPanel.appearance = nil
        instantActionsPanel.backgroundColor = .clear
        instantActionsPanel.isOpaque = false
        instantActionsPanel.hasShadow = false
        instantActionsPanel.isFloatingPanel = true
        instantActionsPanel.becomesKeyOnlyIfNeeded = true
        instantActionsPanel.hidesOnDeactivate = false
        instantActionsPanel.level = .floating
        instantActionsPanel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]
        instantActionsPanel.isMovableByWindowBackground = false
        instantActionsPanel.acceptsMouseMovedEvents = true
        instantActionsPanel.animationBehavior = .none
        instantActionsPanel.isReleasedWhenClosed = false
        position(at: location ?? NSEvent.mouseLocation)

        hostingView.rootView = ShelfView(
            store: store,
            onToggleDetail: { [weak self] in self?.toggleDetail() },
            onLayoutFadeOutCompleted: { [weak self] transitionID in
                self?.completeLayoutFadeOut(for: transitionID)
            },
            onLayoutTargetMounted: { [weak self] transitionID in
                self?.layoutTargetDidMount(for: transitionID)
            },
            onLayoutFadeInCompleted: { [weak self] transitionID in
                self?.completeLayoutFadeIn(for: transitionID)
            },
            onDock: { [weak self] in self?.toggleDock() },
            onQuickLook: { [weak self] in self?.quickLookSelectedItems() },
            onAddClipboard: {
                onDrop(PasteboardReader.representations(from: .general))
            },
            onRevealInFinder: { [weak self] fileURLs in
                guard let self else { return }
                finderRevealController.reveal(
                    fileURLs,
                    from: panel
                )
            },
            onAction: { [weak self] action in self?.run(action) },
            onChange: onChange,
            onClose: { [weak self] in self?.requestClose() }
        )
        instantActionsHostingView.rootView = InstantActionsRailView(
            store: store,
            onAction: { [weak self] action in
                self?.performInstantAction(action)
            },
            onGlassLayout: { [weak self] count, expanded, reduceMotion, reduceTransparency in
                self?.instantActionsGlassView.isHidden = reduceTransparency
                self?.instantActionsGlassView.update(
                    count: count, expanded: expanded, reduceMotion: reduceMotion
                )
            }
        )
        installPanelObservers()
        refreshCollectionBehavior()
        installKeyMonitor()
        installOutsideMouseMonitor()
    }

    func show() {
        panel.orderFrontRegardless()
        updateInstantActionsPanel(
            for: store.shelf.presentationState
        )
    }

    func close() {
        closeWorkItem?.cancel()
        closeWorkItem = nil
        layoutTransitionRecoveryWorkItem?.cancel()
        layoutTransitionRecoveryWorkItem = nil
        activeLayoutTransition = nil
        compactFrameBeforeDetail = nil
        store.cancelLayoutTransition()
        removePanelObservers()
        dragSurface.setWindowActive(false, animated: false)
        dragSurface.stopHandleAnimations()
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let globalOutsideMouseMonitor {
            NSEvent.removeMonitor(globalOutsideMouseMonitor)
            self.globalOutsideMouseMonitor = nil
        }
        if let localOutsideMouseMonitor {
            NSEvent.removeMonitor(localOutsideMouseMonitor)
            self.localOutsideMouseMonitor = nil
        }
        hideInstantActionsPanel()
        instantActionsPanel.close()
        panel.orderOut(nil)
        panel.close()
    }

    func refreshSize() {
        refreshCollectionBehavior()
        dragSurface.refreshMotionPreference()
        guard activeLayoutTransition == nil else { return }
        let state = store.shelf.presentationState
        dropContainer.setGlassCornerRadius(
            ShelfChromeStyle.cornerRadius(for: state),
            duration: ShelfChromeStyle.surfaceMorphDuration(reduceMotion: reduceMotion)
        )
        resize(to: Self.size(
            for: state,
            empty: emptySize,
            compact: Self.compactSize(itemCount: store.shelf.items.count),
            detail: detailSize,
            docked: dockedSize
        ))
        updateInstantActionsPanel(for: state)
    }

    private func refreshCollectionBehavior() {
        let behavior: NSWindow.CollectionBehavior = store.shelf.keepsInOwnSpace == true
            ? [.fullScreenAuxiliary]
            : [.canJoinAllSpaces, .fullScreenAuxiliary]
        for window in [panel, instantActionsPanel] where window.collectionBehavior != behavior {
            window.collectionBehavior = behavior
        }
    }

    private func toggleDetail() {
        guard activeLayoutTransition == nil else { return }
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
        if targetState == .detail {
            compactFrameBeforeDetail = panel.frame
        }
        let targetFrame = detailTransitionTargetFrame(
            to: targetState,
            size: targetSize
        )
        let timing = detailTransitionTiming(to: targetState)
        beginLayoutTransition(
            to: targetState,
            dockedEdge: nil,
            targetFrame: targetFrame,
            timing: timing
        )
    }

    func beginLayoutTransition(
        to targetState: ShelfPresentationState,
        dockedEdge: DockedEdge?,
        targetFrame: CGRect,
        timing: ShelfLayoutTransitionTiming
    ) {
        guard activeLayoutTransition == nil else { return }
        let showsInstantActions = Self.showsInstantActionsPanel(
            for: targetState,
            hasItems: !store.shelf.items.isEmpty
        )
        if showsInstantActions {
            animateInstantActionsPanel(
                toShelfFrame: targetFrame,
                duration: timing.frameDuration
            )
        } else {
            hideInstantActionsPanel()
        }

        let transitionID = store.beginLayoutTransition(
            to: targetState,
            sourceSize: panel.frame.size,
            targetSize: targetFrame.size,
            contentFadeDuration: timing.contentFadeDuration
        )
        activeLayoutTransition = ActiveLayoutTransition(
            id: transitionID,
            targetState: targetState,
            dockedEdge: dockedEdge,
            targetFrame: targetFrame
        )
        instantActionsPanel.ignoresMouseEvents = true
        dropContainer.setGlassCornerRadius(
            ShelfChromeStyle.cornerRadius(for: targetState),
            duration: ShelfChromeStyle.surfaceMorphDuration(reduceMotion: reduceMotion)
        )
        animateFrame(
            to: targetFrame,
            duration: timing.frameDuration
        ) { [weak self] in
            self?.completeLayoutFrameAnimation(for: transitionID)
        }
        scheduleLayoutTransitionRecovery(
            for: transitionID,
            timing: timing
        )
    }

    func completeLayoutFadeOut(for transitionID: UUID) {
        guard let transition = activeLayoutTransition,
              transition.id == transitionID,
              !store.isLayoutContentVisible
        else { return }

        store.shelf.dockedEdge = transition.dockedEdge
        store.shelf.presentationState = transition.targetState
    }

    func layoutTargetDidMount(for transitionID: UUID) {
        guard let transition = activeLayoutTransition,
              transition.id == transitionID,
              store.shelf.presentationState == transition.targetState,
              !store.isLayoutContentVisible
        else { return }
        _ = store.revealLayoutContent(for: transitionID)
    }

    func completeLayoutFadeIn(for transitionID: UUID) {
        guard let transition = activeLayoutTransition,
              transition.id == transitionID,
              store.isLayoutContentVisible
        else { return }
        transition.didCompleteFadeIn = true
        finishLayoutTransitionIfReady(transitionID)
    }

    func completeLayoutFrameAnimation(for transitionID: UUID) {
        guard let transition = activeLayoutTransition,
              transition.id == transitionID
        else { return }
        transition.didCompleteFrame = true
        finishLayoutTransitionIfReady(transitionID)
    }

    private func finishLayoutTransitionIfReady(_ transitionID: UUID) {
        guard let transition = activeLayoutTransition,
              transition.id == transitionID,
              transition.didCompleteFrame,
              transition.didCompleteFadeIn
        else { return }

        finishFrame(to: transition.targetFrame)
        guard store.endLayoutTransition(for: transitionID) else { return }
        layoutTransitionRecoveryWorkItem?.cancel()
        layoutTransitionRecoveryWorkItem = nil
        activeLayoutTransition = nil
        if transition.targetState != .detail {
            compactFrameBeforeDetail = nil
        }
        updateInstantActionsPanel(for: transition.targetState)
        onChange()
    }

    private func scheduleLayoutTransitionRecovery(
        for transitionID: UUID,
        timing: ShelfLayoutTransitionTiming
    ) {
        layoutTransitionRecoveryWorkItem?.cancel()
        let delay = max(
            timing.frameDuration,
            timing.contentFadeDuration * 2
        ) + 0.5
        let workItem = DispatchWorkItem { [weak self] in
            self?.recoverLayoutTransitionIfNeeded(
                transitionID
            )
        }
        layoutTransitionRecoveryWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: workItem
        )
    }

    private func recoverLayoutTransitionIfNeeded(
        _ transitionID: UUID
    ) {
        guard let transition = activeLayoutTransition,
              transition.id == transitionID
        else { return }

        store.shelf.dockedEdge = transition.dockedEdge
        store.shelf.presentationState = transition.targetState
        finishFrame(to: transition.targetFrame)
        _ = store.revealLayoutContent(for: transitionID)
        guard store.endLayoutTransition(for: transitionID) else { return }
        layoutTransitionRecoveryWorkItem = nil
        activeLayoutTransition = nil
        if transition.targetState != .detail {
            compactFrameBeforeDetail = nil
        }
        updateInstantActionsPanel(for: transition.targetState)
        onChange()
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

    func performInstantAction(_ action: BuiltinActionID) {
        guard activeLayoutTransition == nil,
              !store.isClosing
        else { return }
        store.dismissInstantActions()
        run(action)
    }

    private func requestClose() {
        guard !store.isClosing else { return }
        store.isClosing = true
        hideInstantActionsPanel()

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

    @discardableResult
    private func presentActionMenu() -> Bool {
        guard !store.shelf.items.isEmpty else { return false }

        hostingView.layoutSubtreeIfNeeded()
        let point = NSPoint(
            x: hostingView.bounds.midX,
            y: hostingView.bounds.midY
        )
        let windowPoint = hostingView.convert(point, to: nil)
        guard let event = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: windowPoint,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        ) else { return false }

        var candidate = hostingView.hitTest(point)
        while let view = candidate {
            if let menu = view.menu(for: event) {
                DispatchQueue.main.async {
                    NSMenu.popUpContextMenu(
                        menu,
                        with: event,
                        for: view
                    )
                }
                return true
            }
            candidate = view.superview
        }
        return false
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard let self,
                  event.window === panel
                    || event.window === instantActionsPanel
            else { return event }
            guard let command = ShelfKeyboardCommand.resolve(
                characters: event.charactersIgnoringModifiers,
                keyCode: event.keyCode,
                modifierFlags: event.modifierFlags
            ) else { return event }
            let isEditingText = store.isCommandBarPresented
                || panel.firstResponder is NSTextView
            if isEditingText, !command.canHandleWhileEditingText {
                return event
            }

            switch command {
            case .commandBar:
                store.isCommandBarPresented.toggle()
                return nil
            case .close:
                requestClose()
                return nil
            case .dismiss:
                store.isCommandBarPresented = false
                if Self.shouldDismissInstantActions(
                    isPresented: store.isInstantActionsPresented,
                    triggeredByEscape: true,
                    isClickInsideShelfOrAccessory: true
                ) {
                    store.dismissInstantActions()
                }
                return nil
            case .actionMenu:
                presentActionMenu()
                return nil
            case .toggleDetail:
                toggleDetail()
                return nil
            case .quickLook:
                quickLookSelectedItems()
                return nil
            case .delete:
                let ids = store.selectedItemIDs.isEmpty
                    ? Set(store.shelf.items.map(\.id))
                    : store.selectedItemIDs
                store.remove(ids)
                onChange()
                return nil
            case .selectAll:
                store.selectedItemIDs = Set(store.shelf.items.map(\.id))
                return nil
            case .copy:
                return ShelfPasteboardWriter.write(
                    selectedItems,
                    to: .general
                ) ? nil : event
            case .paste:
                let representations = PasteboardReader.representations(
                    from: .general
                )
                guard !representations.isEmpty else { return event }
                onDrop(representations)
                return nil
            }
        }
    }

    private func installOutsideMouseMonitor() {
        let mouseDownEvents: NSEvent.EventTypeMask = [
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown
        ]
        globalOutsideMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: mouseDownEvents
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMouseClick(
                    isClickInsideShelfOrAccessory: false
                )
            }
        }
        localOutsideMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: mouseDownEvents
        ) { [weak self] event in
            guard let self else { return event }
            handleMouseClick(
                isClickInsideShelfOrAccessory:
                    event.window === panel
                        || event.window === instantActionsPanel
            )
            return event
        }
    }

    private func handleMouseClick(
        isClickInsideShelfOrAccessory: Bool
    ) {
        if Self.shouldDismissInstantActions(
            isPresented: store.isInstantActionsPresented,
            triggeredByEscape: false,
            isClickInsideShelfOrAccessory:
                isClickInsideShelfOrAccessory
        ) {
            store.dismissInstantActions()
        }
        collapseDetailAfterMouseClickIfNeeded(
            isClickInsideCurrentPanel:
                isClickInsideShelfOrAccessory
        )
    }

    static func shouldDismissInstantActions(
        isPresented: Bool,
        triggeredByEscape: Bool,
        isClickInsideShelfOrAccessory: Bool
    ) -> Bool {
        isPresented
            && (triggeredByEscape || !isClickInsideShelfOrAccessory)
    }

    private func collapseDetailAfterMouseClickIfNeeded(
        isClickInsideCurrentPanel: Bool
    ) {
        guard !store.isCustomizationPresented else { return }
        guard Self.shouldAutoCloseDetail(
            state: store.shelf.presentationState,
            isTransitioning: store.isLayoutTransitioning,
            preferenceEnabled: AppPreferences.autoCloseDetail(),
            isClickInsideCurrentPanel: isClickInsideCurrentPanel
        ) else { return }
        toggleDetail()
    }

    static func shouldAutoCloseDetail(
        state: ShelfPresentationState,
        isTransitioning: Bool,
        preferenceEnabled: Bool,
        isClickInsideCurrentPanel: Bool
    ) -> Bool {
        state == .detail
            && !isTransitioning
            && preferenceEnabled
            && !isClickInsideCurrentPanel
    }

    private func installPanelObservers() {
        let defaultCenter = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        observe(
            NSWindow.didBecomeKeyNotification,
            object: panel,
            in: defaultCenter
        ) { [weak self] in
            self?.dragSurface.setWindowActive(true, animated: true)
        }
        observe(
            NSWindow.didResignKeyNotification,
            object: panel,
            in: defaultCenter
        ) { [weak self] in
            self?.dragSurface.setWindowActive(false, animated: true)
        }
        observe(
            UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            in: defaultCenter
        ) { [weak self] in
            self?.dragSurface.refreshMotionPreference()
        }
        observe(
            NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            in: workspaceCenter
        ) { [weak self] in
            self?.dragSurface.refreshMotionPreference()
        }

        dragSurface.setWindowActive(panel.isKeyWindow, animated: false)
    }

    private func observe(
        _ name: Notification.Name,
        object: Any?,
        in center: NotificationCenter,
        action: @escaping @MainActor () -> Void
    ) {
        let token = center.addObserver(
            forName: name,
            object: object,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                action()
            }
        }
        panelObservers.append(
            ShelfNotificationObservation(center: center, token: token)
        )
    }

    private func removePanelObservers() {
        for observer in panelObservers {
            observer.cancel()
        }
        panelObservers.removeAll()
    }

    private var selectedItems: [ShelfItemRecord] {
        store.selectedItemIDs.isEmpty
            ? store.shelf.items
            : store.shelf.items.filter {
                store.selectedItemIDs.contains($0.id)
            }
    }

    private func toggleDock() {
        guard activeLayoutTransition == nil else { return }
        if store.shelf.presentationState == .docked {
            let targetState: ShelfPresentationState =
                store.shelf.items.isEmpty ? .empty : .compact
            let targetSize = Self.size(
                for: targetState,
                empty: emptySize,
                compact: Self.compactSize(
                    itemCount: store.shelf.items.count
                ),
                detail: detailSize,
                docked: dockedSize
            )
            beginLayoutTransition(
                to: targetState,
                dockedEdge: nil,
                targetFrame: centeredFrame(
                    to: targetSize,
                    reservingInstantActionsSpace:
                        Self.showsInstantActionsPanel(
                            for: targetState,
                            hasItems: !store.shelf.items.isEmpty
                        )
                ),
                timing: edgeTransitionTiming
            )
            return
        }

        let screen = panel.screen ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let edge: DockedEdge =
            panel.frame.midX < visible.midX ? .left : .right
        beginLayoutTransition(
            to: .docked,
            dockedEdge: edge,
            targetFrame: ShelfPanelGeometry.dockedFrame(
                from: panel.frame,
                to: dockedSize,
                edge: edge,
                constrainedTo: visible
            ),
            timing: edgeTransitionTiming
        )
    }

    private func resize(to size: NSSize) {
        animateFrame(
            to: centeredFrame(
                to: size,
                reservingInstantActionsSpace:
                    Self.showsInstantActionsPanel(
                        for: store.shelf.presentationState,
                        hasItems: !store.shelf.items.isEmpty
                    )
            ),
            duration: layoutTransitionTiming.frameDuration
        )
    }

    private func centeredFrame(
        to size: NSSize,
        reservingInstantActionsSpace: Bool,
        screenMargin: CGFloat = 0
    ) -> CGRect {
        centeredFrame(
            from: panel.frame,
            to: size,
            reservingInstantActionsSpace: reservingInstantActionsSpace,
            screenMargin: screenMargin
        )
    }

    private func centeredFrame(
        from referenceFrame: CGRect,
        to size: NSSize,
        reservingInstantActionsSpace: Bool,
        screenMargin: CGFloat = 0
    ) -> CGRect {
        let visibleFrame = (panel.screen ?? NSScreen.main)?.visibleFrame
        let constrainedVisibleFrame = visibleFrame?.insetBy(
            dx: screenMargin,
            dy: screenMargin
        )
        var frame = ShelfPanelGeometry.centeredFrame(
            from: referenceFrame,
            to: size,
            constrainedTo: constrainedVisibleFrame
        )
        if reservingInstantActionsSpace, let visibleFrame {
            let minimumY = visibleFrame.minY + instantActionsSize.height
            frame.origin.y = min(
                max(frame.minY, minimumY),
                visibleFrame.maxY - frame.height
            )
        }
        return frame
    }

    private func detailTransitionTargetFrame(
        to targetState: ShelfPresentationState,
        size: NSSize
    ) -> CGRect {
        let reservesInstantActionsSpace =
            Self.showsInstantActionsPanel(
                for: targetState,
                hasItems: !store.shelf.items.isEmpty
            )
        if targetState == .compact,
           let compactFrameBeforeDetail
        {
            return centeredFrame(
                from: compactFrameBeforeDetail,
                to: size,
                reservingInstantActionsSpace:
                    reservesInstantActionsSpace,
                screenMargin: 20
            )
        }
        return centeredFrame(
            to: size,
            reservingInstantActionsSpace: reservesInstantActionsSpace,
            screenMargin: 20
        )
    }

    private func updateInstantActionsPanel(
        for state: ShelfPresentationState
    ) {
        guard !store.isClosing,
              Self.showsInstantActionsPanel(
            for: state,
            hasItems: !store.shelf.items.isEmpty
        ),
              panel.isVisible
        else {
            hideInstantActionsPanel()
            return
        }

        instantActionsPanel.setFrame(
            Self.instantActionsFrame(below: panel.frame),
            display: true
        )
        instantActionsPanel.ignoresMouseEvents = false
        if instantActionsPanel.parent !== panel {
            panel.addChildWindow(instantActionsPanel, ordered: .above)
        }
        instantActionsPanel.orderFrontRegardless()
    }

    private func hideInstantActionsPanel() {
        store.dismissInstantActions()
        if instantActionsPanel.parent === panel {
            panel.removeChildWindow(instantActionsPanel)
        }
        instantActionsPanel.orderOut(nil)
    }

    private func animateInstantActionsPanel(
        toShelfFrame shelfFrame: CGRect,
        duration: TimeInterval
    ) {
        guard instantActionsPanel.isVisible else { return }
        if instantActionsPanel.parent === panel {
            panel.removeChildWindow(instantActionsPanel)
        }
        let targetFrame = Self.instantActionsFrame(below: shelfFrame)
        guard duration > 0 else {
            instantActionsPanel.setFrame(targetFrame, display: true)
            instantActionsPanel.orderFrontRegardless()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(
                name: Self.frameMorphTimingFunctionName
            )
            instantActionsPanel.animator().setFrame(
                targetFrame,
                display: true
            )
        }
        instantActionsPanel.orderFrontRegardless()
    }

    private func animateFrame(
        to frame: CGRect,
        duration: TimeInterval,
        completion: (@MainActor @Sendable () -> Void)? = nil
    ) {
        guard panel.frame != frame else {
            completion?()
            return
        }
        guard duration > 0 else {
            panel.setFrame(frame, display: true)
            completion?()
            return
        }

        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(
                    name: Self.frameMorphTimingFunctionName
                )
                panel.animator().setFrame(frame, display: true)
            },
            completionHandler: {
                Task { @MainActor in
                    completion?()
                }
            }
        )
    }

    private func finishFrame(to frame: CGRect) {
        guard panel.frame != frame else { return }
        panel.setFrame(frame, display: true)
    }

    private var layoutTransitionTiming: ShelfLayoutTransitionTiming {
        ShelfLayoutTransitionTiming.resolve(
            profile: .reference,
            reduceMotion: reduceMotion
        )
    }

    private func detailTransitionTiming(
        to targetState: ShelfPresentationState
    ) -> ShelfLayoutTransitionTiming {
        let profile = ShelfMotionProfile.reference
        let duration = targetState == .detail
            ? profile.detailExpandDuration
            : profile.frameMorphDuration
        return ShelfLayoutTransitionTiming.resolve(
            profile: profile,
            reduceMotion: reduceMotion,
            frameDuration: duration
        )
    }

    private var edgeTransitionTiming: ShelfLayoutTransitionTiming {
        layoutTransitionTiming
            .delayingContentSwapUntilFrameSettles()
    }

    private var reduceMotion: Bool {
        AppPreferences.reduceMotion()
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func position(at point: CGPoint) {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let x = min(max(point.x - panel.frame.width / 2, visible.minX), visible.maxX - panel.frame.width)
        let desiredY = point.y - panel.frame.height - 18
        let accessoryClearance = Self.showsInstantActionsPanel(
            for: store.shelf.presentationState,
            hasItems: !store.shelf.items.isEmpty
        ) ? instantActionsSize.height : 0
        let y = min(
            max(desiredY, visible.minY + accessoryClearance),
            visible.maxY - panel.frame.height
        )
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    static func instantActionsFrame(
        below shelfFrame: CGRect
    ) -> CGRect {
        let size = CGSize(
            width: ShelfInstantActionLayout.panel.width,
            height: ShelfInstantActionLayout.panel.height
        )
        return CGRect(
            x: shelfFrame.midX - size.width / 2,
            y: shelfFrame.minY - size.height,
            width: size.width,
            height: size.height
        )
    }

    static func showsInstantActionsPanel(
        for state: ShelfPresentationState,
        hasItems: Bool
    ) -> Bool {
        guard hasItems else { return false }
        return switch state {
        case .compact, .detail, .instantActions:
            true
        case .empty, .docked:
            false
        }
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

    private static func detailSize(itemCount: Int) -> NSSize {
        let metrics = ShelfDetailLayout.panelMetrics(itemCount: itemCount)
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

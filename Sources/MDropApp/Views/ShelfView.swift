import AppKit
import MDropCore
import SwiftUI

struct ShelfView: View {
    @Bindable var store: ShelfStore
    let onToggleDetail: () -> Void
    let onLayoutFadeOutCompleted: (UUID) -> Void
    let onLayoutTargetMounted: (UUID) -> Void
    let onLayoutFadeInCompleted: (UUID) -> Void
    let onDock: () -> Void
    let onQuickLook: () -> Void
    let onAddClipboard: () -> Void
    let onRevealInFinder: ([URL]) -> Void
    let onAction: (BuiltinActionID) -> Void
    let onChange: () -> Void
    let onClose: () -> Void
    @Namespace private var glassNamespace
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(AppPreferences.reduceMotionKey)
    private var reduceShelfMotion = false
    @State private var languageController =
        AppLanguageController.shared
    @State private var hasStartedEntrance = false
    @State private var surfaceScaleX: CGFloat = 0.985
    @State private var surfaceScaleY: CGFloat = 0.985
    @State private var surfaceOpacity: CGFloat = 0
    @State private var entranceContentOpacity: CGFloat = 1
    @State private var entranceContentScale: CGFloat = 1
    @State private var layoutContentOpacity: CGFloat = 1
    @State private var layoutAnimationGeneration = UUID()

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            ZStack {
                shelfContent
                    .id(store.shelf.presentationState)
                    .frame(
                        width: transitionContentSize?.width,
                        height: transitionContentSize?.height
                    )
                    .opacity(resolvedContentOpacity * (store.isReceivingDrop || store.isImporting ? 0.16 : 1))
                    .animation(reduceMotion ? .easeOut(duration: 0.1) : .smooth(duration: 0.18), value: store.isReceivingDrop)
                    .animation(.easeOut(duration: 0.15), value: store.isImporting)
                    .scaleEffect(resolvedContentScale)
                    .allowsHitTesting(!store.isLayoutTransitioning && !store.isReceivingDrop && !store.isImporting)
                    .task(id: store.shelf.presentationState) {
                        // The surrounding host survives .id changes. Re-run for every
                        // mounted layout instead of waiting for the recovery timer.
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        notifyLayoutTargetMountedIfNeeded()
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(
                .rect(cornerRadius: animatedCornerRadius)
            )
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: animatedCornerRadius)
                        .fill(Color(nsColor: .windowBackgroundColor))
                }
            }
            .glassEffect(
                .regular,
                in: .rect(cornerRadius: animatedCornerRadius)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: animatedCornerRadius,
                    style: .continuous
                )
            )
            .glassEffectID(
                store.shelf.id,
                in: glassNamespace
            )
            .animation(
                surfaceMorphAnimation,
                value: surfacePresentationState
            )
            .scaleEffect(
                x: resolvedSurfaceScaleX,
                y: resolvedSurfaceScaleY
            )
            .opacity(resolvedSurfaceOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(store.isClosing ? 0 : 1)
        .task {
            await runEntrance()
        }
        .onAppear {
            layoutContentOpacity =
                store.isLayoutContentVisible ? 1 : 0
        }
        .onChange(of: store.isLayoutContentVisible) { _, isVisible in
            animateLayoutContent(isVisible: isVisible)
        }
        .animation(
            reduceMotion
                ? .linear(duration: 0.01)
                : .easeOut(
                    duration: ShelfMotionProfile.reference.closeDuration
                ),
            value: store.isClosing
        )
        .animation(
            reduceMotion
                ? .linear(duration: 0.01)
                : .easeOut(duration: 0.12),
            value: store.isReceivingDrop
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: animatedCornerRadius,
                style: .continuous
            )
            .stroke(
                .primary.opacity(
                    ShelfChromeStyle.outerStrokeOpacity
                ),
                lineWidth: ShelfChromeStyle.outerStrokeWidth
            )
            .scaleEffect(
                x: resolvedSurfaceScaleX,
                y: resolvedSurfaceScaleY
            )
            .opacity(resolvedSurfaceOpacity)
            .allowsHitTesting(false)
        }
        .overlay {
            if colorSchemeContrast == .increased {
                RoundedRectangle(
                    cornerRadius: animatedCornerRadius,
                    style: .continuous
                )
                .stroke(.white.opacity(0.46), lineWidth: 1.25)
                .scaleEffect(
                    x: resolvedSurfaceScaleX,
                    y: resolvedSurfaceScaleY
                )
                .opacity(resolvedSurfaceOpacity)
                .allowsHitTesting(false)
            }
        }
        .overlay {
            ShelfDropFeedbackView(store: store, cornerRadius: animatedCornerRadius)
                .allowsHitTesting(false)
        }
        .task(id: store.dropReceipt?.id) {
            guard let receipt = store.dropReceipt else { return }
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            store.clearDropReceipt(id: receipt.id)
        }
        .alert(
            "MDrop",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .overlay {
            ZStack {
                if store.isCommandBarPresented {
                    CommandBarView(
                        store: store,
                        onAction: onAction
                    )
                    .transition(commandBarTransition)
                    .padding(18)
                }
            }
            .animation(
                overlayAnimation,
                value: store.isCommandBarPresented
            )
        }
        .overlay(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                if let progress = store.actionProgress {
                    HStack(spacing: 10) {
                        ProgressView(value: progress)
                            .frame(width: 150)
                        if let cancel = store.cancelAction {
                            Button("Cancel", action: cancel)
                                .buttonStyle(.glass)
                        }
                    }
                    .padding(10)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 16)
                    .accessibilityLabel("Action progress")
                    .transition(progressHUDTransition)
                }
            }
            .animation(
                overlayAnimation,
                value: store.actionProgress != nil
            )
        }
        .environment(languageController)
        .environment(\.locale, languageController.locale)
    }

    @ViewBuilder
    private var shelfContent: some View {
        switch store.shelf.presentationState {
        case .empty:
            EmptyShelfView(
                store: store,
                isReceivingDrop: store.isReceivingDrop,
                onClose: onClose
            )
            .transition(
                .opacity.combined(with: .scale(scale: 0.985))
            )
        case .detail:
            ShelfDetailView(
                store: store,
                onCollapse: onToggleDetail,
                onDock: onDock,
                onQuickLook: onQuickLook,
                onAddClipboard: onAddClipboard,
                onRevealInFinder: onRevealInFinder,
                onAction: onAction,
                onChange: onChange,
                onClose: onClose
            )
        case .docked:
            DockedShelfView(
                store: store,
                onUndock: onDock,
                onClose: onClose
            )
        case .compact, .instantActions:
            CompactStackedShelfView(
                store: store,
                onExpand: onToggleDetail,
                onDock: onDock,
                onQuickLook: onQuickLook,
                onAddClipboard: onAddClipboard,
                onRevealInFinder: onRevealInFinder,
                onAction: onAction,
                onChange: onChange,
                onClose: onClose
            )
            .transition(
                .opacity.combined(with: .scale(scale: 0.985))
            )
        }
    }

    private var reduceMotion: Bool {
        reduceShelfMotion
            || systemReduceMotion
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }


    private var resolvedSurfaceScaleX: CGFloat {
        store.animatesInitialAppearance && !reduceMotion
            ? surfaceScaleX
            : 1
    }

    private var resolvedSurfaceScaleY: CGFloat {
        store.animatesInitialAppearance && !reduceMotion
            ? surfaceScaleY
            : 1
    }

    private var resolvedSurfaceOpacity: CGFloat {
        store.animatesInitialAppearance ? surfaceOpacity : 1
    }

    private var resolvedContentOpacity: CGFloat {
        let entranceOpacity = store.animatesInitialAppearance
            ? entranceContentOpacity
            : 1
        return entranceOpacity * layoutContentOpacity
    }

    private var resolvedContentScale: CGFloat {
        let entranceScale = store.animatesInitialAppearance
            ? entranceContentScale
            : 1
        return entranceScale
    }

    private var animatedCornerRadius: CGFloat {
        glassCornerRadius
    }

    private var surfacePresentationState: ShelfPresentationState {
        store.pendingPresentationState
            ?? store.shelf.presentationState
    }

    private var transitionContentSize: CGSize? {
        guard store.isLayoutTransitioning else { return nil }
        if store.shelf.presentationState
            == store.pendingPresentationState
        {
            return store.layoutTargetSize
        }
        return store.layoutSourceSize
    }

    private var layoutVisibilityAnimation: Animation {
        return reduceMotion
            ? .linear(
                duration: store.layoutContentFadeDuration
            )
            : .easeInOut(
                duration: store.layoutContentFadeDuration
            )
    }

    private var surfaceMorphAnimation: Animation {
        let duration = ShelfChromeStyle.surfaceMorphDuration(reduceMotion: reduceMotion)
        return reduceMotion ? .linear(duration: duration) : .easeInOut(duration: duration)
    }

    private var overlayAnimation: Animation {
        reduceMotion
            ? .linear(duration: 0.10)
            : .smooth(duration: 0.18)
    }

    @MainActor
    private func animateLayoutContent(isVisible: Bool) {
        guard let transitionID = store.layoutTransitionID else {
            layoutContentOpacity = isVisible ? 1 : 0
            return
        }

        let generation = UUID()
        layoutAnimationGeneration = generation

        withAnimation(
            layoutVisibilityAnimation,
            completionCriteria: .logicallyComplete
        ) {
            layoutContentOpacity = isVisible ? 1 : 0
        } completion: {
            guard layoutAnimationGeneration == generation else { return }
            if isVisible {
                onLayoutFadeInCompleted(transitionID)
            } else {
                onLayoutFadeOutCompleted(transitionID)
            }
        }
    }

    @MainActor
    private func notifyLayoutTargetMountedIfNeeded() {
        guard store.isLayoutTransitioning,
              !store.isLayoutContentVisible,
              store.shelf.presentationState
                == store.pendingPresentationState,
              let transitionID = store.layoutTransitionID
        else { return }
        onLayoutTargetMounted(transitionID)
    }

    private var commandBarTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: 0.985)
                .combined(with: .opacity)
    }

    private var progressHUDTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .move(edge: .bottom)
                .combined(with: .opacity)
    }

    @MainActor
    private func runEntrance() async {
        guard !hasStartedEntrance else { return }
        hasStartedEntrance = true

        guard store.animatesInitialAppearance else {
            surfaceScaleX = 1
            surfaceScaleY = 1
            surfaceOpacity = 1
            entranceContentOpacity = 1
            entranceContentScale = 1
            return
        }

        await Task.yield()
        if reduceMotion {
            withAnimation(
                .linear(
                    duration:
                        ShelfMotionProfile.reference.reducedMotionDuration
                )
            ) {
                surfaceOpacity = 1
                entranceContentOpacity = 1
            }
            surfaceScaleX = 1
            surfaceScaleY = 1
            entranceContentScale = 1
            return
        }

        withAnimation(
            .easeOut(
                duration:
                    ShelfMotionProfile.reference.appearanceDuration
            )
        ) {
            surfaceScaleX = 1
            surfaceScaleY = 1
            surfaceOpacity = 1
            entranceContentOpacity = 1
            entranceContentScale = 1
        }
    }

    private var glassCornerRadius: CGFloat {
        ShelfChromeStyle.cornerRadius(for: surfacePresentationState)
    }

}

private struct EmptyShelfView: View {
    @Bindable var store: ShelfStore
    let isReceivingDrop: Bool
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Text(
                store.instantActionPreviewTitle
                    ?? AppLocalization.string("Drop files here")
            )
                .font(
                    .system(
                        size: ShelfMotionProfile.reference.emptyLabelPointSize,
                        weight: .medium,
                        design: .rounded
                    )
                )
                .foregroundStyle(.secondary)

            emptyChrome
                .opacity(showsChrome ? 1 : 0)
                .allowsHitTesting(showsChrome)
                .accessibilityHidden(!showsChrome)
                .animation(
                    .easeOut(duration: ShelfMotionProfile.reference.hoverChromeDuration),
                    value: showsChrome
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(
            .rect(
                cornerRadius:
                    ShelfMotionProfile.reference.emptyCornerRadius
            )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Empty MDrop Shelf")
    }

    private var emptyChrome: some View {
        ZStack {
            VStack {
                HStack {
                    Button(action: onClose) {
                        ShelfCircleControlLabel(systemName: "xmark")
                    }
                    .buttonStyle(ShelfControlButtonStyle())
                    .help("Close Shelf")
                    .accessibilityLabel("Close Shelf")

                    Spacer()
                }
                Spacer()
            }
            .padding(
                ShelfMotionProfile.reference.controlCenterInset
                    - ShelfMotionProfile.reference.controlDiameter / 2
            )
        }
    }

    private var showsChrome: Bool {
        store.isPointerInsideShelf && !isReceivingDrop
    }
}

struct ShelfCircleControlLabel: View {
    let systemName: String
    var externallyHovered: Bool? = nil
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(AppPreferences.reduceMotionKey) private var reduceShelfMotion = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: ShelfMotionProfile.reference.controlIconPointSize, weight: .medium))
            .foregroundStyle(.primary.opacity(0.86))
            .frame(
                width: ShelfMotionProfile.reference.controlDiameter,
                height: ShelfMotionProfile.reference.controlDiameter
            )
            .modifier(ShelfGlassSurface(shape: Circle(), interactive: true))
            .contentShape(.circle)
            .scaleEffect(externallyHovered == true && !systemReduceMotion && !reduceShelfMotion ? 1.025 : 1)
            .animation(systemReduceMotion || reduceShelfMotion ? nil : .spring(response: 0.28, dampingFraction: 0.84), value: externallyHovered)
    }
}

struct ShelfCircleMenu<Content: View>: View {
    let systemName: String
    let accessibilityLabel: String
    private let content: Content
    @State private var isHovering = false

    init(
        systemName: String,
        accessibilityLabel: String,
        @ViewBuilder content: () -> Content
    ) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.content = content()
    }

    @State private var isPresented = false

    var body: some View {
        Button { isPresented.toggle() } label: {
            ShelfCircleControlLabel(
                systemName: systemName,
                externallyHovered: isHovering || isPresented
            )
        }
        .buttonStyle(ShelfControlButtonStyle())
        .onHover { isHovering = $0 }
        .help(accessibilityLabel)
        .accessibilityLabel(accessibilityLabel)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    content
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .padding(10)
            .scrollBounceBehavior(.basedOnSize)
            .frame(
                width: 296,
                height: min(560, max(240, (NSScreen.main?.visibleFrame.height ?? 800) - 160))
            )
            .buttonStyle(ShelfPopoverRowStyle { isPresented = false })
            .environment(\.shelfUsesActionPopover, true)
            .onKeyPress(.escape) { isPresented = false; return .handled }
        }
    }
}

private struct ShelfDetailView: View {
    @Bindable var store: ShelfStore
    let onCollapse: () -> Void
    let onDock: () -> Void
    let onQuickLook: () -> Void
    let onAddClipboard: () -> Void
    let onRevealInFinder: ([URL]) -> Void
    let onAction: (BuiltinActionID) -> Void
    let onChange: () -> Void
    let onClose: () -> Void
    @State private var fileMetadata: [UUID: ShelfFileMetadata] = [:]
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(AppPreferences.reduceMotionKey)
    private var reduceShelfMotion = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onCollapse) {
                    ShelfCircleControlLabel(
                        systemName: "chevron.left"
                    )
                }
                .buttonStyle(ShelfControlButtonStyle())
                .help("Back to Compact Shelf")
                .accessibilityLabel("Back to Compact Shelf")

                VStack(alignment: .leading, spacing: 1) {
                    Text(detailTitle)
                        .font(.system(size: 13, weight: .semibold))
                    Text(sizeSummary)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)

                Spacer()

                ShelfCustomizationButton(store: store, onChange: onChange)

                ShelfDetailModePicker(selection: $store.detailViewMode)
            }
            .padding(
                .horizontal,
                CGFloat(ShelfDetailLayout.headerHorizontalInset)
            )
            .padding(
                .top,
                CGFloat(ShelfDetailLayout.headerTopInset)
            )
            .padding(.bottom, 6)

            detailContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contextMenu { detailActionsMenu }
        .task(id: store.shelf.items) {
            let items = store.shelf.items
            let currentIDs = Set(items.map(\.id))
            fileMetadata = fileMetadata.filter {
                currentIDs.contains($0.key)
            }
            while !Task.isCancelled {
                let loadedMetadata = await ShelfFileMetadataLoader.metadata(
                    for: items
                )
                guard !Task.isCancelled else { return }
                fileMetadata = loadedMetadata
                do {
                    try await Task.sleep(
                        for: ShelfFileMetadataLoader.refreshInterval
                    )
                } catch {
                    return
                }
            }
        }
    }

    private var detailContent: some View {
        let selectedDragItems = store.shelf.items.filter {
            store.selectedItemIDs.contains($0.id)
        }
        return ZStack {
            if store.detailViewMode == .grid {
                ScrollView(.vertical) {
                    LazyVGrid(
                        columns: detailGridColumns,
                        alignment: .leading,
                        spacing: CGFloat(
                            ShelfDetailLayout.gridRowSpacing
                        )
                    ) {
                        ForEach(store.shelf.items) { item in
                            detailGridItem(
                                item,
                                selectedDragItems: selectedDragItems
                            )
                        }

                        revealInFinderTile
                    }
                    .padding(
                        .horizontal,
                        CGFloat(
                            ShelfDetailLayout.contentHorizontalInset
                        )
                    )
                    .padding(
                        .vertical,
                        CGFloat(ShelfDetailLayout.contentVerticalInset)
                    )
                }
                .scrollIndicators(.hidden)
                .transition(detailModeTransition)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(store.shelf.items) { item in
                            detailListItem(
                                item,
                                selectedDragItems: selectedDragItems
                            )
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
                .transition(detailModeTransition)
            }
        }
        .animation(detailModeAnimation, value: store.detailViewMode)
    }

    private var revealInFinderTile: some View {
        Button(action: revealInFinder) {
            VStack(spacing: 7) {
                Image(systemName: "arrowshape.turn.up.right.circle")
                    .font(
                        .system(
                            size: CGFloat(
                                ShelfDetailLayout.revealSymbolPointSize
                            ),
                            weight: .light
                        )
                    )
                Text("Reveal in Finder")
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .foregroundStyle(.secondary)
            .frame(
                width: CGFloat(ShelfDetailLayout.gridTileWidth),
                height: CGFloat(ShelfDetailLayout.gridTileHeight),
                alignment: .center
            )
            .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(fileURLs.isEmpty)
        .help("Reveal in Finder")
    }

    private var detailActionsMenu: some View {
        Group {
            ShelfMenuContent(
                store: store,
                onDock: onDock,
                onQuickLook: onQuickLook,
                onAddClipboard: onAddClipboard,
                onRevealInFinder: onRevealInFinder,
                onAction: onAction,
                onChange: onChange
            )
            Divider()
            Button("Close Shelf", systemImage: "xmark", role: .destructive) {
                onClose()
            }
        }
    }

    private func detailGridItem(
        _ item: ShelfItemRecord,
        selectedDragItems: [ShelfItemRecord]
    ) -> some View {
        VStack(spacing: 2) {
            ShelfThumbnailView(
                item: item,
                size: CGSize(
                    width: CGFloat(
                        ShelfDetailLayout.thumbnailMaximum.width
                    ),
                    height: CGFloat(
                        ShelfDetailLayout.thumbnailMaximum.height
                    )
                )
            )
            Text(item.displayName)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: CGFloat(ShelfDetailLayout.gridTileWidth))
            Text(sizeSummary(for: item))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let secondaryMetadata = secondaryMetadata(for: item) {
                Text(secondaryMetadata)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .frame(
            width: CGFloat(ShelfDetailLayout.gridTileWidth),
            height: CGFloat(ShelfDetailLayout.gridTileHeight),
            alignment: .top
        )
        .background(
            store.selectedItemIDs.contains(item.id)
                ? Color.accentColor.opacity(
                    ShelfChromeStyle.selectionOpacity
                )
                : .clear,
            in: .rect(cornerRadius: 10)
        )
        .contentShape(.rect)
        .overlay {
            itemDragSource(item, selectedItems: selectedDragItems)
        }
        .contextMenu {
            Button("Copy Path") {
                if let url = item.fileURL {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        url.path,
                        forType: .string
                    )
                }
            }
            Button("Remove", role: .destructive) {
                store.remove([item.id])
                onChange()
            }
        }
    }

    private func detailListItem(
        _ item: ShelfItemRecord,
        selectedDragItems: [ShelfItemRecord]
    ) -> some View {
        HStack(spacing: 10) {
            ShelfThumbnailView(
                item: item,
                size: CGSize(width: 20, height: 28)
            )
            .frame(width: 28, height: 30)

            Text(item.displayName)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Text(sizeSummary(for: item))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let secondaryMetadata = secondaryMetadata(for: item) {
                    Text(secondaryMetadata)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 19)
        .padding(.vertical, 6)
        .background(
            store.selectedItemIDs.contains(item.id)
                ? Color.accentColor.opacity(
                    ShelfChromeStyle.selectionOpacity
                )
                : .clear,
            in: .rect(cornerRadius: 10)
        )
        .contentShape(.rect)
        .overlay {
            itemDragSource(item, selectedItems: selectedDragItems)
        }
        .contextMenu {
            Button("Copy Path") {
                if let url = item.fileURL {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        url.path,
                        forType: .string
                    )
                }
            }
            Button("Remove", role: .destructive) {
                store.remove([item.id])
                onChange()
            }
        }
    }

    private func itemDragSource(
        _ item: ShelfItemRecord,
        selectedItems: [ShelfItemRecord]
    ) -> some View {
        ShelfItemsDragSourceView(
            items: dragItems(startingWith: item, selectedItems: selectedItems),
            onDraggingChanged: { _ in },
            onDragCompleted: handleDragCompletion,
            onClick: { modifiers in
                store.toggleSelection(item.id, extending: modifiers.contains(.command))
            },
            onDoubleClick: {
                if let url = item.fileURL { onRevealInFinder([url]) }
            }
        )
        .accessibilityLabel(item.displayName)
        .accessibilityAddTraits(store.selectedItemIDs.contains(item.id) ? .isSelected : [])
    }

    private var detailTitle: String {
        let count = store.shelf.items.count
        return count == 1
            ? AppLocalization.string("1 Document")
            : AppLocalization.format(
                "%lld Documents",
                Int64(count)
            )
    }

    private var fileURLs: [URL] {
        store.shelf.items.compactMap(\.fileURL)
    }

    private var detailGridColumns: [GridItem] {
        Array(
            repeating: GridItem(
                .fixed(CGFloat(ShelfDetailLayout.gridTileWidth)),
                spacing: CGFloat(ShelfDetailLayout.gridColumnSpacing),
                alignment: .top
            ),
            count: ShelfDetailLayout.gridColumnCount
        )
    }

    private var sizeSummary: String {
        guard fileMetadata.count == store.shelf.items.count else {
            return "—"
        }
        let totalByteCount = fileMetadata.values.reduce(Int64.zero) {
            $0 + $1.byteCount
        }
        return totalByteCount.formatted(
            .byteCount(style: .file).locale(AppLocalization.selectedLanguage.locale)
        )
    }

    private func sizeSummary(for item: ShelfItemRecord) -> String {
        guard let metadata = fileMetadata[item.id] else {
            return "—"
        }
        return metadata.byteCount.formatted(
            .byteCount(style: .file).locale(AppLocalization.selectedLanguage.locale)
        )
    }

    private func secondaryMetadata(
        for item: ShelfItemRecord
    ) -> String? {
        guard let pageCount = fileMetadata[item.id]?.pdfPageCount else {
            return nil
        }
        return pageCount == 1
            ? AppLocalization.string("1 page")
            : AppLocalization.format(
                "%lld pages",
                Int64(pageCount)
            )
    }

    private func dragItems(
        startingWith item: ShelfItemRecord,
        selectedItems: [ShelfItemRecord]
    ) -> [ShelfItemRecord] {
        store.selectedItemIDs.contains(item.id)
            ? selectedItems
            : [item]
    }

    private func handleDragCompletion(
        _ completion: ShelfItemsDragCompletion
    ) {
        let action = ShelfItemsDragBehavior.completionAction(
            shelfItemIDs: store.shelf.items.map(\.id),
            completion: completion
        )
        switch action {
        case .none:
            break
        case let .remove(itemIDs):
            store.remove(itemIDs)
            onChange()
        case let .close(itemIDs):
            store.remove(itemIDs)
            onClose()
        }
    }

    private func revealInFinder() {
        onRevealInFinder(fileURLs)
    }

    private var reduceMotion: Bool {
        reduceShelfMotion
            || systemReduceMotion
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private var detailModeTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.985))
    }

    private var detailModeAnimation: Animation {
        reduceMotion
            ? .linear(duration: 0.10)
            : .smooth(duration: 0.18)
    }
}

private struct ShelfDetailModePicker: View {
    @Binding var selection: ShelfDetailViewMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(AppPreferences.reduceMotionKey)
    private var reduceShelfMotion = false
    @Namespace private var glassNamespace
    @State private var hoveredMode: ShelfDetailViewMode?

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                modeButton(.grid, systemName: "square.grid.2x2")
                modeButton(.list, systemName: "list.bullet")
            }
            .frame(
                width: CGFloat(ShelfDetailLayout.modePicker.width),
                height: CGFloat(ShelfDetailLayout.modePicker.height)
            )
            .glassEffect(.regular, in: .capsule)
            .clipShape(Capsule())
        }
        .frame(
            width: CGFloat(ShelfDetailLayout.modePicker.width),
            height: CGFloat(ShelfDetailLayout.modePicker.height)
        )
        .animation(selectionAnimation, value: selection)
        .animation(hoverAnimation, value: hoveredMode)
    }

    private func modeButton(
        _ mode: ShelfDetailViewMode,
        systemName: String
    ) -> some View {
        Button {
            selection = mode
        } label: {
            ZStack {
                if hoveredMode == mode, selection != mode {
                    Circle()
                        .glassEffect(
                            .regular
                                .tint(hoveredSurfaceColor)
                                .interactive(),
                            in: .circle
                        )
                        .glassEffectID("mode-hover", in: glassNamespace)
                        .padding(1)
                }

                if selection == mode {
                    Circle()
                        .glassEffect(
                            .regular
                                .tint(selectedSurfaceColor)
                                .interactive(),
                            in: .circle
                        )
                        .glassEffectID(
                            "mode-selection",
                            in: glassNamespace
                        )
                        .padding(1)
                }

                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.78))
            }
            .frame(
                width: CGFloat(ShelfDetailLayout.modePicker.width / 2),
                height: CGFloat(ShelfDetailLayout.modePicker.height)
            )
            .contentShape(.rect)
        }
        .buttonStyle(ShelfControlButtonStyle())
        .accessibilityAddTraits(selection == mode ? .isSelected : [])
        .onHover { hovering in
            if hovering {
                hoveredMode = mode
            } else if hoveredMode == mode {
                hoveredMode = nil
            }
        }
        .help(
            AppLocalization.string(
                mode == .grid ? "Grid View" : "List View"
            )
        )
        .accessibilityLabel(
            AppLocalization.string(
                mode == .grid ? "Grid View" : "List View"
            )
        )
    }

    private var selectedSurfaceColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.09)
            : .black.opacity(0.055)
    }

    private var hoveredSurfaceColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.045)
            : .black.opacity(0.025)
    }

    private var reduceMotion: Bool {
        reduceShelfMotion
            || systemReduceMotion
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private var selectionAnimation: Animation {
        let motion = ShelfDetailModeMotion.reference
        return reduceMotion
            ? .easeOut(duration: motion.reducedMotionDuration)
            : .spring(
                response: motion.morphResponse,
                dampingFraction: motion.morphDampingFraction
            )
    }

    private var hoverAnimation: Animation {
        let motion = ShelfDetailModeMotion.reference
        return .easeOut(
            duration:
                reduceMotion
                    ? motion.reducedMotionDuration
                    : motion.hoverDuration
        )
    }
}

private struct CommandBarView: View {
    @Bindable var store: ShelfStore
    let onAction: (BuiltinActionID) -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "command")
                TextField("Search actions", text: $store.commandQuery)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
            }
            .padding(11)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredActions, id: \.rawValue) { action in
                        Button {
                            onAction(action)
                        } label: {
                            HStack {
                                Image(systemName: action.symbolName)
                                    .frame(width: 22)
                                Text(action.displayTitle)
                                Spacer()
                            }
                            .padding(8)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(8)
        .frame(maxWidth: 330)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .shadow(
            color: .black.opacity(
                ShelfChromeStyle.commandBarShadowOpacity
            ),
            radius: ShelfChromeStyle.commandBarShadowRadius,
            y: ShelfChromeStyle.commandBarShadowY
        )
        .onAppear { isFocused = true }
    }

    private var filteredActions: [BuiltinActionID] {
        let available = BuiltinActionCatalog.availableActions(for: store.shelf.items)
        return BuiltinActionID.allCases.filter {
            available.contains($0) &&
            (store.commandQuery.isEmpty ||
             $0.displayTitle.localizedCaseInsensitiveContains(store.commandQuery))
        }
    }
}

private struct DockedShelfView: View {
    @Bindable var store: ShelfStore
    let onUndock: () -> Void
    let onClose: () -> Void

    var body: some View {
        let dragItems = ShelfDragSelection.items(
            from: store.shelf.items,
            selectedItemIDs: store.selectedItemIDs,
            initiatingItemID: store.shelf.items.first?.id,
            dragsEntireShelf: true
        )

        VStack(spacing: 8) {
            Button(action: onUndock) {
                Image(systemName: store.shelf.dockedEdge == .left ? "chevron.right" : "chevron.left")
            }
            .buttonStyle(.glass)
            ForEach(Array(store.shelf.items.prefix(3))) { item in
                ZStack {
                    ShelfItemIcon(item: item, size: 46)
                    ShelfItemsDragSourceView(
                        items: dragItems,
                        onDraggingChanged: { _ in }
                    )
                    .frame(width: 46, height: 46)
                }
                .frame(width: 46, height: 46)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.glass)
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ShelfItemRow: View {
    let item: ShelfItemRecord
    let isSelected: Bool
    let onMoveBefore: (UUID) -> Void
    let onDragStarted: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ShelfItemIcon(item: item, size: 38)
                .onDrag {
                    onDragStarted()
                    return makeItemProvider(for: item)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .lineLimit(1)
                Text(itemDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .draggable(item.id.uuidString)
                .accessibilityLabel(
                    AppLocalization.format(
                        "Reorder %@",
                        item.displayName
                    )
                )
        }
        .padding(7)
        .background(
            isSelected
                ? Color.accentColor.opacity(
                    ShelfChromeStyle.reorderSelectionOpacity
                )
                : .clear,
            in: .rect(cornerRadius: 11)
        )
        .dropDestination(for: String.self) { values, _ in
            guard let value = values.first,
                  let sourceID = UUID(uuidString: value) else {
                return false
            }
            onMoveBefore(sourceID)
            return true
        }
    }

    private var itemDetail: String {
        switch item.payload {
        case .file:
            guard let url = item.fileURL,
                  FileManager.default.fileExists(atPath: url.path) else {
                return AppLocalization.string("Missing source")
            }
            return url.pathExtension.uppercased()
        case .text:
            return AppLocalization.string("Text")
        case .url:
            return AppLocalization.string("Link")
        }
    }
}

private struct ShelfItemIcon: View {
    let item: ShelfItemRecord
    let size: CGFloat

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .shadow(
                color: .black.opacity(
                    ShelfChromeStyle.itemIconShadowOpacity
                ),
                radius: ShelfChromeStyle.itemIconShadowRadius,
                y: ShelfChromeStyle.itemIconShadowY
            )
            .accessibilityLabel(item.displayName)
    }

    private var icon: NSImage {
        switch item.payload {
        case .file:
            guard let url = item.fileURL else {
                return NSImage(
                    systemSymbolName: "exclamationmark.triangle",
                    accessibilityDescription:
                        AppLocalization.string("Missing source")
                ) ?? NSImage()
            }
            return NSWorkspace.shared.icon(forFile: url.path)
        case .text:
            return NSImage(
                systemSymbolName: "text.quote",
                accessibilityDescription: nil
            ) ?? NSImage()
        case .url:
            return NSImage(
                systemSymbolName: "link",
                accessibilityDescription: nil
            ) ?? NSImage()
        }
    }
}

func makeItemProvider(for item: ShelfItemRecord) -> NSItemProvider {
    switch item.payload {
    case .file:
        guard let url = item.fileURL else { return NSItemProvider() }
        return NSItemProvider(contentsOf: url) ?? NSItemProvider()
    case let .text(value):
        return NSItemProvider(object: value as NSString)
    case let .url(url):
        return NSItemProvider(object: url as NSURL)
    }
}

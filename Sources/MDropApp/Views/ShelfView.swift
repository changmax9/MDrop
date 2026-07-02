import AppKit
import MDropCore
import PDFKit
import SwiftUI

struct ShelfView: View {
    @Bindable var store: ShelfStore
    let onToggleDetail: () -> Void
    let onDock: () -> Void
    let onQuickLook: () -> Void
    let onAddClipboard: () -> Void
    let onAction: (BuiltinActionID) -> Void
    let onPreset: (CustomActionPreset) -> Void
    let onScript: (ScriptDefinition) -> Void
    let onChange: () -> Void
    let onClose: () -> Void
    @Namespace private var glassNamespace
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("reduceShelfMotion") private var reduceShelfMotion = false
    @State private var languageController =
        AppLanguageController.shared
    @State private var hasStartedEntrance = false
    @State private var surfaceScaleX: CGFloat = 0.82
    @State private var surfaceScaleY: CGFloat = 0.82
    @State private var surfaceOpacity: CGFloat = 0
    @State private var entranceCornerRadius: CGFloat = 44
    @State private var entranceContentOpacity: CGFloat = 1
    @State private var entranceContentScale: CGFloat = 1

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            ZStack {
                shelfContent
                    .opacity(resolvedContentOpacity)
                    .scaleEffect(resolvedContentScale)
                    .allowsHitTesting(!store.isLayoutTransitioning)
                    .animation(
                        layoutVisibilityAnimation,
                        value: store.isLayoutContentVisible
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(
                .rect(cornerRadius: animatedCornerRadius)
            )
            .glassEffect(
                .clear,
                in: .rect(cornerRadius: animatedCornerRadius)
            )
            .glassEffectID(
                store.shelf.id,
                in: glassNamespace
            )
            .scaleEffect(
                x: resolvedSurfaceScaleX,
                y: resolvedSurfaceScaleY
            )
            .opacity(resolvedSurfaceOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(store.isClosing ? 0 : 1)
        .scaleEffect(targetingScale)
        .task {
            await runEntrance()
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
            .stroke(.primary.opacity(0.16), lineWidth: 0.6)
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
            if store.isReceivingDrop {
                RoundedRectangle(
                    cornerRadius: animatedCornerRadius,
                    style: .continuous
                )
                    .stroke(.white.opacity(0.18), lineWidth: 1)
                    .padding(1)
                    .scaleEffect(
                        x: resolvedSurfaceScaleX,
                        y: resolvedSurfaceScaleY
                    )
                    .opacity(resolvedSurfaceOpacity)
                    .allowsHitTesting(false)
            }
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
            if store.isCommandBarPresented {
                CommandBarView(
                    store: store,
                    onAction: onAction,
                    onPreset: onPreset,
                    onScript: onScript
                )
                .transition(.scale.combined(with: .opacity))
                .padding(18)
            }
        }
        .overlay(alignment: .bottom) {
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
            }
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
                onAction: onAction,
                onPreset: onPreset,
                onScript: onScript,
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

    private var targetingScale: CGFloat {
        store.isReceivingDrop && !reduceMotion ? 1.006 : 1
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
        return entranceOpacity
            * (store.isLayoutContentVisible ? 1 : 0)
    }

    private var resolvedContentScale: CGFloat {
        let entranceScale = store.animatesInitialAppearance
            ? entranceContentScale
            : 1
        let layoutScale: CGFloat =
            store.isLayoutContentVisible ? 1 : 0.98
        return entranceScale * layoutScale
    }

    private var animatedCornerRadius: CGFloat {
        store.animatesInitialAppearance && !reduceMotion
            ? entranceCornerRadius
            : glassCornerRadius
    }

    private var layoutVisibilityAnimation: Animation {
        let timing = ShelfLayoutTransitionTiming.resolve(
            profile: .reference,
            reduceMotion: reduceMotion
        )
        return reduceMotion
            ? .linear(
                duration: timing.contentFadeDuration
            )
            : .easeOut(
                duration: timing.contentFadeDuration
            )
    }

    @MainActor
    private func runEntrance() async {
        guard !hasStartedEntrance else { return }
        hasStartedEntrance = true

        guard store.animatesInitialAppearance else {
            surfaceScaleX = 1
            surfaceScaleY = 1
            surfaceOpacity = 1
            entranceCornerRadius = glassCornerRadius
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
            entranceCornerRadius = glassCornerRadius
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
            entranceCornerRadius = glassCornerRadius
            entranceContentOpacity = 1
            entranceContentScale = 1
        }
    }

    private var glassCornerRadius: CGFloat {
        switch store.shelf.presentationState {
        case .empty:
            ShelfMotionProfile.reference.emptyCornerRadius
        case .docked:
            20
        case .compact, .instantActions:
            28
        case .detail:
            26
        }
    }
}

private struct EmptyShelfView: View {
    @Bindable var store: ShelfStore
    let isReceivingDrop: Bool
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Text("Drop files here")
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
                .scaleEffect(showsChrome ? 1 : 0.92)
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
                    .buttonStyle(.plain)
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
        !isReceivingDrop
    }
}

struct ShelfCircleControlLabel: View {
    let systemName: String
    var externallyHovered: Bool? = nil
    @Environment(\.colorScheme) private var colorScheme
    @State private var internallyHovered = false

    var body: some View {
        ZStack {
            Circle()
                .fill(surfaceColor)
                .glassEffect(.regular, in: .circle)
                .overlay {
                    Circle()
                        .stroke(outlineColor, lineWidth: 0.5)
                        .allowsHitTesting(false)
                }
                .shadow(
                    color: .black.opacity(
                        isHovered
                            ? hoverShadowOpacity
                            : restingShadowOpacity
                    ),
                    radius: isHovered ? 7 : 4,
                    y: isHovered ? 3 : 2
                )

            Image(systemName: systemName)
                .font(
                    .system(
                        size:
                            ShelfMotionProfile.reference
                                .controlIconPointSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(iconColor)
                .frame(
                    width:
                        ShelfMotionProfile.reference.controlDiameter,
                    height:
                        ShelfMotionProfile.reference.controlDiameter
                )
        }
            .frame(
                width: ShelfMotionProfile.reference.controlDiameter,
                height: ShelfMotionProfile.reference.controlDiameter
            )
            .contentShape(.circle)
            .onHover { hovering in
                guard externallyHovered == nil else { return }
                internallyHovered = hovering
            }
            .animation(
                .easeOut(
                    duration:
                        ShelfMotionProfile.reference.controlHoverDuration
                ),
                value: isHovered
            )
    }

    private var isHovered: Bool {
        externallyHovered ?? internallyHovered
    }

    private var iconColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.9)
            : .black.opacity(0.76)
    }

    private var surfaceColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.075)
            : .black.opacity(0.055)
    }

    private var outlineColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.11)
            : .black.opacity(0.07)
    }

    private var hoverShadowOpacity: Double {
        colorScheme == .dark ? 0.48 : 0.24
    }

    private var restingShadowOpacity: Double {
        colorScheme == .dark ? 0.34 : 0.13
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

    var body: some View {
        Menu {
            content
        } label: {
            ShelfCircleControlLabel(
                systemName: systemName,
                externallyHovered: isHovering
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(
            width: ShelfMotionProfile.reference.controlDiameter,
            height: ShelfMotionProfile.reference.controlDiameter
        )
        .contentShape(.circle)
        .onHover { hovering in
            isHovering = hovering
        }
        .help(accessibilityLabel)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct ShelfDetailView: View {
    @Bindable var store: ShelfStore
    let onCollapse: () -> Void
    let onDock: () -> Void
    let onAction: (BuiltinActionID) -> Void
    let onPreset: (CustomActionPreset) -> Void
    let onScript: (ScriptDefinition) -> Void
    let onChange: () -> Void
    let onClose: () -> Void
    @State private var viewMode: ShelfDetailViewMode = .list
    @State private var automation = AutomationStore.shared

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 8) {
                Button(action: onCollapse) {
                    ShelfCircleControlLabel(
                        systemName: "chevron.left"
                    )
                }
                .buttonStyle(.plain)
                .help("Back to Compact Shelf")

                VStack(alignment: .leading, spacing: 0) {
                    Text(detailTitle)
                        .font(.system(size: 13, weight: .semibold))
                    Text(sizeSummary)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)

                Spacer()

                detailActionsMenu

                ShelfDetailModePicker(selection: $viewMode)
            }
            .padding(.horizontal, 7)
            .padding(.top, 7)

            detailContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var detailContent: some View {
        if viewMode == .grid {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 18) {
                    ForEach(store.shelf.items) { item in
                        detailGridItem(item)
                    }

                    revealInFinderTile
                }
                .padding(.horizontal, 14)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 8)
        } else {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(store.shelf.items) { item in
                        detailListItem(item)
                    }
                }
                .padding(.top, 14)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 8)
        }
    }

    private var revealInFinderTile: some View {
        Button(action: revealInFinder) {
            VStack(spacing: 8) {
                Image(systemName: "arrowshape.turn.up.right.circle")
                    .font(.system(size: 46, weight: .light))
                Text("Reveal in Finder")
                    .font(.system(size: 13))
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
            .frame(width: 112)
            .padding(.top, 24)
        }
        .buttonStyle(.plain)
        .disabled(fileURLs.isEmpty)
    }

    private var detailActionsMenu: some View {
        ShelfCircleMenu(
            systemName: "slider.horizontal.3",
            accessibilityLabel:
                AppLocalization.string("Shelf Options")
        ) {
            Button("Dock to Edge", systemImage: "sidebar.left") {
                onDock()
            }
            Menu("Actions") {
                ForEach(availableActions, id: \.rawValue) { action in
                    Button(
                        action.displayTitle,
                        systemImage: action.symbolName
                    ) {
                        onAction(action)
                    }
                }
            }
            if !automation.customActions.isEmpty {
                Menu("Custom Actions") {
                    ForEach(automation.customActions) { preset in
                        Button(preset.name) {
                            onPreset(preset)
                        }
                    }
                }
            }
            if !automation.scripts.isEmpty {
                Menu("Scripts") {
                    ForEach(automation.scripts) { script in
                        Button(script.name) {
                            onScript(script)
                        }
                    }
                }
            }
            Divider()
            Button("Close Shelf", systemImage: "xmark", role: .destructive) {
                onClose()
            }
        }
    }

    private func detailGridItem(_ item: ShelfItemRecord) -> some View {
        VStack(spacing: 2) {
            ZStack {
                ShelfThumbnailView(
                    item: item,
                    size: CGSize(width: 52, height: 68)
                )
                ShelfItemsDragSourceView(
                    items: dragItems(startingWith: item),
                    onDraggingChanged: { _ in }
                )
                .frame(width: 52, height: 68)
            }
            Text(item.displayName)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 110)
            Text(sizeSummary(for: item))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 110)
        .padding(.top, 10)
        .background(
            store.selectedItemIDs.contains(item.id)
                ? Color.accentColor.opacity(0.11)
                : .clear,
            in: .rect(cornerRadius: 10)
        )
        .contentShape(.rect)
        .onTapGesture {
            store.toggleSelection(
                item.id,
                extending:
                    NSEvent.modifierFlags.contains(.command)
            )
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

    private func detailListItem(_ item: ShelfItemRecord) -> some View {
        HStack(spacing: 10) {
            ZStack {
                ShelfThumbnailView(
                    item: item,
                    size: CGSize(width: 20, height: 28)
                )
                ShelfItemsDragSourceView(
                    items: dragItems(startingWith: item),
                    onDraggingChanged: { _ in }
                )
                .frame(width: 28, height: 30)
            }
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
                ? Color.accentColor.opacity(0.11)
                : .clear,
            in: .rect(cornerRadius: 10)
        )
        .contentShape(.rect)
        .onTapGesture {
            store.toggleSelection(
                item.id,
                extending:
                    NSEvent.modifierFlags.contains(.command)
            )
        }
        .onTapGesture(count: 2) {
            if let url = item.fileURL {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
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

    private var sizeSummary: String {
        let totalByteCount = store.shelf.items.reduce(Int64.zero) {
            $0 + byteCount(for: $1)
        }
        return ByteCountFormatter.string(
            fromByteCount: totalByteCount,
            countStyle: .file
        )
    }

    private func sizeSummary(for item: ShelfItemRecord) -> String {
        ByteCountFormatter.string(
            fromByteCount: byteCount(for: item),
            countStyle: .file
        )
    }

    private func byteCount(for item: ShelfItemRecord) -> Int64 {
        guard let url = item.fileURL else { return 0 }
        let values = try? url.resourceValues(
            forKeys: [
                .fileSizeKey,
                .totalFileAllocatedSizeKey
            ]
        )
        return Int64(
            values?.totalFileAllocatedSize
                ?? values?.fileSize
                ?? 0
        )
    }

    private func secondaryMetadata(
        for item: ShelfItemRecord
    ) -> String? {
        guard let url = item.fileURL,
              url.pathExtension.lowercased() == "pdf",
              let document = PDFDocument(url: url)
        else { return nil }

        return document.pageCount == 1
            ? AppLocalization.string("1 page")
            : AppLocalization.format(
                "%lld pages",
                Int64(document.pageCount)
            )
    }

    private func dragItems(
        startingWith item: ShelfItemRecord
    ) -> [ShelfItemRecord] {
        ShelfDragSelection.items(
            from: store.shelf.items,
            selectedItemIDs: store.selectedItemIDs,
            initiatingItemID: item.id,
            dragsEntireShelf: false
        )
    }

    private var selectedItems: [ShelfItemRecord] {
        store.selectedItemIDs.isEmpty
            ? store.shelf.items
            : store.shelf.items.filter {
                store.selectedItemIDs.contains($0.id)
            }
    }

    private var availableActions: [BuiltinActionID] {
        let available = BuiltinActionCatalog.availableActions(
            for: selectedItems
        )
        return BuiltinActionID.allCases.filter(available.contains)
    }

    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting(fileURLs)
    }
}

private enum ShelfDetailViewMode: Hashable {
    case grid
    case list
}

private struct ShelfDetailModePicker: View {
    @Binding var selection: ShelfDetailViewMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("reduceShelfMotion") private var reduceShelfMotion = false
    @Namespace private var glassNamespace
    @State private var hoveredMode: ShelfDetailViewMode?

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                modeButton(.grid, systemName: "square.grid.2x2")
                modeButton(.list, systemName: "list.bullet")
            }
            .frame(width: 60, height: 32)
            .background(.black.opacity(0.025), in: .capsule)
            .glassEffect(.regular, in: .capsule)
            .clipShape(Capsule())
        }
        .frame(width: 60, height: 32)
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
            .frame(width: 30, height: 32)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
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
            ? .white.opacity(0.13)
            : .black.opacity(0.075)
    }

    private var hoveredSurfaceColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.07)
            : .black.opacity(0.035)
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

private struct ActionMenu: View {
    let items: [ShelfItemRecord]
    let onAction: (BuiltinActionID) -> Void
    let onPreset: (CustomActionPreset) -> Void
    let onScript: (ScriptDefinition) -> Void
    @State private var automation = AutomationStore.shared

    var body: some View {
        Menu {
            ForEach(sortedActions, id: \.rawValue) { action in
                Button(action.displayTitle, systemImage: action.symbolName) {
                    onAction(action)
                }
            }
            if !automation.customActions.isEmpty {
                Divider()
                Menu("Custom Actions") {
                    ForEach(automation.customActions) { preset in
                        Button(preset.name) { onPreset(preset) }
                    }
                }
            }
            if !automation.scripts.isEmpty {
                Menu("Scripts") {
                    ForEach(automation.scripts) { script in
                        Button(script.name) { onScript(script) }
                    }
                }
            }
        } label: {
            Label("Actions", systemImage: "bolt.fill")
        }
        .buttonStyle(.glassProminent)
    }

    private var sortedActions: [BuiltinActionID] {
        BuiltinActionID.allCases.filter(
            BuiltinActionCatalog.availableActions(for: items).contains
        )
    }
}

private struct CommandBarView: View {
    @Bindable var store: ShelfStore
    let onAction: (BuiltinActionID) -> Void
    let onPreset: (CustomActionPreset) -> Void
    let onScript: (ScriptDefinition) -> Void
    @State private var automation = AutomationStore.shared
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
                    ForEach(automation.customActions) { preset in
                        Button {
                            onPreset(preset)
                        } label: {
                            commandRow(title: preset.name, symbol: "wand.and.stars")
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(automation.scripts) { script in
                        Button {
                            onScript(script)
                        } label: {
                            commandRow(title: script.name, symbol: "terminal")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(8)
        .frame(maxWidth: 330)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        .shadow(radius: 22, y: 12)
        .onAppear { isFocused = true }
    }

    private func commandRow(title: String, symbol: String) -> some View {
        HStack {
            Image(systemName: symbol)
                .frame(width: 22)
            Text(title)
            Spacer()
        }
        .padding(8)
        .contentShape(.rect)
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
            isSelected ? Color.accentColor.opacity(0.22) : .clear,
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
            .shadow(radius: 5, y: 3)
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

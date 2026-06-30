import AppKit
import MDropCore
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
    @State private var hasStartedEntrance = false
    @State private var surfaceScaleX: CGFloat = 0.18
    @State private var surfaceScaleY: CGFloat = 0.12
    @State private var surfaceOpacity: CGFloat = 0
    @State private var entranceCornerRadius: CGFloat = 44
    @State private var entranceContentOpacity: CGFloat = 0
    @State private var entranceContentScale: CGFloat = 0.96

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            ZStack {
                Color.clear
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

                shelfContent
                    .opacity(resolvedContentOpacity)
                    .scaleEffect(resolvedContentScale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                : .snappy(
                    duration: ShelfMotionProfile.reference.stackDuration
                ),
            value: store.shelf.presentationState
        )
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
        store.animatesInitialAppearance
            ? entranceContentScale
            : 1
    }

    private var animatedCornerRadius: CGFloat {
        store.animatesInitialAppearance && !reduceMotion
            ? entranceCornerRadius
            : glassCornerRadius
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
            .spring(response: 0.30, dampingFraction: 0.82)
        ) {
            surfaceScaleX = 1
            surfaceOpacity = 1
            entranceCornerRadius = glassCornerRadius
        }
        withAnimation(
            .spring(response: 0.42, dampingFraction: 0.72)
        ) {
            surfaceScaleY = 1
        }

        do {
            try await Task.sleep(
                for: .seconds(
                    ShelfMotionProfile.reference.jellyContentDelay
                )
            )
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        withAnimation(
            .spring(response: 0.28, dampingFraction: 0.88)
        ) {
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
            ShelfDragHandle(store: store)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 8)

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
        Image(systemName: systemName)
            .font(
                .system(
                    size: ShelfMotionProfile.reference.controlIconPointSize,
                    weight: .semibold
                )
            )
            .foregroundStyle(iconColor)
            .frame(
                width: ShelfMotionProfile.reference.controlDiameter,
                height: ShelfMotionProfile.reference.controlDiameter
            )
            .background(
                surfaceColor,
                in: .circle
            )
            .glassEffect(.regular, in: .circle)
            .overlay {
                Circle()
                    .stroke(outlineColor, lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
            .shadow(
                color: .black.opacity(isHovered ? 0.19 : 0.025),
                radius: isHovered ? 5.5 : 1,
                y: isHovered ? 2.5 : 0.5
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
}

struct ShelfDragHandle: View {
    @Bindable var store: ShelfStore
    @AppStorage("reduceShelfMotion") private var reduceShelfMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        Capsule()
            .fill(.secondary.opacity(0.55))
            .frame(
                width: store.isWindowDragging
                    ? ShelfMotionProfile.reference.handleDraggingWidth
                    : ShelfMotionProfile.reference.handleHoverWidth,
                height: ShelfMotionProfile.reference.handleHeight
            )
            .opacity(
                store.isShelfHovered || store.isWindowDragging ? 1 : 0
            )
            .animation(handleAnimation, value: store.isShelfHovered)
            .animation(handleAnimation, value: store.isWindowDragging)
            .accessibilityHidden(true)
    }

    private var handleAnimation: Animation {
        reduceMotion
            ? .linear(duration: 0.08)
            : .spring(response: 0.24, dampingFraction: 0.84)
    }

    private var reduceMotion: Bool {
        reduceShelfMotion
            || systemReduceMotion
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
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
    @AppStorage("autoCloseDetail") private var autoCloseDetail = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: onCollapse) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.glass)
                TextField("Shelf Name", text: $store.shelf.name)
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .onSubmit(onChange)
                Spacer()
                Button(action: onDock) {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(.glass)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.glass)
            }

            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(store.shelf.items) { item in
                        Button {
                            store.toggleSelection(
                                item.id,
                                extending: NSEvent.modifierFlags.contains(.command)
                            )
                        } label: {
                            ShelfItemRow(
                                item: item,
                                isSelected: store.selectedItemIDs.contains(item.id),
                                onMoveBefore: { sourceID in
                                    store.shelf.moveItem(sourceID, before: item.id)
                                    onChange()
                                },
                                onDragStarted: {
                                    if autoCloseDetail {
                                        onCollapse()
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(.rect)
                        .contextMenu {
                            Button("Copy Path") {
                                if let url = item.fileURL {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(url.path, forType: .string)
                                }
                            }
                            Button("Remove", role: .destructive) {
                                store.remove([item.id])
                                onChange()
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            HStack {
                Text("\(store.shelf.items.count) items")
                    .foregroundStyle(.secondary)
                Spacer()
                ActionMenu(
                    items: store.selectedItemIDs.isEmpty
                        ? store.shelf.items
                        : store.shelf.items.filter { store.selectedItemIDs.contains($0.id) },
                    onAction: onAction,
                    onPreset: onPreset,
                    onScript: onScript
                )
            }
            .font(.caption)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        VStack(spacing: 8) {
            Button(action: onUndock) {
                Image(systemName: store.shelf.dockedEdge == .left ? "chevron.right" : "chevron.left")
            }
            .buttonStyle(.glass)
            ForEach(Array(store.shelf.items.prefix(3))) { item in
                ShelfItemIcon(item: item, size: 46)
                    .onDrag { makeItemProvider(for: item) }
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
                .accessibilityLabel("Reorder \(item.displayName)")
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
                return String(localized: "Missing source")
            }
            return url.pathExtension.uppercased()
        case .text:
            return String(localized: "Text")
        case .url:
            return String(localized: "Link")
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
                    accessibilityDescription: String(localized: "Missing source")
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

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
    @State private var hasAppeared = false

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            Group {
                switch store.shelf.presentationState {
                case .empty:
                    EmptyShelfView(
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
            .glassEffect(
                .regular.interactive(),
                in: .rect(cornerRadius: glassCornerRadius)
            )
            .glassEffectID(store.shelf.id, in: glassNamespace)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(store.isClosing ? 0 : (hasAppeared ? 1 : 0))
        .scaleEffect(contentScale)
        .onAppear {
            let duration = reduceMotion
                ? 0
                : ShelfMotionProfile.reference.appearanceDuration
            withAnimation(.easeOut(duration: duration)) {
                hasAppeared = true
            }
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
            if colorSchemeContrast == .increased {
                RoundedRectangle(
                    cornerRadius: glassCornerRadius,
                    style: .continuous
                )
                .stroke(.white.opacity(0.46), lineWidth: 1.25)
                .allowsHitTesting(false)
            }
        }
        .overlay {
            if store.isReceivingDrop {
                RoundedRectangle(
                    cornerRadius: glassCornerRadius,
                    style: .continuous
                )
                    .stroke(.white.opacity(0.18), lineWidth: 1)
                    .padding(1)
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

    private var reduceMotion: Bool {
        reduceShelfMotion
            || systemReduceMotion
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private var contentScale: CGFloat {
        let lifecycleScale: CGFloat
        if store.isClosing || !hasAppeared {
            lifecycleScale = reduceMotion ? 1 : 0.985
        } else {
            lifecycleScale = 1
        }
        let targetingScale: CGFloat =
            store.isReceivingDrop && !reduceMotion ? 1.006 : 1
        return lifecycleScale * targetingScale
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
            Capsule()
                .fill(.secondary.opacity(0.52))
                .frame(width: 36, height: 5)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 10)
                .accessibilityHidden(true)

            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(
                                .white.opacity(0.09),
                                in: .circle
                            )
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .help("Close Shelf")
                    .accessibilityLabel("Close Shelf")

                    Spacer()
                }
                Spacer()
            }
            .padding(18)
        }
    }

    private var showsChrome: Bool {
        !isReceivingDrop
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

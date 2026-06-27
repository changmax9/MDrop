import AppKit
import MDropCore
import SwiftUI

struct ShelfView: View {
    @Bindable var store: ShelfStore
    let onDrop: ([DropRepresentation]) -> Void
    let onToggleDetail: () -> Void
    let onDock: () -> Void
    let onAction: (BuiltinActionID) -> Void
    let onChange: () -> Void
    let onClose: () -> Void
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            Group {
                switch store.shelf.presentationState {
                case .detail:
                    ShelfDetailView(
                        store: store,
                        onCollapse: onToggleDetail,
                        onDock: onDock,
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
                case .empty, .compact, .instantActions:
                    CompactShelfView(
                        store: store,
                        onExpand: onToggleDetail,
                        onDock: onDock,
                        onAction: onAction,
                        onClose: onClose
                    )
                }
            }
            .glassEffect(
                .regular.interactive(),
                in: .rect(cornerRadius: store.shelf.presentationState == .docked ? 20 : 26)
            )
            .glassEffectID(store.shelf.id, in: glassNamespace)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
        .overlay {
            DropReceiverView(
                onTargeted: { store.isReceivingDrop = $0 },
                onDrop: onDrop
            )
            .allowsHitTesting(false)
        }
        .overlay {
            if store.isReceivingDrop {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 3, dash: [7, 5]))
                    .padding(11)
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
                    onAction: onAction
                )
                .transition(.scale.combined(with: .opacity))
                .padding(18)
            }
        }
    }
}

private struct CompactShelfView: View {
    @Bindable var store: ShelfStore
    let onExpand: () -> Void
    let onDock: () -> Void
    let onAction: (BuiltinActionID) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("Close Shelf")

                Button(action: onExpand) {
                    HStack(spacing: 5) {
                        Text(title)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Menu {
                    Button("Dock Shelf", systemImage: "sidebar.left", action: onDock)
                    Button(store.shelf.isPinned ? "Unpin Shelf" : "Pin Shelf", systemImage: "pin") {
                        store.shelf.isPinned.toggle()
                    }
                    Divider()
                    Button("Close Shelf", systemImage: "xmark", action: onClose)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .font(.system(size: 12, weight: .semibold))

            if store.shelf.items.isEmpty {
                VStack(spacing: 7) {
                    Image(systemName: "arrow.down.doc")
                        .font(.title2)
                    Text("Drop files here")
                        .font(.headline)
                    Text("Shake while dragging or press ⌥⇧Space")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: -9) {
                    ForEach(Array(store.shelf.items.prefix(5))) { item in
                        ShelfItemIcon(item: item, size: 54)
                            .onDrag { makeItemProvider(for: item) }
                    }
                    if store.shelf.items.count > 5 {
                        Text("+\(store.shelf.items.count - 5)")
                            .font(.caption.bold())
                            .padding(7)
                            .glassEffect(.regular, in: .circle)
                    }
                    Spacer(minLength: 0)
                }
            }

            if store.showsInstantActions {
                HStack {
                    instantButton(.systemShare)
                    instantButton(.createArchive)
                    instantButton(.copyTo)
                    instantButton(.moveTo)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if store.shelf.items.isEmpty {
                Button {
                    withAnimation(.snappy) {
                        store.showsInstantActions.toggle()
                    }
                } label: {
                    Image(systemName: "bolt.fill")
                }
                .buttonStyle(.glass)
                .help("Instant Actions")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Shelf \(title)")
    }

    private func instantButton(_ action: BuiltinActionID) -> some View {
        Button {
            onAction(action)
        } label: {
            Image(systemName: action.symbolName)
        }
        .buttonStyle(.glass)
        .help(action.displayTitle)
    }

    private var title: String {
        if !store.shelf.name.isEmpty { return store.shelf.name }
        return store.shelf.items.isEmpty
            ? String(localized: "New Shelf")
            : String(localized: "\(store.shelf.items.count) Items")
    }
}

private struct ShelfDetailView: View {
    @Bindable var store: ShelfStore
    let onCollapse: () -> Void
    let onDock: () -> Void
    let onAction: (BuiltinActionID) -> Void
    let onChange: () -> Void
    let onClose: () -> Void

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
                        ShelfItemRow(
                            item: item,
                            isSelected: store.selectedItemIDs.contains(item.id)
                        )
                        .contentShape(.rect)
                        .onTapGesture {
                            store.toggleSelection(
                                item.id,
                                extending: NSEvent.modifierFlags.contains(.command)
                            )
                        }
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
                        .onDrag { makeItemProvider(for: item) }
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
                    onAction: onAction
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

    var body: some View {
        Menu {
            ForEach(sortedActions, id: \.rawValue) { action in
                Button(action.displayTitle, systemImage: action.symbolName) {
                    onAction(action)
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
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        .shadow(radius: 22, y: 12)
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

    var body: some View {
        HStack(spacing: 10) {
            ShelfItemIcon(item: item, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .lineLimit(1)
                Text(itemDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(7)
        .background(
            isSelected ? Color.accentColor.opacity(0.22) : .clear,
            in: .rect(cornerRadius: 11)
        )
    }

    private var itemDetail: String {
        switch item.payload {
        case let .file(reference):
            return reference.url.pathExtension.uppercased()
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
        case let .file(reference):
            NSWorkspace.shared.icon(forFile: reference.url.path)
        case .text:
            NSImage(systemSymbolName: "text.quote", accessibilityDescription: nil) ?? NSImage()
        case .url:
            NSImage(systemSymbolName: "link", accessibilityDescription: nil) ?? NSImage()
        }
    }
}

private func makeItemProvider(for item: ShelfItemRecord) -> NSItemProvider {
    switch item.payload {
    case let .file(reference):
        return NSItemProvider(contentsOf: reference.url) ?? NSItemProvider()
    case let .text(value):
        return NSItemProvider(object: value as NSString)
    case let .url(url):
        return NSItemProvider(object: url as NSURL)
    }
}

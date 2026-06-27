import AppKit
import MDropCore
import SwiftUI

struct CompactStackedShelfView: View {
    @Bindable var store: ShelfStore
    let onExpand: () -> Void
    let onDock: () -> Void
    let onQuickLook: () -> Void
    let onAddClipboard: () -> Void
    let onAction: (BuiltinActionID) -> Void
    let onChange: () -> Void
    let onClose: () -> Void

    @AppStorage("reduceShelfMotion") private var reduceShelfMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var isHovering = false

    var body: some View {
        ZStack {
            Capsule()
                .fill(.secondary.opacity(0.55))
                .frame(width: 34, height: 5)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 4)
                .accessibilityHidden(true)

            HStack {
                closeButton
                Spacer()
                menuButton
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 1)
            .padding(.top, 5)

            thumbnailStack
                .offset(y: -1)

            detailButton
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 8)
                .padding(.bottom, 5)
        }
        .padding(5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect(cornerRadius: 30))
        .contextMenu {
            ShelfMenuContent(
                store: store,
                onDock: onDock,
                onQuickLook: onQuickLook,
                onAddClipboard: onAddClipboard,
                onAction: onAction,
                onChange: onChange
            )
        }
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(store.shelf.items.count) items, \(store.shelf.items.last?.displayName ?? "")"
        )
        .animation(stackAnimation, value: store.shelf.items)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .help("Close Shelf")
        .accessibilityLabel("Close Shelf")
    }

    private var menuButton: some View {
        Menu {
            ShelfMenuContent(
                store: store,
                onDock: onDock,
                onQuickLook: onQuickLook,
                onAddClipboard: onAddClipboard,
                onAction: onAction,
                onChange: onChange
            )
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 30, height: 30)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Shelf Actions")
        .accessibilityLabel("Shelf Actions")
    }

    private var thumbnailStack: some View {
        let visibleItems = Array(store.shelf.items.suffix(3))
        let transforms = CompactShelfLayout.transforms(
            itemCount: store.shelf.items.count,
            reduceMotion: reduceMotion
        )

        return ZStack {
            ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                let transform = transforms[index]
                thumbnailCard(item)
                    .offset(x: transform.x, y: transform.y)
                    .rotationEffect(.degrees(transform.rotationDegrees))
                    .scaleEffect(transform.scale)
                    .zIndex(Double(index))
                    .onDrag { makeItemProvider(for: item) }
            }
        }
        .frame(width: 92, height: 104)
        .offset(y: 4)
    }

    private func thumbnailCard(_ item: ShelfItemRecord) -> some View {
        ShelfThumbnailView(
            item: item,
            size: CGSize(width: 78, height: 94)
        )
        .shadow(
            color: .black.opacity(isHovering ? 0.42 : 0.30),
            radius: isHovering ? 8 : 5,
            y: 4
        )
    }

    private var detailButton: some View {
        Button(action: onExpand) {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .padding(.horizontal, 10)
            .frame(height: 25)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 126)
        .help("Show Shelf Details")
        .accessibilityLabel("Show Shelf Details, \(label)")
    }

    private var label: String {
        if !store.shelf.name.isEmpty {
            return store.shelf.name
        }
        guard store.shelf.items.count > 1 else {
            return store.shelf.items.first?.displayName ?? "Shelf"
        }

        let urls = store.shelf.items.compactMap(\.fileURL)
        guard urls.count == store.shelf.items.count else {
            return "\(store.shelf.items.count) Items"
        }
        let directoryFlags = urls.map {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory)
                ?? false
        }
        if directoryFlags.allSatisfy({ $0 }) {
            return "\(urls.count) Folders"
        }
        if directoryFlags.allSatisfy({ !$0 }) {
            return "\(urls.count) Documents"
        }
        return "\(urls.count) Items"
    }

    private var reduceMotion: Bool {
        reduceShelfMotion
            || systemReduceMotion
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private var stackAnimation: Animation {
        reduceMotion ? .linear(duration: 0.12) : .snappy(duration: 0.32)
    }
}

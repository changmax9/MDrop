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
    @State private var isDraggingItems = false

    var body: some View {
        ZStack {
            HStack {
                closeButton
                Spacer()
                menuButton
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(
                ShelfMotionProfile.reference.controlCenterInset
                    - ShelfMotionProfile.reference.controlDiameter / 2
                    - 5
            )
            .opacity(isDraggingItems ? 0.22 : 1)

            thumbnailStack

            detailButton
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 8)
                .padding(.bottom, 5)
                .opacity(isDraggingItems ? 0.22 : 1)
        }
        .padding(5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect(cornerRadius: 28))
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
        .onHover { hovering in
            withAnimation(hoverAnimation) {
                isHovering = hovering
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(store.shelf.items.count) items, \(store.shelf.items.last?.displayName ?? "")"
        )
        .animation(stackAnimation, value: store.shelf.items)
        .animation(dragChromeAnimation, value: isDraggingItems)
        .onDisappear {
            isDraggingItems = false
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            ShelfCircleControlLabel(systemName: "xmark")
        }
        .buttonStyle(.plain)
        .help("Close Shelf")
        .accessibilityLabel("Close Shelf")
    }

    private var menuButton: some View {
        ShelfCircleMenu(
            systemName: "chevron.down",
            accessibilityLabel: "Shelf Actions"
        ) {
            ShelfMenuContent(
                store: store,
                onDock: onDock,
                onQuickLook: onQuickLook,
                onAddClipboard: onAddClipboard,
                onAction: onAction,
                onChange: onChange
            )
        }
    }

    private var thumbnailStack: some View {
        let visibleItems = Array(store.shelf.items.suffix(3))
        let transforms = CompactShelfLayout.transforms(
            itemCount: store.shelf.items.count,
            reduceMotion: reduceMotion
        )
        let dragItems = ShelfDragSelection.items(
            from: store.shelf.items,
            selectedItemIDs: store.selectedItemIDs,
            initiatingItemID: store.shelf.items.last?.id,
            dragsEntireShelf: true
        )

        return ZStack {
            ZStack {
                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                    let transform = transforms[index]
                    thumbnailCard(item)
                        .offset(x: transform.x, y: transform.y)
                        .rotationEffect(.degrees(transform.rotationDegrees))
                        .scaleEffect(transform.scale)
                        .zIndex(Double(index))
                }
            }
            .opacity(isDraggingItems ? 0 : 1)

            ShelfItemsDragSourceView(
                items: dragItems,
                onDraggingChanged: { isDraggingItems = $0 }
            )
            .frame(width: 92, height: 104)
            .zIndex(10)
        }
        .frame(width: 92, height: 104)
        .offset(y: -8)
    }

    private func thumbnailCard(_ item: ShelfItemRecord) -> some View {
        ShelfThumbnailView(
            item: item,
            size: CGSize(width: 70, height: 90)
        )
        .shadow(
            color: .black.opacity(isHovering ? 0.26 : 0.18),
            radius: isHovering ? 9 : 5,
            y: isHovering ? 5 : 3
        )
        .scaleEffect(isHovering ? 1.012 : 1)
        .offset(y: isHovering ? -1 : 0)
        .animation(hoverAnimation, value: isHovering)
    }

    private var detailButton: some View {
        Button(action: onExpand) {
            HStack(spacing: 5) {
                ShelfMarqueeText(
                    text: label,
                    viewportWidth: 88,
                    viewportHeight: 20
                )
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 9)
                    .zIndex(1)
            }
            .padding(.horizontal, 8)
            .frame(width: 126, height: 29)
            .background(.black.opacity(0.025), in: .capsule)
            .glassEffect(.regular.interactive(), in: .capsule)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(width: 126, height: 29)
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
        reduceMotion
            ? .linear(duration: 0.12)
            : .snappy(
                duration: ShelfMotionProfile.reference.stackDuration
            )
    }

    private var dragChromeAnimation: Animation {
        reduceMotion
            ? .linear(duration: 0.08)
            : .spring(response: 0.26, dampingFraction: 0.82)
    }

    private var hoverAnimation: Animation {
        reduceMotion
            ? .linear(duration: 0.08)
            : .spring(response: 0.22, dampingFraction: 0.88)
    }
}

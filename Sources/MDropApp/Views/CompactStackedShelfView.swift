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
    @State private var isMenuHovering = false
    @State private var draggedItemID: UUID?
    @State private var dragResetTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            ShelfDragHandle(store: store)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 4)

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
            .opacity(isDraggingItem ? 0.22 : 1)

            thumbnailStack

            detailButton
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 8)
                .padding(.bottom, 5)
                .opacity(isDraggingItem ? 0.22 : 1)
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
        .animation(dragChromeAnimation, value: draggedItemID)
        .onDisappear {
            dragResetTask?.cancel()
            dragResetTask = nil
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
        ZStack {
            ShelfCircleControlLabel(
                systemName: "chevron.down",
                externallyHovered: isMenuHovering
            )
            .allowsHitTesting(false)

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
                Color.clear
                    .frame(
                        width: ShelfMotionProfile.reference.controlDiameter,
                        height: ShelfMotionProfile.reference.controlDiameter
                    )
                    .contentShape(.circle)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .frame(
            width: ShelfMotionProfile.reference.controlDiameter,
            height: ShelfMotionProfile.reference.controlDiameter
        )
        .contentShape(.circle)
        .onHover { hovering in
            isMenuHovering = hovering
        }
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
                    .opacity(draggedItemID == item.id ? 0 : 1)
                    .zIndex(Double(index))
                    .onDrag {
                        beginDragging(item)
                        return makeItemProvider(for: item)
                    } preview: {
                        dragPreview(item)
                    }
            }
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

    private func dragPreview(_ item: ShelfItemRecord) -> some View {
        ShelfThumbnailView(
            item: item,
            size: CGSize(width: 96, height: 116)
        )
        .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
    }

    private var isDraggingItem: Bool {
        draggedItemID != nil
    }

    private func beginDragging(_ item: ShelfItemRecord) {
        draggedItemID = item.id
        dragResetTask?.cancel()
        dragResetTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            while !Task.isCancelled,
                  NSEvent.pressedMouseButtons & 1 != 0 {
                try? await Task.sleep(for: .milliseconds(34))
            }
            guard !Task.isCancelled else { return }
            draggedItemID = nil
            dragResetTask = nil
        }
    }

    private var detailButton: some View {
        Button(action: onExpand) {
            HStack(spacing: 5) {
                ShelfMarqueeText(text: label)
                    .frame(width: 96)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .padding(.horizontal, 10)
            .frame(height: 29)
            .background(.black.opacity(0.025), in: .capsule)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .frame(width: 126)
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

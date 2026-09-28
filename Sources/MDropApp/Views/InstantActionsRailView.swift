import AppKit
import MDropCore
import SwiftUI

struct InstantActionSlot: Identifiable, Equatable {
    let index: Int
    let action: BuiltinActionID
    let isAvailable: Bool

    var id: Int { index }
}

enum InstantActionsRailPolicy {
    static func slots(
        for items: [ShelfItemRecord],
        selectedItemIDs: Set<UUID>,
        configuredActions: [BuiltinActionID]
    ) -> [InstantActionSlot] {
        guard !items.isEmpty else { return [] }
        let selectedItems = selectedItemIDs.isEmpty
            ? items
            : items.filter { selectedItemIDs.contains($0.id) }
        let available = BuiltinActionCatalog.availableActions(for: selectedItems)
        return configuredActions
            .prefix(ShelfInstantActionLayout.actionLimit)
            .enumerated()
            .map { index, action in
                InstantActionSlot(
                    index: index,
                    action: action,
                    isAvailable: available.contains(action)
                )
            }
    }
}

struct InstantActionsRailView: View {
    @Bindable var store: ShelfStore
    let onAction: (BuiltinActionID) -> Void
    var onGlassLayout: (Int, Bool, Bool, Bool) -> Void = { _, _, _, _ in }

    @AppStorage(AppPreferences.reduceMotionKey) private var reduceShelfMotion = false
    @AppStorage(AppPreferences.instantActionSlot1Key)
    private var slot1 = AppPreferences.defaultInstantActionIDs[0].rawValue
    @AppStorage(AppPreferences.instantActionSlot2Key)
    private var slot2 = AppPreferences.defaultInstantActionIDs[1].rawValue
    @AppStorage(AppPreferences.instantActionSlot3Key)
    private var slot3 = AppPreferences.defaultInstantActionIDs[2].rawValue
    @AppStorage(AppPreferences.instantActionSlot4Key)
    private var slot4 = AppPreferences.defaultInstantActionIDs[3].rawValue
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var languageController = AppLanguageController.shared
    @State private var hoveredSlotIndex: Int?
    @State private var isEntryHovered = false
    @State private var collapseTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                ForEach(slots) { slot in
                    actionButton(slot)
                        .offset(x: offset(for: slot))
                }
            }
            .frame(height: ShelfInstantActionLayout.entryHitDiameter)

            // Glyphs stay outside the glass compositor in this transparent child panel.
            ZStack {
                ForEach(slots) { slot in
                    Image(systemName: slot.action.symbolName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(iconColor)
                        .opacity(isExpanded ? (slot.isAvailable ? 1 : 0.34) : 0)
                        .offset(x: offset(for: slot))
                }
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .opacity(isExpanded || slots.isEmpty ? 0 : 1)
            }
            .frame(height: ShelfInstantActionLayout.entryHitDiameter)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            Button(action: expand) {
                Circle().fill(.clear)
                    .frame(
                        width: ShelfInstantActionLayout.entryHitDiameter,
                        height: ShelfInstantActionLayout.entryHitDiameter
                    )
                    .contentShape(.circle)
            }
            .buttonStyle(ShelfControlButtonStyle())
            .allowsHitTesting(!isExpanded && !slots.isEmpty)
            .accessibilityHidden(isExpanded || slots.isEmpty)
            .onHover { hovering in
                isEntryHovered = hovering
                if hovering { expand() }
            }
            .help("Instant Actions")
            .accessibilityLabel("Show Instant Actions")
        }
        .frame(
            width: ShelfInstantActionLayout.panel.width,
            height: ShelfInstantActionLayout.panel.height,
            alignment: .bottom
        )
        .animation(railAnimation, value: isExpanded)
        .animation(.easeOut(duration: 0.14), value: hoveredSlotIndex)
        .contentShape(.rect)
        .onHover { hovering in
            collapseTask?.cancel()
            collapseTask = nil
            guard !hovering else { return }
            collapseTask = Task { @MainActor in
                do {
                    try await Task.sleep(for: .milliseconds(160))
                } catch { return }
                guard !Task.isCancelled else { return }
                hoveredSlotIndex = nil
                store.dismissInstantActions()
            }
        }
        .onAppear { syncGlassLayout() }
        .onChange(of: isExpanded) { _, _ in syncGlassLayout() }
        .onChange(of: reduceTransparency) { _, _ in syncGlassLayout() }
        .onChange(of: reduceMotion) { _, _ in syncGlassLayout() }
        .onChange(of: slots) { _, newSlots in
            if newSlots.isEmpty { store.dismissInstantActions() }
            syncGlassLayout()
        }
        .onExitCommand { store.dismissInstantActions() }
        .onDisappear {
            collapseTask?.cancel()
            collapseTask = nil
            hoveredSlotIndex = nil
            isEntryHovered = false
            store.instantActionPreviewTitle = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Instant Actions")
        .environment(languageController)
        .environment(\.locale, languageController.locale)
    }

    private func actionButton(_ slot: InstantActionSlot) -> some View {
        let isHovered = isExpanded ? hoveredSlotIndex == slot.index : isEntryHovered
        let diameter = isExpanded
            ? ShelfInstantActionLayout.actionDiameter
            : ShelfInstantActionLayout.entryVisibleDiameter
        return Button {
            guard isExpanded, slot.isAvailable else { return }
            hoveredSlotIndex = nil
            store.dismissInstantActions()
            Task { @MainActor in
                await Task.yield()
                onAction(slot.action)
            }
        } label: {
            Circle()
                .fill(.clear)
                .frame(width: diameter, height: diameter)
                .background {
                    if reduceTransparency {
                        Circle().fill(Color(nsColor: .windowBackgroundColor))
                            .overlay { Circle().stroke(.primary.opacity(0.35), lineWidth: 1) }
                    }
                }
                .overlay {
                    if !reduceTransparency {
                        // A quiet rim stays readable on a white page without
                        // tinting the whole glass surface into an opaque disk.
                        Circle()
                            .strokeBorder(.primary.opacity(isHovered ? 0.14 : 0.09), lineWidth: 0.5)
                            .shadow(color: .black.opacity(0.10), radius: 2.5, y: 1)
                            .overlay {
                                Circle().strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.9), .clear, .white.opacity(0.35)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.75
                                )
                            }
                    }
                }
                .contentShape(.circle)
        }
        .buttonStyle(ShelfControlButtonStyle())
        .opacity(isExpanded ? (slot.isAvailable ? 1 : 0.34) : (slot.index == 0 ? 1 : 0))
        .disabled(isExpanded && !slot.isAvailable)
        .allowsHitTesting(isExpanded)
        .accessibilityHidden(!isExpanded)
        .onHover { hovering in
            guard isExpanded else { return }
            if hovering {
                hoveredSlotIndex = slot.index
                store.instantActionPreviewTitle = slot.action.displayTitle
            } else if hoveredSlotIndex == slot.index {
                hoveredSlotIndex = nil
                store.instantActionPreviewTitle = nil
            }
        }
        .help(slot.isAvailable ? slot.action.displayTitle : AppLocalization.string("Not available for these items"))
        .accessibilityLabel(slot.action.displayTitle)
    }

    private func syncGlassLayout() {
        onGlassLayout(slots.count, isExpanded, reduceMotion, reduceTransparency)
    }

    private func expand() {
        guard !slots.isEmpty else { return }
        collapseTask?.cancel()
        collapseTask = nil
        store.isInstantActionsPresented = true
    }

    private func offset(for slot: InstantActionSlot) -> CGFloat {
        CGFloat(ShelfInstantActionLayout.horizontalOffset(
            index: slot.index,
            buttonCount: slots.count,
            isExpanded: isExpanded
        ))
    }

    private var slots: [InstantActionSlot] {
        InstantActionsRailPolicy.slots(
            for: store.shelf.items,
            selectedItemIDs: store.selectedItemIDs,
            configuredActions: AppPreferences.instantActionIDs(rawValues: [slot1, slot2, slot3, slot4])
        )
    }

    private var isExpanded: Bool { store.isInstantActionsPresented && !slots.isEmpty }
    private var iconColor: Color { colorScheme == .dark ? .white.opacity(0.92) : .black.opacity(0.78) }
    private var reduceMotion: Bool {
        reduceShelfMotion || systemReduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    private var railAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: ShelfInstantActionLayout.animationDuration)
    }
}

final class InstantActionGlassView: NSGlassEffectContainerView {
    private let surfaceContainer = NSView()
    private var surfaces: [NSGlassEffectView] = []
    private var expanded = false
    private var itemCount = 0
    private var lastLayoutSize = NSSize.zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        clipsToBounds = false
        surfaceContainer.clipsToBounds = false
        spacing = ShelfInstantActionLayout.actionSpacing
        surfaceContainer.frame = bounds
        surfaceContainer.autoresizingMask = [.width, .height]
        contentView = surfaceContainer
        for _ in 0..<ShelfInstantActionLayout.actionLimit {
            let surface = NSGlassEffectView()
            surface.style = .clear
            // These controls have no shelf glass behind them. A light adaptive
            // tint matches the controls on the shelf without stacking blur layers.
            surface.tintColor = NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                    ? NSColor.white.withAlphaComponent(0.06)
                    : NSColor.white.withAlphaComponent(0.28)
            }
            // SwiftUI already supplies hover/press feedback; AppKit's interactive
            // material would darken the hovered circle a second time.
            if #available(macOS 27, *) { surface.effectIsInteractive = false }
            surfaceContainer.addSubview(surface)
            surfaces.append(surface)
        }
    }

    required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(count: Int, expanded: Bool, reduceMotion: Bool) {
        guard itemCount != count || self.expanded != expanded else { return }
        let shouldAnimate = itemCount > 0 && self.expanded != expanded && !reduceMotion
        itemCount = count
        self.expanded = expanded
        positionSurfaces(animated: shouldAnimate)
    }

    override func layout() {
        super.layout()
        if lastLayoutSize != bounds.size {
            lastLayoutSize = bounds.size
            positionSurfaces(animated: false)
        }
    }

    private func positionSurfaces(animated: Bool) {
        let diameter = expanded
            ? ShelfInstantActionLayout.actionDiameter
            : ShelfInstantActionLayout.entryVisibleDiameter
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated ? ShelfInstantActionLayout.animationDuration : 0
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for (index, surface) in surfaces.enumerated() {
                let offset = ShelfInstantActionLayout.horizontalOffset(
                    index: index, buttonCount: itemCount, isExpanded: expanded
                )
                let frame = NSRect(
                    x: bounds.midX + offset - diameter / 2,
                    y: bounds.midY - diameter / 2,
                    width: diameter, height: diameter
                )
                surface.cornerRadius = diameter / 2
                let opacity: CGFloat = index < itemCount && (expanded || index == 0) ? 1 : 0
                if animated {
                    surface.animator().frame = frame
                    surface.animator().alphaValue = opacity
                } else {
                    surface.frame = frame
                    surface.alphaValue = opacity
                }
            }
        }
    }
}

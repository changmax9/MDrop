import CoreGraphics
import Foundation
import MDropCore
import Observation

enum ShelfDetailViewMode: Hashable {
    case grid
    case list
}

@MainActor
@Observable
final class ShelfStore {
    var shelf: ShelfRecord
    var selectedItemIDs: Set<UUID> = []
    var detailViewMode: ShelfDetailViewMode = .grid
    var isPointerInsideShelf = false
    var isCustomizationPresented = false
    var isReceivingDrop = false
    var targetedItemCount = 0
    private(set) var pendingImports = 0
    private(set) var dropReceipt: DropReceipt?

    struct DropReceipt: Equatable {
        let id = UUID()
        let count: Int
    }

    var isImporting: Bool { pendingImports > 0 }

    func beginImport() {
        pendingImports += 1
        dropReceipt = nil
    }

    func endImport() {
        pendingImports = max(0, pendingImports - 1)
    }

    func confirmDrop(count: Int) {
        guard count > 0 else { return }
        dropReceipt = DropReceipt(count: count)
    }

    func clearDropReceipt(id: UUID) {
        guard dropReceipt?.id == id else { return }
        dropReceipt = nil
    }

    var isCommandBarPresented = false
    var commandQuery = ""
    var isInstantActionsPresented = false
    var instantActionPreviewTitle: String?
    var actionProgress: Double?
    var errorMessage: String?
    var isClosing = false
    var isLayoutTransitioning = false
    var isLayoutContentVisible = true
    var pendingPresentationState: ShelfPresentationState?
    private(set) var layoutTransitionID: UUID?
    private(set) var layoutSourceSize: CGSize?
    private(set) var layoutTargetSize: CGSize?
    private(set) var layoutContentFadeDuration =
        ShelfMotionProfile.reference.layoutFadeDuration
    let animatesInitialAppearance: Bool
    @ObservationIgnored var cancelAction: (() -> Void)?

    init(
        shelf: ShelfRecord,
        animatesInitialAppearance: Bool = true
    ) {
        self.shelf = shelf
        self.animatesInitialAppearance = animatesInitialAppearance
    }

    @discardableResult
    func beginLayoutTransition(
        to targetState: ShelfPresentationState,
        sourceSize: CGSize? = nil,
        targetSize: CGSize? = nil,
        contentFadeDuration: TimeInterval =
            ShelfMotionProfile.reference.layoutFadeDuration
    ) -> UUID {
        let transitionID = UUID()
        layoutTransitionID = transitionID
        pendingPresentationState = targetState
        layoutSourceSize = sourceSize
        layoutTargetSize = targetSize
        layoutContentFadeDuration = max(0.01, contentFadeDuration)
        isLayoutTransitioning = true
        isLayoutContentVisible = false
        return transitionID
    }

    @discardableResult
    func revealLayoutContent(for transitionID: UUID) -> Bool {
        guard layoutTransitionID == transitionID else { return false }
        isLayoutContentVisible = true
        return true
    }

    @discardableResult
    func endLayoutTransition(for transitionID: UUID) -> Bool {
        guard layoutTransitionID == transitionID else { return false }
        isLayoutTransitioning = false
        isLayoutContentVisible = true
        pendingPresentationState = nil
        layoutTransitionID = nil
        layoutSourceSize = nil
        layoutTargetSize = nil
        layoutContentFadeDuration =
            ShelfMotionProfile.reference.layoutFadeDuration
        return true
    }

    func cancelLayoutTransition() {
        isLayoutTransitioning = false
        isLayoutContentVisible = true
        pendingPresentationState = nil
        layoutTransitionID = nil
        layoutSourceSize = nil
        layoutTargetSize = nil
        layoutContentFadeDuration =
            ShelfMotionProfile.reference.layoutFadeDuration
    }

    func append(_ items: [ShelfItemRecord]) {
        let wasDetail = shelf.presentationState == .detail
        shelf.append(items)
        if wasDetail, !shelf.items.isEmpty {
            shelf.presentationState = .detail
        }
    }

    func remove(_ ids: Set<UUID>) {
        shelf.items.removeAll { ids.contains($0.id) }
        selectedItemIDs.subtract(ids)
        shelf.modifiedAt = .now
        if shelf.items.isEmpty {
            shelf.presentationState = .empty
            dismissInstantActions()
        }
    }

    func dismissInstantActions() {
        isInstantActionsPresented = false
        instantActionPreviewTitle = nil
    }

    func toggleSelection(_ id: UUID, extending: Bool) {
        if extending {
            if !selectedItemIDs.insert(id).inserted {
                selectedItemIDs.remove(id)
            }
        } else {
            selectedItemIDs = [id]
        }
    }
}

import Foundation
import MDropCore
import Observation

@MainActor
@Observable
final class ShelfStore {
    var shelf: ShelfRecord
    var selectedItemIDs: Set<UUID> = []
    var isReceivingDrop = false
    var isCommandBarPresented = false
    var commandQuery = ""
    var showsInstantActions = false
    var actionProgress: Double?
    var errorMessage: String?
    var isClosing = false
    var isShelfHovered = false
    var isWindowDragging = false
    var isLayoutContentVisible = true
    let animatesInitialAppearance: Bool
    @ObservationIgnored var cancelAction: (() -> Void)?

    init(
        shelf: ShelfRecord,
        animatesInitialAppearance: Bool = true
    ) {
        self.shelf = shelf
        self.animatesInitialAppearance = animatesInitialAppearance
    }

    func append(_ items: [ShelfItemRecord]) {
        shelf.append(items)
    }

    func remove(_ ids: Set<UUID>) {
        shelf.items.removeAll { ids.contains($0.id) }
        selectedItemIDs.subtract(ids)
        shelf.modifiedAt = .now
        if shelf.items.isEmpty {
            shelf.presentationState = .empty
        }
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

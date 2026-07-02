import Foundation

public enum ShelfDragSelection {
    public static func items(
        from allItems: [ShelfItemRecord],
        selectedItemIDs: Set<UUID>,
        initiatingItemID: UUID?,
        dragsEntireShelf: Bool
    ) -> [ShelfItemRecord] {
        guard !allItems.isEmpty else { return [] }
        if dragsEntireShelf {
            return allItems
        }

        guard let initiatingItemID,
              let initiatingItem = allItems.first(where: {
                  $0.id == initiatingItemID
              })
        else { return [] }

        guard selectedItemIDs.contains(initiatingItemID) else {
            return [initiatingItem]
        }
        return allItems.filter { selectedItemIDs.contains($0.id) }
    }
}

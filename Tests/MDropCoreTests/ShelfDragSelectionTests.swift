import Foundation
import Testing
@testable import MDropCore

@Suite("Shelf drag selection")
struct ShelfDragSelectionTests {
    @Test("Compact shelf drags every item in shelf order")
    func compactShelfDragsEveryItemInShelfOrder() {
        let first = ShelfItemRecord.text("first")
        let second = ShelfItemRecord.text("second")
        let third = ShelfItemRecord.text("third")

        let result = ShelfDragSelection.items(
            from: [first, second, third],
            selectedItemIDs: [],
            initiatingItemID: third.id,
            dragsEntireShelf: true
        )

        #expect(result.map(\.id) == [first.id, second.id, third.id])
    }

    @Test("Detail drag keeps an existing multi-selection")
    func detailDragKeepsExistingMultiSelection() {
        let first = ShelfItemRecord.text("first")
        let second = ShelfItemRecord.text("second")
        let third = ShelfItemRecord.text("third")

        let result = ShelfDragSelection.items(
            from: [first, second, third],
            selectedItemIDs: [first.id, third.id],
            initiatingItemID: third.id,
            dragsEntireShelf: false
        )

        #expect(result.map(\.id) == [first.id, third.id])
    }

    @Test("Unselected detail item drags by itself")
    func unselectedDetailItemDragsByItself() {
        let first = ShelfItemRecord.text("first")
        let second = ShelfItemRecord.text("second")

        let result = ShelfDragSelection.items(
            from: [first, second],
            selectedItemIDs: [first.id],
            initiatingItemID: second.id,
            dragsEntireShelf: false
        )

        #expect(result.map(\.id) == [second.id])
    }
}

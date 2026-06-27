import Foundation
import XCTest
@testable import MDropCore

final class ShelfRecordTests: XCTestCase {
    func testAppendingItemsUpdatesModificationDateAndKeepsOrder() {
        let createdAt = Date(timeIntervalSince1970: 10)
        let modifiedAt = Date(timeIntervalSince1970: 20)
        let newModifiedAt = Date(timeIntervalSince1970: 30)
        let first = ShelfItemRecord.text("first", now: createdAt)
        let second = ShelfItemRecord.text("second", now: newModifiedAt)
        var shelf = ShelfRecord(
            name: "Inbox",
            items: [first],
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )

        shelf.append([second], now: newModifiedAt)

        XCTAssertEqual(shelf.items.map(\.id), [first.id, second.id])
        XCTAssertEqual(shelf.modifiedAt, newModifiedAt)
    }

    func testPinnedShelfDoesNotAutoCloseWhenEmpty() {
        var shelf = ShelfRecord(name: "Pinned", isPinned: true)

        shelf.removeAll(now: Date(timeIntervalSince1970: 40))

        XCTAssertFalse(shelf.shouldAutoClose)
    }

    func testUnpinnedShelfAutoClosesWhenEmpty() {
        var shelf = ShelfRecord(name: "Temporary")

        shelf.removeAll(now: Date(timeIntervalSince1970: 40))

        XCTAssertTrue(shelf.shouldAutoClose)
    }
}

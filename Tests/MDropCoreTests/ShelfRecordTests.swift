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

    func testAppendingTheSameFileAgainDoesNotDuplicateIt() {
        let fileURL = URL(filePath: "/tmp/MDrop-duplicate.pdf")
        let first = ShelfItemRecord(
            payload: .file(FileReference(url: fileURL)),
            displayName: fileURL.lastPathComponent
        )
        let duplicate = ShelfItemRecord(
            payload: .file(FileReference(url: fileURL)),
            displayName: fileURL.lastPathComponent
        )
        var shelf = ShelfRecord(items: [first])

        shelf.append([duplicate])

        XCTAssertEqual(shelf.items.map(\.id), [first.id])
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

    func testMoveItemPlacesDraggedItemBeforeDestination() {
        let first = ShelfItemRecord.text("First")
        let second = ShelfItemRecord.text("Second")
        let third = ShelfItemRecord.text("Third")
        var shelf = ShelfRecord(items: [first, second, third])

        shelf.moveItem(first.id, before: third.id)

        XCTAssertEqual(shelf.items.map(\.id), [second.id, first.id, third.id])
    }

    func testInvalidBookmarkFallsBackToOriginalURL() {
        let original = URL(filePath: "/tmp/missing-mdrop-file")
        let reference = FileReference(
            url: original,
            bookmarkData: Data("not-a-bookmark".utf8)
        )

        XCTAssertEqual(reference.resolvedURL(), original)
    }

    func testPortableBookmarkResolvesWithoutSecurityScope() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "portable.txt")
        try Data().write(to: fileURL)
        let bookmark = try fileURL.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let reference = FileReference(
            url: URL(filePath: "/tmp/stale-path"),
            bookmarkData: bookmark
        )

        XCTAssertEqual(
            reference.resolvedURL().standardizedFileURL,
            fileURL.standardizedFileURL
        )
    }
}

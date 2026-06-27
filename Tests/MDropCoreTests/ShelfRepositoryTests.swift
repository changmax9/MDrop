import Foundation
import XCTest
@testable import MDropCore

final class ShelfRepositoryTests: XCTestCase {
    func testArchiveRoundTripsThroughDisk() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "shelves.json")
        let shelf = ShelfRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Design",
            items: [.text("Brief")]
        )
        let repository = ShelfRepository(fileURL: fileURL)

        try await repository.save(ShelfArchive(visible: [shelf], recent: []))
        let loaded = try await repository.load()

        XCTAssertEqual(loaded.visible, [shelf])
        XCTAssertTrue(loaded.recent.isEmpty)
    }

    func testRememberClosedKeepsPinnedShelvesAndOnlyTenRegularShelves() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let repository = ShelfRepository(
            fileURL: directory.appending(path: "shelves.json"),
            maxRecent: 10
        )
        let pinned = ShelfRecord(name: "Pinned", isPinned: true)
        try await repository.save(ShelfArchive(visible: [], recent: [pinned]))

        for index in 0..<12 {
            try await repository.rememberClosed(
                ShelfRecord(
                    name: "Shelf \(index)",
                    modifiedAt: Date(timeIntervalSince1970: TimeInterval(index))
                )
            )
        }

        let archive = try await repository.load()
        XCTAssertEqual(archive.recent.filter(\.isPinned), [pinned])
        XCTAssertEqual(archive.recent.filter { !$0.isPinned }.count, 10)
        XCTAssertEqual(archive.recent.first { !$0.isPinned }?.name, "Shelf 11")
    }
}

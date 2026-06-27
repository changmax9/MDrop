import Foundation
import XCTest
@testable import MDropCore

final class ThumbnailCacheKeyTests: XCTestCase {
    func testKeyChangesWithFileModificationOrRequestedSize() {
        let url = URL(filePath: "/tmp/example.pdf")
        let first = ThumbnailCacheKey(
            url: url,
            modificationDate: Date(timeIntervalSince1970: 1),
            width: 80,
            height: 96,
            scale: 2
        )
        let modified = ThumbnailCacheKey(
            url: url,
            modificationDate: Date(timeIntervalSince1970: 2),
            width: 80,
            height: 96,
            scale: 2
        )
        let resized = ThumbnailCacheKey(
            url: url,
            modificationDate: Date(timeIntervalSince1970: 1),
            width: 120,
            height: 120,
            scale: 2
        )

        XCTAssertNotEqual(first, modified)
        XCTAssertNotEqual(first, resized)
    }

    func testEquivalentStandardizedURLsShareAKey() {
        let first = ThumbnailCacheKey(
            url: URL(filePath: "/tmp/folder/../example.pdf"),
            modificationDate: nil,
            width: 80,
            height: 96,
            scale: 2
        )
        let second = ThumbnailCacheKey(
            url: URL(filePath: "/tmp/example.pdf"),
            modificationDate: nil,
            width: 80,
            height: 96,
            scale: 2
        )

        XCTAssertEqual(first, second)
    }
}

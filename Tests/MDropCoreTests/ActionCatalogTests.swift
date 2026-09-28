import Foundation
import Testing
import XCTest
@testable import MDropCore

final class ActionCatalogTests: XCTestCase {
    func testImageOnlyActionsRequireEveryItemToBeAnImage() {
        let image = ShelfItemRecord(
            payload: .file(FileReference(url: URL(filePath: "/tmp/photo.png"))),
            displayName: "photo.png"
        )
        let textFile = ShelfItemRecord(
            payload: .file(FileReference(url: URL(filePath: "/tmp/notes.txt"))),
            displayName: "notes.txt"
        )

        XCTAssertTrue(
            BuiltinActionCatalog.availableActions(for: [image]).contains(.extractText)
        )
        XCTAssertFalse(
            BuiltinActionCatalog.availableActions(for: [image, textFile]).contains(.extractText)
        )
    }

    func testGeneralFileActionsRejectTextAndURLPayloads() {
        let text = ShelfItemRecord.text("hello")
        let url = ShelfItemRecord(
            payload: .url(URL(string: "https://example.com")!),
            displayName: "example.com"
        )

        let actions = BuiltinActionCatalog.availableActions(for: [text, url])

        XCTAssertFalse(actions.contains(.moveTo))
        XCTAssertFalse(actions.contains(.copyPath))
        XCTAssertTrue(actions.contains(.copyText))
    }

    func testArchiveIsAvailableForAnyNonEmptySelection() {
        let text = ShelfItemRecord.text("hello")

        XCTAssertTrue(
            BuiltinActionCatalog.availableActions(for: [text]).contains(.createArchive)
        )
        XCTAssertFalse(
            BuiltinActionCatalog.availableActions(for: []).contains(.createArchive)
        )
    }

}

@Suite("Instant action catalog")
struct InstantActionCatalogTests {
    @Test("Cardinality-sensitive actions match their executors")
    func cardinalitySensitiveActions() {
        let firstImage = ShelfItemRecord(
            payload: .file(FileReference(url: URL(filePath: "/tmp/first.png"))),
            displayName: "first.png"
        )
        let secondImage = ShelfItemRecord(
            payload: .file(FileReference(url: URL(filePath: "/tmp/second.png"))),
            displayName: "second.png"
        )

        let singleImageActions = BuiltinActionCatalog.availableActions(
            for: [firstImage]
        )
        #expect(singleImageActions.contains(.rename))
        #expect(!singleImageActions.contains(.stitchImages))

        let multipleImageActions = BuiltinActionCatalog.availableActions(
            for: [firstImage, secondImage]
        )
        #expect(!multipleImageActions.contains(.rename))
        #expect(multipleImageActions.contains(.stitchImages))
    }

    @Test("Priority, limit, and availability remain deterministic")
    func priorityLimitAndAvailability() {
        let image = ShelfItemRecord(
            payload: .file(FileReference(url: URL(filePath: "/tmp/photo.png"))),
            displayName: "photo.png"
        )

        #expect(
            BuiltinActionCatalog.instantActions(for: [image])
                == [.systemShare, .copyTo, .moveTo, .resizeImages]
        )
        #expect(
            BuiltinActionCatalog.instantActions(for: [image], limit: 2)
                == [.systemShare, .copyTo]
        )
        #expect(
            BuiltinActionCatalog.instantActions(
                for: [ShelfItemRecord.text("hello")]
            ) == [.systemShare, .copyText, .createArchive]
        )
        #expect(
            BuiltinActionCatalog.instantActions(for: [], limit: 4).isEmpty
        )
        #expect(
            BuiltinActionCatalog.instantActions(
                for: [image],
                limit: 0
            ).isEmpty
        )
    }
}

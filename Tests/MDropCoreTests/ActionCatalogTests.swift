import Foundation
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

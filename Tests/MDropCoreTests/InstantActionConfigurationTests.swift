import XCTest
@testable import MDropCore

final class InstantActionConfigurationTests: XCTestCase {
    func testConfigurationDropsDuplicatesAndCapsActionsAtSix() {
        let configuration = InstantActionConfiguration(actions: [
            .systemShare,
            .systemShare,
            .createArchive,
            .copyTo,
            .moveTo,
            .copyPath,
            .copyText,
            .moveToTrash
        ])

        XCTAssertEqual(configuration.actions, [
            .systemShare,
            .createArchive,
            .copyTo,
            .moveTo,
            .copyPath,
            .copyText
        ])
    }

    func testAvailableActionsPreserveConfiguredOrder() {
        let configuration = InstantActionConfiguration(actions: [
            .extractText,
            .systemShare,
            .createPDF,
            .createArchive
        ])
        let textItem = ShelfItemRecord.text("Hello")

        XCTAssertEqual(
            configuration.availableActions(for: [textItem]),
            [.systemShare, .createArchive]
        )
    }
}

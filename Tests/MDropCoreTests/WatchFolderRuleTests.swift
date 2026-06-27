import Foundation
import XCTest
@testable import MDropCore

final class WatchFolderRuleTests: XCTestCase {
    func testExtensionMatchingIsCaseInsensitive() {
        let rule = WatchFolderRule(allowedExtensions: ["png", "jpg"])

        XCTAssertTrue(rule.matches(URL(filePath: "/tmp/HERO.PNG")))
        XCTAssertFalse(rule.matches(URL(filePath: "/tmp/notes.txt")))
    }

    func testHiddenFilesAreRejectedByDefault() {
        let rule = WatchFolderRule()

        XCTAssertFalse(rule.matches(URL(filePath: "/tmp/.download")))
    }

    func testNameFilterAndExtensionMustBothMatch() {
        let rule = WatchFolderRule(
            allowedExtensions: ["png"],
            nameContains: "screenshot"
        )

        XCTAssertTrue(rule.matches(URL(filePath: "/tmp/Screenshot 2026.PNG")))
        XCTAssertFalse(rule.matches(URL(filePath: "/tmp/hero.png")))
        XCTAssertFalse(rule.matches(URL(filePath: "/tmp/screenshot.txt")))
    }
}

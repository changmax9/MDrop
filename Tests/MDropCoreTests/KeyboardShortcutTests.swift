import XCTest
@testable import MDropCore

final class KeyboardShortcutTests: XCTestCase {
    func testValidatorFindsShortcutsWithIdenticalKeyAndModifiers() {
        let shortcuts = [
            KeyboardShortcut(id: "new", keyCode: 49, modifiers: 3),
            KeyboardShortcut(id: "clipboard", keyCode: 0, modifiers: 3),
            KeyboardShortcut(id: "duplicate", keyCode: 49, modifiers: 3)
        ]

        XCTAssertEqual(
            KeyboardShortcutValidator.conflictingIDs(in: shortcuts),
            Set(["new", "duplicate"])
        )
    }

    func testValidatorAllowsSameKeyWithDifferentModifiers() {
        let shortcuts = [
            KeyboardShortcut(id: "one", keyCode: 49, modifiers: 3),
            KeyboardShortcut(id: "two", keyCode: 49, modifiers: 4)
        ]

        XCTAssertTrue(
            KeyboardShortcutValidator.conflictingIDs(in: shortcuts).isEmpty
        )
    }
}

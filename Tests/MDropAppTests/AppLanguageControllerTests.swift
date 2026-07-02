import Foundation
import Testing
@testable import MDropApp

@MainActor
@Suite("Application language")
struct AppLanguageControllerTests {
    @Test("Supports the eight requested language identifiers")
    func supportedIdentifiers() {
        #expect(
            AppLanguage.allCases.map(\.rawValue) == [
                "en",
                "zh-Hans",
                "zh-Hant",
                "ja",
                "fr",
                "ru",
                "es",
                "pt"
            ]
        )
    }

    @Test("Persists selection and restores its locale")
    func persistence() {
        let suiteName = "AppLanguageControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = AppLanguageController(defaults: defaults)
        controller.selection = .japanese
        let restored = AppLanguageController(defaults: defaults)

        #expect(defaults.string(forKey: "appLanguage") == "ja")
        #expect(restored.selection == .japanese)
        #expect(restored.locale.identifier == "ja")
    }

    @Test("Falls back to English for an invalid stored identifier")
    func invalidStoredIdentifier() {
        let suiteName = "AppLanguageControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("not-a-language", forKey: "appLanguage")

        let controller = AppLanguageController(defaults: defaults)

        #expect(controller.selection == .english)
        #expect(controller.locale.identifier == "en")
    }
}

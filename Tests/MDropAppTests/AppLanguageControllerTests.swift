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

    @Test("Explicit locale selects its lproj bundle at runtime")
    func explicitLocaleSelectsLocalizedBundle() throws {
        let bundleURL = FileManager.default.temporaryDirectory
            .appending(
                path: "MDropLocalization-\(UUID().uuidString).bundle",
                directoryHint: .isDirectory
            )
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }
        let resources = bundleURL
            .appending(path: "Contents/Resources")
        let russian = resources
            .appending(path: "ru.lproj")
        try FileManager.default.createDirectory(
            at: russian,
            withIntermediateDirectories: true
        )
        let info: [String: Any] = [
            "CFBundleIdentifier": "com.maxchang.MDrop.LocalizationFixture",
            "CFBundleName": "LocalizationFixture",
            "CFBundlePackageType": "BNDL"
        ]
        let infoData = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try infoData.write(
            to: bundleURL.appending(path: "Contents/Info.plist")
        )
        try #"""
        "Settings" = "Настройки";
        """#.write(
            to: russian.appending(path: "Localizable.strings"),
            atomically: true,
            encoding: .utf8
        )
        let bundle = try #require(Bundle(url: bundleURL))

        #expect(
            AppLocalization.string(
                "Settings",
                locale: Locale(identifier: "ru"),
                bundle: bundle
            ) == "Настройки"
        )
    }
}

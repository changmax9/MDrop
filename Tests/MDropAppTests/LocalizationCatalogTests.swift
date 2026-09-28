import Foundation
import Testing

@Suite("Localization catalog")
struct LocalizationCatalogTests {
    private let supportedLocales = Set([
        "en",
        "zh-Hans",
        "zh-Hant",
        "ja",
        "fr",
        "ru",
        "es",
        "pt"
    ])

    @Test("Every catalog key contains all supported languages")
    func everyKeyContainsEveryLanguage() throws {
        let strings = try catalogStrings()

        for (key, value) in strings {
            let localizations = try #require(
                value["localizations"] as? [String: Any],
                "Missing localizations for \(key)"
            )
            #expect(
                Set(localizations.keys) == supportedLocales,
                "Incomplete locales for \(key)"
            )
            for locale in supportedLocales {
                let localization = try #require(
                    localizations[locale] as? [String: Any]
                )
                let stringUnit = try #require(
                    localization["stringUnit"] as? [String: Any]
                )
                let translated = try #require(
                    stringUnit["value"] as? String
                )
                #expect(
                    !translated.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty,
                    "Empty \(locale) value for \(key)"
                )
            }
        }
    }

    @Test("Catalog contains cross-surface runtime language keys")
    func containsCrossSurfaceKeys() throws {
        let keys = Set(try catalogStrings().keys)
        let required = Set([
            "Language",
            "English",
            "Simplified Chinese",
            "Traditional Chinese",
            "Japanese",
            "French",
            "Russian",
            "Spanish",
            "Portuguese",
            "Grid View",
            "List View",
            "Check for Updates…",
            "Automatically check for updates",
            "Instant Actions",
            "More",
            "All Actions",
            "Text Actions",
            "Image Actions",
            "General Actions",
            "Customize",
            "Change Name…",
            "Copy Text Content",
            "Create ZIP Archive…",
            "Show Instant Actions",
            "After adding items, hover the lightning button to reveal four shortcuts.",
            "Not available for these items",
            "Restore Defaults",
            "Privacy & Legal",
            "Privacy",
            "Disclaimer",
            "Please read before using MDrop.",
            "Independent Project",
            "MDrop is an independent project and is not affiliated with, endorsed by, sponsored by, or officially associated with any company, organization, product, or service.",
            "Learning & Knowledge Exchange Only",
            "MDrop is provided solely for learning, research, and knowledge-sharing purposes.",
            "Use at Your Own Risk",
            "MDrop is provided “as is.” You use it at your own risk. To the fullest extent permitted by law, the developer and contributors are not liable for data loss, file damage, indirect loss, disputes, or other consequences arising from its use.",
            "About",
            "Settings…",
            "Quit MDrop"
        ])

        #expect(required.isSubset(of: keys))
    }

    private func catalogStrings() throws -> [String: [String: Any]] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(
            contentsOf:
                root.appending(path: "Resources/Localizable.xcstrings")
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        return try #require(
            object["strings"] as? [String: [String: Any]]
        )
    }
}

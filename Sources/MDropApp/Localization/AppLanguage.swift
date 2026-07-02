import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    static let storageKey = "appLanguage"

    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case french = "fr"
    case russian = "ru"
    case spanish = "es"
    case portuguese = "pt"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .french: "Français"
        case .russian: "Русский"
        case .spanish: "Español"
        case .portuguese: "Português"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

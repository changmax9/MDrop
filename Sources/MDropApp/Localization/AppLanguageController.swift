import Foundation
import Observation

enum AppLocalization {
    static func string(
        _ key: String,
        locale: Locale = selectedLanguage.locale,
        bundle: Bundle = .main
    ) -> String {
        let language =
            AppLanguage(rawValue: locale.identifier)
            ?? AppLanguage.allCases.first {
                locale.identifier.hasPrefix($0.rawValue)
            }
            ?? .english
        let localizedBundle =
            bundle.path(
                forResource: language.rawValue,
                ofType: "lproj"
            )
            .flatMap(Bundle.init(path:))
            ?? bundle
        return localizedBundle.localizedString(
            forKey: key,
            value: key,
            table: "Localizable"
        )
    }

    static func format(
        _ key: String,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: string(key),
            locale: selectedLanguage.locale,
            arguments: arguments
        )
    }

    static var selectedLanguage: AppLanguage {
        UserDefaults.standard.string(
            forKey: AppLanguage.storageKey
        )
        .flatMap(AppLanguage.init(rawValue:))
            ?? .english
    }
}

@MainActor
@Observable
final class AppLanguageController {
    static let shared = AppLanguageController()
    static let didChangeNotification = Notification.Name(
        "MDropAppLanguageDidChange"
    )

    private let defaults: UserDefaults

    var selection: AppLanguage {
        didSet {
            guard selection != oldValue else { return }
            defaults.set(selection.rawValue, forKey: AppLanguage.storageKey)
            NotificationCenter.default.post(
                name: Self.didChangeNotification,
                object: self
            )
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selection =
            defaults.string(forKey: AppLanguage.storageKey)
                .flatMap(AppLanguage.init(rawValue:))
            ?? .english
    }

    var locale: Locale {
        selection.locale
    }

    func string(_ key: String) -> String {
        AppLocalization.string(key, locale: locale)
    }
}

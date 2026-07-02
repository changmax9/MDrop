import SwiftUI

@main
struct MDropApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var languageController =
        AppLanguageController.shared

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(languageController)
                .environment(
                    \.locale,
                    languageController.locale
                )
        }
    }
}

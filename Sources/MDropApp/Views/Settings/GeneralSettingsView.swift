import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var languageController: AppLanguageController
    @Bindable var launchAtLogin: LaunchAtLoginSettings

    var body: some View {
        SettingsPage(
            "General",
            subtitle: "Choose MDrop's language and startup behavior."
        ) {
            SettingsCard {
                SettingsCardRow(
                    systemImage: "globe",
                    title: "Language",
                    subtitle: "Language & Region"
                ) {
                    SettingsGlassPicker(
                        title: "Language",
                        selection: $languageController.selection,
                        options: AppLanguage.allCases.map {
                            .init(value: $0, title: $0.nativeName)
                        }
                    )
                    .frame(width: 164)
                }

                SettingsCardDivider()

                SettingsCardRow(
                    systemImage: "power",
                    title: "Launch MDrop at login",
                    subtitle: "Startup"
                ) {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { enabled in
                                launchAtLogin.setEnabled(enabled)
                            }
                        )
                    )
                    .labelsHidden()
                }
            }
        }
    }
}

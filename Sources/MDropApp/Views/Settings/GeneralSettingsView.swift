import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var languageController: AppLanguageController
    @Binding var launchAtLogin: Bool
    @Binding var showDockIcon: Bool
    @Binding var copyByDefault: Bool
    @Binding var autoCloseDetail: Bool

    var body: some View {
        Section("Language & Region") {
            Picker(
                "Language",
                selection: $languageController.selection
            ) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.nativeName)
                        .tag(language)
                }
            }
        }

        Section("Startup") {
            Toggle("Launch MDrop at login", isOn: $launchAtLogin)
            Toggle("Show MDrop in the Dock", isOn: $showDockIcon)
        }

        Section("File Handling") {
            LabeledContent("Files") {
                Text("Files stay in their original locations.")
                    .foregroundStyle(.secondary)
            }
            Toggle(
                "Always copy items when dragging out",
                isOn: $copyByDefault
            )
            Toggle(
                "Automatically close Detail View",
                isOn: $autoCloseDetail
            )
        }
    }
}

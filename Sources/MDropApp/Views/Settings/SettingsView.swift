import AppKit
import MDropCore
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var selection: SettingsSection? = .general
    @State private var automation = AutomationStore.shared
    @State private var instantActions = InstantActionSettings.shared
    @State private var languageController =
        AppLanguageController.shared
    @State private var importsScripts = false
    @State private var importsFolder = false
    @State private var importedFolderIsForScreenshots = false

    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("shakeEnabled") private var shakeEnabled = true
    @AppStorage("shakeSensitivity") private var shakeSensitivity = 0.5
    @AppStorage("menuBarDropEnabled") private var menuBarDropEnabled = true
    @AppStorage("notchDropEnabled") private var notchDropEnabled = true
    @AppStorage("copyByDefault") private var copyByDefault = false
    @AppStorage("autoCloseDetail") private var autoCloseDetail = false
    @AppStorage("reduceShelfMotion") private var reduceShelfMotion = false
    @AppStorage("showDockIcon") private var showDockIcon = false

    var body: some View {
        NavigationSplitView {
            List(
                SettingsSection.allCases,
                selection: $selection
            ) { section in
                Label(section.title, systemImage: section.symbol)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(
                min: SettingsLayout.sidebarMinimumWidth,
                ideal: SettingsLayout.sidebarIdealWidth,
                max: 270
            )
        } detail: {
            Form {
                content(for: selection ?? .general)
            }
            .formStyle(.grouped)
            .navigationTitle(selection?.title ?? "Settings")
            .frame(minWidth: SettingsLayout.detailMinimumWidth)
        }
        .frame(
            width: SettingsLayout.preferredWidth,
            height: SettingsLayout.preferredHeight
        )
        .fileImporter(
            isPresented: $importsScripts,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true,
            onCompletion: importScripts
        )
        .fileImporter(
            isPresented: $importsFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: importFolder
        )
        .alert(
            "MDrop",
            isPresented: Binding(
                get: { automation.errorMessage != nil },
                set: { if !$0 { automation.errorMessage = nil } }
            )
        ) {
            Button("OK") { automation.errorMessage = nil }
        } message: {
            Text(automation.errorMessage ?? "")
        }
        .onChange(of: launchAtLogin, setLaunchAtLogin)
        .onChange(of: showDockIcon) { _, enabled in
            NSApp.setActivationPolicy(enabled ? .regular : .accessory)
        }
        .environment(languageController)
        .environment(\.locale, languageController.locale)
    }

    @ViewBuilder
    private func content(
        for section: SettingsSection
    ) -> some View {
        switch section {
        case .general:
            GeneralSettingsView(
                languageController: languageController,
                launchAtLogin: $launchAtLogin,
                showDockIcon: $showDockIcon,
                copyByDefault: $copyByDefault,
                autoCloseDetail: $autoCloseDetail
            )

        case .activationInteraction:
            Section("Shake Gesture") {
                Toggle(
                    "Create a Shelf while shaking dragged items",
                    isOn: $shakeEnabled
                )
                Slider(value: $shakeSensitivity, in: 0...1) {
                    Text("Sensitivity")
                }
            }
            Section("Other Methods") {
                Toggle(
                    "Drop to menu bar",
                    isOn: $menuBarDropEnabled
                )
                Toggle(
                    "Drop to MacBook notch",
                    isOn: $notchDropEnabled
                )
            }

        case .actionsAutomation:
            instantActionsSections
            customActionsSection
            folderMonitoringSection
            scriptsSection

        case .shortcutsIntegrations:
            Section("System") {
                LabeledContent(
                    "Shortcuts & Spotlight",
                    value: AppLocalization.string("Enabled")
                )
                LabeledContent(
                    "Services Menu",
                    value: AppLocalization.string("Enabled")
                )
                LabeledContent("URL Scheme", value: "mdrop://")
            }
            Section("Global") {
                LabeledContent("New Shelf", value: "⌥⇧Space")
                LabeledContent("Clipboard Shelf", value: "⌥⇧A")
                LabeledContent("Select Shelf", value: "⌥⇧S")
                if !hotKeyRegistrationFailures.isEmpty {
                    Label(
                        "Some shortcuts are already used by another app.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.orange)
                }
            }
            Section("Shelf") {
                LabeledContent("Command Bar", value: "⌘K")
                LabeledContent("Quick Look", value: "Space")
                LabeledContent("Close", value: "⌘W")
            }

        case .appearance:
            Section("Motion") {
                Toggle(
                    "Reduce MDrop motion",
                    isOn: $reduceShelfMotion
                )
            }
            Section("Glass") {
                Text(
                    "Floating Shelves use dark Liquid Glass; settings follow the system appearance and accessibility preferences."
                )
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
            }

        case .privacyLegal:
            PrivacyLegalSettingsView()

        case .about:
            AboutSettingsView()
        }
    }

    @ViewBuilder
    private var instantActionsSections: some View {
        Section("Instant Actions") {
            Text(
                "Choose up to six actions. Drag selected actions to reorder them."
            )
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(.secondary)

            ForEach(
                instantActions.configuration.actions,
                id: \.rawValue
            ) { action in
                Toggle(
                    action.displayTitle,
                    isOn: Binding(
                        get: { instantActions.isEnabled(action) },
                        set: {
                            instantActions.setEnabled($0, for: action)
                        }
                    )
                )
            }
            .onMove(perform: instantActions.move)
        }

        Section("Available Actions") {
            ForEach(
                BuiltinActionID.allCases.filter {
                    !instantActions.isEnabled($0)
                },
                id: \.rawValue
            ) { action in
                Toggle(
                    action.displayTitle,
                    isOn: Binding(
                        get: { instantActions.isEnabled(action) },
                        set: {
                            instantActions.setEnabled($0, for: action)
                        }
                    )
                )
                .disabled(
                    instantActions.configuration.actions.count
                        >= InstantActionConfiguration.maximumActionCount
                )
            }
        }
    }

    private var customActionsSection: some View {
        Section("Custom Actions") {
            if automation.customActions.isEmpty {
                Text("Save action parameters for one-click reuse.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(
                    Array(automation.customActions.enumerated()),
                    id: \.element.id
                ) { index, preset in
                    HStack {
                        Label(
                            preset.name,
                            systemImage: preset.action.symbolName
                        )
                        Spacer()
                        Button("Remove", systemImage: "trash") {
                            automation.removePresets(
                                at: IndexSet(integer: index)
                            )
                        }
                        .labelStyle(.iconOnly)
                    }
                }
            }

            Menu("Add Action…") {
                Button("Resize Images") {
                    automation.addPreset(for: .resizeImages)
                }
                Button("Compress Images") {
                    automation.addPreset(for: .compressImages)
                }
                Button("Convert to PNG") {
                    automation.addPreset(for: .convertImages)
                }
                Button("Create ZIP Archive") {
                    automation.addPreset(for: .createArchive)
                }
            }
        }
    }

    private var folderMonitoringSection: some View {
        Section("Folder Monitoring") {
            ForEach(
                Array(automation.watchedFolders.enumerated()),
                id: \.element.id
            ) { index, folder in
                HStack {
                    Label(
                        folder.name,
                        systemImage:
                            folder.isScreenshotFolder
                                ? "camera.viewfinder"
                                : "folder"
                    )
                    Spacer()
                    Button("Remove", systemImage: "trash") {
                        automation.removeWatchedFolders(
                            at: IndexSet(integer: index)
                        )
                    }
                    .labelStyle(.iconOnly)
                }
            }

            Button("Add Watched Folder…") {
                importedFolderIsForScreenshots = false
                importsFolder = true
            }
            Button("Configure Screenshot Shelves…") {
                importedFolderIsForScreenshots = true
                importsFolder = true
            }
        }
    }

    private var scriptsSection: some View {
        Section("Scripts") {
            ForEach(
                Array(automation.scripts.enumerated()),
                id: \.element.id
            ) { index, script in
                DisclosureGroup {
                    Picker(
                        "Output",
                        selection: Binding(
                            get: { script.outputMode },
                            set: { value in
                                automation.updateScript(script.id) {
                                    $0.outputMode = value
                                }
                            }
                        )
                    ) {
                        Text("Ignore")
                            .tag(ScriptOutputMode.ignore)
                        Text("Copy to Clipboard")
                            .tag(ScriptOutputMode.clipboard)
                    }
                    Stepper(
                        AppLocalization.format(
                            "Timeout: %lld seconds",
                            Int64(script.timeout)
                        ),
                        value: Binding(
                            get: { script.timeout },
                            set: { value in
                                automation.updateScript(script.id) {
                                    $0.timeout = value
                                }
                            }
                        ),
                        in: 1...600,
                        step: 1
                    )
                    Toggle(
                        "Close Shelf after success",
                        isOn: Binding(
                            get: { script.closesShelfOnSuccess },
                            set: { value in
                                automation.updateScript(script.id) {
                                    $0.closesShelfOnSuccess = value
                                }
                            }
                        )
                    )
                } label: {
                    HStack {
                        Label(script.name, systemImage: "terminal")
                        Spacer()
                        Text(script.kind.rawValue)
                            .foregroundStyle(.secondary)
                        Button("Remove", systemImage: "trash") {
                            automation.removeScripts(
                                at: IndexSet(integer: index)
                            )
                        }
                        .labelStyle(.iconOnly)
                    }
                }
            }

            Button("Import Scripts…") {
                importsScripts = true
            }
            Button("Reveal Script Logs") {
                NSWorkspace.shared.activateFileViewerSelecting(
                    [AppPaths.scriptLogs]
                )
            }
        }
    }

    private var hotKeyRegistrationFailures: [String] {
        UserDefaults.standard.stringArray(
            forKey: "hotKeyRegistrationFailures"
        ) ?? []
    }

    private func setLaunchAtLogin(
        _ oldValue: Bool,
        _ enabled: Bool
    ) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            automation.errorMessage = error.localizedDescription
            launchAtLogin = oldValue
        }
    }

    private func importScripts(
        _ result: Result<[URL], any Error>
    ) {
        guard case let .success(urls) = result else { return }
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            automation.addScript(url)
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    private func importFolder(
        _ result: Result<[URL], any Error>
    ) {
        guard case let .success(urls) = result,
              let url = urls.first
        else { return }

        let accessed = url.startAccessingSecurityScopedResource()
        automation.addWatchedFolder(
            url,
            screenshots: importedFolderIsForScreenshots
        )
        if accessed {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

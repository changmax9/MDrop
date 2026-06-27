import SwiftUI
import UniformTypeIdentifiers
import MDropCore
import ServiceManagement
import AppKit

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case activation
    case interaction
    case instantActions
    case customActions
    case automation
    case integrations
    case shortcuts
    case appearance
    case advanced

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .activation: "Shelf Activation"
        case .interaction: "Interaction"
        case .instantActions: "Instant Actions"
        case .customActions: "Custom Actions"
        case .automation: "Automation"
        case .integrations: "Integrations"
        case .shortcuts: "Keyboard Shortcuts"
        case .appearance: "Appearance"
        case .advanced: "Advanced"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gear"
        case .activation: "cursorarrow.motionlines"
        case .interaction: "hand.draw"
        case .instantActions: "bolt"
        case .customActions: "wand.and.stars"
        case .automation: "folder.badge.gearshape"
        case .integrations: "puzzlepiece.extension"
        case .shortcuts: "keyboard"
        case .appearance: "paintpalette"
        case .advanced: "gearshape.2"
        }
    }
}

struct SettingsView: View {
    @State private var selection: SettingsSection? = .general
    @State private var automation = AutomationStore.shared
    @State private var instantActions = InstantActionSettings.shared
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
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            Form {
                content(for: selection ?? .general)
            }
            .formStyle(.grouped)
            .navigationTitle(selection?.title ?? "Settings")
        }
        .frame(width: 760, height: 520)
        .fileImporter(
            isPresented: $importsScripts,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            if case let .success(urls) = result {
                for url in urls {
                    let accessed = url.startAccessingSecurityScopedResource()
                    automation.addScript(url)
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }
            }
        }
        .fileImporter(
            isPresented: $importsFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                let accessed = url.startAccessingSecurityScopedResource()
                automation.addWatchedFolder(
                    url,
                    screenshots: importedFolderIsForScreenshots
                )
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
        }
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
        .onChange(of: launchAtLogin) { _, enabled in
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                automation.errorMessage = error.localizedDescription
            }
        }
        .onChange(of: showDockIcon) { _, enabled in
            NSApp.setActivationPolicy(enabled ? .regular : .accessory)
        }
    }

    @ViewBuilder
    private func content(for section: SettingsSection) -> some View {
        switch section {
        case .general:
            Section("Startup") {
                Toggle("Launch MDrop at login", isOn: $launchAtLogin)
                Toggle("Show MDrop in the Dock", isOn: $showDockIcon)
            }
            Section("Storage") {
                LabeledContent("Files") {
                    Text("MDrop stores references to original files")
                        .foregroundStyle(.secondary)
                }
            }

        case .activation:
            Section("Shake Gesture") {
                Toggle("Create a Shelf while shaking dragged items", isOn: $shakeEnabled)
                Slider(value: $shakeSensitivity, in: 0...1) {
                    Text("Sensitivity")
                }
            }
            Section("Other Methods") {
                Toggle("Drop to menu bar", isOn: $menuBarDropEnabled)
                Toggle("Drop to MacBook notch", isOn: $notchDropEnabled)
            }

        case .interaction:
            Section("Dragging") {
                Toggle("Always copy items when dragging out", isOn: $copyByDefault)
                Toggle("Automatically close Detail View", isOn: $autoCloseDetail)
            }

        case .instantActions:
            Section("Instant Actions") {
                Text("Choose up to six actions. Drag selected actions to reorder them.")
                    .foregroundStyle(.secondary)
                ForEach(instantActions.configuration.actions, id: \.rawValue) { action in
                    Toggle(
                        action.displayTitle,
                        isOn: Binding(
                            get: { instantActions.isEnabled(action) },
                            set: { instantActions.setEnabled($0, for: action) }
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
                            set: { instantActions.setEnabled($0, for: action) }
                        )
                    )
                    .disabled(
                        instantActions.configuration.actions.count >=
                        InstantActionConfiguration.maximumActionCount
                    )
                }
            }

        case .customActions:
            Section("Saved Presets") {
                if automation.customActions.isEmpty {
                    Text("Save action parameters for one-click reuse.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(automation.customActions.enumerated()), id: \.element.id) { index, preset in
                        HStack {
                            Label(preset.name, systemImage: preset.action.symbolName)
                            Spacer()
                            Button("Remove", systemImage: "trash") {
                                automation.removePresets(at: IndexSet(integer: index))
                            }
                            .labelStyle(.iconOnly)
                        }
                    }
                }
                Menu("Add Action…") {
                    Button("Resize Images") { automation.addPreset(for: .resizeImages) }
                    Button("Compress Images") { automation.addPreset(for: .compressImages) }
                    Button("Convert to PNG") { automation.addPreset(for: .convertImages) }
                    Button("Create ZIP Archive") { automation.addPreset(for: .createArchive) }
                }
            }

        case .automation:
            Section("Folder Monitoring") {
                ForEach(Array(automation.watchedFolders.enumerated()), id: \.element.id) { index, folder in
                    HStack {
                        Label(
                            folder.name,
                            systemImage: folder.isScreenshotFolder ? "camera.viewfinder" : "folder"
                        )
                        Spacer()
                        Button("Remove", systemImage: "trash") {
                            automation.removeWatchedFolders(at: IndexSet(integer: index))
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
            Section("Scripts") {
                ForEach(Array(automation.scripts.enumerated()), id: \.element.id) { index, script in
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
                            Text("Ignore").tag(ScriptOutputMode.ignore)
                            Text("Copy to Clipboard").tag(ScriptOutputMode.clipboard)
                        }
                        Stepper(
                            "Timeout: \(Int(script.timeout)) seconds",
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

        case .integrations:
            Section("System") {
                LabeledContent("Shortcuts & Spotlight", value: "Enabled")
                LabeledContent("Services Menu", value: "Enabled")
                LabeledContent("URL Scheme", value: "mdrop://")
            }

        case .shortcuts:
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
                Toggle("Reduce MDrop motion", isOn: $reduceShelfMotion)
            }
            Section("Glass") {
                Text("MDrop follows the system appearance and accessibility settings.")
                    .foregroundStyle(.secondary)
            }

        case .advanced:
            Section("MDrop") {
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Minimum macOS", value: "26")
            }
            Section {
                Button("Reveal Application Support Folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([AppPaths.applicationSupport])
                }
            }
        }
    }

    private var hotKeyRegistrationFailures: [String] {
        UserDefaults.standard.stringArray(
            forKey: "hotKeyRegistrationFailures"
        ) ?? []
    }
}

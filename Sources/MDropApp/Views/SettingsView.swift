import SwiftUI

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
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("shakeEnabled") private var shakeEnabled = true
    @AppStorage("shakeSensitivity") private var shakeSensitivity = 0.5
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
                Toggle("Drop to menu bar", isOn: .constant(true))
                Toggle("Drop to MacBook notch", isOn: .constant(true))
            }

        case .interaction:
            Section("Dragging") {
                Toggle("Always copy items when dragging out", isOn: $copyByDefault)
                Toggle("Automatically close Detail View", isOn: $autoCloseDetail)
            }

        case .instantActions:
            Section("Instant Actions") {
                Text("AirDrop, Messages, Mail, Resize, OCR and Archive")
                    .foregroundStyle(.secondary)
                Button("Customize…") {}
            }

        case .customActions:
            Section {
                ContentUnavailableView(
                    "No Custom Actions",
                    systemImage: "wand.and.stars",
                    description: Text("Save action parameters for one-click reuse.")
                )
                Button("Add Action…") {}
            }

        case .automation:
            Section("Folder Monitoring") {
                Button("Add Watched Folder…") {}
                Button("Configure Screenshot Shelves…") {}
            }
            Section("Scripts") {
                Button("Manage Scripts…") {}
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
}

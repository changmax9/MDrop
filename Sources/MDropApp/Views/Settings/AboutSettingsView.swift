import AppKit
import SwiftUI

struct AboutSettingsView: View {
    @State private var updateService = UpdateService.shared

    var body: some View {
        Section {
            HStack(spacing: 16) {
                appIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text("About MDrop")
                        .font(.title2.weight(.semibold))
                    Text("Local-first")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .glassEffect(
                .regular,
                in: .rect(cornerRadius: 18)
            )
        }

        Section("Version") {
            LabeledContent("Current Version", value: shortVersion)
            LabeledContent("Build", value: buildNumber)
            LabeledContent("Minimum macOS", value: "26")
        }

        Section("Updates") {
            Button("Check for Updates…") {
                updateService.checkForUpdates()
            }
            .disabled(!updateService.canCheckForUpdates)

            Toggle(
                "Automatically check for updates",
                isOn: $updateService.automaticallyChecksForUpdates
            )
            Toggle(
                "Automatically download updates",
                isOn: $updateService.automaticallyDownloadsUpdates
            )
            .disabled(!updateService.automaticallyChecksForUpdates)
        }

        Section("Application Support") {
            Button("Reveal Application Support Folder") {
                NSWorkspace.shared.activateFileViewerSelecting(
                    [AppPaths.applicationSupport]
                )
            }
            Button("Open GitHub Project") {
                NSWorkspace.shared.open(
                    URL(string: "https://github.com/changmax9/MDrop")!
                )
            }
        }
        .onAppear {
            updateService.refresh()
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let image = BrandAssets.applicationIcon() {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
        } else {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 34, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 52, height: 52)
        }
    }

    private var shortVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.2.3"
    }

    private var buildNumber: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "5"
    }
}

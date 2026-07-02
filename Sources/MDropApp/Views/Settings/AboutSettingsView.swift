import AppKit
import SwiftUI

struct AboutSettingsView: View {
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
        ) as? String ?? "0.1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "1"
    }
}

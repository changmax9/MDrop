import SwiftUI

struct PrivacyLegalSettingsView: View {
    var body: some View {
        Section {
            ViewThatFits(in: .horizontal) {
                badgeRow
                badgeColumn
            }
            .padding(.vertical, 4)
        }

        Section("Privacy") {
            Text(
                "MDrop works entirely on this Mac. It does not upload files, create an account, or collect analytics."
            )
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(.secondary)

            LabeledContent("Storage") {
                Text("MDrop stores references to original files")
                    .foregroundStyle(.secondary)
            }
        }

        Section("Disclaimer") {
            Text(
                "File actions can move, rename, overwrite, or delete original files. Scripts and automations can make additional changes. Keep backups of important data."
            )
            .fixedSize(horizontal: false, vertical: true)

            Text(
                "MDrop is provided as-is without warranties. You are responsible for reviewing actions before running them."
            )
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(.secondary)
        }
    }

    private var badgeRow: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                privacyBadge("Local-first", systemImage: "internaldrive")
                privacyBadge("No cloud uploads", systemImage: "icloud.slash")
                privacyBadge("No telemetry", systemImage: "waveform.slash")
            }
        }
    }

    private var badgeColumn: some View {
        GlassEffectContainer(spacing: 6) {
            VStack(alignment: .leading, spacing: 6) {
                privacyBadge("Local-first", systemImage: "internaldrive")
                privacyBadge("No cloud uploads", systemImage: "icloud.slash")
                privacyBadge("No telemetry", systemImage: "waveform.slash")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func privacyBadge(
        _ title: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
    }
}

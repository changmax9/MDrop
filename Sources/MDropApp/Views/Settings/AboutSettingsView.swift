import AppKit
import SwiftUI

struct AboutSettingsView: View {
    @State private var updateService = UpdateService.shared

    var body: some View {
        SettingsPage(
            "About",
            subtitle: "Version information and software updates."
        ) {
            SettingsCard {
                appIdentityRow

                SettingsCardDivider()

                SettingsCardRow(
                    systemImage: "tag",
                    title: "Version"
                ) {
                    Text(verbatim: shortVersion)
                        .foregroundStyle(.secondary)
                }

                SettingsCardDivider()

                SettingsCardRow(
                    systemImage: "hammer",
                    title: "Build"
                ) {
                    Text(verbatim: buildNumber)
                        .foregroundStyle(.secondary)
                }
            }

            SettingsCard {
                SettingsCardRow(
                    systemImage: "arrow.triangle.2.circlepath",
                    title: "Updates"
                ) {
                    Button("Check for Updates…") {
                        updateService.checkForUpdates()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!updateService.canCheckForUpdates)
                }
            }

            SettingsCard {
                SettingsCardRow(
                    systemImage: "exclamationmark.shield.fill",
                    title: "Disclaimer",
                    subtitle: "Please read before using MDrop."
                )

                SettingsCardDivider()

                disclaimerRow(
                    number: 1,
                    title: "Independent Project",
                    body: "MDrop is an independent project and is not affiliated with, endorsed by, sponsored by, or officially associated with any company, organization, product, or service."
                )

                SettingsCardDivider()

                disclaimerRow(
                    number: 2,
                    title: "Learning & Knowledge Exchange Only",
                    body: "MDrop is provided solely for learning, research, and knowledge-sharing purposes."
                )

                SettingsCardDivider()

                disclaimerRow(
                    number: 3,
                    title: "Use at Your Own Risk",
                    body: "MDrop is provided “as is.” You use it at your own risk. To the fullest extent permitted by law, the developer and contributors are not liable for data loss, file damage, indirect loss, disputes, or other consequences arising from its use."
                )
            }
        }
        .onAppear {
            updateService.refresh()
        }
    }

    private func disclaimerRow(
        number: Int,
        title: LocalizedStringKey,
        body: LocalizedStringKey
    ) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(verbatim: String(number))
                .font(.caption.weight(.bold))
                .foregroundStyle(.tint)
                .frame(width: 30, height: 30)
                .background(
                    Color.accentColor.opacity(0.12),
                    in: .rect(cornerRadius: 8)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))

                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: SettingsLayout.cardRowMinimumHeight)
        .accessibilityElement(children: .combine)
    }

    private var appIdentityRow: some View {
        HStack(spacing: 14) {
            appIcon

            VStack(alignment: .leading, spacing: 2) {
                Text("MDrop")
                    .font(.body.weight(.semibold))
                Text(verbatim: "\(shortVersion) (\(buildNumber))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 68)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let image = BrandAssets.applicationIcon() {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
        } else {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 28, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 42, height: 42)
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

import AppKit
import SwiftUI

struct SettingsPage<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let content: Content

    init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 7) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity)

                GlassEffectContainer(spacing: 16) {
                    VStack(spacing: 16) {
                        content
                    }
                }
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 28)
            .padding(.top, 30)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .frame(
            minWidth: SettingsLayout.detailMinimumWidth,
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }
}

struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity)
        .modifier(ShelfGlassSurface(
            shape: RoundedRectangle(cornerRadius: SettingsLayout.cardCornerRadius, style: .continuous)
        ))
    }
}

struct SettingsCardRow<Trailing: View>: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let trailing: Trailing

    init(
        systemImage: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 30, height: 30)
                .background(
                    Color.accentColor.opacity(0.12),
                    in: .rect(cornerRadius: 8)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            trailing
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: SettingsLayout.cardRowMinimumHeight)
        .contentShape(.rect)
    }
}

extension SettingsCardRow where Trailing == EmptyView {
    init(
        systemImage: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil
    ) {
        self.init(
            systemImage: systemImage,
            title: title,
            subtitle: subtitle
        ) {
            EmptyView()
        }
    }
}

struct SettingsCardDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 59)
    }
}

struct SettingsShortcutBadge: View {
    let value: String

    var body: some View {
        Text(verbatim: value)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: .rect(cornerRadius: 6))
    }
}

struct SettingsSidebarIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.tint)
            .frame(width: 24, height: 24)
            .background(
                Color.accentColor.opacity(0.14),
                in: .rect(cornerRadius: 6)
            )
            .accessibilityHidden(true)
    }
}

struct SettingsAppIdentityView: View {
    var body: some View {
        HStack(spacing: 10) {
            appIcon

            Text(verbatim: "MDrop \(shortVersion)")
                .font(.body.weight(.semibold))

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let image = BrandAssets.applicationIcon() {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
        } else {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 22, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 34, height: 34)
        }
    }

    private var shortVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.2.3"
    }
}

/// Native desktop-sampling glass, without lowering foreground opacity.
struct SettingsWindowGlassBackground: NSViewRepresentable {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.style = .regular
        view.cornerRadius = 0
        return view
    }

    func updateNSView(_ view: NSGlassEffectView, context: Context) {
        view.isHidden = reduceTransparency
    }
}

/// Compact glass selection control with a bounded, keyboard-accessible options popover.
struct SettingsGlassPicker<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let title: String
        var symbol: String? = nil
        var id: Value { value }
    }

    let title: LocalizedStringKey
    @Binding var selection: Value
    let options: [Option]
    @State private var isPresented = false

    var body: some View {
        Button { isPresented.toggle() } label: {
            HStack(spacing: 8) {
                Text(options.first { $0.value == selection }?.title ?? "")
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .accessibilityLabel(Text(title))
        .accessibilityValue(options.first { $0.value == selection }?.title ?? "")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(options) { option in
                        Button {
                            selection = option.value
                        } label: {
                            HStack(spacing: 9) {
                                if let symbol = option.symbol {
                                    Image(systemName: symbol).frame(width: 18)
                                }
                                Text(option.title)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .opacity(selection == option.value ? 1 : 0)
                            }
                        }
                    }
                }
                .padding(4)
            }
            .scrollBounceBehavior(.basedOnSize)
            .padding(10)
            .frame(width: 280, height: min(420, CGFloat(options.count) * 38 + 28))
            .buttonStyle(ShelfPopoverRowStyle { isPresented = false })
            .onKeyPress(.escape) { isPresented = false; return .handled }
        }
    }
}

import AppKit
import MDropCore
import SwiftUI

struct ShelfCustomizationButton: View {
    @Bindable var store: ShelfStore
    let onChange: () -> Void

    var body: some View {
        Button {
            store.isCustomizationPresented.toggle()
        } label: {
            ShelfCircleControlLabel(systemName: "slider.horizontal.2.square")
        }
        .buttonStyle(ShelfControlButtonStyle())
        .help("Shelf Options")
        .accessibilityLabel("Shelf Options")
        .popover(isPresented: $store.isCustomizationPresented, arrowEdge: .bottom) {
            ShelfCustomizationView(store: store, onChange: onChange)
        }
    }
}

struct ShelfCustomizationView: View {
    @Bindable var store: ShelfStore
    let onChange: () -> Void
    @State private var languageController = AppLanguageController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Shelf Name")
                TextField(
                    "Shelf Name", text: $store.shelf.name,
                    prompt: Text(store.shelf.items.count == 1 ? store.shelf.items[0].displayName : "")
                )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 176)
            }
            Divider()
            Toggle("Always Show Indicator", isOn: Binding(
                get: { store.shelf.alwaysShowsIndicator ?? false },
                set: { store.shelf.alwaysShowsIndicator = $0 }
            ))
            HStack(alignment: .top, spacing: 12) {
                Text("Indicator Color")
                    .frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(20), spacing: 7), count: 5), spacing: 7) {
                    ForEach(ShelfColorTag.allCases, id: \.self) { tag in
                        Button {
                            store.shelf.colorTag = tag
                        } label: {
                            Circle()
                                .fill(Color(nsColor: tag.indicatorNSColor))
                                .frame(width: 18, height: 18)
                                .padding(2)
                                .overlay {
                                    Circle().stroke(
                                        store.shelf.colorTag == tag ? Color.accentColor : .clear,
                                        lineWidth: 1.5
                                    )
                                }
                                .contentShape(.circle)
                        }
                        .buttonStyle(ShelfControlButtonStyle())
                        .help(tag.localizedColorName)
                        .accessibilityLabel(tag.localizedColorName)
                        .accessibilityAddTraits(store.shelf.colorTag == tag ? .isSelected : [])
                    }
                }
                .fixedSize()
            }
            Divider()
            Toggle("Pin Shelf", isOn: $store.shelf.isPinned)
            Toggle("Keep Shelf in Own Space", isOn: Binding(
                get: { store.shelf.keepsInOwnSpace ?? false },
                set: { store.shelf.keepsInOwnSpace = $0 }
            ))
            Text("These preferences apply only to this shelf.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 13))
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(16)
        .frame(width: 320)
        .environment(languageController)
        .environment(\.locale, languageController.locale)
        .onChange(of: store.shelf) { old, new in
            guard old.name != new.name || old.colorTag != new.colorTag
                || old.isPinned != new.isPinned
                || old.alwaysShowsIndicator != new.alwaysShowsIndicator
                || old.keepsInOwnSpace != new.keepsInOwnSpace
            else { return }
            store.shelf.modifiedAt = .now
            onChange()
        }
    }
}

extension ShelfColorTag {
    var indicatorNSColor: NSColor {
        switch self {
        case .none: .systemGray
        case .red: .systemRed
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .mint: .systemMint
        case .blue: .systemBlue
        case .purple: .systemPurple
        case .pink: .systemPink
        case .brown: .systemBrown
        }
    }

    var localizedColorName: String {
        let key = switch self {
        case .none: "Gray"
        case .red: "Red"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .mint: "Mint"
        case .blue: "Blue"
        case .purple: "Purple"
        case .pink: "Pink"
        case .brown: "Brown"
        }
        return AppLocalization.string(key)
    }
}

import MDropCore
import SwiftUI

struct ShelfActivationSettingsView: View {
    @Binding var shakeEnabled: Bool
    @Binding var shakeSensitivity: Double
    @Binding var menuBarDropEnabled: Bool
    @Binding var notchDropEnabled: Bool

    var body: some View {
        SettingsPage(
            "Shelf Activation",
            subtitle: "Choose how MDrop creates shelves while you drag."
        ) {
            SettingsCard {
                SettingsCardRow(
                    systemImage: "cursorarrow.motionlines",
                    title: "Activate with shake gesture",
                    subtitle: "Shake cursor while dragging."
                ) {
                    Toggle("", isOn: $shakeEnabled)
                        .labelsHidden()
                }

                SettingsCardDivider()

                SettingsCardRow(
                    systemImage: "dial.medium",
                    title: "Sensitivity"
                ) {
                    Slider(value: $shakeSensitivity, in: 0...1)
                        .frame(width: 128)
                        .disabled(!shakeEnabled)
                        .accessibilityLabel(Text("Sensitivity"))
                }

                SettingsCardDivider()

                SettingsCardRow(
                    systemImage: "menubar.rectangle",
                    title: "Drop to menu bar"
                ) {
                    Toggle("", isOn: $menuBarDropEnabled)
                        .labelsHidden()
                }

                SettingsCardDivider()

                SettingsCardRow(
                    systemImage: "macbook",
                    title: "Drop to MacBook notch"
                ) {
                    Toggle("", isOn: $notchDropEnabled)
                        .labelsHidden()
                }
            }

            SettingsCard {
                shortcutRow(
                    title: "New Shelf",
                    symbol: "plus.rectangle.on.rectangle",
                    shortcut: "⌥⇧Space"
                )
                SettingsCardDivider()
                shortcutRow(
                    title: "Clipboard Shelf",
                    symbol: "clipboard",
                    shortcut: "⌥⇧A"
                )
                SettingsCardDivider()
                shortcutRow(
                    title: "Select Shelf",
                    symbol: "rectangle.and.hand.point.up.left",
                    shortcut: "⌥⇧S"
                )
            }

            if !hotKeyRegistrationFailures.isEmpty {
                SettingsCard {
                    SettingsCardRow(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Some shortcuts are already used by another app."
                    )
                    .foregroundStyle(.orange)
                }
            }
        }
    }

    private func shortcutRow(
        title: LocalizedStringKey,
        symbol: String,
        shortcut: String
    ) -> some View {
        SettingsCardRow(
            systemImage: symbol,
            title: title
        ) {
            SettingsShortcutBadge(value: shortcut)
        }
    }

    private var hotKeyRegistrationFailures: [String] {
        UserDefaults.standard.stringArray(
            forKey: "hotKeyRegistrationFailures"
        ) ?? []
    }
}

struct ShelfInteractionSettingsView: View {
    @Binding var activateNewShelves: Bool
    @Binding var autoCloseDetail: Bool
    @Binding var alwaysCopyDraggedItems: Bool
    @Binding var reduceShelfMotion: Bool
    @Binding var instantActionSlot1: String
    @Binding var instantActionSlot2: String
    @Binding var instantActionSlot3: String
    @Binding var instantActionSlot4: String

    var body: some View {
        SettingsPage(
            "Shelf Interaction",
            subtitle: "Control how shelves move and respond while you work."
        ) {
            SettingsCard {
                SettingsCardRow(
                    systemImage: "keyboard",
                    title: "Activate new shelves",
                    subtitle: "Allow shelf keyboard shortcuts immediately"
                ) {
                    Toggle("", isOn: $activateNewShelves)
                        .labelsHidden()
                }

                SettingsCardDivider()

                SettingsCardRow(
                    systemImage: "rectangle.compress.vertical",
                    title: "Automatically close detail view",
                    subtitle: "Collapse after clicking elsewhere"
                ) {
                    Toggle("", isOn: $autoCloseDetail)
                        .labelsHidden()
                }

                SettingsCardDivider()

                SettingsCardRow(
                    systemImage: "doc.on.doc",
                    title: "Always copy items when dragging out",
                    subtitle: "Hold modifiers no longer changes the operation"
                ) {
                    Toggle("", isOn: $alwaysCopyDraggedItems)
                        .labelsHidden()
                }

                SettingsCardDivider()

                SettingsCardRow(
                    systemImage: "figure.walk.motion",
                    title: "Reduce MDrop motion",
                    subtitle: "Motion"
                ) {
                    Toggle("", isOn: $reduceShelfMotion)
                        .labelsHidden()
                }
            }

            SettingsCard {
                SettingsCardRow(
                    systemImage: "bolt.fill",
                    title: "Instant Actions",
                    subtitle: "After adding items, hover the lightning button to reveal four shortcuts."
                ) {
                    Button("Restore Defaults") {
                        restoreInstantActionDefaults()
                    }
                    .buttonStyle(.borderless)
                }

                SettingsCardDivider()

                instantActionPickerRow(
                    title: "Action 1",
                    selection: $instantActionSlot1
                )

                SettingsCardDivider()

                instantActionPickerRow(
                    title: "Action 2",
                    selection: $instantActionSlot2
                )

                SettingsCardDivider()

                instantActionPickerRow(
                    title: "Action 3",
                    selection: $instantActionSlot3
                )

                SettingsCardDivider()

                instantActionPickerRow(
                    title: "Action 4",
                    selection: $instantActionSlot4
                )
            }
        }
    }

    private func instantActionPickerRow(
        title: LocalizedStringKey,
        selection: Binding<String>
    ) -> some View {
        SettingsCardRow(
            systemImage: selectedAction(for: selection).symbolName,
            title: title
        ) {
            SettingsGlassPicker(
                title: title,
                selection: selection,
                options: BuiltinActionID.allCases.map {
                    .init(value: $0.rawValue, title: $0.displayTitle, symbol: $0.symbolName)
                }
            )
            .frame(width: 188)
        }
    }

    private func selectedAction(
        for selection: Binding<String>
    ) -> BuiltinActionID {
        BuiltinActionID(rawValue: selection.wrappedValue)
            ?? .systemShare
    }

    private func restoreInstantActionDefaults() {
        let defaults = AppPreferences.defaultInstantActionIDs
        instantActionSlot1 = defaults[0].rawValue
        instantActionSlot2 = defaults[1].rawValue
        instantActionSlot3 = defaults[2].rawValue
        instantActionSlot4 = defaults[3].rawValue
    }
}

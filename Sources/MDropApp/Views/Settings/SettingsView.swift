import SwiftUI

struct SettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var selection: SettingsSection? = .shelfActivation
    @State private var languageController =
        AppLanguageController.shared
    @State private var launchAtLogin = LaunchAtLoginSettings()

    @AppStorage(AppPreferences.shakeEnabledKey)
    private var shakeEnabled = true
    @AppStorage(AppPreferences.shakeSensitivityKey)
    private var shakeSensitivity = 0.5
    @AppStorage(AppPreferences.menuBarDropEnabledKey)
    private var menuBarDropEnabled = true
    @AppStorage(AppPreferences.notchDropEnabledKey)
    private var notchDropEnabled = true
    @AppStorage(AppPreferences.activateNewShelvesKey)
    private var activateNewShelves = false
    @AppStorage(AppPreferences.autoCloseDetailKey)
    private var autoCloseDetail = false
    @AppStorage(AppPreferences.alwaysCopyDraggedItemsKey)
    private var alwaysCopyDraggedItems = false
    @AppStorage(AppPreferences.reduceMotionKey)
    private var reduceShelfMotion = false
    @AppStorage(AppPreferences.instantActionSlot1Key)
    private var instantActionSlot1 =
        AppPreferences.defaultInstantActionIDs[0].rawValue
    @AppStorage(AppPreferences.instantActionSlot2Key)
    private var instantActionSlot2 =
        AppPreferences.defaultInstantActionIDs[1].rawValue
    @AppStorage(AppPreferences.instantActionSlot3Key)
    private var instantActionSlot3 =
        AppPreferences.defaultInstantActionIDs[2].rawValue
    @AppStorage(AppPreferences.instantActionSlot4Key)
    private var instantActionSlot4 =
        AppPreferences.defaultInstantActionIDs[3].rawValue

    var body: some View {
        NavigationSplitView {
            settingsSidebar
        } detail: {
            ZStack(alignment: .topLeading) {
                settingsDetail(for: selection ?? .shelfActivation)
                    .id(selection)
                    .transition(systemReduceMotion || reduceShelfMotion
                        ? .opacity
                        : .opacity.combined(with: .offset(y: 10)))
            }
            .clipped()
            .animation(systemReduceMotion || reduceShelfMotion
                ? nil : .spring(response: 0.32, dampingFraction: 0.92), value: selection)
        }
        .navigationSplitViewStyle(.balanced)
        .toggleStyle(.switch)
        .background {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                SettingsWindowGlassBackground().ignoresSafeArea()
            }
        }
        .frame(
            minWidth: SettingsLayout.minimumWidth,
            idealWidth: SettingsLayout.preferredWidth,
            maxWidth: .infinity,
            minHeight: SettingsLayout.minimumHeight,
            idealHeight: SettingsLayout.preferredHeight,
            maxHeight: .infinity
        )
        .alert(
            "MDrop",
            isPresented: Binding(
                get: { launchAtLogin.errorMessage != nil },
                set: {
                    if !$0 {
                        launchAtLogin.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                launchAtLogin.errorMessage = nil
            }
        } message: {
            Text(launchAtLogin.errorMessage ?? "")
        }
        .onAppear {
            launchAtLogin.refresh()
        }
        .environment(languageController)
        .environment(\.locale, languageController.locale)
    }

    private var settingsSidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section("Settings") {
                    ForEach(SettingsSection.allCases) { section in
                        HStack(spacing: 10) {
                            SettingsSidebarIcon(
                                systemImage: section.symbol
                            )
                            Text(section.title)
                                .lineLimit(1)
                        }
                        .frame(minHeight: 32)
                        .contentShape(.rect)
                        .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            SettingsAppIdentityView()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
        .navigationSplitViewColumnWidth(
            min: SettingsLayout.sidebarMinimumWidth,
            ideal: SettingsLayout.sidebarIdealWidth,
            max: 220
        )
    }

    @ViewBuilder
    private func settingsDetail(
        for section: SettingsSection
    ) -> some View {
        switch section {
        case .shelfActivation:
            ShelfActivationSettingsView(
                shakeEnabled: $shakeEnabled,
                shakeSensitivity: $shakeSensitivity,
                menuBarDropEnabled: $menuBarDropEnabled,
                notchDropEnabled: $notchDropEnabled
            )
        case .shelfInteraction:
            ShelfInteractionSettingsView(
                activateNewShelves: $activateNewShelves,
                autoCloseDetail: $autoCloseDetail,
                alwaysCopyDraggedItems: $alwaysCopyDraggedItems,
                reduceShelfMotion: $reduceShelfMotion,
                instantActionSlot1: $instantActionSlot1,
                instantActionSlot2: $instantActionSlot2,
                instantActionSlot3: $instantActionSlot3,
                instantActionSlot4: $instantActionSlot4
            )
        case .general:
            GeneralSettingsView(
                languageController: languageController,
                launchAtLogin: launchAtLogin
            )
        case .about:
            AboutSettingsView()
        }
    }
}

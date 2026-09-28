import Testing
@testable import MDropApp

@Suite("Settings configuration")
struct SettingsConfigurationTests {
    @Test("Sidebar exposes only the wired settings areas")
    func sectionOrder() {
        #expect(
            SettingsSection.allCases.map(\.rawValue) == [
                "shelfActivation",
                "shelfInteraction",
                "general",
                "about"
            ]
        )
    }

    @Test("Preferred window matches the reference split layout")
    func windowGeometry() {
        #expect(SettingsLayout.preferredWidth == 700)
        #expect(SettingsLayout.preferredHeight == 600)
        #expect(SettingsLayout.sidebarIdealWidth == 200)
        #expect(
            SettingsLayout.sidebarMinimumWidth
                + SettingsLayout.detailMinimumWidth
                <= SettingsLayout.minimumWidth
        )
    }

    @Test("Instant Actions exposes four stable preference slots")
    func instantActionSlotConfiguration() {
        #expect(AppPreferences.instantActionSlotKeys.count == 4)
        #expect(Set(AppPreferences.instantActionSlotKeys).count == 4)
        #expect(AppPreferences.defaultInstantActionIDs.count == 4)
    }
}

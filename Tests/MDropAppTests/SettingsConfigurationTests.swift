import Testing
@testable import MDropApp

@Suite("Settings configuration")
struct SettingsConfigurationTests {
    @Test("Uses seven stable desktop settings sections")
    func sectionOrder() {
        #expect(
            SettingsSection.allCases.map(\.rawValue) == [
                "general",
                "activationInteraction",
                "actionsAutomation",
                "shortcutsIntegrations",
                "appearance",
                "privacyLegal",
                "about"
            ]
        )
    }

    @Test("Preferred window keeps both columns inside safe bounds")
    func windowGeometry() {
        #expect(SettingsLayout.preferredWidth == 760)
        #expect(SettingsLayout.preferredHeight == 520)
        #expect(SettingsLayout.sidebarMinimumWidth == 230)
        #expect(SettingsLayout.detailMinimumWidth == 480)
        #expect(
            SettingsLayout.sidebarMinimumWidth
                + SettingsLayout.detailMinimumWidth
                <= SettingsLayout.preferredWidth
        )
    }
}

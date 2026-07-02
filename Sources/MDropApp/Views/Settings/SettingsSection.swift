import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case activationInteraction
    case actionsAutomation
    case shortcutsIntegrations
    case appearance
    case privacyLegal
    case about

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .activationInteraction: "Activation & Interaction"
        case .actionsAutomation: "Actions & Automation"
        case .shortcutsIntegrations: "Shortcuts & Integrations"
        case .appearance: "Appearance"
        case .privacyLegal: "Privacy & Legal"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gear"
        case .activationInteraction: "cursorarrow.motionlines"
        case .actionsAutomation: "bolt.badge.clock"
        case .shortcutsIntegrations: "keyboard"
        case .appearance: "paintpalette"
        case .privacyLegal: "hand.raised"
        case .about: "info.circle"
        }
    }
}

enum SettingsLayout {
    static let preferredWidth: CGFloat = 760
    static let preferredHeight: CGFloat = 520
    static let sidebarMinimumWidth: CGFloat = 230
    static let sidebarIdealWidth: CGFloat = 250
    static let detailMinimumWidth: CGFloat = 480
}

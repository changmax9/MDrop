import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case shelfActivation
    case shelfInteraction
    case general
    case about

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .shelfActivation:
            "Shelf Activation"
        case .shelfInteraction:
            "Shelf Interaction"
        case .general:
            "General"
        case .about:
            "About"
        }
    }

    var symbol: String {
        switch self {
        case .shelfActivation:
            "cursorarrow.motionlines"
        case .shelfInteraction:
            "rectangle.and.hand.point.up.left"
        case .general:
            "gearshape"
        case .about:
            "info.circle"
        }
    }
}

enum SettingsLayout {
    static let preferredWidth: CGFloat = 700
    static let preferredHeight: CGFloat = 600
    static let minimumWidth: CGFloat = 640
    static let minimumHeight: CGFloat = 520
    static let sidebarMinimumWidth: CGFloat = 190
    static let sidebarIdealWidth: CGFloat = 200
    static let detailMinimumWidth: CGFloat = 430
    static let cardCornerRadius: CGFloat = 16
    static let cardRowMinimumHeight: CGFloat = 58
}

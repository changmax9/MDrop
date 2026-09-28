import CoreGraphics
import MDropCore

enum ShelfChromeStyle {
    static func cornerRadius(for state: ShelfPresentationState) -> CGFloat {
        switch state {
        case .empty: CGFloat(ShelfMotionProfile.reference.emptyCornerRadius)
        case .docked: 20
        case .compact, .instantActions: 28
        case .detail: 26
        }
    }

    static func surfaceMorphDuration(reduceMotion: Bool) -> Double {
        reduceMotion
            ? ShelfMotionProfile.reference.reducedMotionDuration / 2
            : max(0.01, ShelfMotionProfile.reference.frameMorphDuration - ShelfMotionProfile.reference.layoutFadeDuration)
    }

    static let outerStrokeOpacity = 0.10
    static let outerStrokeWidth: CGFloat = 0.5

    static let cardRestingShadowOpacity = 0.10
    static let cardHoverShadowOpacity = 0.16
    static let cardRestingShadowRadius: CGFloat = 3
    static let cardHoverShadowRadius: CGFloat = 7
    static let cardRestingShadowY: CGFloat = 2
    static let cardHoverShadowY: CGFloat = 3

    static let controlSurfaceOpacityDark = 0.05
    static let controlSurfaceOpacityLight = 0.03
    static let controlOutlineOpacityDark = 0.07
    static let controlOutlineOpacityLight = 0.04
    static let controlRestingShadowOpacityDark = 0.14
    static let controlHoverShadowOpacityDark = 0.22
    static let controlRestingShadowOpacityLight = 0.07
    static let controlHoverShadowOpacityLight = 0.13
    static let controlRestingShadowRadius: CGFloat = 3
    static let controlHoverShadowRadius: CGFloat = 6
    static let controlRestingShadowY: CGFloat = 1
    static let controlHoverShadowY: CGFloat = 2

    static let commandBarShadowOpacity = 0.12
    static let commandBarShadowRadius: CGFloat = 16
    static let commandBarShadowY: CGFloat = 8
    static let itemIconShadowOpacity = 0.10
    static let itemIconShadowRadius: CGFloat = 3
    static let itemIconShadowY: CGFloat = 2

    static let selectionOpacity = 0.08
    static let reorderSelectionOpacity = 0.12
}

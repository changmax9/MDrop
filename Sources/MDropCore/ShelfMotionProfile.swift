import Foundation

public enum ShelfInstantActionLayout {
    public static let panel = ShelfPanelMetrics(width: 198, height: 52)
    public static let topGap = 12.0
    public static let entryVisibleDiameter = 36.0
    public static let entryHitDiameter = 44.0
    public static let actionDiameter = 40.0
    public static let actionSpacing = 8.0
    public static let actionLimit = 4
    public static let animationDuration = 0.20

    public static func expandedWidth(
        buttonCount: Int = actionLimit
    ) -> Double {
        let count = max(0, buttonCount)
        guard count > 0 else { return 0 }
        return Double(count) * actionDiameter
            + Double(count - 1) * actionSpacing
    }

    public static func horizontalOffset(
        index: Int,
        buttonCount: Int,
        isExpanded: Bool
    ) -> Double {
        guard isExpanded, buttonCount > 0 else { return 0 }
        return (Double(index) - Double(buttonCount - 1) / 2)
            * (actionDiameter + actionSpacing)
    }
}

public enum ShelfDetailLayout {
    public static let panel = ShelfPanelMetrics(width: 400, height: 207)
    public static let mediumPanel = ShelfPanelMetrics(width: 400, height: 310)
    public static let tallPanel = ShelfPanelMetrics(width: 400, height: 435)
    public static let cornerRadius = 24.0
    public static let modePicker = ShelfPanelMetrics(width: 60, height: 32)
    public static let thumbnailMaximum = ShelfPanelMetrics(
        width: 70,
        height: 68
    )
    public static let revealSymbolPointSize = 46.0
    public static let headerHorizontalInset = 14.0
    public static let headerTopInset = 14.0
    public static let contentHorizontalInset = 14.0
    public static let contentVerticalInset = 12.0
    public static let gridColumnCount = 3
    public static let gridColumnSpacing = 18.0
    public static let gridRowSpacing = 14.0
    public static let gridTileWidth = 110.0
    public static let gridTileHeight = 112.0
    public static let headerRevealDelay = 0.15
    public static let headerRevealDuration = 0.20
    public static let contentRevealDelay = 0.18
    public static let contentRevealDuration = 0.30

    public static func panelMetrics(itemCount: Int) -> ShelfPanelMetrics {
        switch max(0, itemCount) {
        case 0...2:
            panel
        case 3...5:
            mediumPanel
        default:
            tallPanel
        }
    }
}

public struct ShelfMotionProfile: Equatable, Sendable {
    public var emptyPanel: ShelfPanelMetrics
    public var emptyGlassBody: ShelfPanelMetrics
    public var detailPanel: ShelfPanelMetrics
    public var emptyCornerRadius: Double
    public var emptyLabelPointSize: Double
    public var controlDiameter: Double
    public var controlCenterInset: Double
    public var controlIconPointSize: Double
    public var controlHoverDuration: Double
    public var handleHoverWidth: Double
    public var handleDraggingWidth: Double
    public var handleHeight: Double
    public var marqueeInitialDelay: Double
    public var marqueePointsPerSecond: Double
    public var appearanceDuration: Double
    public var jellyContentDelay: Double
    public var frameMorphDuration: Double
    public var detailExpandDuration: Double
    public var layoutFadeDuration: Double
    public var reducedMotionDuration: Double
    public var hoverChromeDuration: Double
    public var stackDuration: Double
    public var closeDuration: Double

    public init(
        emptyPanel: ShelfPanelMetrics,
        emptyGlassBody: ShelfPanelMetrics,
        detailPanel: ShelfPanelMetrics,
        emptyCornerRadius: Double,
        emptyLabelPointSize: Double,
        controlDiameter: Double,
        controlCenterInset: Double,
        controlIconPointSize: Double,
        controlHoverDuration: Double,
        handleHoverWidth: Double,
        handleDraggingWidth: Double,
        handleHeight: Double,
        marqueeInitialDelay: Double,
        marqueePointsPerSecond: Double,
        appearanceDuration: Double,
        jellyContentDelay: Double,
        frameMorphDuration: Double,
        detailExpandDuration: Double,
        layoutFadeDuration: Double,
        reducedMotionDuration: Double,
        hoverChromeDuration: Double,
        stackDuration: Double,
        closeDuration: Double
    ) {
        self.emptyPanel = emptyPanel
        self.emptyGlassBody = emptyGlassBody
        self.detailPanel = detailPanel
        self.emptyCornerRadius = emptyCornerRadius
        self.emptyLabelPointSize = emptyLabelPointSize
        self.controlDiameter = controlDiameter
        self.controlCenterInset = controlCenterInset
        self.controlIconPointSize = controlIconPointSize
        self.controlHoverDuration = controlHoverDuration
        self.handleHoverWidth = handleHoverWidth
        self.handleDraggingWidth = handleDraggingWidth
        self.handleHeight = handleHeight
        self.marqueeInitialDelay = marqueeInitialDelay
        self.marqueePointsPerSecond = marqueePointsPerSecond
        self.appearanceDuration = appearanceDuration
        self.jellyContentDelay = jellyContentDelay
        self.frameMorphDuration = frameMorphDuration
        self.detailExpandDuration = detailExpandDuration
        self.layoutFadeDuration = layoutFadeDuration
        self.reducedMotionDuration = reducedMotionDuration
        self.hoverChromeDuration = hoverChromeDuration
        self.stackDuration = stackDuration
        self.closeDuration = closeDuration
    }

    public static let reference = Self(
        emptyPanel: .init(width: 198, height: 207),
        emptyGlassBody: .init(width: 198, height: 207),
        detailPanel: ShelfDetailLayout.panel,
        emptyCornerRadius: 24,
        emptyLabelPointSize: 15,
        controlDiameter: 32,
        controlCenterInset: 30,
        controlIconPointSize: 12,
        controlHoverDuration: 0.14,
        handleHoverWidth: 20,
        handleDraggingWidth: 36,
        handleHeight: 4,
        marqueeInitialDelay: 0.7,
        marqueePointsPerSecond: 24,
        appearanceDuration: 0.24,
        jellyContentDelay: 0,
        frameMorphDuration: 0.23,
        detailExpandDuration: 0.18,
        layoutFadeDuration: 0.12,
        reducedMotionDuration: 0.16,
        hoverChromeDuration: 0.14,
        stackDuration: 0.28,
        closeDuration: 0.10
    )

    public func handleAnimationDuration(
        requested: Bool,
        reduceMotion: Bool
    ) -> TimeInterval {
        requested && !reduceMotion ? hoverChromeDuration : 0
    }
}

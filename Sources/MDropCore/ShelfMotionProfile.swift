import Foundation

public struct ShelfMotionProfile: Equatable, Sendable {
    public var emptyPanel: ShelfPanelMetrics
    public var emptyGlassBody: ShelfPanelMetrics
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
    public var layoutFadeDuration: Double
    public var reducedMotionDuration: Double
    public var hoverChromeDuration: Double
    public var stackDuration: Double
    public var closeDuration: Double

    public init(
        emptyPanel: ShelfPanelMetrics,
        emptyGlassBody: ShelfPanelMetrics,
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
        layoutFadeDuration: Double,
        reducedMotionDuration: Double,
        hoverChromeDuration: Double,
        stackDuration: Double,
        closeDuration: Double
    ) {
        self.emptyPanel = emptyPanel
        self.emptyGlassBody = emptyGlassBody
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
        self.layoutFadeDuration = layoutFadeDuration
        self.reducedMotionDuration = reducedMotionDuration
        self.hoverChromeDuration = hoverChromeDuration
        self.stackDuration = stackDuration
        self.closeDuration = closeDuration
    }

    public static let reference = Self(
        emptyPanel: .init(width: 198, height: 207),
        emptyGlassBody: .init(width: 198, height: 207),
        emptyCornerRadius: 28,
        emptyLabelPointSize: 15,
        controlDiameter: 32,
        controlCenterInset: 23,
        controlIconPointSize: 12,
        controlHoverDuration: 0.14,
        handleHoverWidth: 20,
        handleDraggingWidth: 36,
        handleHeight: 4,
        marqueeInitialDelay: 0.7,
        marqueePointsPerSecond: 24,
        appearanceDuration: 0.42,
        jellyContentDelay: 0.09,
        frameMorphDuration: 0.36,
        layoutFadeDuration: 0.11,
        reducedMotionDuration: 0.16,
        hoverChromeDuration: 0.14,
        stackDuration: 0.28,
        closeDuration: 0.10
    )
}

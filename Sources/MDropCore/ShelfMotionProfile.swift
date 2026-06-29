import Foundation

public struct ShelfMotionProfile: Equatable, Sendable {
    public var emptyPanel: ShelfPanelMetrics
    public var emptyGlassBody: ShelfPanelMetrics
    public var emptyCornerRadius: Double
    public var emptyLabelPointSize: Double
    public var appearanceDuration: Double
    public var frameMorphDuration: Double
    public var hoverChromeDuration: Double
    public var stackDuration: Double
    public var closeDuration: Double

    public init(
        emptyPanel: ShelfPanelMetrics,
        emptyGlassBody: ShelfPanelMetrics,
        emptyCornerRadius: Double,
        emptyLabelPointSize: Double,
        appearanceDuration: Double,
        frameMorphDuration: Double,
        hoverChromeDuration: Double,
        stackDuration: Double,
        closeDuration: Double
    ) {
        self.emptyPanel = emptyPanel
        self.emptyGlassBody = emptyGlassBody
        self.emptyCornerRadius = emptyCornerRadius
        self.emptyLabelPointSize = emptyLabelPointSize
        self.appearanceDuration = appearanceDuration
        self.frameMorphDuration = frameMorphDuration
        self.hoverChromeDuration = hoverChromeDuration
        self.stackDuration = stackDuration
        self.closeDuration = closeDuration
    }

    public static let reference = Self(
        emptyPanel: .init(width: 382, height: 400),
        emptyGlassBody: .init(width: 362, height: 380),
        emptyCornerRadius: 36,
        emptyLabelPointSize: 15,
        appearanceDuration: 0.08,
        frameMorphDuration: 0.22,
        hoverChromeDuration: 0.14,
        stackDuration: 0.28,
        closeDuration: 0.10
    )
}

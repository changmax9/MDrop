import Foundation

public struct ShelfMarqueeMetrics: Equatable, Sendable {
    public let travelDistance: Double
    public let travelDuration: Double

    public init(
        travelDistance: Double,
        travelDuration: Double
    ) {
        self.travelDistance = travelDistance
        self.travelDuration = travelDuration
    }

    public static func measure(
        textWidth: Double,
        viewportWidth: Double,
        pointsPerSecond: Double = 24
    ) -> Self {
        guard textWidth.isFinite,
              viewportWidth.isFinite,
              pointsPerSecond.isFinite,
              pointsPerSecond > 0 else {
            return Self(travelDistance: 0, travelDuration: 0)
        }

        let distance = max(0, textWidth - viewportWidth)
        return Self(
            travelDistance: distance,
            travelDuration: distance == 0
                ? 0
                : distance / pointsPerSecond
        )
    }

    public func shouldAnimate(
        isHovering: Bool,
        reduceMotion: Bool
    ) -> Bool {
        isHovering
            && !reduceMotion
            && travelDistance > 0
            && travelDuration > 0
    }
}

import Foundation

public struct ShelfPanelMetrics: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct ShelfStackTransform: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var rotationDegrees: Double
    public var scale: Double

    public init(
        x: Double,
        y: Double,
        rotationDegrees: Double,
        scale: Double
    ) {
        self.x = x
        self.y = y
        self.rotationDegrees = rotationDegrees
        self.scale = scale
    }
}

public enum CompactShelfLayout {
    public static func panelMetrics(itemCount: Int) -> ShelfPanelMetrics {
        ShelfPanelMetrics(width: 166, height: 164)
    }

    public static func transforms(
        itemCount: Int,
        reduceMotion: Bool
    ) -> [ShelfStackTransform] {
        let visibleCount = min(max(itemCount, 0), 3)
        let base = Array([
            ShelfStackTransform(x: -7, y: 1, rotationDegrees: -7, scale: 0.96),
            ShelfStackTransform(x: 7, y: 1, rotationDegrees: 6, scale: 0.97),
            ShelfStackTransform(x: 0, y: 0, rotationDegrees: 0, scale: 1)
        ].suffix(visibleCount))

        guard reduceMotion else { return base }
        return base.map {
            ShelfStackTransform(
                x: $0.x,
                y: $0.y,
                rotationDegrees: 0,
                scale: $0.scale
            )
        }
    }
}

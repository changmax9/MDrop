public struct ShelfDetailModeMotion: Equatable, Sendable {
    public let morphResponse: Double
    public let morphDampingFraction: Double
    public let hoverDuration: Double
    public let reducedMotionDuration: Double

    public static let reference = Self(
        morphResponse: 0.36,
        morphDampingFraction: 0.82,
        hoverDuration: 0.14,
        reducedMotionDuration: 0.12
    )
}

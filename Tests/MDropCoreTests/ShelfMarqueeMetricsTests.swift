import Testing
@testable import MDropCore

@Suite("Shelf filename marquee metrics")
struct ShelfMarqueeMetricsTests {
    @Test("Overflow distance and duration use measured widths")
    func overflowUsesMeasuredTravelAndSpeed() {
        let metrics = ShelfMarqueeMetrics.measure(
            textWidth: 180,
            viewportWidth: 112
        )

        #expect(metrics.travelDistance == 68)
        #expect(metrics.travelDuration == 68.0 / 24.0)
    }

    @Test("Fitting text remains stationary")
    func fittingTextDoesNotTravel() {
        let metrics = ShelfMarqueeMetrics.measure(
            textWidth: 80,
            viewportWidth: 112
        )

        #expect(metrics.travelDistance == 0)
        #expect(metrics.travelDuration == 0)
    }

    @Test("Invalid speed does not produce an infinite duration")
    func invalidSpeedDoesNotTravel() {
        let metrics = ShelfMarqueeMetrics.measure(
            textWidth: 180,
            viewportWidth: 112,
            pointsPerSecond: 0
        )

        #expect(metrics.travelDistance == 0)
        #expect(metrics.travelDuration == 0)
    }

    @Test("Overflow marquee animates only while hovered")
    func overflowAnimatesOnlyWhileHovered() {
        let metrics = ShelfMarqueeMetrics.measure(
            textWidth: 180,
            viewportWidth: 112
        )

        #expect(
            !metrics.shouldAnimate(
                isHovering: false,
                reduceMotion: false
            )
        )
        #expect(
            metrics.shouldAnimate(
                isHovering: true,
                reduceMotion: false
            )
        )
        #expect(
            !metrics.shouldAnimate(
                isHovering: true,
                reduceMotion: true
            )
        )
    }
}

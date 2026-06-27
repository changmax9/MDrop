import XCTest
@testable import MDropCore

final class ShakeDetectorTests: XCTestCase {
    func testRapidAlternatingMovementTriggersShake() {
        var detector = ShakeDetector(
            configuration: .init(
                timeWindow: 0.6,
                minimumSegmentDistance: 20,
                requiredReversals: 3,
                cooldown: 1
            )
        )

        XCTAssertFalse(detector.record(x: 0, at: 0))
        XCTAssertFalse(detector.record(x: 30, at: 0.1))
        XCTAssertFalse(detector.record(x: -5, at: 0.2))
        XCTAssertFalse(detector.record(x: 35, at: 0.3))
        XCTAssertTrue(detector.record(x: 0, at: 0.4))
    }

    func testMovementOutsideTimeWindowDoesNotTrigger() {
        var detector = ShakeDetector()

        _ = detector.record(x: 0, at: 0)
        _ = detector.record(x: 40, at: 0.4)
        _ = detector.record(x: 0, at: 0.8)
        _ = detector.record(x: 40, at: 1.2)

        XCTAssertFalse(detector.record(x: 0, at: 1.6))
    }

    func testCooldownPreventsImmediateSecondTrigger() {
        var detector = ShakeDetector(
            configuration: .init(
                timeWindow: 0.6,
                minimumSegmentDistance: 20,
                requiredReversals: 3,
                cooldown: 1
            )
        )
        for (x, time) in [(0.0, 0.0), (30, 0.1), (-5, 0.2), (35, 0.3)] {
            _ = detector.record(x: x, at: time)
        }
        XCTAssertTrue(detector.record(x: 0, at: 0.4))

        for (x, time) in [(30.0, 0.5), (0, 0.6), (30, 0.7), (0, 0.8)] {
            _ = detector.record(x: x, at: time)
        }

        XCTAssertFalse(detector.record(x: 30, at: 0.9))
    }

    func testResetDiscardsPartialGesture() {
        var detector = ShakeDetector(
            configuration: .init(
                timeWindow: 0.6,
                minimumSegmentDistance: 20,
                requiredReversals: 3,
                cooldown: 1
            )
        )
        for (x, time) in [(0.0, 0.0), (30, 0.1), (0, 0.2), (30, 0.3)] {
            _ = detector.record(x: x, at: time)
        }

        detector.reset()

        XCTAssertFalse(detector.record(x: 0, at: 0.4))
    }
}

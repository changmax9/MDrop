import XCTest
@testable import MDropCore

final class CompactShelfLayoutTests: XCTestCase {
    func testPopulatedCompactShelfUsesVerticalReferenceSize() {
        XCTAssertEqual(
            CompactShelfLayout.panelMetrics(itemCount: 1),
            .init(width: 198, height: 207)
        )
        XCTAssertEqual(
            CompactShelfLayout.panelMetrics(itemCount: 8),
            .init(width: 198, height: 207)
        )
    }

    func testThreeItemStackUsesOpposingRearRotations() {
        XCTAssertEqual(
            CompactShelfLayout.transforms(itemCount: 3, reduceMotion: false),
            [
                .init(x: -7, y: 1, rotationDegrees: -7, scale: 0.96),
                .init(x: 7, y: 1, rotationDegrees: 6, scale: 0.97),
                .init(x: 0, y: 0, rotationDegrees: 0, scale: 1)
            ]
        )
    }

    func testOnlyThreeItemsAreVisibleInTheStack() {
        XCTAssertEqual(
            CompactShelfLayout.transforms(itemCount: 12, reduceMotion: false).count,
            3
        )
    }

    func testReduceMotionRemovesRotation() {
        XCTAssertTrue(
            CompactShelfLayout.transforms(itemCount: 3, reduceMotion: true)
                .allSatisfy { $0.rotationDegrees == 0 }
        )
    }
}

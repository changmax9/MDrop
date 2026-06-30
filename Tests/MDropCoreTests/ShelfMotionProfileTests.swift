import Testing
@testable import MDropCore

@Suite("Reference Shelf motion profile")
struct ShelfMotionProfileTests {
    @Test("Empty panel matches the measured reference surface")
    func emptyPanelMatchesMeasuredReferenceSurface() {
        #expect(
            ShelfMotionProfile.reference.emptyPanel
                == .init(width: 198, height: 207)
        )
        #expect(
            ShelfMotionProfile.reference.emptyGlassBody
                == .init(width: 198, height: 207)
        )
        #expect(ShelfMotionProfile.reference.emptyCornerRadius == 28)
        #expect(ShelfMotionProfile.reference.emptyLabelPointSize == 15)
        #expect(ShelfMotionProfile.reference.controlDiameter == 32)
        #expect(ShelfMotionProfile.reference.controlCenterInset == 23)
        #expect(ShelfMotionProfile.reference.controlIconPointSize == 12)
        #expect(ShelfMotionProfile.reference.controlHoverDuration == 0.14)
    }

    @Test("Motion durations stay snappy")
    func motionDurationsStaySnappy() {
        let profile = ShelfMotionProfile.reference
        #expect(profile.appearanceDuration == 0.08)
        #expect(profile.frameMorphDuration == 0.22)
        #expect(profile.hoverChromeDuration == 0.14)
        #expect(profile.stackDuration == 0.28)
        #expect(profile.closeDuration == 0.10)
    }
}

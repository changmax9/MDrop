import Testing
@testable import MDropCore

@Suite("Reference Shelf motion profile")
struct ShelfMotionProfileTests {
    @Test("Empty panel matches the measured reference surface")
    func emptyPanelMatchesMeasuredReferenceSurface() {
        #expect(
            ShelfMotionProfile.reference.emptyPanel
                == .init(width: 382, height: 400)
        )
        #expect(
            ShelfMotionProfile.reference.emptyGlassBody
                == .init(width: 362, height: 380)
        )
        #expect(ShelfMotionProfile.reference.emptyCornerRadius == 36)
        #expect(ShelfMotionProfile.reference.emptyLabelPointSize == 15)
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

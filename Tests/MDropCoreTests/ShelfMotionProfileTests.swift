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
        #expect(
            ShelfMotionProfile.reference.detailPanel
                == .init(width: 400, height: 207)
        )
        #expect(
            ShelfMotionProfile.reference.detailPanel.width
                > CompactShelfLayout.panelMetrics(itemCount: 1).width
        )
        #expect(
            ShelfMotionProfile.reference.detailPanel.height
                == CompactShelfLayout.panelMetrics(itemCount: 1).height
        )
        #expect(ShelfMotionProfile.reference.emptyCornerRadius == 28)
        #expect(ShelfMotionProfile.reference.emptyLabelPointSize == 15)
        #expect(ShelfMotionProfile.reference.controlDiameter == 32)
        #expect(ShelfMotionProfile.reference.controlCenterInset == 23)
        #expect(ShelfMotionProfile.reference.controlIconPointSize == 12)
        #expect(ShelfMotionProfile.reference.controlHoverDuration == 0.14)
        #expect(ShelfMotionProfile.reference.handleHoverWidth == 20)
        #expect(ShelfMotionProfile.reference.handleDraggingWidth == 36)
        #expect(ShelfMotionProfile.reference.handleHeight == 4)
    }

    @Test("Entrance settles without overshoot or a blank content hold")
    func entranceSettlesWithoutOvershootOrBlankHold() {
        let profile = ShelfMotionProfile.reference
        #expect(profile.appearanceDuration == 0.24)
        #expect(profile.jellyContentDelay == 0)
    }

    @Test("Layout motion durations stay snappy")
    func layoutMotionDurationsStaySnappy() {
        let profile = ShelfMotionProfile.reference
        #expect(profile.frameMorphDuration == 0.36)
        #expect(profile.layoutFadeDuration == 0.11)
        #expect(profile.reducedMotionDuration == 0.16)
        #expect(profile.hoverChromeDuration == 0.14)
        #expect(profile.stackDuration == 0.28)
        #expect(profile.closeDuration == 0.10)
    }

    @Test("Marquee timing matches the measured reference")
    func marqueeTimingMatchesReference() {
        let profile = ShelfMotionProfile.reference
        #expect(profile.marqueeInitialDelay == 0.7)
        #expect(profile.marqueePointsPerSecond == 24)
    }

    @Test("Handle motion respects Reduce Motion")
    func handleMotionRespectsReduceMotion() {
        let profile = ShelfMotionProfile.reference

        #expect(
            profile.handleAnimationDuration(
                requested: true,
                reduceMotion: false
            ) == 0.14
        )
        #expect(
            profile.handleAnimationDuration(
                requested: true,
                reduceMotion: true
            ) == 0
        )
        #expect(
            profile.handleAnimationDuration(
                requested: false,
                reduceMotion: false
            ) == 0
        )
    }
}

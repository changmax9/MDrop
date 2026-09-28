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
        #expect(ShelfMotionProfile.reference.emptyCornerRadius == 24)
        #expect(ShelfMotionProfile.reference.emptyLabelPointSize == 15)
        #expect(ShelfMotionProfile.reference.controlDiameter == 32)
        #expect(ShelfMotionProfile.reference.controlCenterInset == 30)
        #expect(ShelfMotionProfile.reference.controlIconPointSize == 12)
        #expect(ShelfMotionProfile.reference.controlHoverDuration == 0.14)
        #expect(ShelfMotionProfile.reference.handleHoverWidth == 20)
        #expect(ShelfMotionProfile.reference.handleDraggingWidth == 36)
        #expect(ShelfMotionProfile.reference.handleHeight == 4)
    }

    @Test("Detail layout matches Dropover's item-count breakpoints")
    func detailLayoutMatchesItemCountBreakpoints() {
        #expect(ShelfDetailLayout.panel == .init(width: 400, height: 207))
        #expect(
            ShelfDetailLayout.mediumPanel
                == .init(width: 400, height: 310)
        )
        #expect(
            ShelfDetailLayout.tallPanel
                == .init(width: 400, height: 435)
        )
        #expect(ShelfDetailLayout.panelMetrics(itemCount: 1) == .init(width: 400, height: 207))
        #expect(ShelfDetailLayout.panelMetrics(itemCount: 2) == .init(width: 400, height: 207))
        #expect(ShelfDetailLayout.panelMetrics(itemCount: 3) == .init(width: 400, height: 310))
        #expect(ShelfDetailLayout.panelMetrics(itemCount: 5) == .init(width: 400, height: 310))
        #expect(ShelfDetailLayout.panelMetrics(itemCount: 6) == .init(width: 400, height: 435))
        #expect(ShelfDetailLayout.cornerRadius == 24)
        #expect(ShelfMotionProfile.reference.controlDiameter == 32)
        #expect(ShelfDetailLayout.modePicker == .init(width: 60, height: 32))
        #expect(
            ShelfDetailLayout.thumbnailMaximum
                == .init(width: 70, height: 68)
        )
        #expect(ShelfDetailLayout.revealSymbolPointSize == 46)
        #expect(ShelfDetailLayout.headerHorizontalInset == 14)
        #expect(ShelfDetailLayout.headerTopInset == 14)
        #expect(ShelfDetailLayout.contentHorizontalInset == 14)
        #expect(ShelfDetailLayout.contentVerticalInset == 12)
        #expect(ShelfDetailLayout.gridColumnCount == 3)
        #expect(ShelfDetailLayout.gridColumnSpacing == 18)
        #expect(ShelfDetailLayout.gridRowSpacing == 14)
        #expect(ShelfDetailLayout.gridTileWidth == 110)
        #expect(ShelfDetailLayout.gridTileHeight == 112)
        #expect(ShelfDetailLayout.headerRevealDelay == 0.15)
        #expect(ShelfDetailLayout.headerRevealDuration == 0.20)
        #expect(ShelfDetailLayout.contentRevealDelay == 0.18)
        #expect(ShelfDetailLayout.contentRevealDuration == 0.30)

        let gridWidth = ShelfDetailLayout.contentHorizontalInset * 2
            + ShelfDetailLayout.gridTileWidth
                * Double(ShelfDetailLayout.gridColumnCount)
            + ShelfDetailLayout.gridColumnSpacing
                * Double(ShelfDetailLayout.gridColumnCount - 1)
        #expect(gridWidth == 394)
        #expect(gridWidth <= ShelfDetailLayout.panel.width)
    }

    @Test("Instant Actions accessory keeps the main shelf geometry unchanged")
    func instantActionsAccessoryMatchesMeasuredReference() {
        #expect(
            ShelfInstantActionLayout.panel
                == .init(width: 198, height: 52)
        )
        #expect(ShelfInstantActionLayout.topGap == 12)
        #expect(ShelfInstantActionLayout.entryVisibleDiameter == 36)
        #expect(ShelfInstantActionLayout.entryHitDiameter == 44)
        #expect(ShelfInstantActionLayout.actionDiameter == 40)
        #expect(ShelfInstantActionLayout.actionSpacing == 8)
        #expect(ShelfInstantActionLayout.actionLimit == 4)
        #expect(ShelfInstantActionLayout.expandedWidth() == 184)
        #expect(
            ShelfInstantActionLayout.expandedWidth()
                <= ShelfInstantActionLayout.panel.width
        )
        #expect(
            ShelfInstantActionLayout.topGap
                + ShelfInstantActionLayout.actionDiameter
                == ShelfInstantActionLayout.panel.height
        )
        #expect(
            ShelfMotionProfile.reference.emptyPanel
                == .init(width: 198, height: 207)
        )
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
        #expect(profile.frameMorphDuration == 0.23)
        #expect(profile.detailExpandDuration == 0.18)
        #expect(profile.layoutFadeDuration == 0.12)
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

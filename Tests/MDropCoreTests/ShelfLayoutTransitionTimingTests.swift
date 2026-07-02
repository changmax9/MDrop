import Testing
@testable import MDropCore

@Suite("Shelf layout transition timing")
struct ShelfLayoutTransitionTimingTests {
    @Test("Reference motion keeps content swap inside the frame morph")
    func referenceMotionKeepsContentSwapInsideFrameMorph() {
        let timing = ShelfLayoutTransitionTiming.resolve(
            profile: .reference,
            reduceMotion: false
        )

        #expect(timing.frameDuration == 0.36)
        #expect(timing.contentFadeDuration == 0.11)
        #expect(timing.contentSwapDelay == 0.11)
        #expect(timing.completionDelay == 0.36)
    }

    @Test("Reduce Motion completes one crossfade in 160 milliseconds")
    func reduceMotionCompletesOneCrossfadeIn160Milliseconds() {
        let timing = ShelfLayoutTransitionTiming.resolve(
            profile: .reference,
            reduceMotion: true
        )

        #expect(timing.frameDuration == 0)
        #expect(timing.contentFadeDuration == 0.08)
        #expect(timing.contentSwapDelay == 0.08)
        #expect(timing.completionDelay == 0.16)
    }

    @Test("Edge docking swaps content during the final fade window")
    func edgeDockingSwapsContentDuringFinalFadeWindow() {
        let timing = ShelfLayoutTransitionTiming.resolve(
            profile: .reference,
            reduceMotion: false
        ).delayingContentSwapUntilFrameSettles()

        #expect(timing.contentFadeDuration == 0.11)
        #expect(timing.contentSwapDelay == 0.25)
        #expect(timing.completionDelay == 0.36)
    }
}

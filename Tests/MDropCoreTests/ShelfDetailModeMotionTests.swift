import Testing
@testable import MDropCore

@Suite("Shelf detail mode motion")
struct ShelfDetailModeMotionTests {
    @Test("Reference motion preserves the recorded glass morph")
    func referenceMotion() {
        let profile = ShelfDetailModeMotion.reference

        #expect(profile.morphResponse == 0.36)
        #expect(profile.morphDampingFraction == 0.82)
        #expect(profile.hoverDuration == 0.14)
        #expect(profile.reducedMotionDuration == 0.12)
    }
}

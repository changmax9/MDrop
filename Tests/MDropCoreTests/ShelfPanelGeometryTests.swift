import CoreGraphics
import Testing
@testable import MDropCore

@Suite("Shelf panel frame geometry")
struct ShelfPanelGeometryTests {
    @Test("Detail morph preserves the panel center")
    func detailMorphPreservesCenter() {
        let current = CGRect(x: 100, y: 200, width: 198, height: 207)

        let result = ShelfPanelGeometry.centeredFrame(
            from: current,
            to: CGSize(width: 430, height: 180)
        )

        #expect(result.midX == current.midX)
        #expect(result.midY == current.midY)
        #expect(result.size == CGSize(width: 430, height: 180))
    }

    @Test("Expanded detail frame stays on the visible screen")
    func expandedFrameStaysVisible() {
        let current = CGRect(x: 0, y: 0, width: 198, height: 207)
        let visible = CGRect(x: 0, y: 0, width: 900, height: 700)

        let result = ShelfPanelGeometry.centeredFrame(
            from: current,
            to: CGSize(width: 430, height: 180),
            constrainedTo: visible
        )

        #expect(result.minX == visible.minX)
        #expect(result.minY >= visible.minY)
        #expect(result.maxX <= visible.maxX)
        #expect(result.maxY <= visible.maxY)
    }
}

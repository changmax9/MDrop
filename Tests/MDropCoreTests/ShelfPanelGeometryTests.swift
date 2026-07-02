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
            to: CGSize(width: 400, height: 207)
        )

        #expect(result.midX == current.midX)
        #expect(result.midY == current.midY)
        #expect(result.width > current.width)
        #expect(result.height == current.height)
        #expect(result.size == CGSize(width: 400, height: 207))
    }

    @Test("Expanded detail frame stays on the visible screen")
    func expandedFrameStaysVisible() {
        let current = CGRect(x: 0, y: 0, width: 198, height: 207)
        let visible = CGRect(x: 0, y: 0, width: 900, height: 700)

        let result = ShelfPanelGeometry.centeredFrame(
            from: current,
            to: CGSize(width: 400, height: 207),
            constrainedTo: visible
        )

        #expect(result.minX == visible.minX)
        #expect(result.minY >= visible.minY)
        #expect(result.maxX <= visible.maxX)
        #expect(result.maxY <= visible.maxY)
    }

    @Test("Pointer dragging updates both window axes")
    func pointerDraggingUpdatesBothWindowAxes() {
        let result = ShelfPanelGeometry.draggedOrigin(
            from: CGPoint(x: 100, y: 200),
            pointerStart: CGPoint(x: 320, y: 480),
            pointerCurrent: CGPoint(x: 275, y: 552)
        )

        #expect(result == CGPoint(x: 55, y: 272))
    }

    @Test("Docking resolves one final frame at either screen edge")
    func dockingResolvesOneFinalFrameAtEitherScreenEdge() {
        let current = CGRect(x: 440, y: 120, width: 400, height: 207)
        let visible = CGRect(x: 40, y: 30, width: 1_000, height: 700)
        let size = CGSize(width: 92, height: 250)

        let left = ShelfPanelGeometry.dockedFrame(
            from: current,
            to: size,
            edge: .left,
            constrainedTo: visible
        )
        let right = ShelfPanelGeometry.dockedFrame(
            from: current,
            to: size,
            edge: .right,
            constrainedTo: visible
        )

        #expect(left == CGRect(x: 40, y: 120, width: 92, height: 250))
        #expect(right == CGRect(x: 948, y: 120, width: 92, height: 250))
    }
}

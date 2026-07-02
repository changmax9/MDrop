import CoreGraphics
import Testing
@testable import MDropCore

@Suite("Shelf window drag layout")
struct ShelfDragLayoutTests {
    @Test("Compact controls, thumbnail, and filename stay interactive")
    func compactInteractiveRegionsProtectControlsAndFileDrag() {
        let layout = ShelfDragLayout.compact(
            panelSize: CGSize(width: 198, height: 207)
        )

        #expect(layout.isInteractive(CGPoint(x: 23, y: 184)))
        #expect(layout.isInteractive(CGPoint(x: 175, y: 184)))
        #expect(layout.isInteractive(CGPoint(x: 99, y: 105)))
        #expect(layout.isInteractive(CGPoint(x: 99, y: 20)))
        #expect(!layout.isInteractive(CGPoint(x: 20, y: 100)))
    }

    @Test("Empty shelf protects only its close control")
    func emptyShelfKeepsMostOfItsSurfaceDraggable() {
        let layout = ShelfDragLayout.empty(
            panelSize: CGSize(width: 198, height: 207)
        )

        #expect(layout.isInteractive(CGPoint(x: 23, y: 184)))
        #expect(!layout.isInteractive(CGPoint(x: 99, y: 105)))
    }

    @Test("Detail content remains interactive")
    func detailShelfProtectsHeaderAndContent() {
        let layout = ShelfDragLayout.detail(
            panelSize: CGSize(width: 400, height: 207)
        )

        #expect(layout.isInteractive(CGPoint(x: 24, y: 183)))
        #expect(layout.isInteractive(CGPoint(x: 309, y: 183)))
        #expect(layout.isInteractive(CGPoint(x: 378, y: 183)))
        #expect(layout.isInteractive(CGPoint(x: 215, y: 80)))
        #expect(!layout.isInteractive(CGPoint(x: 215, y: 192)))
    }
}

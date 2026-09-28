import AppKit
import MDropCore
import Testing
@testable import MDropApp

@MainActor
@Suite("Active shelf grabber")
struct ShelfWindowDragSurfaceViewTests {
    @Test("Inactive shelf only reveals the grabber for hover or drag")
    func inactiveShelfUsesTransientGrabberVisibility() {
        let resting = ShelfWindowDragSurfaceView.grabberPresentation(
            showsHandle: true,
            isHovered: false,
            isDraggingWindow: false,
            isWindowActive: false,
            reduceMotion: false
        )
        let hovered = ShelfWindowDragSurfaceView.grabberPresentation(
            showsHandle: true,
            isHovered: true,
            isDraggingWindow: false,
            isWindowActive: false,
            reduceMotion: false
        )
        let dragged = ShelfWindowDragSurfaceView.grabberPresentation(
            showsHandle: true,
            isHovered: false,
            isDraggingWindow: true,
            isWindowActive: false,
            reduceMotion: false
        )

        #expect(!resting.isVisible)
        #expect(hovered.isVisible)
        #expect(dragged.isVisible)
        #expect(!hovered.shouldPulse)
        #expect(!dragged.shouldPulse)
    }

    @Test("Active shelf keeps the grabber visible and pulses it")
    func activeShelfUsesPersistentPulsingGrabber() {
        let presentation = ShelfWindowDragSurfaceView.grabberPresentation(
            showsHandle: true,
            isHovered: false,
            isDraggingWindow: false,
            isWindowActive: true,
            reduceMotion: false
        )
        let unsupportedPresentation =
            ShelfWindowDragSurfaceView.grabberPresentation(
                showsHandle: false,
                isHovered: true,
                isDraggingWindow: true,
                isWindowActive: true,
                reduceMotion: false
            )

        #expect(presentation.isVisible)
        #expect(presentation.shouldPulse)
        #expect(presentation.width == 20)
        #expect(presentation.height == 4)
        #expect(!unsupportedPresentation.isVisible)
        #expect(!unsupportedPresentation.shouldPulse)
    }

    @Test("Window drag preserves the 36 by 4 point grabber geometry")
    func windowDragPreservesExpandedGrabberGeometry() {
        let presentation = ShelfWindowDragSurfaceView.grabberPresentation(
            showsHandle: true,
            isHovered: false,
            isDraggingWindow: true,
            isWindowActive: true,
            reduceMotion: false
        )

        #expect(presentation.isVisible)
        #expect(presentation.width == 36)
        #expect(presentation.height == 4)
    }

    @Test("Reduce Motion keeps the active grabber static")
    func reduceMotionDisablesPulseWithoutHidingGrabber() {
        let presentation = ShelfWindowDragSurfaceView.grabberPresentation(
            showsHandle: true,
            isHovered: false,
            isDraggingWindow: false,
            isWindowActive: true,
            reduceMotion: true
        )

        #expect(presentation.isVisible)
        #expect(!presentation.shouldPulse)
    }

    @Test("Shelf panel stays shadowless while its frame moves")
    func shelfPanelKeepsShadowlessInvariantDuringDrag() {
        let panel = ShelfPanel(
            contentRect: NSRect(x: 0, y: 0, width: 198, height: 207),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        defer { panel.close() }

        panel.hasShadow = true
        panel.setFrameOrigin(NSPoint(x: 120, y: 140))

        #expect(!panel.hasShadow)
    }

    @Test("Pulse animation is idempotent and stops on resign or Reduce Motion")
    func pulseAnimationHasBoundedLifecycle() {
        let view = ShelfWindowDragSurfaceView(
            frame: CGRect(x: 0, y: 0, width: 198, height: 207)
        )
        var reduceMotion = false
        view.reducesMotionProvider = { reduceMotion }

        view.setWindowActive(true, animated: false)
        #expect(view.isActiveHandlePulseRunning)

        view.setWindowActive(true, animated: false)
        #expect(view.isActiveHandlePulseRunning)

        view.setWindowActive(false, animated: false)
        #expect(!view.isActiveHandlePulseRunning)

        view.setWindowActive(true, animated: false)
        #expect(view.isActiveHandlePulseRunning)
        reduceMotion = true
        view.refreshMotionPreference()
        #expect(!view.isActiveHandlePulseRunning)
    }
}

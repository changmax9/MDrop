import AppKit
import MDropCore
import SwiftUI
import Testing
@testable import MDropApp

@MainActor
@Suite("Shelf interaction continuity")
struct ShelfInteractionParityTests {
    @Test("Expand and collapse finish without the recovery timer")
    func layoutTransitionsFinishPromptly() async throws {
        _ = NSApplication.shared
        let controller = ShelfPanelController(
            shelf: ShelfRecord(items: [.text("Transition fixture")]),
            location: CGPoint(x: 500, y: 500),
            animatesInitialAppearance: false,
            onDrop: { _ in }, onChange: {}, onClose: {}
        )
        controller.show()
        defer { controller.close() }
        try await Task.sleep(for: .milliseconds(80))
        for state in [ShelfPresentationState.detail, .compact] {
            controller.beginLayoutTransition(
                to: state, dockedEdge: nil,
                targetFrame: CGRect(x: 400, y: 300, width: state == .detail ? 400 : 198, height: 207),
                timing: .resolve(profile: .reference, reduceMotion: false)
            )
            // Recovery starts after 740 ms. A working mount/fade handshake
            // must complete well before it in both directions.
            try await Task.sleep(for: .milliseconds(500))
            #expect(controller.store.shelf.presentationState == state)
            #expect(controller.store.isLayoutContentVisible)
            #expect(!controller.store.isLayoutTransitioning)
        }
    }

    @Test("Shelf preferences round-trip and older archives still load")
    func customizationArchiveCompatibility() throws {
        let oldShelf = ShelfRecord(items: [.text("Earlier shelf")])
        let oldData = try JSONEncoder().encode(oldShelf)
        let decodedOld = try JSONDecoder().decode(ShelfRecord.self, from: oldData)
        #expect(decodedOld.alwaysShowsIndicator == nil)
        #expect(decodedOld.keepsInOwnSpace == nil)
        var customized = oldShelf
        customized.name = "Reference shelf"
        customized.colorTag = .blue
        customized.isPinned = true
        customized.alwaysShowsIndicator = true
        customized.keepsInOwnSpace = true
        let data = try JSONEncoder().encode(customized)
        #expect(try JSONDecoder().decode(ShelfRecord.self, from: data) == customized)
    }

    @Test("Own-Space preference updates native window behavior immediately")
    func ownSpacePreferenceReachesWindow() {
        let controller = ShelfPanelController(
            shelf: ShelfRecord(items: [.text("Space preference")]),
            location: CGPoint(x: 500, y: 500),
            animatesInitialAppearance: false,
            onDrop: { _ in }, onChange: {}, onClose: {}
        )
        defer { controller.close() }
        #expect(controller.panel.collectionBehavior.contains(.canJoinAllSpaces))
        controller.store.shelf.keepsInOwnSpace = true
        controller.refreshSize()
        #expect(!controller.panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(controller.panel.collectionBehavior.contains(.fullScreenAuxiliary))
        controller.store.shelf.keepsInOwnSpace = false
        controller.refreshSize()
        #expect(controller.panel.collectionBehavior.contains(.canJoinAllSpaces))
    }

    @Test("Always-visible indicator remains visible without pointer or focus")
    func persistentIndicatorRespectsPreference() {
        let indicator = ShelfWindowDragSurfaceView.grabberPresentation(
            showsHandle: true, isHovered: false, isDraggingWindow: false,
            isWindowActive: false, reduceMotion: false, alwaysShow: true
        )
        #expect(indicator.isVisible)
        #expect(!indicator.shouldPulse)
    }

    @Test("Instant Action targets spread symmetrically without overlap or clipping")
    func instantActionsKeepUsableHitTargets() {
        for count in 1...ShelfInstantActionLayout.actionLimit {
            let offsets = (0..<count).map {
                ShelfInstantActionLayout.horizontalOffset(index: $0, buttonCount: count, isExpanded: true)
            }
            #expect(abs(offsets.reduce(0, +)) < 0.01)
            for offset in offsets {
                #expect(abs(offset) + ShelfInstantActionLayout.actionDiameter / 2 <= ShelfInstantActionLayout.panel.width / 2)
            }
            for pair in zip(offsets, offsets.dropFirst()) {
                #expect(pair.1 - pair.0 >= ShelfInstantActionLayout.actionDiameter)
            }
        }
    }

    @Test("Detail mode and selection survive collapse and adding items")
    func detailStateSurvivesLayoutChanges() {
        let first = ShelfItemRecord.text("First")
        let store = ShelfStore(shelf: ShelfRecord(items: [first]))
        store.detailViewMode = .list
        store.selectedItemIDs = [first.id]
        store.shelf.presentationState = .detail
        store.append([.text("Second")])
        #expect(store.shelf.presentationState == .detail)
        #expect(store.selectedItemIDs == [first.id])
        let collapse = store.beginLayoutTransition(to: .compact)
        store.shelf.presentationState = .compact
        _ = store.endLayoutTransition(for: collapse)
        let expand = store.beginLayoutTransition(to: .detail)
        store.shelf.presentationState = .detail
        _ = store.endLayoutTransition(for: expand)
        #expect(store.detailViewMode == .list)
        #expect(store.shelf.items.count == 2)
        store.remove(Set(store.shelf.items.map(\.id)))
        #expect(store.shelf.presentationState == .empty)
        #expect(store.selectedItemIDs.isEmpty)
    }

    @Test("File card clicks reach selection and double clicks reach the action")
    func nativeClicksAreNotSwallowed() throws {
        let view = ShelfItemsDragSourceNSView(frame: CGRect(x: 0, y: 0, width: 110, height: 112))
        var clicks: [NSEvent.ModifierFlags] = []
        var doubleClicks = 0
        view.onClick = { clicks.append($0) }
        view.onDoubleClick = { doubleClicks += 1 }
        view.mouseDown(with: try event(.leftMouseDown, modifiers: .command))
        view.mouseUp(with: try event(.leftMouseUp, modifiers: .command))
        view.mouseDown(with: try event(.leftMouseDown, clickCount: 2))
        view.mouseUp(with: try event(.leftMouseUp, clickCount: 2))
        #expect(clicks == [.command])
        #expect(doubleClicks == 1)
    }

    @Test("Small pointer movement stays a click and release outside cancels")
    func clickToleranceAndCancellation() throws {
        let view = ShelfItemsDragSourceNSView(frame: CGRect(x: 0, y: 0, width: 110, height: 112))
        var clicks = 0
        view.onClick = { _ in clicks += 1 }
        view.mouseDown(with: try event(.leftMouseDown))
        view.mouseDragged(with: try event(.leftMouseDragged, point: CGPoint(x: 21, y: 21)))
        view.mouseUp(with: try event(.leftMouseUp, point: CGPoint(x: 21, y: 21)))
        #expect(clicks == 1)
        view.mouseDown(with: try event(.leftMouseDown))
        view.mouseUp(with: try event(.leftMouseUp, point: CGPoint(x: 200, y: 200)))
        #expect(clicks == 1)
        view.mouseDown(with: try event(.leftMouseDown))
        view.discardPendingDrag()
        view.mouseUp(with: try event(.leftMouseUp))
        #expect(clicks == 1)
    }

    @Test("One file's drag overlay cannot intercept another file")
    func dragHitTargetStaysInsideItsCard() {
        let container = NSView(frame: CGRect(x: 0, y: 0, width: 400, height: 207))
        let view = ShelfItemsDragSourceNSView(frame: CGRect(x: 130, y: 20, width: 110, height: 112))
        container.addSubview(view)
        #expect(view.hitTest(CGPoint(x: 140, y: 30)) === view)
        #expect(view.hitTest(CGPoint(x: 20, y: 30)) == nil)
        #expect(view.hitTest(CGPoint(x: 250, y: 30)) == nil)
    }

    @Test("Expanding preserves the live glass surface throughout the morph")
    func glassStaysVisibleDuringExpansion() throws {
        let controller = ShelfPanelController(
            shelf: ShelfRecord(items: [.text("Live glass")]),
            location: CGPoint(x: 500, y: 500),
            animatesInitialAppearance: false,
            onDrop: { _ in }, onChange: {}, onClose: {}
        )
        defer { controller.close() }
        let host = try #require(controller.panel.contentView?.subviews.compactMap {
            $0 as? NSHostingView<ShelfView>
        }.first)
        controller.beginLayoutTransition(
            to: .detail, dockedEdge: nil,
            targetFrame: CGRect(x: 400, y: 300, width: 400, height: 207),
            timing: .resolve(profile: .reference, reduceMotion: false)
        )
        #expect(host.alphaValue == 1)
        #expect(controller.panel.contentView?.subviews.contains { $0 is NSImageView } == false)
    }

    private func event(
        _ type: NSEvent.EventType,
        point: CGPoint = CGPoint(x: 20, y: 20),
        modifiers: NSEvent.ModifierFlags = [],
        clickCount: Int = 1
    ) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: modifiers,
            timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 0, clickCount: clickCount, pressure: 0
        ))
    }
}

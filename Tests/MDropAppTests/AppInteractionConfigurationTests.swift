import AppKit
import MDropCore
import SwiftUI
import Testing
@testable import MDropApp

@MainActor
@Suite("App interaction configuration")
struct AppInteractionConfigurationTests {
    @Test("Visible shelf action control is the menu hit target")
    func visibleShelfActionControlIsTheMenuHitTarget() {
        let hostingView = NSHostingView(
            rootView: ShelfCircleMenu(
                systemName: "chevron.down",
                accessibilityLabel: "Shelf Actions"
            ) {
                Button("Example") {}
            }
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 32, height: 32)
        let panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        defer { panel.close() }
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        let hitTarget = hostingView.hitTest(
            NSPoint(x: hostingView.bounds.midX, y: hostingView.bounds.midY)
        )

        #expect(hitTarget != nil)
        #expect(hitTarget !== hostingView)
    }

    @Test("App bundle prohibits overlapping MDrop instances")
    func appBundleProhibitsOverlappingInstances() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoPlistURL = repositoryRoot
            .appending(path: "Config/Info.plist")
        let data = try Data(contentsOf: infoPlistURL)
        let propertyList = try #require(
            PropertyListSerialization.propertyList(
                from: data,
                format: nil
            ) as? [String: Any]
        )

        #expect(
            propertyList["LSMultipleInstancesProhibited"] as? Bool == true
        )
    }

    @Test("Settings window bridge uses the tested safe content size")
    func settingsWindowBridgeUsesSafeContentSize() throws {
        let controller = SettingsWindowController()
        let window = try #require(controller.window)
        defer { window.close() }

        #expect(
            window.contentLayoutRect.width
                >= SettingsLayout.preferredWidth
        )
        #expect(
            window.contentLayoutRect.height
                >= SettingsLayout.preferredHeight
        )
        #expect(window.isReleasedWhenClosed == false)
        #expect(window.styleMask.contains(.titled))
        #expect(window.styleMask.contains(.closable))
    }

    @Test("Settings window bridge reopens the same window")
    func settingsWindowBridgeReopens() throws {
        let controller = SettingsWindowController()
        let window = try #require(controller.window)
        defer { window.close() }

        controller.show()
        #expect(window.isVisible)
        window.close()
        controller.show()

        #expect(window.isVisible)
        #expect(controller.window === window)
    }

    @Test("Shelf layout transition crossfades content during the frame morph")
    func shelfLayoutTransitionCrossfadesContent() {
        let store = ShelfStore(
            shelf: ShelfRecord(
                items: [
                    .text("Crossfade during transition")
                ]
            ),
            animatesInitialAppearance: true
        )

        store.beginLayoutTransition()

        #expect(store.isLayoutTransitioning)
        #expect(!store.isLayoutContentVisible)

        store.revealLayoutContent()

        #expect(store.isLayoutContentVisible)

        store.endLayoutTransition()

        #expect(!store.isLayoutTransitioning)
        #expect(store.isLayoutContentVisible)
    }
}

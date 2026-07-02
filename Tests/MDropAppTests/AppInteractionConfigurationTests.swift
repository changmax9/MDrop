import AppKit
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

}

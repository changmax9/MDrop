import AppKit
import Carbon
import MDropCore
import QuartzCore
import SwiftUI
import Testing
@testable import MDropApp

@MainActor
@Suite("App interaction configuration")
struct AppInteractionConfigurationTests {
    @Test("Shelf frame morph uses Dropover's ease-in-out timing")
    func shelfFrameMorphUsesReferenceTiming() {
        #expect(
            ShelfPanelController.frameMorphTimingFunctionName
                == .easeInEaseOut
        )
    }

    @Test("Shelf panel can receive shortcuts without becoming a main window")
    func shelfPanelCanReceiveKeyboardFocus() {
        let panel = ShelfPanel(
            contentRect: NSRect(x: 0, y: 0, width: 198, height: 207),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        defer { panel.close() }

        #expect(panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
    }

    @Test("Clicking a shelf focuses its Dropover-style shortcuts")
    func clickingShelfFocusesShortcuts() {
        let controller = ShelfPanelController(
            shelf: ShelfRecord(items: [.text("Focus")]),
            location: CGPoint(x: 500, y: 500),
            animatesInitialAppearance: false,
            onDrop: { _ in },
            onChange: {},
            onClose: {}
        )
        defer { controller.close() }

        #expect(!controller.panel.becomesKeyOnlyIfNeeded)
    }

    @Test("Finder-style shelf shortcuts resolve without hijacking typing")
    func finderStyleShelfShortcutsResolve() {
        #expect(
            ShelfKeyboardCommand.resolve(
                characters: "\r",
                keyCode: UInt16(kVK_Return),
                modifierFlags: []
            ) == .actionMenu
        )
        #expect(
            ShelfKeyboardCommand.resolve(
                characters: "\u{3}",
                keyCode: UInt16(kVK_ANSI_KeypadEnter),
                modifierFlags: []
            ) == .actionMenu
        )
        #expect(
            ShelfKeyboardCommand.resolve(
                characters: "\r",
                keyCode: UInt16(kVK_Return),
                modifierFlags: [.command]
            ) == nil
        )
        #expect(
            ShelfKeyboardCommand.resolve(
                characters: "a",
                modifierFlags: [.command]
            ) == .selectAll
        )
        #expect(
            ShelfKeyboardCommand.resolve(
                characters: "c",
                modifierFlags: [.command]
            ) == .copy
        )
        #expect(
            ShelfKeyboardCommand.resolve(
                characters: "v",
                modifierFlags: [.command]
            ) == .paste
        )
        #expect(
            ShelfKeyboardCommand.resolve(
                characters: "v",
                modifierFlags: []
            ) == nil
        )
        #expect(
            ShelfKeyboardCommand.resolve(
                characters: "c",
                modifierFlags: [.command, .option]
            ) == nil
        )
        #expect(
            ShelfKeyboardCommand.resolve(
                characters: "ф",
                keyCode: UInt16(kVK_ANSI_A),
                modifierFlags: [.command]
            ) == .selectAll
        )
        #expect(
            ShelfKeyboardCommand.resolve(
                characters: "a",
                keyCode: UInt16(kVK_ANSI_Q),
                modifierFlags: [.command]
            ) == .selectAll
        )
        #expect(
            ShelfKeyboardCommand.resolve(
                characters: "q",
                keyCode: UInt16(kVK_ANSI_A),
                modifierFlags: [.command]
            ) == nil
        )
    }

    @Test("Shelf shortcuts leave Command Bar editing keys untouched")
    func shelfShortcutsRespectTextEditing() {
        #expect(ShelfKeyboardCommand.commandBar.canHandleWhileEditingText)
        #expect(ShelfKeyboardCommand.close.canHandleWhileEditingText)
        #expect(ShelfKeyboardCommand.dismiss.canHandleWhileEditingText)
        #expect(!ShelfKeyboardCommand.actionMenu.canHandleWhileEditingText)
        #expect(!ShelfKeyboardCommand.toggleDetail.canHandleWhileEditingText)
        #expect(!ShelfKeyboardCommand.quickLook.canHandleWhileEditingText)
        #expect(!ShelfKeyboardCommand.delete.canHandleWhileEditingText)
        #expect(!ShelfKeyboardCommand.selectAll.canHandleWhileEditingText)
        #expect(!ShelfKeyboardCommand.copy.canHandleWhileEditingText)
        #expect(!ShelfKeyboardCommand.paste.canHandleWhileEditingText)
    }

    @Test("Shelf copy writes file URLs for Finder-compatible paste")
    func shelfCopyWritesFileURLs() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let fileURL = URL(fileURLWithPath: "/tmp/MDrop Copy Test.txt")
        let item = ShelfItemRecord(
            payload: .file(FileReference(url: fileURL)),
            displayName: fileURL.lastPathComponent
        )

        #expect(ShelfPasteboardWriter.write([item], to: pasteboard))

        let copiedURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]
        #expect(copiedURLs == [fileURL])
    }

    @Test("Shelf copy preserves mixed payloads as readable text")
    func shelfCopyWritesMixedPayloadsAsText() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let fileURL = URL(fileURLWithPath: "/tmp/MDrop Mixed Test.txt")
        let items = [
            ShelfItemRecord(
                payload: .file(FileReference(url: fileURL)),
                displayName: fileURL.lastPathComponent
            ),
            ShelfItemRecord.text("A useful note"),
            ShelfItemRecord(
                payload: .url(URL(string: "https://example.com")!),
                displayName: "Example"
            )
        ]

        #expect(ShelfPasteboardWriter.write(items, to: pasteboard))
        #expect(
            pasteboard.string(forType: .string)
                == "/tmp/MDrop Mixed Test.txt\nA useful note\nhttps://example.com"
        )
    }

    @Test("Compact shelf exposes its action menu through AppKit")
    func compactShelfExposesActionMenuThroughAppKit() throws {
        let store = ShelfStore(
            shelf: ShelfRecord(items: [.text("Action menu")]),
            animatesInitialAppearance: false
        )
        let hostingView = NSHostingView(
            rootView: CompactStackedShelfView(
                store: store,
                onExpand: {},
                onDock: {},
                onQuickLook: {},
                onAddClipboard: {},
                onRevealInFinder: { _ in },
                onAction: { _ in },
                onChange: {},
                onClose: {}
            )
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 198, height: 207)
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

        let point = NSPoint(x: hostingView.bounds.midX, y: hostingView.bounds.midY)
        let event = try #require(
            NSEvent.mouseEvent(
                with: .rightMouseDown,
                location: point,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: panel.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        var candidate = hostingView.hitTest(point)
        var menu: NSMenu?
        while let view = candidate, menu == nil {
            menu = view.menu(for: event)
            candidate = view.superview
        }

        #expect(menu != nil)
    }

    @Test("Shelf menu matches Dropover's share grouping")
    func shelfMenuShareGrouping() {
        let sections = ShelfSharingMenuPolicy.sections(
            for: Array(0..<7)
        )

        #expect(sections.primary == [0, 1, 2, 3])
        #expect(sections.overflow == [4, 5, 6])

        let shortSections = ShelfSharingMenuPolicy.sections(
            for: ["AirDrop", "Mail"]
        )
        #expect(shortSections.primary == ["AirDrop", "Mail"])
        #expect(shortSections.overflow.isEmpty)
    }

    @Test("All Actions omits actions already promoted in the shelf menu")
    func shelfMenuAvoidsDuplicateActions() {
        let availableActions: Set<BuiltinActionID> = [
            .systemShare,
            .copyText,
            .resizeImages,
            .createArchive,
            .copyTo,
            .moveTo,
            .rename,
            .copyPath
        ]
        let sections = ShelfActionMenuPolicy.sections(
            from: availableActions
        )
        let actions = ShelfActionMenuPolicy.submenuActions(
            from: availableActions
        )

        #expect(sections.text == [.copyText])
        #expect(sections.image == [.resizeImages])
        #expect(
            sections.general == [.rename, .createArchive, .copyPath]
        )
        #expect(
            actions == [
                .copyText,
                .resizeImages,
                .rename,
                .createArchive,
                .copyPath
            ]
        )
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

    @Test("Finder service declares a named application port")
    func finderServiceRegistration() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(
            contentsOf: repositoryRoot.appending(path: "Config/Info.plist")
        )
        let propertyList = try #require(
            PropertyListSerialization.propertyList(
                from: data,
                format: nil
            ) as? [String: Any]
        )
        let services = try #require(
            propertyList["NSServices"] as? [[String: Any]]
        )
        let service = try #require(services.first)

        #expect(service["NSMessage"] as? String == "addToShelf")
        #expect(service["NSPortName"] as? String == "MDrop")
        #expect(service["NSRequiredContext"] as? [String: Any] != nil)
        #expect(
            Set(service["NSSendTypes"] as? [String] ?? [])
                == Set([
                    "NSStringPboardType",
                    "NSFilenamesPboardType",
                    "NSFileContentsPboardType",
                    "NSRTFPboardType",
                    "NSRTFDPboardType",
                    "NSURLPboardType",
                    "public.file-url",
                    "public.url",
                    "public.utf8-plain-text"
                ])
        )
    }

    @Test("Revealing files hides the floating shelf after opening Finder")
    func finderRevealGetsTheFloatingShelfOutOfTheWay() {
        let fileURL = URL(fileURLWithPath: "/tmp/reveal-me.txt")
        var revealedURLs: [URL] = []
        let controller = FinderRevealController {
            revealedURLs = $0
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.orderFrontRegardless()
        defer { panel.close() }

        controller.reveal([fileURL], from: panel)

        #expect(revealedURLs == [fileURL])
        #expect(!panel.isVisible)
    }

    @Test("Revealing no files leaves the shelf visible")
    func emptyFinderRevealDoesNothing() {
        var activationCount = 0
        let controller = FinderRevealController { _ in
            activationCount += 1
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.orderFrontRegardless()
        defer { panel.close() }

        controller.reveal([], from: panel)

        #expect(activationCount == 0)
        #expect(panel.isVisible)
    }

    @Test("Settings window bridge uses the tested safe content size")
    func settingsWindowBridgeUsesSafeContentSize() throws {
        let controller = SettingsWindowController()
        let window = try #require(controller.window)
        let contentView = try #require(window.contentView)
        defer { window.close() }

        #expect(
            contentView.frame.width
                >= SettingsLayout.preferredWidth
        )
        #expect(
            contentView.frame.height
                >= SettingsLayout.preferredHeight
        )
        #expect(
            window.contentLayoutRect.height
                >= SettingsLayout.minimumHeight
        )
        #expect(window.isReleasedWhenClosed == false)
        #expect(window.styleMask.contains(.titled))
        #expect(window.styleMask.contains(.closable))
        #expect(window.styleMask.contains(.resizable))
        #expect(
            window.contentMinSize.width
                == SettingsLayout.minimumWidth
        )
        #expect(
            window.contentMinSize.height
                == SettingsLayout.minimumHeight
        )
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

    @Test("New shelf focus follows the Dropover 5.2 preference")
    func newShelfFocusPreference() {
        #expect(
            !ShelfCoordinator.shouldActivateShelf(
                isNewShelf: true,
                preferenceEnabled: false
            )
        )
        #expect(
            ShelfCoordinator.shouldActivateShelf(
                isNewShelf: true,
                preferenceEnabled: true
            )
        )
        #expect(
            !ShelfCoordinator.shouldActivateShelf(
                isNewShelf: false,
                preferenceEnabled: true
            )
        )
    }

    @Test("Outside clicks only collapse a settled detail shelf")
    func detailAutoClosePreference() {
        #expect(
            ShelfPanelController.shouldAutoCloseDetail(
                state: .detail,
                isTransitioning: false,
                preferenceEnabled: true,
                isClickInsideCurrentPanel: false
            )
        )
        #expect(
            !ShelfPanelController.shouldAutoCloseDetail(
                state: .compact,
                isTransitioning: false,
                preferenceEnabled: true,
                isClickInsideCurrentPanel: false
            )
        )
        #expect(
            !ShelfPanelController.shouldAutoCloseDetail(
                state: .detail,
                isTransitioning: true,
                preferenceEnabled: true,
                isClickInsideCurrentPanel: false
            )
        )
        #expect(
            !ShelfPanelController.shouldAutoCloseDetail(
                state: .detail,
                isTransitioning: false,
                preferenceEnabled: false,
                isClickInsideCurrentPanel: false
            )
        )
        #expect(
            !ShelfPanelController.shouldAutoCloseDetail(
                state: .detail,
                isTransitioning: false,
                preferenceEnabled: true,
                isClickInsideCurrentPanel: true
            )
        )
    }

    @Test("Instant Actions stays attached below the shelf")
    func instantActionsAccessoryFrame() {
        let shelfFrame = CGRect(x: 100, y: 300, width: 198, height: 207)
        let accessoryFrame = ShelfPanelController.instantActionsFrame(
            below: shelfFrame
        )

        #expect(accessoryFrame.width == 198)
        #expect(accessoryFrame.height == 52)
        #expect(accessoryFrame.midX == shelfFrame.midX)
        #expect(accessoryFrame.maxY == shelfFrame.minY)
        #expect(
            !ShelfPanelController.showsInstantActionsPanel(
                for: .empty,
                hasItems: false
            )
        )
        #expect(
            !ShelfPanelController.showsInstantActionsPanel(
                for: .empty,
                hasItems: true
            )
        )
        #expect(
            !ShelfPanelController.showsInstantActionsPanel(
                for: .compact,
                hasItems: false
            )
        )
        #expect(
            ShelfPanelController.showsInstantActionsPanel(
                for: .compact,
                hasItems: true
            )
        )
        #expect(
            ShelfPanelController.showsInstantActionsPanel(
                for: .instantActions,
                hasItems: true
            )
        )
        #expect(
            !ShelfPanelController.showsInstantActionsPanel(
                for: .instantActions,
                hasItems: false
            )
        )
        #expect(
            ShelfPanelController.showsInstantActionsPanel(
                for: .detail,
                hasItems: true
            )
        )
        #expect(
            !ShelfPanelController.showsInstantActionsPanel(
                for: .docked,
                hasItems: true
            )
        )
    }

    @Test("Instant Actions follows the shelf item lifecycle")
    func instantActionsAccessoryLifecycle() throws {
        let item = ShelfItemRecord.text("Instant Actions")
        let controller = ShelfPanelController(
            shelf: ShelfRecord(),
            location: CGPoint(x: 500, y: 500),
            animatesInitialAppearance: false,
            onDrop: { _ in },
            onChange: {},
            onClose: {}
        )
        defer { controller.close() }

        controller.show()
        #expect(controller.panel.childWindows?.isEmpty ?? true)

        controller.store.append([item])
        controller.refreshSize()

        let child = try #require(controller.panel.childWindows?.first)
        #expect(controller.panel.childWindows?.count == 1)
        #expect(child.isVisible)
        #expect(child.frame.width == 198)
        #expect(child.frame.height == 52)
        #expect(child.frame.midX == controller.panel.frame.midX)
        #expect(child.frame.maxY == controller.panel.frame.minY)

        let detailFrame = CGRect(
            x: controller.panel.frame.midX - 200,
            y: controller.panel.frame.midY - 103.5,
            width: 400,
            height: 207
        )
        controller.beginLayoutTransition(
            to: .detail,
            dockedEdge: nil,
            targetFrame: detailFrame,
            timing: .init(
                frameDuration: 0,
                contentFadeDuration: 0.12,
                contentSwapDelay: 0.12,
                completionDelay: 0
            )
        )
        let transitionID = try #require(
            controller.store.layoutTransitionID
        )
        #expect(child.isVisible)
        #expect(child.ignoresMouseEvents)
        #expect(controller.panel.childWindows?.isEmpty ?? true)
        #expect(child.parent == nil)

        controller.completeLayoutFadeOut(for: transitionID)
        controller.layoutTargetDidMount(for: transitionID)
        controller.completeLayoutFadeIn(for: transitionID)

        #expect(controller.store.shelf.presentationState == .detail)
        #expect(controller.panel.childWindows?.first === child)
        #expect(child.isVisible)
        #expect(!child.ignoresMouseEvents)
        #expect(child.frame.midX == controller.panel.frame.midX)
        #expect(child.frame.maxY == controller.panel.frame.minY)

        controller.store.remove(Set([item.id]))
        controller.refreshSize()

        #expect(controller.panel.childWindows?.isEmpty ?? true)
    }

    @Test("Instant Action slots preserve configuration and availability")
    func instantActionSlotsPreserveConfiguration() {
        let configured: [BuiltinActionID] = [
            .resizeImages,
            .systemShare,
            .copyText,
            .systemShare
        ]

        #expect(
            InstantActionsRailPolicy.slots(
                for: [],
                selectedItemIDs: [],
                configuredActions: configured
            ).isEmpty
        )

        let slots = InstantActionsRailPolicy.slots(
            for: [.text("Custom actions")],
            selectedItemIDs: [],
            configuredActions: configured
        )

        #expect(slots.count == 4)
        #expect(slots.map(\.action) == configured)
        #expect(slots.map(\.isAvailable) == [false, true, true, true])
        #expect(slots.map(\.id) == [0, 1, 2, 3])
        #expect(Set(slots.map(\.id)).count == 4)
    }

    @Test("Instant Actions dismisses on outside click or Escape")
    func instantActionsDismissPolicy() {
        #expect(
            ShelfPanelController.shouldDismissInstantActions(
                isPresented: true,
                triggeredByEscape: false,
                isClickInsideShelfOrAccessory: false
            )
        )
        #expect(
            ShelfPanelController.shouldDismissInstantActions(
                isPresented: true,
                triggeredByEscape: true,
                isClickInsideShelfOrAccessory: true
            )
        )
        #expect(
            !ShelfPanelController.shouldDismissInstantActions(
                isPresented: true,
                triggeredByEscape: false,
                isClickInsideShelfOrAccessory: true
            )
        )
        #expect(
            !ShelfPanelController.shouldDismissInstantActions(
                isPresented: false,
                triggeredByEscape: true,
                isClickInsideShelfOrAccessory: false
            )
        )
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

        let transitionID = store.beginLayoutTransition(
            to: .detail,
            sourceSize: CGSize(width: 198, height: 207),
            targetSize: CGSize(width: 400, height: 207),
            contentFadeDuration: 0.12
        )

        #expect(store.isLayoutTransitioning)
        #expect(!store.isLayoutContentVisible)
        #expect(store.pendingPresentationState == .detail)
        #expect(store.shelf.presentationState == .compact)
        #expect(store.layoutSourceSize == CGSize(width: 198, height: 207))
        #expect(store.layoutTargetSize == CGSize(width: 400, height: 207))
        #expect(store.layoutContentFadeDuration == 0.12)
        #expect(
            !store.revealLayoutContent(for: UUID())
        )
        #expect(!store.isLayoutContentVisible)

        #expect(store.revealLayoutContent(for: transitionID))

        #expect(store.isLayoutContentVisible)

        #expect(store.endLayoutTransition(for: transitionID))

        #expect(!store.isLayoutTransitioning)
        #expect(store.isLayoutContentVisible)
        #expect(store.pendingPresentationState == nil)
        #expect(store.layoutTransitionID == nil)
        #expect(store.layoutSourceSize == nil)
        #expect(store.layoutTargetSize == nil)
    }

    @Test("Shelf swaps layouts only after real fade completions")
    func shelfSwapsLayoutsAfterFadeCompletions() throws {
        let controller = ShelfPanelController(
            shelf: ShelfRecord(
                items: [.text("Fade before swapping")]
            ),
            location: CGPoint(x: 500, y: 500),
            animatesInitialAppearance: false,
            onDrop: { _ in },
            onChange: {},
            onClose: {}
        )
        defer { controller.close() }

        controller.beginLayoutTransition(
            to: .detail,
            dockedEdge: nil,
            targetFrame: CGRect(
                x: 300,
                y: 300,
                width: 400,
                height: 207
            ),
            timing: .init(
                frameDuration: 0,
                contentFadeDuration: 0.12,
                contentSwapDelay: 0.12,
                completionDelay: 0.18
            )
        )
        let transitionID = try #require(
            controller.store.layoutTransitionID
        )

        #expect(controller.store.shelf.presentationState == .compact)
        #expect(
            controller.store.pendingPresentationState == .detail
        )

        controller.completeLayoutFadeOut(for: UUID())
        #expect(controller.store.shelf.presentationState == .compact)

        controller.completeLayoutFadeOut(for: transitionID)
        #expect(controller.store.shelf.presentationState == .detail)
        #expect(!controller.store.isLayoutContentVisible)

        controller.layoutTargetDidMount(for: transitionID)
        #expect(controller.store.isLayoutContentVisible)
        #expect(controller.store.isLayoutTransitioning)

        controller.completeLayoutFadeIn(for: transitionID)
        #expect(!controller.store.isLayoutTransitioning)
        #expect(controller.store.pendingPresentationState == nil)
    }
}

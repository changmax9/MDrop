import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(
        languageController: AppLanguageController = .shared
    ) {
        let rootView = SettingsView()
            .environment(languageController)
            .environment(
                \.locale,
                languageController.locale
            )
        let hostingController = NSHostingController(
            rootView: rootView
        )
        let contentSize = NSSize(
            width: SettingsLayout.preferredWidth,
            height: SettingsLayout.preferredHeight
        )
        let window = NSWindow(
            contentRect: NSRect(
                origin: .zero,
                size: contentSize
            ),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentViewController = hostingController
        window.setContentSize(contentSize)
        window.contentMinSize = NSSize(
            width: SettingsLayout.minimumWidth,
            height: SettingsLayout.minimumHeight
        )
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbarStyle = .unified
        window.setFrameAutosaveName("MDrop.Settings.Dropover")

        super.init(window: window)
        refreshLanguage()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func show() {
        guard let window else { return }
        refreshLanguage()
        if !window.isVisible {
            window.center()
        }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refreshLanguage() {
        window?.title = AppLocalization.string("Settings")
    }
}

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
                .miniaturizable
            ],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.setContentSize(contentSize)
        window.contentMinSize = contentSize
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.setFrameAutosaveName("MDrop.Settings")

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

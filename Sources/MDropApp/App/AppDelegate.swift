import AppKit
import MDropCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = ShelfCoordinator()
    private var statusItem: NSStatusItem?
    private var shakeMonitor: ShakeMonitor?
    private var hotKeyManager: GlobalHotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureActivation()
        coordinator.restore()
        openCommandLineFiles()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        coordinator.createShelf(with: urls.map(DropRepresentation.file))
    }

    func applicationWillTerminate(_ notification: Notification) {
        shakeMonitor?.stop()
        hotKeyManager?.stop()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "square.stack.3d.up.fill",
            accessibilityDescription: "MDrop"
        )
        item.menu = makeStatusMenu()
        statusItem = item
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            withTitle: String(localized: "New Shelf"),
            action: #selector(newShelf),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: String(localized: "Clipboard Shelf"),
            action: #selector(newClipboardShelf),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: String(localized: "Open Last Shelf"),
            action: #selector(openLastShelf),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: String(localized: "Close All Shelves"),
            action: #selector(closeAllShelves),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: String(localized: "Settings…"),
            action: #selector(openSettings),
            keyEquivalent: ","
        ).target = self
        menu.addItem(
            withTitle: String(localized: "Quit MDrop"),
            action: #selector(quit),
            keyEquivalent: "q"
        ).target = self
        return menu
    }

    private func configureActivation() {
        shakeMonitor = ShakeMonitor { [weak self] point in
            self?.coordinator.createShelf(at: point)
        }
        shakeMonitor?.start()

        hotKeyManager = GlobalHotKeyManager()
        hotKeyManager?.registerDefaults(
            newShelf: { [weak self] in self?.coordinator.createShelf() },
            clipboardShelf: { [weak self] in self?.coordinator.createClipboardShelf() },
            selectShelf: { [weak self] in self?.coordinator.selectShelf() }
        )
    }

    private func openCommandLineFiles() {
        let paths = Array(CommandLine.arguments.dropFirst())
            .filter { !$0.hasPrefix("-") }
        guard !paths.isEmpty else { return }
        coordinator.createShelf(with: paths.map { .file(URL(filePath: $0)) })
    }

    @objc private func newShelf() {
        coordinator.createShelf()
    }

    @objc private func newClipboardShelf() {
        coordinator.createClipboardShelf()
    }

    @objc private func openLastShelf() {
        coordinator.openLastShelf()
    }

    @objc private func closeAllShelves() {
        coordinator.closeAll()
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

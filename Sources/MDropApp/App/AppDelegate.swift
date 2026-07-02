import AppKit
import MDropCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let coordinator = ShelfCoordinator()
    private var statusItem: NSStatusItem?
    private var shakeMonitor: ShakeMonitor?
    private var hotKeyManager: GlobalHotKeyManager?
    private var servicesProvider: MDropServicesProvider?
    private var statusDropView: StatusDropReceiverView?
    private var shelfMenu: NSMenu?
    private var lastURLRoute: (url: URL, date: Date)?
    private var languageObserver: NSObjectProtocol?
    private var settingsWindowController: SettingsWindowController?
    private lazy var notchDropController = NotchDropController { [weak self] representations in
        self?.coordinator.createShelf(with: representations)
    }
    private lazy var folderMonitor = FolderMonitorService { [weak self] definition, urls in
        self?.coordinator.receiveWatchedFiles(urls, definition: definition)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppServices.coordinator = coordinator
        configureServices()
        configureURLHandler()
        configureStatusItem()
        observeLanguageChanges()
        configureActivation()
        configureAutomation()
        coordinator.restore()
        openCommandLineFiles()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "mdrop" {
            handleURLRoute(url)
        }
        let files = urls.filter(\.isFileURL)
        if !files.isEmpty {
            coordinator.createShelf(with: files.map(DropRepresentation.file))
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        shakeMonitor?.stop()
        hotKeyManager?.stop()
        folderMonitor.stop()
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image =
            BrandAssets.menuBarImage()
            ?? NSImage(
                systemSymbolName: "square.stack.3d.up.fill",
                accessibilityDescription: "MDrop"
            )
        item.menu = makeStatusMenu()
        if let button = item.button {
            let dropView = StatusDropReceiverView(frame: button.bounds)
            dropView.autoresizingMask = [.width, .height]
            dropView.onClick = { [weak item] in item?.button?.performClick(nil) }
            dropView.onDrop = { [weak self] representations in
                guard UserDefaults.standard.object(
                    forKey: "menuBarDropEnabled"
                ) as? Bool ?? true else {
                    return
                }
                self?.coordinator.createShelf(with: representations)
            }
            button.addSubview(dropView)
            statusDropView = dropView
        }
        statusItem = item
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(
            withTitle: AppLocalization.string("New Shelf"),
            action: #selector(newShelf),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: AppLocalization.string("Clipboard Shelf"),
            action: #selector(newClipboardShelf),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: AppLocalization.string("Open Last Shelf"),
            action: #selector(openLastShelf),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: AppLocalization.string("Close All Shelves"),
            action: #selector(closeAllShelves),
            keyEquivalent: ""
        ).target = self
        let shelfItem = NSMenuItem(
            title: AppLocalization.string("Shelves"),
            action: nil,
            keyEquivalent: ""
        )
        let shelfMenu = NSMenu(
            title: AppLocalization.string("Shelves")
        )
        shelfItem.submenu = shelfMenu
        menu.addItem(shelfItem)
        self.shelfMenu = shelfMenu
        menu.addItem(.separator())
        menu.addItem(
            withTitle: AppLocalization.string("Settings…"),
            action: #selector(openSettings),
            keyEquivalent: ","
        ).target = self
        menu.addItem(
            withTitle: AppLocalization.string("Quit MDrop"),
            action: #selector(quit),
            keyEquivalent: "q"
        ).target = self
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === statusItem?.menu else { return }
        refreshShelfMenu()
    }

    private func refreshShelfMenu() {
        guard let shelfMenu else { return }
        shelfMenu.removeAllItems()
        let shelves = coordinator.shelvesForMenu()
        guard !shelves.isEmpty else {
            let item = NSMenuItem(
                title: AppLocalization.string("No Recent Shelves"),
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = false
            shelfMenu.addItem(item)
            return
        }

        for shelf in shelves {
            let itemCount = shelf.items.count
            let fallback = String(
                format: AppLocalization.string("%lld Items"),
                locale: AppLocalization.selectedLanguage.locale,
                Int64(itemCount)
            )
            let item = NSMenuItem(
                title: shelf.name.isEmpty ? fallback : shelf.name,
                action: #selector(openShelfFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = shelf.id.uuidString
            item.state = coordinator.isShelfVisible(shelf.id) ? .on : .off
            if shelf.isPinned {
                item.image = NSImage(
                    systemSymbolName: "pin.fill",
                    accessibilityDescription:
                        AppLocalization.string("Pinned")
                )
            }
            shelfMenu.addItem(item)
        }
    }

    private func observeLanguageChanges() {
        languageObserver = NotificationCenter.default.addObserver(
            forName: AppLanguageController.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let statusItem else { return }
                statusItem.menu = makeStatusMenu()
                settingsWindowController?.refreshLanguage()
            }
        }
    }

    private func configureActivation() {
        shakeMonitor = ShakeMonitor(
            onDrag: { [weak self] point in
                guard UserDefaults.standard.object(
                    forKey: "notchDropEnabled"
                ) as? Bool ?? true else {
                    self?.notchDropController.hide()
                    return
                }
                self?.notchDropController.update(pointer: point)
            },
            onDragEnded: { [weak self] in
                self?.notchDropController.hide()
            },
            onShake: { [weak self] point in
                self?.coordinator.createShelf(at: point)
            }
        )
        shakeMonitor?.start()

        hotKeyManager = GlobalHotKeyManager()
        hotKeyManager?.registerDefaults(
            newShelf: { [weak self] in self?.coordinator.createShelf() },
            clipboardShelf: { [weak self] in self?.coordinator.createClipboardShelf() },
            selectShelf: { [weak self] in self?.coordinator.selectShelf() }
        )
        UserDefaults.standard.set(
            hotKeyManager?.registrationFailures ?? [],
            forKey: "hotKeyRegistrationFailures"
        )
    }

    private func configureAutomation() {
        let automation = AutomationStore.shared
        automation.onChange = { [weak self] in
            self?.folderMonitor.update(AutomationStore.shared.watchedFolders)
        }
        folderMonitor.update(automation.watchedFolders)
    }

    private func configureServices() {
        let provider = MDropServicesProvider(coordinator: coordinator)
        servicesProvider = provider
        NSApp.servicesProvider = provider
        NSUpdateDynamicServices()
    }

    private func configureURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        guard let value = event.paramDescriptor(
            forKeyword: AEKeyword(keyDirectObject)
        )?.stringValue,
        let url = URL(string: value) else {
            return
        }
        handleURLRoute(url)
    }

    private func handleURLRoute(_ url: URL) {
        let now = Date()
        if let lastURLRoute,
           lastURLRoute.url == url,
           now.timeIntervalSince(lastURLRoute.date) < 0.25 {
            return
        }
        lastURLRoute = (url, now)
        coordinator.handle(url)
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

    @objc private func openShelfFromMenu(_ sender: NSMenuItem) {
        guard let rawID = sender.representedObject as? String,
              let id = UUID(uuidString: rawID) else {
            return
        }
        coordinator.openShelf(id)
    }

    @objc private func openSettings() {
        let controller =
            settingsWindowController
            ?? SettingsWindowController()
        settingsWindowController = controller
        controller.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

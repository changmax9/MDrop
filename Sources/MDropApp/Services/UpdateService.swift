import Foundation
import Observation
import Sparkle

enum UpdateConfiguration {
    static let feedURL = URL(
        string:
            "https://raw.githubusercontent.com/changmax9/MDrop/main/appcast.xml"
    )!
}

private final class UpdateUserDriverDelegate:
    NSObject,
    SPUStandardUserDriverDelegate
{
    var supportsGentleScheduledUpdateReminders: Bool {
        true
    }
}

@MainActor
@Observable
final class UpdateService {
    static let shared = UpdateService(
        startingUpdater:
            Bundle.main.bundleURL.pathExtension == "app"
    )

    @ObservationIgnored
    private let controller: SPUStandardUpdaterController
    @ObservationIgnored
    private let userDriverDelegate: UpdateUserDriverDelegate

    private(set) var canCheckForUpdates: Bool
    var automaticallyChecksForUpdates: Bool {
        didSet {
            guard
                automaticallyChecksForUpdates
                    != controller.updater.automaticallyChecksForUpdates
            else {
                return
            }
            controller.updater.automaticallyChecksForUpdates =
                automaticallyChecksForUpdates
            refresh()
        }
    }
    var automaticallyDownloadsUpdates: Bool {
        didSet {
            guard
                automaticallyDownloadsUpdates
                    != controller.updater.automaticallyDownloadsUpdates
            else {
                return
            }
            controller.updater.automaticallyDownloadsUpdates =
                automaticallyDownloadsUpdates
        }
    }

    init(startingUpdater: Bool) {
        let userDriverDelegate = UpdateUserDriverDelegate()
        let controller = SPUStandardUpdaterController(
            startingUpdater: startingUpdater,
            updaterDelegate: nil,
            userDriverDelegate: userDriverDelegate
        )
        self.userDriverDelegate = userDriverDelegate
        self.controller = controller
        canCheckForUpdates = controller.updater.canCheckForUpdates
        automaticallyChecksForUpdates =
            controller.updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates =
            controller.updater.automaticallyDownloadsUpdates

        if startingUpdater {
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.refresh()
            }
        }
    }

    func refresh() {
        canCheckForUpdates = controller.updater.canCheckForUpdates
        automaticallyChecksForUpdates =
            controller.updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates =
            controller.updater.automaticallyDownloadsUpdates
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
        refresh()
    }
}

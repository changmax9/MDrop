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
    @ObservationIgnored
    private var canCheckForUpdatesObservation: NSKeyValueObservation?

    private(set) var canCheckForUpdates: Bool

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

        if startingUpdater {
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.refresh()
            }
        }

        canCheckForUpdatesObservation = controller.updater.observe(
            \.canCheckForUpdates,
            options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func refresh() {
        canCheckForUpdates = controller.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
        refresh()
    }
}

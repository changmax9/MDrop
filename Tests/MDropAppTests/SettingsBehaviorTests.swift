import Foundation
import MDropCore
import ServiceManagement
import Testing
@testable import MDropApp

@MainActor
@Suite("Settings behavior")
struct SettingsBehaviorTests {
    @Test("Shared preference keys preserve defaults and runtime changes")
    func sharedPreferenceKeys() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(AppPreferences.shakeEnabled(in: defaults))
        #expect(AppPreferences.shakeSensitivity(in: defaults) == 0.5)
        #expect(
            AppPreferences.shakeMinimumSegmentDistance(in: defaults) == 21
        )
        #expect(AppPreferences.menuBarDropEnabled(in: defaults))
        #expect(AppPreferences.notchDropEnabled(in: defaults))
        #expect(!AppPreferences.activateNewShelves(in: defaults))
        #expect(!AppPreferences.autoCloseDetail(in: defaults))
        #expect(!AppPreferences.alwaysCopyDraggedItems(in: defaults))
        #expect(!AppPreferences.reduceMotion(in: defaults))

        defaults.set(false, forKey: AppPreferences.shakeEnabledKey)
        defaults.set(
            0.8,
            forKey: AppPreferences.shakeSensitivityKey
        )
        defaults.set(
            false,
            forKey: AppPreferences.menuBarDropEnabledKey
        )
        defaults.set(
            false,
            forKey: AppPreferences.notchDropEnabledKey
        )
        defaults.set(
            true,
            forKey: AppPreferences.activateNewShelvesKey
        )
        defaults.set(
            true,
            forKey: AppPreferences.autoCloseDetailKey
        )
        defaults.set(
            true,
            forKey: AppPreferences.alwaysCopyDraggedItemsKey
        )
        defaults.set(true, forKey: AppPreferences.reduceMotionKey)

        #expect(!AppPreferences.shakeEnabled(in: defaults))
        #expect(AppPreferences.shakeSensitivity(in: defaults) == 0.8)
        #expect(!AppPreferences.menuBarDropEnabled(in: defaults))
        #expect(!AppPreferences.notchDropEnabled(in: defaults))
        #expect(AppPreferences.activateNewShelves(in: defaults))
        #expect(AppPreferences.autoCloseDetail(in: defaults))
        #expect(AppPreferences.alwaysCopyDraggedItems(in: defaults))
        #expect(AppPreferences.reduceMotion(in: defaults))
    }

    @Test("Shake sensitivity remains inside detector bounds")
    func shakeSensitivityBounds() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(-1.0, forKey: AppPreferences.shakeSensitivityKey)
        #expect(AppPreferences.shakeSensitivity(in: defaults) == 0)
        #expect(
            AppPreferences.shakeMinimumSegmentDistance(in: defaults) == 30
        )

        defaults.set(2.0, forKey: AppPreferences.shakeSensitivityKey)
        #expect(AppPreferences.shakeSensitivity(in: defaults) == 1)
        #expect(
            AppPreferences.shakeMinimumSegmentDistance(in: defaults) == 12
        )
    }

    @Test("Instant Actions keeps four independent persisted slots")
    func instantActionSlots() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(
            AppPreferences.instantActionIDs(in: defaults)
                == AppPreferences.defaultInstantActionIDs
        )

        let custom: [BuiltinActionID] = [
            .moveToTrash,
            .resizeImages,
            .resizeImages,
            .copyPath
        ]
        for (key, action) in zip(
            AppPreferences.instantActionSlotKeys,
            custom
        ) {
            defaults.set(action.rawValue, forKey: key)
        }
        #expect(AppPreferences.instantActionIDs(in: defaults) == custom)

        defaults.set(
            "not-a-real-action",
            forKey: AppPreferences.instantActionSlot2Key
        )
        var expected = custom
        expected[1] = AppPreferences.defaultInstantActionIDs[1]
        #expect(AppPreferences.instantActionIDs(in: defaults) == expected)
    }

    @Test("Launch at login reflects the actual service status")
    func launchAtLoginStatus() {
        let service = FakeLoginItemService(status: .notRegistered)
        let settings = LaunchAtLoginSettings(service: service)

        #expect(!settings.isEnabled)

        settings.setEnabled(true)
        #expect(service.registerCount == 1)
        #expect(settings.isEnabled)

        settings.setEnabled(false)
        #expect(service.unregisterCount == 1)
        #expect(!settings.isEnabled)
    }

    @Test("Launch at login surfaces service failures without lying")
    func launchAtLoginFailure() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.failure = FakeSettingsError()
        let settings = LaunchAtLoginSettings(service: service)

        settings.setEnabled(true)

        #expect(!settings.isEnabled)
        #expect(settings.errorMessage == "Settings test failure")
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "MDrop.SettingsTests.\(UUID().uuidString)"
        return (
            try #require(UserDefaults(suiteName: suiteName)),
            suiteName
        )
    }
}

@MainActor
private final class FakeLoginItemService: LoginItemService {
    var status: SMAppService.Status
    var failure: (any Error)?
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        registerCount += 1
        if let failure { throw failure }
        status = .enabled
    }

    func unregister() throws {
        unregisterCount += 1
        if let failure { throw failure }
        status = .notRegistered
    }
}

private struct FakeSettingsError: LocalizedError {
    var errorDescription: String? {
        "Settings test failure"
    }
}

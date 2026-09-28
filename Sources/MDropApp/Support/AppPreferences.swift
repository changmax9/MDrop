import Foundation
import MDropCore

enum AppPreferences {
    static let shakeEnabledKey = "shakeEnabled"
    static let shakeSensitivityKey = "shakeSensitivity"
    static let menuBarDropEnabledKey = "menuBarDropEnabled"
    static let notchDropEnabledKey = "notchDropEnabled"
    static let activateNewShelvesKey = "activateNewShelves"
    static let autoCloseDetailKey = "autoCloseDetail"
    static let alwaysCopyDraggedItemsKey = "alwaysCopyDraggedItems"
    static let reduceMotionKey = "reduceShelfMotion"
    static let instantActionSlot1Key = "instantActionSlot1"
    static let instantActionSlot2Key = "instantActionSlot2"
    static let instantActionSlot3Key = "instantActionSlot3"
    static let instantActionSlot4Key = "instantActionSlot4"

    static let instantActionSlotKeys = [
        instantActionSlot1Key,
        instantActionSlot2Key,
        instantActionSlot3Key,
        instantActionSlot4Key
    ]

    static let defaultInstantActionIDs: [BuiltinActionID] = [
        .systemShare,
        .copyTo,
        .moveTo,
        .createArchive
    ]

    static func shakeEnabled(
        in defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.object(forKey: shakeEnabledKey) as? Bool ?? true
    }

    static func shakeSensitivity(
        in defaults: UserDefaults = .standard
    ) -> Double {
        let value = defaults.object(forKey: shakeSensitivityKey)
            as? Double ?? 0.5
        return min(max(value, 0), 1)
    }

    static func shakeMinimumSegmentDistance(
        in defaults: UserDefaults = .standard
    ) -> Double {
        30 - shakeSensitivity(in: defaults) * 18
    }

    static func menuBarDropEnabled(
        in defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.object(forKey: menuBarDropEnabledKey) as? Bool ?? true
    }

    static func notchDropEnabled(
        in defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.object(forKey: notchDropEnabledKey) as? Bool ?? true
    }

    static func activateNewShelves(
        in defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.bool(forKey: activateNewShelvesKey)
    }

    static func autoCloseDetail(
        in defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.bool(forKey: autoCloseDetailKey)
    }

    static func alwaysCopyDraggedItems(
        in defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.bool(forKey: alwaysCopyDraggedItemsKey)
    }

    static func reduceMotion(
        in defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.bool(forKey: reduceMotionKey)
    }

    static func instantActionIDs(
        in defaults: UserDefaults = .standard
    ) -> [BuiltinActionID] {
        instantActionIDs(
            rawValues: instantActionSlotKeys.map {
                defaults.string(forKey: $0)
            }
        )
    }

    static func instantActionIDs(
        rawValues: [String?]
    ) -> [BuiltinActionID] {
        defaultInstantActionIDs.indices.map { index in
            guard rawValues.indices.contains(index),
                  let rawValue = rawValues[index],
                  let action = BuiltinActionID(rawValue: rawValue)
            else {
                return defaultInstantActionIDs[index]
            }
            return action
        }
    }
}

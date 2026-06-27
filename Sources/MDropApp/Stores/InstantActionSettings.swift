import Foundation
import MDropCore
import Observation

@MainActor
@Observable
final class InstantActionSettings {
    static let shared = InstantActionSettings()

    private static let defaultsKey = "instantActionConfiguration"
    private(set) var configuration: InstantActionConfiguration

    private init(defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: Self.defaultsKey),
           let stored = try? JSONDecoder().decode(
               InstantActionConfiguration.self,
               from: data
           ) {
            configuration = stored
        } else {
            configuration = .default
        }
    }

    func isEnabled(_ action: BuiltinActionID) -> Bool {
        configuration.actions.contains(action)
    }

    func setEnabled(_ enabled: Bool, for action: BuiltinActionID) {
        var actions = configuration.actions.filter { $0 != action }
        if enabled, actions.count < InstantActionConfiguration.maximumActionCount {
            actions.append(action)
        }
        configuration = InstantActionConfiguration(actions: actions)
        save()
    }

    func move(from offsets: IndexSet, to destination: Int) {
        var actions = configuration.actions
        actions.move(fromOffsets: offsets, toOffset: destination)
        configuration = InstantActionConfiguration(actions: actions)
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
}

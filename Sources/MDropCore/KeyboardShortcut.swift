import Foundation

public struct KeyboardShortcut: Codable, Hashable, Sendable {
    public var id: String
    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(id: String, keyCode: UInt32, modifiers: UInt32) {
        self.id = id
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum KeyboardShortcutValidator {
    public static func conflictingIDs(
        in shortcuts: [KeyboardShortcut]
    ) -> Set<String> {
        let groups = Dictionary(grouping: shortcuts) {
            ShortcutChord(keyCode: $0.keyCode, modifiers: $0.modifiers)
        }
        return Set(
            groups.values
                .filter { $0.count > 1 }
                .flatMap { $0.map(\.id) }
        )
    }

    private struct ShortcutChord: Hashable {
        var keyCode: UInt32
        var modifiers: UInt32
    }
}

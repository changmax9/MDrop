import Carbon
import MDropCore

@MainActor
final class GlobalHotKeyManager {
    private var references: [EventHotKeyRef?] = []
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    private(set) var registrationFailures: [String] = []

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let event, let context else { return noErr }
                let manager = Unmanaged<GlobalHotKeyManager>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                Task { @MainActor in
                    manager.handlers[hotKeyID.id]?()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    func registerDefaults(
        newShelf: @escaping () -> Void,
        clipboardShelf: @escaping () -> Void,
        selectShelf: @escaping () -> Void
    ) {
        let modifiers = UInt32(optionKey | shiftKey)
        let shortcuts = [
            KeyboardShortcut(
                id: "newShelf",
                keyCode: UInt32(kVK_Space),
                modifiers: modifiers
            ),
            KeyboardShortcut(
                id: "clipboardShelf",
                keyCode: UInt32(kVK_ANSI_A),
                modifiers: modifiers
            ),
            KeyboardShortcut(
                id: "selectShelf",
                keyCode: UInt32(kVK_ANSI_S),
                modifiers: modifiers
            )
        ]
        guard KeyboardShortcutValidator.conflictingIDs(in: shortcuts).isEmpty else {
            registrationFailures = shortcuts.map(\.id)
            return
        }
        let callbacks = [newShelf, clipboardShelf, selectShelf]
        for (index, shortcut) in shortcuts.enumerated() {
            register(
                id: UInt32(index + 1),
                shortcut: shortcut,
                handler: callbacks[index]
            )
        }
    }

    private func register(
        id: UInt32,
        shortcut: KeyboardShortcut,
        handler: @escaping () -> Void
    ) {
        let signature = OSType(
            UInt32(ascii: "M") << 24 |
            UInt32(ascii: "D") << 16 |
            UInt32(ascii: "R") << 8 |
            UInt32(ascii: "P")
        )
        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        if RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        ) == noErr {
            references.append(reference)
            handlers[id] = handler
        } else {
            registrationFailures.append(shortcut.id)
        }
    }

    func stop() {
        for reference in references {
            if let reference {
                UnregisterEventHotKey(reference)
            }
        }
        references.removeAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        handlers.removeAll()
    }
}

private extension UInt32 {
    init(ascii character: Character) {
        self = character.asciiValue.map(UInt32.init) ?? 0
    }
}

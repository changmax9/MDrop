import Carbon

@MainActor
final class GlobalHotKeyManager {
    private var references: [EventHotKeyRef?] = []
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?

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
        register(id: 1, keyCode: UInt32(kVK_Space), modifiers: modifiers, handler: newShelf)
        register(id: 2, keyCode: UInt32(kVK_ANSI_A), modifiers: modifiers, handler: clipboardShelf)
        register(id: 3, keyCode: UInt32(kVK_ANSI_S), modifiers: modifiers, handler: selectShelf)
    }

    private func register(
        id: UInt32,
        keyCode: UInt32,
        modifiers: UInt32,
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
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        ) == noErr {
            references.append(reference)
            handlers[id] = handler
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

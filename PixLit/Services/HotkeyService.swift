import Carbon

private var hotkeyHandler: (() -> Void)?

private func hotkeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    hotkeyHandler?()
    return noErr
}

class HotkeyService {
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    /// Register a global hotkey.
    /// Default: Cmd+Shift+2 (keyCode 0x13, modifiers cmdKey | shiftKey)
    func register(
        keyCode: UInt32 = 0x13,
        modifiers: UInt32 = UInt32(cmdKey | shiftKey),
        handler: @escaping () -> Void
    ) {
        hotkeyHandler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyCallback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        let hotkeyID = EventHotKeyID(
            signature: OSType(0x50584C54), // "PXLT"
            id: 1
        )

        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
    }

    func unregister() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        hotkeyHandler = nil
    }

    deinit {
        unregister()
    }
}

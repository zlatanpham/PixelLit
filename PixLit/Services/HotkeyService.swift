import AppKit
import Carbon

// MARK: - HotkeyShortcut Model

struct HotkeyShortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let `default` = HotkeyShortcut(keyCode: 0x13, modifiers: UInt32(cmdKey | shiftKey))

    private static let userDefaultsKey = "hotkeyShortcut"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }

    static func load() -> HotkeyShortcut {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let shortcut = try? JSONDecoder().decode(HotkeyShortcut.self, from: data)
        else {
            return .default
        }
        return shortcut
    }

    var displayString: String {
        var parts: [String] = []

        // Order: Control, Option, Shift, Command (standard macOS ordering)
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }

        parts.append(Self.keyCodeToString(keyCode))
        return parts.joined()
    }

    private static func keyCodeToString(_ keyCode: UInt32) -> String {
        let mapping: [UInt32: String] = [
            // Letters
            0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E",
            0x03: "F", 0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J",
            0x28: "K", 0x25: "L", 0x2E: "M", 0x2D: "N", 0x1F: "O",
            0x23: "P", 0x0C: "Q", 0x0F: "R", 0x01: "S", 0x11: "T",
            0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X", 0x10: "Y",
            0x06: "Z",
            // Numbers
            0x1D: "0", 0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4",
            0x17: "5", 0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9",
            // Function keys
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
            // Special keys
            0x31: "Space", 0x30: "Tab", 0x33: "Delete", 0x75: "⌦",
            0x24: "Return", 0x4C: "Enter", 0x35: "Esc",
            // Arrow keys
            0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
            // Punctuation
            0x1B: "-", 0x18: "=", 0x21: "[", 0x1E: "]",
            0x29: ";", 0x27: "'", 0x2A: "\\", 0x2B: ",",
            0x2F: ".", 0x2C: "/", 0x32: "`",
        ]
        return mapping[keyCode] ?? "?"
    }
}

// MARK: - NSEvent to Carbon Conversion

extension HotkeyShortcut {
    /// Convert NSEvent modifier flags to Carbon modifier mask
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }

    /// Check if NSEvent modifier flags contain at least one modifier
    static func hasModifier(_ flags: NSEvent.ModifierFlags) -> Bool {
        !flags.intersection([.command, .shift, .option, .control]).isEmpty
    }
}

// MARK: - Hotkey Service

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
    func register(
        keyCode: UInt32 = HotkeyShortcut.default.keyCode,
        modifiers: UInt32 = HotkeyShortcut.default.modifiers,
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

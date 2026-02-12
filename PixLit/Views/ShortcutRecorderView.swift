import SwiftUI

struct ShortcutRecorderView: View {
    @Binding var shortcut: HotkeyShortcut
    var onChange: ((HotkeyShortcut) -> Void)?

    @State private var isRecording = false

    var body: some View {
        ShortcutRecorderNSView(
            shortcut: $shortcut,
            isRecording: $isRecording,
            onChange: onChange
        )
        .frame(minWidth: 80, maxWidth: 120, minHeight: 24)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isRecording ? Color.accentColor : Color(NSColor.separatorColor),
                    lineWidth: isRecording ? 2 : 1
                )
        )
    }
}

// MARK: - NSViewRepresentable

private struct ShortcutRecorderNSView: NSViewRepresentable {
    @Binding var shortcut: HotkeyShortcut
    @Binding var isRecording: Bool
    var onChange: ((HotkeyShortcut) -> Void)?

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.delegate = context.coordinator
        view.setRecording(false, displayString: shortcut.displayString)
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.setRecording(isRecording, displayString: shortcut.displayString)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, KeyCaptureViewDelegate {
        var parent: ShortcutRecorderNSView

        init(_ parent: ShortcutRecorderNSView) {
            self.parent = parent
        }

        func keyCaptureViewDidClick() {
            parent.isRecording = true
            Task { @MainActor in
                AppDelegate.shared?.suspendHotkey()
            }
        }

        func keyCaptureViewDidCaptureKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
            let carbonMods = HotkeyShortcut.carbonModifiers(from: modifiers)
            let newShortcut = HotkeyShortcut(keyCode: UInt32(keyCode), modifiers: carbonMods)
            parent.shortcut = newShortcut
            parent.isRecording = false
            parent.onChange?(newShortcut)
        }

        func keyCaptureViewDidCancel() {
            parent.isRecording = false
            // Re-register the previously saved shortcut
            Task { @MainActor in
                let current = HotkeyShortcut.load()
                AppDelegate.shared?.updateHotkey(shortcut: current)
            }
        }
    }
}

// MARK: - Key Capture NSView

protocol KeyCaptureViewDelegate: AnyObject {
    func keyCaptureViewDidClick()
    func keyCaptureViewDidCaptureKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags)
    func keyCaptureViewDidCancel()
}

/// C-compatible callback for the CGEvent tap.
/// Intercepts key events at the session level, before they reach any app's
/// Carbon hotkey handler, so we can capture shortcuts that would otherwise
/// be swallowed by another application.
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
    let view = Unmanaged<KeyCaptureView>.fromOpaque(userInfo).takeUnretainedValue()
    return view.handleTapEvent(type: type, event: event)
}

class KeyCaptureView: NSView {
    weak var delegate: KeyCaptureViewDelegate?
    private let label = NSTextField(labelWithString: "")
    private let recordingIndicator = NSTextField(labelWithString: "\u{2022}\u{2022}\u{2022}")
    private var isRecording = false
    private var clickMonitor: Any?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var usesEventTap = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        recordingIndicator.font = .systemFont(ofSize: 14, weight: .medium)
        recordingIndicator.textColor = .controlAccentColor
        recordingIndicator.alignment = .center
        recordingIndicator.translatesAutoresizingMaskIntoConstraints = false
        recordingIndicator.isHidden = true

        addSubview(label)
        addSubview(recordingIndicator)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            recordingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            recordingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func setRecording(_ recording: Bool, displayString: String) {
        isRecording = recording
        label.stringValue = displayString
        label.isHidden = recording
        recordingIndicator.isHidden = !recording
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if !isRecording {
            window?.makeFirstResponder(self)
            isRecording = true
            delegate?.keyCaptureViewDidClick()
            installEventTap()
            installClickOutsideMonitor()
        }
    }

    override func keyDown(with event: NSEvent) {
        // When the CGEvent tap is active it handles all key events;
        // this override is the fallback when accessibility permissions
        // are not granted and the tap could not be created.
        guard isRecording, !usesEventTap else {
            if !isRecording { super.keyDown(with: event) }
            return
        }
        processKeyEvent(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
    }

    override func flagsChanged(with event: NSEvent) {
        if !isRecording {
            super.flagsChanged(with: event)
        }
    }

    // MARK: - Key Processing (shared by both paths)

    private static let modifierOnlyKeyCodes: Set<UInt16> = [
        0x37, 0x36, // Command L/R
        0x38, 0x3C, // Shift L/R
        0x3A, 0x3D, // Option L/R
        0x3B, 0x3E, // Control L/R
        0x3F,       // Function
    ]

    private func processKeyEvent(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        if keyCode == 0x35 { // Escape
            cancelRecording()
            return
        }

        guard HotkeyShortcut.hasModifier(modifierFlags) else { return }
        guard !Self.modifierOnlyKeyCodes.contains(keyCode) else { return }

        let modifiers = modifierFlags.intersection([.command, .shift, .option, .control])
        finishRecording(keyCode: keyCode, modifiers: modifiers)
    }

    private func finishRecording(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        isRecording = false
        removeEventTap()
        removeClickOutsideMonitor()
        delegate?.keyCaptureViewDidCaptureKey(keyCode: keyCode, modifiers: modifiers)
    }

    // MARK: - CGEvent Tap

    /// Called from the C callback. Runs on the main thread (the tap source
    /// is added to the main run loop).
    func handleTapEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if the system disabled it due to timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard isRecording else { return Unmanaged.passUnretained(event) }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        var nsFlags = NSEvent.ModifierFlags()
        if flags.contains(.maskCommand) { nsFlags.insert(.command) }
        if flags.contains(.maskShift) { nsFlags.insert(.shift) }
        if flags.contains(.maskAlternate) { nsFlags.insert(.option) }
        if flags.contains(.maskControl) { nsFlags.insert(.control) }

        processKeyEvent(keyCode: keyCode, modifierFlags: nsFlags)

        // Suppress the event so it doesn't trigger other apps' hotkeys
        return nil
    }

    private func installEventTap() {
        removeEventTap()

        let eventMask: CGEventMask = 1 << CGEventType.keyDown.rawValue

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            // Accessibility permissions not granted — fall back to keyDown
            usesEventTap = false
            return
        }

        usesEventTap = true
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func removeEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        usesEventTap = false
    }

    // MARK: - Click Outside / Cancel

    private func cancelRecording() {
        isRecording = false
        removeEventTap()
        removeClickOutsideMonitor()
        delegate?.keyCaptureViewDidCancel()
    }

    private func installClickOutsideMonitor() {
        removeClickOutsideMonitor()
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            let locationInView = self.convert(event.locationInWindow, from: nil)
            if !self.bounds.contains(locationInView) {
                self.cancelRecording()
            }
            return event
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    deinit {
        removeEventTap()
        removeClickOutsideMonitor()
        if isRecording {
            // View deallocated while recording (e.g. settings window closed) —
            // make sure the hotkey gets re-registered.
            DispatchQueue.main.async {
                let shortcut = HotkeyShortcut.load()
                AppDelegate.shared?.updateHotkey(shortcut: shortcut)
            }
        }
    }
}

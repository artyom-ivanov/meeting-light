import Cocoa
import Carbon.HIToolbox

class HotkeyManager {
    private let state: LightState
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var recordMonitor: Any?

    static weak var shared: HotkeyManager?

    init(state: LightState) {
        self.state = state
        Self.shared = self
    }

    func register() {
        installCarbonHandler()
        registerHotKey()
    }

    func reregister() {
        unregisterHotKey()
        registerHotKey()
    }

    // MARK: - Recording

    func startRecording() {
        state.isRecordingHotkey = true
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.captureRecordedKey(event)
            return nil
        }
    }

    private func captureRecordedKey(_ event: NSEvent) {
        let nsFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        var carbonMods: UInt32 = 0
        if nsFlags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if nsFlags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        if nsFlags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if nsFlags.contains(.control) { carbonMods |= UInt32(controlKey) }

        guard carbonMods != 0 else { return }

        state.hotkeyKeyCode = UInt32(event.keyCode)
        state.hotkeyModifiers = carbonMods
        stopRecording()
        reregister()
    }

    private func stopRecording() {
        state.isRecordingHotkey = false
        if let monitor = recordMonitor {
            NSEvent.removeMonitor(monitor)
            recordMonitor = nil
        }
    }

    // MARK: - Carbon Hot Key

    private func installCarbonHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                mgr.hotkeyFired()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }

    private func registerHotKey() {
        guard state.hotkeyKeyCode != .max else { return }

        let carbonMods = carbonModifierFlags(state.hotkeyModifiers)
        let hotKeyID = EventHotKeyID(signature: fourCharCode("MLht"), id: 1)

        RegisterEventHotKey(
            state.hotkeyKeyCode,
            carbonMods,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func unregisterHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func hotkeyFired() {
        DispatchQueue.main.async { [weak self] in
            self?.state.isEnabled.toggle()
        }
    }

    /// Convert our stored Carbon modifier mask to the Carbon API modifier format
    private func carbonModifierFlags(_ mods: UInt32) -> UInt32 {
        var result: UInt32 = 0
        if mods & UInt32(cmdKey) != 0 { result |= UInt32(cmdKey) }
        if mods & UInt32(shiftKey) != 0 { result |= UInt32(shiftKey) }
        if mods & UInt32(optionKey) != 0 { result |= UInt32(optionKey) }
        if mods & UInt32(controlKey) != 0 { result |= UInt32(controlKey) }
        return result
    }

    private func fourCharCode(_ string: String) -> OSType {
        var result: OSType = 0
        for char in string.utf8.prefix(4) {
            result = (result << 8) | OSType(char)
        }
        return result
    }

    deinit {
        stopRecording()
        unregisterHotKey()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}

import AppKit
import Carbon.HIToolbox
import os

/// Registers global hotkeys via Carbon and emits press/release events.
/// Two independent slots: the user's binding (start/stop, mode-aware in the
/// engine) and a cancel key (Escape) registered only while a dictation is in
/// flight. Only the exact bound combos are captured; no system-wide key
/// swallowing.
@MainActor
final class HotkeyService {
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    var onCancel: () -> Void = {}

    private static let signature = OSType(0x53504B45) // 'SPKE'
    private static let primaryID: UInt32 = 1
    private static let cancelID: UInt32 = 2

    private nonisolated(unsafe) var hotKeyRef: EventHotKeyRef?
    private nonisolated(unsafe) var cancelKeyRef: EventHotKeyRef?
    private nonisolated(unsafe) var eventHandler: EventHandlerRef?

    func update(binding: HotkeyBinding, enabled: Bool) {
        unregisterPrimary()
        guard enabled else { return }
        ensureEventHandler()
        let mods = Self.carbonModifiers(from: NSEvent.ModifierFlags(rawValue: binding.modifierFlags))
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.primaryID)
        let status = RegisterEventHotKey(
            UInt32(binding.keyCode),
            mods,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            Log.hotkey.error("RegisterEventHotKey failed: \(status, privacy: .public)")
        }
    }

    /// Capture Escape globally. Registered only for the duration of a dictation.
    func registerCancelKey() {
        guard cancelKeyRef == nil else { return }
        ensureEventHandler()
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.cancelID)
        let status = RegisterEventHotKey(
            UInt32(kVK_Escape),
            0,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &cancelKeyRef
        )
        if status != noErr {
            Log.hotkey.error("RegisterEventHotKey (cancel) failed: \(status, privacy: .public)")
        }
    }

    func unregisterCancelKey() {
        if let cancelKeyRef {
            UnregisterEventHotKey(cancelKeyRef)
            self.cancelKeyRef = nil
        }
    }

    private func ensureEventHandler() {
        guard eventHandler == nil else { return }
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyReleased))
        ]
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventCallback,
            2,
            &eventTypes,
            selfPtr,
            &eventHandler
        )
    }

    private func unregisterPrimary() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    fileprivate func handle(id: UInt32, pressed: Bool) {
        switch id {
        case Self.primaryID:
            if pressed { onPress() } else { onRelease() }
        case Self.cancelID:
            if pressed { onCancel() }
        default:
            break
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let cancelKeyRef { UnregisterEventHotKey(cancelKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }
}

/// C callback for Carbon hot-key events. Reads which registered key fired and
/// routes to the owning service on main.
private func hotkeyEventCallback(
    _ next: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData, let event else { return OSStatus(eventNotHandledErr) }
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
    let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
    let id = hotKeyID.id
    let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        service.handle(id: id, pressed: pressed)
    }
    return noErr
}

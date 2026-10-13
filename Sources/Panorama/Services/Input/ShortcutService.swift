import AppKit
import Carbon

@MainActor
final class ShortcutService {
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onActivate: (() -> Void)?
    private(set) var error: String?

    func register(key: UInt32, modifiers: UInt) {
        unregister()
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated { Unmanaged<ShortcutService>.fromOpaque(context).takeUnretainedValue().onActivate?() }
            return noErr
        }, 1, &type, context, &eventHandler)
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        let status = RegisterEventHotKey(key, carbon, EventHotKeyID(signature: 0x57535452, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        error = status == noErr ? nil : "This shortcut could not be registered. Choose another combination."
    }
    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKey = nil; eventHandler = nil
    }
}

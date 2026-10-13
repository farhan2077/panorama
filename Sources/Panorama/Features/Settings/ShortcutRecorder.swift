import AppKit
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    let preferences: Preferences
    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.bezelStyle = .rounded
        button.title = preferences.shortcutLabel
        button.onRecorded = { key, flags, label in
            preferences.shortcutModifiers = flags.rawValue
            preferences.shortcutKey = UInt32(key)
            preferences.shortcutLabel = label
        }
        return button
    }
    func updateNSView(_ view: RecorderButton, context: Context) { if !view.recording { view.title = preferences.shortcutLabel } }
}

final class RecorderButton: NSButton {
    var recording = false
    var onRecorded: ((UInt16, NSEvent.ModifierFlags, String) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        recording = true; title = "Type shortcut…"; window?.makeFirstResponder(self)
    }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { recording = false; title = "Click to record"; return }
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.intersection([.command, .option, .control]).isEmpty else { title = "Include ⌘, ⌥ or ⌃"; return }
        var label = ""
        if flags.contains(.control) { label += "⌃" }
        if flags.contains(.option) { label += "⌥" }
        if flags.contains(.shift) { label += "⇧" }
        if flags.contains(.command) { label += "⌘" }
        label += event.keyCode == 49 ? "Space" : event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        recording = false; title = label
        onRecorded?(event.keyCode, flags, label)
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording { keyDown(with: event); return true }
        return super.performKeyEquivalent(with: event)
    }
}

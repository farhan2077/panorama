import AppKit
import Observation
import SwiftUI

@MainActor @Observable
final class Preferences {
    enum PreviewMode: String, CaseIterable { case live = "Live", snapshot = "Snapshot" }
    enum NavigatorMode: String, CaseIterable { case previews = "Previews + icons", icons = "Icons only" }
    var isEnabled: Bool { didSet { save() } }
    var previewMode: PreviewMode { didSet { save() } }
    var navigatorMode: NavigatorMode { didSet { save() } }
    var naturalScrolling: Bool { didSet { save() } }
    var gentleSnapping: Bool { didSet { save() } }
    var fourFingerEnabled: Bool { didSet { save() } }
    var useSystemAccent: Bool { didSet { save() } }
    var customAccentHex: String { didSet { save() } }
    var previewFPS: Int { didSet { save() } }
    var shortcutKey: UInt32 { didSet { save() } }
    var shortcutModifiers: UInt { didSet { save() } }
    var shortcutLabel: String { didSet { save() } }
    var automaticUpdates: Bool { didSet { save() } }
    var dockReserve: Double { didSet { save() } }
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["enabled": true, "preview": "Live", "navigator": "Previews + icons", "natural": true,
            "snap": true, "fourFinger": true, "systemAccent": true, "accentHex": "007AFF", "fps": 30,
            "shortcutKey": 49, "shortcutModifiers": NSEvent.ModifierFlags([.control, .option]).rawValue,
            "shortcutLabel": "⌃⌥Space", "automaticUpdates": true, "dockReserve": 96.0])
        isEnabled = defaults.bool(forKey: "enabled")
        previewMode = PreviewMode(rawValue: defaults.string(forKey: "preview") ?? "") ?? .live
        navigatorMode = NavigatorMode(rawValue: defaults.string(forKey: "navigator") ?? "") ?? .previews
        naturalScrolling = defaults.bool(forKey: "natural")
        gentleSnapping = defaults.bool(forKey: "snap")
        fourFingerEnabled = defaults.bool(forKey: "fourFinger")
        useSystemAccent = defaults.bool(forKey: "systemAccent")
        customAccentHex = defaults.string(forKey: "accentHex") ?? "007AFF"
        previewFPS = defaults.integer(forKey: "fps")
        shortcutKey = UInt32(defaults.integer(forKey: "shortcutKey"))
        shortcutModifiers = UInt(defaults.integer(forKey: "shortcutModifiers"))
        shortcutLabel = defaults.string(forKey: "shortcutLabel") ?? "⌃⌥Space"
        automaticUpdates = defaults.bool(forKey: "automaticUpdates")
        dockReserve = defaults.double(forKey: "dockReserve")
    }
    var accentColor: NSColor {
        guard !useSystemAccent, let rgb = UInt32(customAccentHex, radix: 16) else { return .controlAccentColor }
        return NSColor(srgbRed: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255,
                       blue: Double(rgb & 255) / 255, alpha: 1)
    }
    var color: Color { Color(nsColor: accentColor) }
    private func save() {
        let values: [String: Any] = ["enabled": isEnabled, "preview": previewMode.rawValue, "navigator": navigatorMode.rawValue,
            "natural": naturalScrolling, "snap": gentleSnapping, "fourFinger": fourFingerEnabled, "systemAccent": useSystemAccent,
            "accentHex": customAccentHex, "fps": previewFPS, "shortcutKey": Int(shortcutKey), "shortcutModifiers": Int(shortcutModifiers),
            "shortcutLabel": shortcutLabel, "automaticUpdates": automaticUpdates, "dockReserve": dockReserve]
        for (key, value) in values { defaults.set(value, forKey: key) }
        onChange?()
    }
}

import AppKit
import Observation

@MainActor @Observable
final class PermissionService {
    var screenRecording = CGPreflightScreenCaptureAccess()
    var accessibility = AXIsProcessTrusted()
    func refresh() {
        screenRecording = CGPreflightScreenCaptureAccess()
        accessibility = AXIsProcessTrusted()
    }
    func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
        refresh()
        if !screenRecording { openPrivacy("Privacy_ScreenCapture") }
    }
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibility = AXIsProcessTrustedWithOptions(options)
    }
    private func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }
}

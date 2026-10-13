import AppKit
import ScreenCaptureKit

struct WindowRecord: Identifiable {
    let id: CGWindowID
    let ownerPID: pid_t
    let appName: String
    let title: String
    let frame: CGRect
    let icon: NSImage
    let source: SCWindow
    var aspectRatio: Double { Double(frame.width / max(1, frame.height)) }
    var label: String { title.isEmpty ? appName : "\(appName) — \(title)" }
}

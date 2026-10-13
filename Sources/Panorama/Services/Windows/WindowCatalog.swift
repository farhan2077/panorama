import AppKit
import ScreenCaptureKit

@MainActor
final class WindowCatalog {
    func windows(on screen: NSScreen) async throws -> [WindowRecord] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        let displayBounds = content.displays.first(where: { $0.displayID == displayID })?.frame ?? .zero
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let onScreen = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let order = onScreen.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return content.windows.compactMap { window -> WindowRecord? in
            guard window.windowLayer == 0, window.isOnScreen,
                  window.frame.width >= 80, window.frame.height >= 60,
                  let app = window.owningApplication, app.processID != ownPID,
                  rank[window.windowID] != nil,
                  window.frame.intersects(displayBounds),
                  let running = NSRunningApplication(processIdentifier: app.processID),
                  running.activationPolicy == .regular, !running.isHidden else { return nil }
            return WindowRecord(id: window.windowID, ownerPID: app.processID, appName: app.applicationName,
                title: window.title ?? "", frame: window.frame,
                icon: running.icon ?? NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)!, source: window)
        }.sorted { (rank[$0.id] ?? Int.max) < (rank[$1.id] ?? Int.max) }
    }
}

import AppKit
import OSLog

/// Accessibility calls have a bounded timeout and run off the UI thread.
final class WindowFocusService {
    private let queue = DispatchQueue(label: "app.panorama.window-focus", qos: .userInitiated)
    func focus(_ record: WindowRecord, completion: @escaping (Bool) -> Void) {
        queue.async {
            let app = AXUIElementCreateApplication(record.ownerPID)
            AXUIElementSetMessagingTimeout(app, 0.4)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement] else { DispatchQueue.main.async { completion(false) }; return }
            let matched = windows.first { Self.number($0) == record.id } ?? windows.first { element in
                var title: CFTypeRef?, position: CFTypeRef?, size: CFTypeRef?
                AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
                AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
                AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
                var p = CGPoint.zero, s = CGSize.zero
                if let position, CFGetTypeID(position) == AXValueGetTypeID() { AXValueGetValue(position as! AXValue, .cgPoint, &p) }
                if let size, CFGetTypeID(size) == AXValueGetTypeID() { AXValueGetValue(size as! AXValue, .cgSize, &s) }
                return (title as? String ?? "") == record.title && abs(p.x - record.frame.minX) < 3 && abs(p.y - record.frame.minY) < 3 && abs(s.width - record.frame.width) < 3
            }
            guard let target = matched else { DispatchQueue.main.async { completion(false) }; return }
            AXUIElementSetAttributeValue(target, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            let raised = AXUIElementPerformAction(target, kAXRaiseAction as CFString) == .success
            AXUIElementSetAttributeValue(target, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(app, kAXFocusedWindowAttribute as CFString, target)
            DispatchQueue.main.async {
                NSRunningApplication(processIdentifier: record.ownerPID)?.activate(options: [])
                completion(raised)
            }
        }
    }
    private static func number(_ element: AXUIElement) -> UInt32? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, "AXWindowNumber" as CFString, &value)
        return (value as? NSNumber)?.uint32Value
    }
}

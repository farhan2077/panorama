import AppKit

struct DockGeometry {
    /// visibleFrame excludes an shown Dock, but not an auto-hidden one. Reserve the greater of both.
    static func usableRect(on screen: NSScreen, minimumReserve: Double) -> CGRect {
        let full = screen.frame
        var safe = screen.visibleFrame
        let defaults = UserDefaults(suiteName: "com.apple.dock")
        let orientation = defaults?.string(forKey: "orientation") ?? "bottom"
        let tile = defaults?.double(forKey: "tilesize") ?? 64
        let magnified = defaults?.bool(forKey: "magnification") == true ? (defaults?.double(forKey: "largesize") ?? 96) : tile
        let reserve = max(minimumReserve, max(tile, magnified) + 24)
        switch orientation {
        case "left":
            let edge = max(safe.minX, full.minX + reserve)
            safe.size.width = max(1, safe.maxX - edge); safe.origin.x = edge
        case "right": safe.size.width = max(1, min(safe.maxX, full.maxX - reserve) - safe.minX)
        default:
            let edge = max(safe.minY, full.minY + reserve)
            safe.size.height = max(1, safe.maxY - edge); safe.origin.y = edge
        }
        return safe.insetBy(dx: 12, dy: 12).offsetBy(dx: -full.minX, dy: -full.minY)
    }
}

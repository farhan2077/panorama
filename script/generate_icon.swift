import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: 1024, height: 1024))
        image.lockFocus()
        let background = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 200, yRadius: 200)
        NSGradient(starting: NSColor(srgbRed: 0.23, green: 0.48, blue: 0.9, alpha: 1), ending: NSColor(srgbRed: 0.26, green: 0.27, blue: 0.7, alpha: 1))!.draw(in: background, angle: -60)
        for (x, width, alpha) in [(150.0, 160.0, 0.6), (342.0, 340.0, 1.0), (714.0, 160.0, 0.6)] {
            NSColor.white.withAlphaComponent(alpha).setStroke()
            let window = NSBezierPath(roundedRect: NSRect(x: x, y: 322, width: width, height: 390), xRadius: 24, yRadius: 24)
            window.lineWidth = 14; window.stroke()
            let line = NSBezierPath(); line.move(to: NSPoint(x: x + 4, y: 650)); line.line(to: NSPoint(x: x + width - 4, y: 650)); line.lineWidth = 10; line.stroke()
        }
        NSColor.white.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: NSRect(x: 368, y: 228, width: 288, height: 18), xRadius: 9, yRadius: 9).fill()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels)); NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}

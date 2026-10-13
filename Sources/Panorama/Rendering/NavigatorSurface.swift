import AppKit

/// Only the navigator receives a grouped material surface.
final class NavigatorSurface: NSView {
    let content = NSView()
    let viewport = CALayer()
    override var isFlipped: Bool { true }
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        if #available(macOS 26, *), !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
            let glass = NSGlassEffectView()
            glass.cornerRadius = 18
            glass.style = .regular
            glass.contentView = content
            glass.frame = bounds; glass.autoresizingMask = [.width, .height]
            addSubview(glass)
        } else {
            let material = NSVisualEffectView()
            material.material = .hudWindow
            material.blendingMode = .behindWindow
            material.state = .active
            material.wantsLayer = true; material.layer?.cornerRadius = 18; material.layer?.masksToBounds = true
            material.frame = bounds; material.autoresizingMask = [.width, .height]
            addSubview(material)
            content.frame = bounds; content.autoresizingMask = [.width, .height]; material.addSubview(content)
        }
        content.wantsLayer = true
        viewport.borderWidth = 1.5
        viewport.borderColor = NSColor.labelColor.withAlphaComponent(0.45).cgColor
        viewport.backgroundColor = NSColor.labelColor.withAlphaComponent(0.045).cgColor
        viewport.cornerRadius = 9
        content.layer?.addSublayer(viewport)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

import AppKit
import AVFoundation

/// Video stays in CoreMedia buffers; neither SwiftUI state nor NSImage is rebuilt per frame.
final class WindowPreviewView: NSView {
    private let surface = CALayer()
    private let video = AVSampleBufferDisplayLayer()
    private let still = CALayer()
    private let placeholder = CALayer()
    private let titleField = NSTextField(labelWithString: "")
    private let iconView = NSImageView()
    private let badge = NSTextField(labelWithString: "New")
    private let compact: Bool
    var selected = false { didSet { updateBorder() } }
    var accent: NSColor = .controlAccentColor { didSet { updateBorder() } }
    var hasContent = false
    override var isFlipped: Bool { true }

    init(record: WindowRecord, compact: Bool = false, iconsOnly: Bool = false) {
        self.compact = compact
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(surface)
        surface.cornerRadius = compact ? 5 : 10
        surface.masksToBounds = true
        surface.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.85).cgColor
        surface.addSublayer(still); surface.addSublayer(video); surface.addSublayer(placeholder)
        video.videoGravity = .resizeAspect
        still.contentsGravity = .resizeAspect
        placeholder.contents = record.icon
        placeholder.contentsGravity = .resizeAspect
        titleField.stringValue = compact ? record.appName : record.label
        titleField.font = .systemFont(ofSize: compact ? 10 : 12, weight: .medium)
        titleField.textColor = .labelColor
        titleField.lineBreakMode = .byTruncatingTail
        titleField.alignment = .center
        iconView.image = record.icon
        addSubview(titleField); addSubview(iconView)
        badge.font = .systemFont(ofSize: 9, weight: .semibold)
        badge.textColor = .controlAccentColor
        badge.isHidden = true; addSubview(badge)
        toolTip = record.label
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(record.label)
        if iconsOnly {
            surface.backgroundColor = NSColor.clear.cgColor
            video.isHidden = true; still.isHidden = true
            hasContent = true
        }
        self.iconsOnly = iconsOnly
    }
    private var iconsOnly = false
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        let footer: CGFloat = compact ? 18 : 26
        surface.frame = CGRect(x: 0, y: 0, width: bounds.width, height: max(1, bounds.height - footer))
        video.frame = surface.bounds; still.frame = surface.bounds
        let iconSize: CGFloat = iconsOnly ? 28 : compact ? 18 : 48
        placeholder.frame = CGRect(x: (surface.bounds.width - iconSize) / 2, y: (surface.bounds.height - iconSize) / 2, width: iconSize, height: iconSize)
        CATransaction.commit()
        let size: CGFloat = compact ? 12 : 16
        iconView.frame = CGRect(x: 2, y: bounds.height - footer + 4, width: size, height: size)
        iconView.isHidden = iconsOnly
        titleField.frame = CGRect(x: iconsOnly ? 0 : size + 6, y: bounds.height - footer + 3, width: max(0, bounds.width - (iconsOnly ? 0 : size + 8)), height: footer - 4)
        badge.frame = CGRect(x: max(0, bounds.width - 25), y: 0, width: 25, height: 14)
    }
    func show(_ sample: CMSampleBuffer) {
        guard !iconsOnly else { return }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true) as? [NSMutableDictionary], let attachment = attachments.first {
            attachment[kCMSampleAttachmentKey_DisplayImmediately] = true
        }
        let renderer = video.sampleBufferRenderer
        if renderer.status == .failed { renderer.flush() }
        guard renderer.isReadyForMoreMediaData else { return }
        renderer.enqueue(sample)
        video.isHidden = false; still.isHidden = true; placeholder.isHidden = true; hasContent = true
    }
    func show(_ image: CGImage) {
        guard !iconsOnly else { return }
        still.contents = image; still.isHidden = false
        video.isHidden = true; placeholder.isHidden = true; hasContent = true
    }
    func releaseVideo() { video.sampleBufferRenderer.flush(removingDisplayedImage: true, completionHandler: nil) }
    func markNew(_ value: Bool) { badge.isHidden = !value }
    private func updateBorder() {
        surface.borderWidth = selected ? (compact ? 2 : 3) : 0
        surface.borderColor = accent.cgColor
    }
}

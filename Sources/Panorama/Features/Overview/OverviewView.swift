import AppKit
import AVFoundation
import PanoramaCore

@MainActor
final class OverviewView: NSView {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    private let backdrop = NSVisualEffectView()
    private let navigator = NavigatorSurface()
    private let message = NSTextField(labelWithString: "")
    private var cards: [CGWindowID: WindowPreviewView] = [:]
    private var miniatures: [CGWindowID: WindowPreviewView] = [:]
    private var miniFrames: [CGRect] = []
    private var strip = StripLayout(items: [], viewport: .zero)
    private var records: [WindowRecord] = []
    private var newIDs = Set<CGWindowID>()
    private var selectedID: CGWindowID?
    private var offset = 0.0
    private var target = 0.0
    private var velocity = 0.0
    private var dragging = false
    private var displayLink: CADisplayLink?
    private var previousTimestamp = 0.0
    private var safeRect: CGRect = .zero
    private var stripOrigin: CGPoint = .zero
    private var pendingSnap: DispatchWorkItem?
    private var benchmarkStart: Double?
    let preferences: Preferences
    var onActivate: ((WindowRecord) -> Void)?
    var onDismiss: (() -> Void)?
    var onVisible: ((Set<CGWindowID>, Double) -> Void)?
    var onFrameTiming: ((Double) -> Void)?
    private var lastVisible = Set<CGWindowID>()
    private var tracking: NSTrackingArea?

    init(preferences: Preferences) {
        self.preferences = preferences
        super.init(frame: .zero)
        wantsLayer = true
        backdrop.material = .underWindowBackground
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        addSubview(backdrop)
        addSubview(navigator)
        message.font = .systemFont(ofSize: 15, weight: .medium)
        message.alignment = .center
        message.textColor = .secondaryLabelColor
        addSubview(message)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(screen: NSScreen) {
        frame = CGRect(origin: .zero, size: screen.frame.size)
        let available = DockGeometry.usableRect(on: screen, minimumReserve: preferences.dockReserve)
        safeRect = CGRect(x: available.minX, y: bounds.height - available.maxY, width: available.width, height: available.height)
        backdrop.frame = bounds
        message.frame = CGRect(x: safeRect.minX, y: safeRect.midY - 20, width: safeRect.width, height: 60)
        recomputeLayout()
    }
    func setMessage(_ text: String) { message.stringValue = text; message.isHidden = text.isEmpty }
    func setWindows(_ fresh: [WindowRecord], initialPID: pid_t? = nil) {
        let old = strip
        let anchorID = old.nearestIndex(to: offset).map { old.items[$0].id }
        let oldOffset = offset
        let oldIDs = Set(records.map(\.id))
        let freshMap = Dictionary(uniqueKeysWithValues: fresh.map { ($0.id, $0) })
        // Retain established order. Append new arrivals, avoiding rearrangement during a gesture.
        records = records.compactMap { freshMap[$0.id] } + fresh.filter { !oldIDs.contains($0.id) }
        if !oldIDs.isEmpty { newIDs.formUnion(Set(freshMap.keys).subtracting(oldIDs)) }
        for id in Array(cards.keys) where freshMap[id] == nil {
            cards.removeValue(forKey: id)?.removeFromSuperview()
            miniatures.removeValue(forKey: id)?.removeFromSuperview()
            newIDs.remove(id)
        }
        for record in records where cards[record.id] == nil {
            let card = WindowPreviewView(record: record)
            cards[record.id] = card; addSubview(card, positioned: .below, relativeTo: navigator)
            let miniature = WindowPreviewView(record: record, compact: true, iconsOnly: preferences.navigatorMode == .icons)
            miniatures[record.id] = miniature; navigator.content.addSubview(miniature)
        }
        if let selectedID, freshMap[selectedID] == nil { self.selectedID = nil }
        recomputeLayout()
        if let anchorID {
            offset = strip.anchoredOffset(from: old, offset: oldOffset, anchorID: anchorID); target = offset
        } else if let initialPID, let index = records.firstIndex(where: { $0.ownerPID == initialPID }) {
            offset = strip.offset(centering: index); target = offset
        }
        setMessage(records.isEmpty ? "No windows on this display and Space." : "")
        lastVisible.removeAll(); render()
    }
    private func recomputeLayout() {
        let navHeight: CGFloat = preferences.navigatorMode == .icons ? 72 : 100
        let stripHeight = max(120, safeRect.height - navHeight - 70)
        stripOrigin = CGPoint(x: safeRect.minX, y: safeRect.minY + 12)
        strip = StripLayout(items: records.map { .init(id: $0.id, aspectRatio: $0.aspectRatio) }, viewport: CGSize(width: safeRect.width, height: stripHeight))
        let preferredWidths = records.map { preferences.navigatorMode == .icons ? 44.0 : max(36, min(110, 54 * $0.aspectRatio)) }
        let total = preferredWidths.reduce(0, +) + Double(max(0, records.count - 1)) * 6 + 24
        let width = min(safeRect.width - 32, total)
        navigator.frame = CGRect(x: safeRect.midX - width / 2, y: safeRect.maxY - navHeight, width: max(40, width), height: navHeight)
        let scale = min(1, (width - 24) / max(1, total - 24))
        var x = 12.0
        miniFrames = preferredWidths.map { width in
            defer { x += (width + 6) * scale }
            return CGRect(x: x, y: 10, width: width * scale, height: navHeight - 20)
        }
        offset = strip.clamped(offset); target = strip.clamped(target)
    }
    private func render() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        let visible = Set(strip.visibleIndices(at: offset, overscan: 120).map { records[$0].id })
        for (index, record) in records.enumerated() {
            let rect = strip.frames[index].offsetBy(dx: stripOrigin.x - offset, dy: stripOrigin.y)
            cards[record.id]?.frame = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height + 26)
            cards[record.id]?.isHidden = !visible.contains(record.id)
            cards[record.id]?.accent = preferences.accentColor
            cards[record.id]?.selected = selectedID == record.id
            miniatures[record.id]?.frame = miniFrames[index]
            miniatures[record.id]?.accent = preferences.accentColor
            miniatures[record.id]?.selected = selectedID == record.id
            miniatures[record.id]?.markNew(newIDs.contains(record.id))
        }
        if !records.isEmpty {
            let left = navigatorX(for: offset), right = navigatorX(for: offset + strip.viewportWidth)
            navigator.viewport.frame = CGRect(x: left - 3, y: 5, width: max(8, right - left + 6), height: navigator.bounds.height - 10)
        }
        navigator.isHidden = records.isEmpty
        CATransaction.commit()
        if visible != lastVisible {
            for id in lastVisible.subtracting(visible) { cards[id]?.releaseVideo(); miniatures[id]?.releaseVideo() }
            lastVisible = visible; onVisible?(visible, Double(strip.frames.map(\.height).max() ?? 600))
        }
    }
    private func navigatorX(for contentX: Double) -> Double {
        guard !miniFrames.isEmpty else { return 0 }
        for i in strip.frames.indices {
            let frame = strip.frames[i], miniature = miniFrames[i]
            if contentX <= frame.maxX {
                if contentX < frame.minX && i > 0 {
                    let previous = strip.frames[i - 1], miniPrevious = miniFrames[i - 1]
                    let t = (contentX - previous.maxX) / max(1, frame.minX - previous.maxX)
                    return miniPrevious.maxX + (miniature.minX - miniPrevious.maxX) * max(0, t)
                }
                return miniature.minX + miniature.width * max(0, min(1, (contentX - frame.minX) / frame.width))
            }
        }
        return miniFrames.last!.maxX
    }
    func showFrame(_ buffer: CMSampleBuffer, id: CGWindowID) { cards[id]?.show(buffer); miniatures[id]?.show(buffer) }
    func showSnapshot(_ image: CGImage, id: CGWindowID) { cards[id]?.show(image); miniatures[id]?.show(image) }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(tracking!)
    }
    override func mouseMoved(with event: NSEvent) {
        guard !dragging, abs(target - offset) < 1 else { return }
        selectedID = hitID(convert(event.locationInWindow, from: nil)); render()
    }
    private func hitID(_ point: CGPoint) -> CGWindowID? {
        if navigator.frame.contains(point) {
            let local = CGPoint(x: point.x - navigator.frame.minX, y: point.y - navigator.frame.minY)
            return miniFrames.firstIndex(where: { $0.contains(local) }).map { records[$0].id }
        }
        return records.first(where: { cards[$0.id]?.frame.contains(point) == true })?.id
    }
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let id = hitID(point), let record = records.first(where: { $0.id == id }) {
            if navigator.frame.contains(point) {
                selectedID = id; newIDs.remove(id)
                if let index = records.firstIndex(where: { $0.id == id }) { animate(to: strip.offset(centering: index)) }
            } else { onActivate?(record) }
        }
    }
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onDismiss?()
        case 36, 76:
            let index = selectedID.flatMap { id in records.firstIndex(where: { $0.id == id }) } ?? strip.nearestIndex(to: offset)
            if let index { onActivate?(records[index]) }
        case 123, 124:
            guard !records.isEmpty else { return }
            let current = selectedID.flatMap { id in records.firstIndex(where: { $0.id == id }) } ?? strip.nearestIndex(to: offset) ?? 0
            let index = min(records.count - 1, max(0, current + (event.keyCode == 124 ? 1 : -1)))
            selectedID = records[index].id; newIDs.remove(records[index].id)
            animate(to: strip.offset(centering: index)); render()
        default: super.keyDown(with: event)
        }
    }
    override func scrollWheel(with event: NSEvent) {
        pendingSnap?.cancel()
        selectedID = nil
        let raw = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
        let natural = event.isDirectionInvertedFromDevice
        let delta = -raw * (natural == preferences.naturalScrolling ? 1 : -1) * (event.hasPreciseScrollingDeltas ? 1 : 28)
        offset = resisted(offset + delta); target = offset; velocity = 0
        render()
        if event.phase == .ended && event.momentumPhase == [] || event.momentumPhase == .ended || event.phase == [] {
            let work = DispatchWorkItem { [weak self] in self?.settle() }
            pendingSnap = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.14, execute: work)
        }
    }
    func gesture(_ event: FourFingerRecognizer.Event) {
        switch event {
        case .began: dragging = true; selectedID = nil; pendingSnap?.cancel(); displayLink?.isPaused = true
        case .changed(let delta):
            offset = resisted(offset - delta * safeRect.width * 2 * (preferences.naturalScrolling ? 1 : -1))
            target = offset; velocity = 0; render()
        case .ended: dragging = false; settle()
        }
    }
    private func resisted(_ proposed: Double) -> Double {
        let clamped = strip.clamped(proposed)
        return clamped + (proposed - clamped) * 0.22
    }
    private func settle() {
        guard !dragging else { return }
        let destination = preferences.gentleSnapping ? strip.nearestIndex(to: offset).map { strip.offset(centering: $0) } ?? 0 : strip.clamped(offset)
        animate(to: destination)
    }
    private func animate(to destination: Double) {
        target = strip.clamped(destination)
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { offset = target; render(); return }
        if displayLink == nil {
            displayLink = displayLink(target: self, selector: #selector(tick(_:)))
            displayLink?.add(to: .main, forMode: .common)
        }
        previousTimestamp = 0; displayLink?.isPaused = false
    }
    @objc private func tick(_ link: CADisplayLink) {
        let dt = previousTimestamp == 0 ? 1 / 60.0 : min(0.05, link.timestamp - previousTimestamp)
        if previousTimestamp != 0 { onFrameTiming?(link.timestamp - previousTimestamp) }
        previousTimestamp = link.timestamp
        if let start = benchmarkStart {
            let elapsed = CACurrentMediaTime() - start
            if elapsed < 10 { target = strip.maxOffset * (0.5 - 0.5 * cos(elapsed * .pi / 2.5)) }
            else { benchmarkStart = nil }
        }
        // Analytic critically damped spring: stable across varying refresh rates.
        let omega = 22.0, displacement = offset - target
        let c = velocity + omega * displacement, decay = exp(-omega * dt)
        offset = target + (displacement + c * dt) * decay
        velocity = (velocity - omega * c * dt) * decay
        render()
        if benchmarkStart == nil && abs(offset - target) < 0.1 && abs(velocity) < 1 {
            offset = target; velocity = 0; render(); link.isPaused = true
        }
    }
    func benchmark() { benchmarkStart = CACurrentMediaTime(); animate(to: strip.maxOffset) }
    func stop() {
        pendingSnap?.cancel(); displayLink?.invalidate(); displayLink = nil
        benchmarkStart = nil
        for card in cards.values { card.releaseVideo() }
        for card in miniatures.values { card.releaseVideo() }
    }
}

import AppKit
import PanoramaCore
import OSLog

private final class OverviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverviewController {
    private var panel: OverviewPanel?
    private var overview: OverviewView?
    private var screen: NSScreen?
    private var windows: [WindowRecord] = []
    private var refreshTask: Task<Void, Never>?
    private var benchmarkTask: Task<Void, Never>?
    private let catalog = WindowCatalog()
    private let capture = CaptureService()
    private let focus = WindowFocusService()
    private let preferences: Preferences
    private let performance: PerformanceService
    private var initialPID: pid_t?
    private var previousApplication: NSRunningApplication?
    private var session = UUID()
    private let logger = Logger(subsystem: "app.panorama", category: "Overview")
    var didClose: (() -> Void)?
    var isOpen: Bool { panel != nil }

    init(preferences: Preferences, performance: PerformanceService) {
        self.preferences = preferences; self.performance = performance
    }
    func open() {
        guard panel == nil else { panel?.makeKeyAndOrderFront(nil); return }
        performance.opening()
        previousApplication = NSWorkspace.shared.frontmostApplication
        initialPID = previousApplication?.processIdentifier
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        self.screen = screen
        let panel = OverviewPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.acceptsMouseMovedEvents = true
        let view = OverviewView(preferences: preferences)
        view.configure(screen: screen)
        view.setMessage("Loading your windows…")
        view.onActivate = { [weak self] record in self?.activate(record) }
        view.onDismiss = { [weak self] in self?.close(restoreFocus: true) }
        view.onFrameTiming = { [weak performance] in performance?.recordFrame($0) }
        view.onVisible = { [weak self] ids, height in
            guard let self else { return }
            self.capture.synchronize(windows: self.windows, ids: ids, live: self.preferences.previewMode == .live,
                                     fps: self.preferences.previewFPS, maxHeight: height)
        }
        capture.onFrame = { [weak view, weak performance] id, buffer in view?.showFrame(buffer, id: id); performance?.receivedCaptureFrame() }
        capture.onSnapshot = { [weak view, weak performance] id, image in view?.showSnapshot(image, id: id); performance?.receivedCaptureFrame() }
        capture.onError = { [weak self] _, _ in self?.logger.error("A preview is unavailable; keeping its window item accessible.") }
        panel.contentView = view
        self.panel = panel; overview = view
        panel.makeKeyAndOrderFront(nil); panel.makeFirstResponder(view)
        performance.presented()
        let token = UUID(); session = token
        refreshTask = Task { [weak self] in
            guard let self else { return }
            var first = true
            while !Task.isCancelled && self.session == token {
                do {
                    let discovered = try await self.catalog.windows(on: screen)
                    guard !Task.isCancelled && self.session == token else { return }
                    let changed = discovered.map(\.id).sorted() != self.windows.map(\.id).sorted()
                    self.windows = discovered
                    if changed || first {
                        view.setWindows(discovered, initialPID: first ? self.initialPID : nil)
                        self.capture.prepareThumbnails(windows: discovered)
                    }
                    first = false
                } catch {
                    if first { view.setMessage("Couldn’t load windows. Check Screen Recording permission in Settings.") }
                    self.logger.error("Catalog failed: \(error.localizedDescription, privacy: .public)")
                }
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
        logger.info("Overview opened")
    }
    func gesture(_ event: FourFingerRecognizer.Event) { overview?.gesture(event) }
    private func activate(_ record: WindowRecord) {
        close(restoreFocus: false)
        let began = CACurrentMediaTime()
        focus.focus(record) { [weak self] success in
            self?.performance.lastWindowActivationMilliseconds = (CACurrentMediaTime() - began) * 1000
            if !success { self?.logger.error("Could not focus requested window; it may have closed or Accessibility permission is unavailable.") }
        }
    }
    func close(restoreFocus: Bool) {
        guard panel != nil else { return }
        session = UUID(); refreshTask?.cancel(); refreshTask = nil; benchmarkTask?.cancel(); benchmarkTask = nil
        performance.finish(windowCount: windows.count, preferences: preferences, refreshRate: screen?.maximumFramesPerSecond ?? 60, cancelled: true)
        capture.stop(); overview?.stop(); panel?.orderOut(nil); panel?.close()
        panel = nil; overview = nil; windows.removeAll(); screen = nil
        if restoreFocus { previousApplication?.activate(options: []) }
        previousApplication = nil; didClose?()
        logger.info("Overview closed; capture stopped")
    }
    func runBenchmark() {
        if !isOpen { open() }
        benchmarkTask?.cancel()
        benchmarkTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, !Task.isCancelled, self.isOpen else { return }
            guard self.windows.count >= 2 else { self.performance.status = "Open at least two windows on this display to benchmark scrolling."; return }
            self.performance.begin(); self.overview?.benchmark()
            try? await Task.sleep(for: .seconds(10.5))
            guard !Task.isCancelled else { return }
            self.performance.finish(windowCount: self.windows.count, preferences: self.preferences, refreshRate: self.screen?.maximumFramesPerSecond ?? 60)
        }
    }
}

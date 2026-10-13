import AppKit
import Observation
import ServiceManagement
import SwiftUI

@MainActor @Observable
final class AppCoordinator {
    let preferences = Preferences()
    let permissions = PermissionService()
    let performance = PerformanceService()
    let updates = UpdateService()
    var inputStatus = ""
    var loginEnabled = SMAppService.mainApp.status == .enabled
    @ObservationIgnored private var statusItem: NSStatusItem?
    @ObservationIgnored private var settingsWindow: NSWindow?
    @ObservationIgnored private let shortcut = ShortcutService()
    @ObservationIgnored private let trackpad = TrackpadService()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var inputConfiguration = ""
    @ObservationIgnored lazy var overview = OverviewController(preferences: preferences, performance: performance)

    func start() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "Panorama")
        statusItem?.button?.toolTip = "Panorama"
        updateMenu()
        shortcut.onActivate = { [weak self] in self?.toggleOverview() }
        trackpad.onGesture = { [weak self] event in
            guard let self else { return }
            switch event {
            case .began:
                guard self.canOpen() else { return }
                self.overview.open(); self.overview.gesture(event)
            default: self.overview.gesture(event)
            }
        }
        overview.didClose = { [weak self] in self?.updates.overviewDidClose() }
        updates.overviewIsOpen = { [weak self] in self?.overview.isOpen ?? false }
        preferences.onChange = { [weak self] in self?.preferencesChanged() }
        configureInput()
        updates.start(automatic: preferences.automaticUpdates)
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.overview.close(restoreFocus: false); self?.trackpad.stop() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.inputConfiguration = ""; self?.configureInput() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.overview.close(restoreFocus: false) }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.overview.close(restoreFocus: false) }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.permissions.refresh() } })
        if !permissions.screenRecording || !permissions.accessibility { showSettings() }
    }
    private func preferencesChanged() {
        if overview.isOpen { overview.close(restoreFocus: true) }
        configureInput(); updateMenu(); updates.configure(automatic: preferences.automaticUpdates)
    }
    private func configureInput() {
        let key = "\(preferences.isEnabled)-\(preferences.fourFingerEnabled)-\(preferences.shortcutKey)-\(preferences.shortcutModifiers)"
        guard key != inputConfiguration else { return }
        inputConfiguration = key
        shortcut.unregister(); trackpad.stop()
        guard preferences.isEnabled else { inputStatus = "Panorama is disabled."; return }
        shortcut.register(key: preferences.shortcutKey, modifiers: preferences.shortcutModifiers)
        if preferences.fourFingerEnabled { trackpad.start() }
        inputStatus = shortcut.error ?? (preferences.fourFingerEnabled ? (trackpad.available ? "Shortcut and four-finger listener are ready." : "Trackpad input unavailable. The shortcut is ready.") : "Shortcut is ready.")
    }
    private func canOpen() -> Bool {
        permissions.refresh()
        guard preferences.isEnabled, permissions.screenRecording, permissions.accessibility else { showSettings(); return false }
        return true
    }
    func toggleOverview() {
        if overview.isOpen { overview.close(restoreFocus: true) }
        else if canOpen() { settingsWindow?.orderOut(nil); overview.open() }
    }
    func runBenchmark() { if canOpen() { settingsWindow?.orderOut(nil); overview.runBenchmark() } }
    func showSettings() {
        permissions.refresh()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 580), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Panorama Settings"; window.minSize = NSSize(width: 700, height: 500)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(app: self))
            window.center(); settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true); settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
        } catch { inputStatus = "Login item: \(error.localizedDescription)" }
    }
    private func updateMenu() {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: preferences.isEnabled ? "Disable Panorama" : "Enable Panorama", action: #selector(AppDelegate.toggleEnabled), keyEquivalent: "")
        menu.addItem(toggle)
        menu.addItem(NSMenuItem(title: "Open Overview", action: #selector(AppDelegate.openOverview), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(AppDelegate.openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit Panorama", action: #selector(AppDelegate.quit), keyEquivalent: "q"))
        for item in menu.items { item.target = NSApp.delegate }
        statusItem?.menu = menu
        statusItem?.button?.appearsDisabled = !preferences.isEnabled
    }
    func shutdown() { overview.close(restoreFocus: false); shortcut.unregister(); trackpad.stop() }
}

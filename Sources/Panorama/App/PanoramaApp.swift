import AppKit

@main
struct PanoramaApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()
    func applicationDidFinishLaunching(_ notification: Notification) { coordinator.start() }
    func applicationWillTerminate(_ notification: Notification) { coordinator.shutdown() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    @objc func toggleEnabled() { coordinator.preferences.isEnabled.toggle() }
    @objc func openOverview() { coordinator.toggleOverview() }
    @objc func openSettings() { coordinator.showSettings() }
    @objc func quit() { NSApp.terminate(nil) }
}

import AppKit
import Observation
import Sparkle

@MainActor @Observable
final class UpdateService: NSObject, SPUUpdaterDelegate {
    var status = "Updates are not configured in this development build."
    var isConfigured = false
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private var pendingInstall: (() -> Void)?
    @ObservationIgnored var overviewIsOpen: () -> Bool = { false }

    func start(automatic: Bool) {
        guard controller == nil else { configure(automatic: automatic); return }
        guard let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed), url.scheme == "https",
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String, !key.isEmpty else { return }
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        guard let updater = controller?.updater else { return }
        do {
            try updater.start()
            isConfigured = true; status = "Checks at startup and every three hours."
            configure(automatic: automatic)
            if automatic { updater.checkForUpdatesInBackground() }
        } catch { status = error.localizedDescription }
    }
    func configure(automatic: Bool) {
        guard let updater = controller?.updater else { return }
        updater.automaticallyChecksForUpdates = automatic
        updater.automaticallyDownloadsUpdates = automatic
        updater.updateCheckInterval = 3 * 60 * 60
    }
    func checkNow() { controller?.checkForUpdates(nil) }
    func overviewDidClose() {
        guard let install = pendingInstall else { return }
        pendingInstall = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { install() }
    }
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        if overviewIsOpen() { pendingInstall = immediateInstallHandler; status = "Update ready. Installation will begin when the overview closes." }
        else { DispatchQueue.main.async { immediateInstallHandler() } }
        return true
    }
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) { status = "Downloading Panorama \(item.displayVersionString)…" }
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) { status = "You’re up to date." }
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) { status = "Update check: \(error.localizedDescription)" }
}

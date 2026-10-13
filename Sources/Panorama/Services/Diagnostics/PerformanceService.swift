import AppKit
import Observation
import OSLog
import PanoramaCore

struct PerformanceReport: Codable {
    struct ResourceSample: Codable {
        let seconds: Double
        let residentMB: Double
        let cpuPercent: Double
    }
    let schemaVersion: Int
    let appVersion: String
    let date: Date
    let osVersion: String
    let windowCount: Int
    let previewMode: String
    let configuredCaptureFPS: Int
    let displayRefreshHz: Int
    let activationMilliseconds: Double?
    let firstPreviewMilliseconds: Double?
    let lastWindowActivationMilliseconds: Double?
    let averageAnimationFPS: Double
    let p95FrameMilliseconds: Double
    let estimatedMissedFrames: Int
    let samples: [ResourceSample]
    let captureFrameCount: Int
    let durationSeconds: Double
    let notes: String
}

@MainActor @Observable
final class PerformanceService {
    var isBenchmarking = false
    var status = "Run a 10-second scroll benchmark with your current windows."
    var latestReport: URL?
    var firstPreviewMilliseconds: Double?
    var activationMilliseconds: Double?
    var lastWindowActivationMilliseconds: Double?
    private var frameStats = FrameStatistics()
    private var samples: [PerformanceReport.ResourceSample] = []
    private var timer: Timer?
    private var activationStart = 0.0
    private var benchmarkStart = 0.0
    private var lastCPU = 0.0
    private var lastSample = 0.0
    private var captureFrames = 0
    private var captureFirstSeen = false
    private let signposter = OSSignposter(subsystem: "app.panorama", category: "Performance")
    private var signpostState: OSSignpostIntervalState?
    var peakMemoryMB: Double { samples.map(\.residentMB).max() ?? 0 }

    func opening() {
        activationStart = CACurrentMediaTime(); captureFirstSeen = false
        firstPreviewMilliseconds = nil; activationMilliseconds = nil
        signpostState = signposter.beginInterval("OpenOverview")
    }
    func presented() {
        activationMilliseconds = (CACurrentMediaTime() - activationStart) * 1000
        if let signpostState { signposter.endInterval("OpenOverview", signpostState) }
        signpostState = nil
    }
    func receivedCaptureFrame() {
        if !captureFirstSeen {
            captureFirstSeen = true
            firstPreviewMilliseconds = (CACurrentMediaTime() - activationStart) * 1000
        }
        if isBenchmarking { captureFrames += 1 }
    }
    func recordFrame(_ interval: Double) { if isBenchmarking { frameStats.record(interval) } }
    func begin() {
        guard !isBenchmarking else { return }
        isBenchmarking = true; status = "Benchmark running…"; frameStats = FrameStatistics(); samples = []; captureFrames = 0
        benchmarkStart = CACurrentMediaTime(); lastSample = benchmarkStart; lastCPU = Self.cpuTime()
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }
    func finish(windowCount: Int, preferences: Preferences, refreshRate: Int, cancelled: Bool = false) {
        guard isBenchmarking else { return }
        sample(); timer?.invalidate(); timer = nil; isBenchmarking = false
        let report = PerformanceReport(schemaVersion: 1, appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "development",
            date: Date(), osVersion: ProcessInfo.processInfo.operatingSystemVersionString, windowCount: windowCount,
            previewMode: preferences.previewMode.rawValue, configuredCaptureFPS: preferences.previewFPS, displayRefreshHz: refreshRate,
            activationMilliseconds: activationMilliseconds, firstPreviewMilliseconds: firstPreviewMilliseconds, lastWindowActivationMilliseconds: lastWindowActivationMilliseconds,
            averageAnimationFPS: frameStats.averageFPS, p95FrameMilliseconds: frameStats.p95Milliseconds,
            estimatedMissedFrames: frameStats.missedFrames(expectedInterval: 1 / Double(max(1, refreshRate))), samples: samples,
            captureFrameCount: captureFrames, durationSeconds: CACurrentMediaTime() - benchmarkStart,
            notes: "\(cancelled ? "Cancelled early. " : "")Display-link callback timing estimates animation cadence, not GPU presentation. CPU percent is relative to one core. Memory is this process only; use Instruments for WindowServer/GPU impact. Capture frame count aggregates active streams. No window titles or content are recorded.")
        do {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Panorama/Benchmarks")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("benchmark-\(Int(Date().timeIntervalSince1970)).json")
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(report).write(to: url, options: .atomic)
            latestReport = url
            status = String(format: "%@%.1f FPS · p95 %.1f ms · peak %.1f MB", cancelled ? "Partial: " : "", frameStats.averageFPS, frameStats.p95Milliseconds, peakMemoryMB)
        } catch { status = "Could not save report: \(error.localizedDescription)" }
    }
    private func sample() {
        let now = CACurrentMediaTime(), cpu = Self.cpuTime()
        let percent = max(0, (cpu - lastCPU) / max(0.001, now - lastSample) * 100)
        samples.append(.init(seconds: now - benchmarkStart, residentMB: Self.residentMB(), cpuPercent: percent))
        lastCPU = cpu; lastSample = now
    }
    private static func cpuTime() -> Double {
        var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }
    private static func residentMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count) }
        }
        return result == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : 0
    }
}

import AppKit
import AVFoundation
import ScreenCaptureKit
import OSLog

/// Each stream retains at most one pending frame between the capture queue and main thread.
private final class StreamOutput: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var latest: CMSampleBuffer?
    private var scheduled = false
    var deliver: ((CMSampleBuffer) -> Void)?
    var failed: ((Error) -> Void)?
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int, status == SCFrameStatus.complete.rawValue else { return }
        lock.lock(); latest = sampleBuffer
        let shouldSchedule = !scheduled; scheduled = true; lock.unlock()
        guard shouldSchedule else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock(); let buffer = self.latest; self.latest = nil; self.scheduled = false; self.lock.unlock()
            if let buffer { self.deliver?(buffer) }
        }
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.failed?(error) }
    }
}

@MainActor
final class CaptureService {
    private struct Session { let stream: SCStream; let output: StreamOutput }
    private var sessions: [CGWindowID: Session] = [:]
    private var starting: Set<CGWindowID> = []
    private var desired: Set<CGWindowID> = []
    private var snapshots: Set<CGWindowID> = []
    private var generation = 0
    private var thumbnailIDs: Set<CGWindowID> = []
    private let queue = DispatchQueue(label: "app.panorama.capture", qos: .userInteractive)
    private let logger = Logger(subsystem: "app.panorama", category: "Capture")
    var onFrame: ((CGWindowID, CMSampleBuffer) -> Void)?
    var onSnapshot: ((CGWindowID, CGImage) -> Void)?
    var onError: ((CGWindowID, String) -> Void)?
    var count: Int { sessions.count }

    func synchronize(windows: [WindowRecord], ids: Set<CGWindowID>, live: Bool, fps: Int, maxHeight: Double) {
        desired = ids
        for id in Array(sessions.keys) where !ids.contains(id) {
            if let session = sessions.removeValue(forKey: id) { Task { try? await session.stream.stopCapture() } }
        }
        for record in windows where ids.contains(record.id) && sessions[record.id] == nil && !starting.contains(record.id) {
            if !live && snapshots.contains(record.id) { continue }
            starting.insert(record.id)
            let token = generation
            Task { [weak self] in
                guard let self else { return }
                let filter = SCContentFilter(desktopIndependentWindow: record.source)
                let config = SCStreamConfiguration()
                let height = min(1200, max(240, maxHeight * 1.5))
                config.width = Int(min(2400, height * record.aspectRatio))
                config.height = Int(height)
                config.scalesToFit = true
                config.showsCursor = false
                config.capturesAudio = false
                config.queueDepth = 3
                config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(max(5, min(60, fps))))
                do {
                    if live {
                        let output = StreamOutput()
                        output.deliver = { [weak self] buffer in
                            guard let self, token == self.generation, self.desired.contains(record.id) else { return }
                            self.onFrame?(record.id, buffer)
                        }
                        output.failed = { [weak self] error in
                            guard let self, token == self.generation else { return }
                            self.sessions.removeValue(forKey: record.id)
                            self.onError?(record.id, error.localizedDescription)
                        }
                        let stream = SCStream(filter: filter, configuration: config, delegate: output)
                        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: self.queue)
                        try await stream.startCapture()
                        if token == self.generation && self.desired.contains(record.id) { self.sessions[record.id] = Session(stream: stream, output: output) }
                        else { try? await stream.stopCapture() }
                    } else {
                        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                        if token == self.generation && self.desired.contains(record.id) {
                            self.snapshots.insert(record.id); self.onSnapshot?(record.id, image)
                        }
                    }
                } catch {
                    if token == self.generation { self.onError?(record.id, error.localizedDescription) }
                    self.logger.error("Capture failed: \(error.localizedDescription, privacy: .public)")
                }
                if token == self.generation { self.starting.remove(record.id) }
            }
        }
    }
    func prepareThumbnails(windows: [WindowRecord]) {
        let token = generation
        let missing = windows.filter { !thumbnailIDs.contains($0.id) }
        thumbnailIDs.formUnion(missing.map(\.id))
        Task { [weak self] in
            guard let self else { return }
            for record in missing {
                guard token == self.generation else { return }
                // Visible live windows receive their thumbnail from the same stream.
                if self.desired.contains(record.id) { continue }
                let config = SCStreamConfiguration()
                config.width = max(32, Int(100 * record.aspectRatio)); config.height = 100
                config.showsCursor = false
                do {
                    let image = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: record.source), configuration: config)
                    if token == self.generation { self.onSnapshot?(record.id, image) }
                } catch { /* Icon remains usable when a thumbnail is unavailable. */ }
            }
        }
    }
    func stop() {
        generation += 1; thumbnailIDs.removeAll(); desired.removeAll(); starting.removeAll(); snapshots.removeAll()
        let old = sessions.values; sessions.removeAll()
        for session in old { Task { try? await session.stream.stopCapture() } }
    }
}

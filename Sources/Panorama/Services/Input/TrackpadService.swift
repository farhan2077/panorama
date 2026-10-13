import Foundation
import TrackpadBridge
import PanoramaCore

@MainActor
final class TrackpadService {
    private static weak var current: TrackpadService?
    private var recognizer = FourFingerRecognizer()
    private(set) var available = false
    var onGesture: ((FourFingerRecognizer.Event) -> Void)?
    func start() {
        stop(); Self.current = self
        available = WSStartTrackpad { count, x, y in
            DispatchQueue.main.async {
                guard let service = TrackpadService.current else { return }
                for event in service.recognizer.update(count: Int(count), x: x, y: y) { service.onGesture?(event) }
            }
        }
    }
    func stop() {
        WSStopTrackpad(); Self.current = nil; recognizer = FourFingerRecognizer(); available = false
    }
}

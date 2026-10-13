import CoreGraphics
import Foundation

public struct FourFingerRecognizer: Sendable {
    public enum Event: Equatable, Sendable { case began, changed(Double), ended }
    private var origin: CGPoint?
    private var lastX: Double = 0
    private var active = false
    public init() {}
    public mutating func update(count: Int, x: Double, y: Double) -> [Event] {
        guard count == 4, x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) else {
            let result: [Event] = active ? [.ended] : []
            origin = nil; active = false
            return result
        }
        let point = CGPoint(x: x, y: y)
        guard let origin else { self.origin = point; lastX = x; return [] }
        let dx = x - origin.x, dy = y - origin.y
        if !active {
            guard abs(dx) > 0.035, abs(dx) > abs(dy) * 1.4 else { return [] }
            active = true; lastX = x
            return [.began, .changed(dx)]
        }
        let delta = x - lastX; lastX = x
        return [.changed(delta)]
    }
}

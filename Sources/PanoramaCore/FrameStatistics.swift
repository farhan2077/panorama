import Foundation

public struct FrameStatistics: Sendable, Codable {
    public private(set) var intervals: [Double] = []
    public init() {}
    public mutating func record(_ seconds: Double) {
        guard seconds > 0, seconds < 1 else { return }
        if intervals.count >= 3600 { intervals.removeFirst(600) }
        intervals.append(seconds)
    }
    public var p95Milliseconds: Double {
        guard !intervals.isEmpty else { return 0 }
        let values = intervals.sorted()
        return values[min(values.count - 1, Int(Double(values.count - 1) * 0.95))] * 1000
    }
    public var averageFPS: Double { intervals.isEmpty ? 0 : Double(intervals.count) / intervals.reduce(0, +) }
    public func missedFrames(expectedInterval: Double) -> Int {
        guard expectedInterval > 0 else { return 0 }
        return intervals.reduce(0) { $0 + max(0, Int(($1 / expectedInterval).rounded()) - 1) }
    }
}

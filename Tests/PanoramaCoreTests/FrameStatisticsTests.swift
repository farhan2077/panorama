import XCTest
@testable import PanoramaCore

final class FrameStatisticsTests: XCTestCase {
    func testSteadyFramesAndHitchAreMeasured() {
        var stats = FrameStatistics()
        for _ in 0..<100 { stats.record(1 / 60) }
        XCTAssertEqual(stats.averageFPS, 60, accuracy: 0.01)
        XCTAssertEqual(stats.p95Milliseconds, 1000 / 60, accuracy: 0.01)
        XCTAssertEqual(stats.missedFrames(expectedInterval: 1 / 60), 0)
        stats.record(3 / 60)
        XCTAssertEqual(stats.missedFrames(expectedInterval: 1 / 60), 2)
    }
    func testSamplingStorageIsBounded() {
        var stats = FrameStatistics()
        for _ in 0..<10_000 { stats.record(1 / 120) }
        XCTAssertLessThanOrEqual(stats.intervals.count, 3600)
        XCTAssertEqual(stats.averageFPS, 120, accuracy: 0.01)
    }
}

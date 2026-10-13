import CoreGraphics
import XCTest
@testable import PanoramaCore

final class StripLayoutTests: XCTestCase {
    func testPreservesAspectRatiosAndCentersEndpoints() {
        let layout = StripLayout(items: [.init(id: 1, aspectRatio: 0.5), .init(id: 2, aspectRatio: 1.6), .init(id: 3, aspectRatio: 3)], viewport: CGSize(width: 1000, height: 650))
        for (item, frame) in zip(layout.items, layout.frames) {
            XCTAssertEqual(frame.width / frame.height, item.aspectRatio, accuracy: 0.0001)
            XCTAssertLessThanOrEqual(frame.height, 650)
            XCTAssertLessThanOrEqual(frame.width, 820)
        }
        XCTAssertEqual(layout.offset(centering: 0), 0, accuracy: 0.001)
        XCTAssertEqual(layout.offset(centering: 2), layout.maxOffset, accuracy: 0.001)
        XCTAssertEqual(layout.nearestIndex(to: layout.maxOffset), 2)
    }
    func testInsertionPreservesAnchorScreenPosition() {
        let items: [StripLayout.Item] = (1...4).map { .init(id: UInt32($0), aspectRatio: 1.2) }
        let old = StripLayout(items: items, viewport: CGSize(width: 1200, height: 650))
        let offset = old.offset(centering: 2)
        let new = StripLayout(items: [.init(id: 5, aspectRatio: 2)] + items, viewport: CGSize(width: 1200, height: 650))
        let anchored = new.anchoredOffset(from: old, offset: offset, anchorID: 3)
        XCTAssertEqual(old.frames[2].midX - offset, new.frames[3].midX - anchored, accuracy: 0.001)
    }
    func testAppendingDoesNotMoveViewport() {
        let items = [StripLayout.Item(id: 1, aspectRatio: 1), .init(id: 2, aspectRatio: 2)]
        let old = StripLayout(items: items, viewport: CGSize(width: 1000, height: 700))
        let new = StripLayout(items: items + [.init(id: 3, aspectRatio: 1.4)], viewport: CGSize(width: 1000, height: 700))
        let offset = old.offset(centering: 1)
        XCTAssertEqual(new.anchoredOffset(from: old, offset: offset, anchorID: 2), offset, accuracy: 0.001)
    }
    func testEmptyAndInvalidGeometryRemainFinite() {
        let empty = StripLayout(items: [], viewport: .zero)
        XCTAssertNil(empty.nearestIndex(to: 0))
        XCTAssertEqual(empty.visibleIndices(at: 0), [])
        XCTAssertEqual(empty.clamped(-500), 0)
        let item = StripLayout.Item(id: 1, aspectRatio: .nan)
        let single = StripLayout(items: [item], viewport: CGSize(width: 1000, height: 500))
        XCTAssertTrue(single.frames[0].width.isFinite)
        XCTAssertEqual(single.maxOffset, 0)
    }
}

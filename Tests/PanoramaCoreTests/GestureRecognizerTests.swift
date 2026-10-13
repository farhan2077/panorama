import XCTest
@testable import PanoramaCore

final class GestureRecognizerTests: XCTestCase {
    func testFourFingerHorizontalDragHasOneBeginningAndEnd() {
        var recognizer = FourFingerRecognizer()
        XCTAssertEqual(recognizer.update(count: 4, x: 0.5, y: 0.5), [])
        XCTAssertEqual(recognizer.update(count: 4, x: 0.51, y: 0.5), [])
        let beginning = recognizer.update(count: 4, x: 0.56, y: 0.5)
        XCTAssertEqual(beginning.first, .began)
        XCTAssertEqual(beginning.count, 2)
        let movement = recognizer.update(count: 4, x: 0.6, y: 0.5)
        XCTAssertEqual(movement.count, 1)
        XCTAssertEqual(recognizer.update(count: 0, x: 0, y: 0), [.ended])
        XCTAssertEqual(recognizer.update(count: 0, x: 0, y: 0), [])
    }
    func testRejectsVerticalAndWrongFingerGestures() {
        var recognizer = FourFingerRecognizer()
        XCTAssertEqual(recognizer.update(count: 3, x: 0.5, y: 0.5), [])
        XCTAssertEqual(recognizer.update(count: 3, x: 0.8, y: 0.5), [])
        XCTAssertEqual(recognizer.update(count: 4, x: 0.5, y: 0.5), [])
        XCTAssertEqual(recognizer.update(count: 4, x: 0.51, y: 0.7), [])
        XCTAssertEqual(recognizer.update(count: 0, x: 0, y: 0), [])
    }
    func testInvalidCoordinatesCancelActiveGesture() {
        var recognizer = FourFingerRecognizer()
        _ = recognizer.update(count: 4, x: 0.5, y: 0.5)
        _ = recognizer.update(count: 4, x: 0.6, y: 0.5)
        XCTAssertEqual(recognizer.update(count: 4, x: .nan, y: 0.5), [.ended])
    }
}

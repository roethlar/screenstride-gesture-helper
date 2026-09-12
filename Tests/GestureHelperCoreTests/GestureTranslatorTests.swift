import XCTest
@testable import GestureHelperCore

final class GestureTranslatorTests: XCTestCase {
    func testVerticalBeginMatchesCapturedTrackpadConvention() {
        for direction in [-1.0, 1.0] {
            var translator = GestureTranslator()
            XCTAssertTrue(translator.receive(.init(axis: 2, phase: 1, progress: 0), now: 0).isEmpty)
            let begin = translator.receive(.init(axis: 2, phase: 2, progress: direction * 0.012664794921875), now: 0.01)
            XCTAssertEqual(begin.count, 1)
            XCTAssertEqual(begin.first?.phase, 1)
            XCTAssertEqual(begin.first?.progress, -direction * 0.012664794921875)
            XCTAssertEqual(begin.first?.directionFlags, 1)
            XCTAssertEqual(begin.first?.flavor, 3)
        }
    }
    func testHoldHeartbeatAllowsLongPauseThenReversal() {
        var translator = GestureTranslator()
        _ = translator.receive(.init(axis: 1, phase: 1, progress: 0), now: 0)
        _ = translator.receive(.init(axis: 1, phase: 2, progress: 0.5), now: 0.1)
        for tick in 1...40 {
            let now = Double(tick) * 0.25
            XCTAssertTrue(translator.receive(.init(axis: 1, phase: 2, progress: 0.5), now: now).isEmpty)
            XCTAssertTrue(translator.expire(now: now + 0.2).isEmpty)
            XCTAssertTrue(translator.active)
        }
        let reversed = translator.receive(.init(axis: 1, phase: 2, progress: 0.2), now: 10.1)
        XCTAssertEqual(reversed.first?.progress, 0.2)
        XCTAssertEqual(translator.cancel().first?.phase, 8)
        XCTAssertTrue(translator.cancel().isEmpty)
    }
    func testLostConnectionCancelsOnceAndRejectsOrphanMovement() {
        var translator = GestureTranslator()
        _ = translator.receive(.init(axis: 1, phase: 1, progress: 0), now: 0)
        _ = translator.receive(.init(axis: 1, phase: 2, progress: -0.4), now: 1)
        XCTAssertTrue(translator.expire(now: 2.9).isEmpty)
        let expired = translator.expire(now: 3.1)
        XCTAssertEqual(expired.first?.phase, 8)
        XCTAssertEqual(expired.first?.progress, -0.4)
        XCTAssertFalse(translator.active)
        XCTAssertTrue(translator.expire(now: 10).isEmpty)
        XCTAssertTrue(translator.receive(.init(axis: 1, phase: 2, progress: -0.7), now: 11).isEmpty)
    }
    func testInvalidInputAndReplacementReleasePreviousGesture() {
        var translator = GestureTranslator()
        _ = translator.receive(.init(axis: 1, phase: 1, progress: 0), now: 0)
        let replacement = translator.receive(.init(axis: 1, phase: 1, progress: 0), now: 1)
        XCTAssertEqual(replacement.map(\.phase), [8, 1])
        XCTAssertEqual(translator.receive(.init(axis: 1, phase: 2, progress: .nan), now: 2).first?.phase, 8)
        XCTAssertFalse(translator.active)
        XCTAssertTrue(translator.receive(.init(axis: 8, phase: 1, progress: 0), now: 3).isEmpty)
    }
    func testUnmovedVerticalGestureEndsWithoutPosting() {
        var translator = GestureTranslator()
        _ = translator.receive(.init(axis: 2, phase: 1, progress: 0), now: 0)
        XCTAssertTrue(translator.receive(.init(axis: 2, phase: 4, progress: 0), now: 1).isEmpty)
        XCTAssertFalse(translator.active)
    }
}

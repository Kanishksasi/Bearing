import XCTest
@testable import Bearing

final class SignalFilterTests: XCTestCase {
    private func raw(_ x: Double, _ y: Double, confidence: Double = 0.9) -> [Joint: JointPoint] {
        [.leftShoulder: JointPoint(x: x, y: y, confidence: confidence)]
    }

    private func run(_ filter: inout SignalFilter, _ points: [Joint: JointPoint], t: Double = 0) -> PoseFrame {
        filter.process(raw: points, timestamp: t, imageWidth: 720, imageHeight: 1280)
    }

    func testFirstSampleIsPassedThrough() {
        var filter = SignalFilter()
        let frame = run(&filter, raw(100, 100))
        XCTAssertEqual(frame.joints[.leftShoulder]?.x, 100)
    }

    func testEMAUsesAlphaPointFour() throws {
        var filter = SignalFilter()
        _ = run(&filter, raw(100, 100))
        let frame = run(&filter, raw(200, 300))
        let p = try XCTUnwrap(frame.joints[.leftShoulder])
        XCTAssertEqual(p.x, 0.4 * 200 + 0.6 * 100, accuracy: 0.0001)
        XCTAssertEqual(p.y, 0.4 * 300 + 0.6 * 100, accuracy: 0.0001)
    }

    func testDroppedJointIsHeldForTwoFramesThenRemoved() {
        var filter = SignalFilter()
        _ = run(&filter, raw(100, 100))
        XCTAssertEqual(run(&filter, [:]).joints[.leftShoulder]?.x, 100, "held on frame 1")
        XCTAssertEqual(run(&filter, [:]).joints[.leftShoulder]?.x, 100, "held on frame 2")
        XCTAssertNil(run(&filter, [:]).joints[.leftShoulder], "invalid on frame 3")
    }

    func testReturnAfterHoldRestartsFromRawValue() {
        var filter = SignalFilter()
        _ = run(&filter, raw(100, 100))
        for _ in 0..<3 { _ = run(&filter, [:]) }
        XCTAssertEqual(run(&filter, raw(500, 500)).joints[.leftShoulder]?.x, 500)
    }

    func testShoulderThresholdIsPointThree() {
        var filter = SignalFilter()
        XCTAssertNil(run(&filter, raw(100, 100, confidence: 0.29)).joints[.leftShoulder])
        XCTAssertNotNil(run(&filter, raw(100, 100, confidence: 0.30)).joints[.leftShoulder])
    }

    func testElbowThresholdIsPointFive() {
        var filter = SignalFilter()
        let low = [Joint.leftElbow: JointPoint(x: 1, y: 1, confidence: 0.49)]
        let ok = [Joint.leftElbow: JointPoint(x: 1, y: 1, confidence: 0.5)]
        XCTAssertNil(run(&filter, low).joints[.leftElbow])
        XCTAssertNotNil(run(&filter, ok).joints[.leftElbow])
    }
}

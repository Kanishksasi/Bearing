import XCTest
@testable import Bearing

final class ArmRaiseEngineTests: XCTestCase {
    /// Runs 30 frames with the arm at `offset` and returns the outcome.
    private func run(offset: (Double, Double),
                     hipShiftX: Double = 0,
                     tilt: Double = 0,
                     dropElbowEvery: Int? = nil,
                     side: Side = .left) -> TrialOutcome {
        let engine = ArmRaiseEngine(side: side)
        engine.start()
        for i in 0..<30 {
            let drop = dropElbowEvery.map { i % $0 == 0 } ?? false
            engine.ingest(Synthetic.armFrame(elbowOffset: offset,
                                             hipShiftX: hipShiftX,
                                             includeElbow: !drop,
                                             t: Double(i) * 0.1,
                                             tilt: tilt))
        }
        return engine.finish()
    }

    private func peak(_ outcome: TrialOutcome) -> Double? {
        if case .accepted(.armRaise(_, let degrees)) = outcome { return degrees }
        return nil
    }

    func testArmAtSideIsZeroDegrees() throws {
        XCTAssertEqual(try XCTUnwrap(peak(run(offset: (0, -200)))), 0, accuracy: 0.001)
    }

    func testArmAtFortyFiveDegrees() throws {
        XCTAssertEqual(try XCTUnwrap(peak(run(offset: (200, -200)))), 45, accuracy: 0.001)
    }

    func testArmAtShoulderHeightIsNinetyDegrees() throws {
        XCTAssertEqual(try XCTUnwrap(peak(run(offset: (200, 0)))), 90, accuracy: 0.001)
    }

    func testArmAboveShoulderIsOneThirtyFive() throws {
        XCTAssertEqual(try XCTUnwrap(peak(run(offset: (200, 200)))), 135, accuracy: 0.001)
    }

    func testPeakIsTheLargestAngleSeen() throws {
        let engine = ArmRaiseEngine(side: .left)
        engine.start()
        let offsets: [(Double, Double)] = [(0, -200), (200, -200), (200, 0), (200, -200), (0, -200)]
        for (i, o) in offsets.enumerated() {
            engine.ingest(Synthetic.armFrame(elbowOffset: o, t: Double(i) * 0.1))
        }
        guard case .accepted(.armRaise(_, let degrees)) = engine.finish() else { return XCTFail("expected accept") }
        XCTAssertEqual(degrees, 90, accuracy: 0.001)
    }

    func testLeaningTrunkIsRejected() {
        // Hips 150 px to the side of 300 px of height: about 26.6 degrees of lean, over the 15 degree limit.
        XCTAssertEqual(run(offset: (200, 0), hipShiftX: 150), .rejected(.trunkLean))
    }

    func testSmallLeanIsAccepted() {
        // atan(30 / 300) is about 5.7 degrees.
        XCTAssertNotNil(peak(run(offset: (200, 0), hipShiftX: 30)))
    }

    func testTiltOverFiveDegreesIsRejected() {
        XCTAssertEqual(run(offset: (200, 0), tilt: 5.1), .rejected(.tilt))
    }

    func testTiltAtFiveDegreesIsAccepted() {
        XCTAssertNotNil(peak(run(offset: (200, 0), tilt: 5.0)))
    }

    func testTooManyMissingFramesIsRejected() {
        // The elbow is missing for 1 frame in 2. The filter is not involved here, so each gap is a real gap.
        XCTAssertEqual(run(offset: (200, 0), dropElbowEvery: 2), .rejected(.lowConfidence))
    }

    func testEightyPercentValidFramesIsAccepted() {
        // Every fifth frame is missing, so exactly 80 percent are valid.
        XCTAssertNotNil(peak(run(offset: (200, 0), dropElbowEvery: 5)))
    }

    func testCutOffBodyIsReportedAsOutOfFrame() {
        let engine = ArmRaiseEngine(side: .left)
        engine.start()
        for i in 0..<20 {
            var frame = Synthetic.armFrame(elbowOffset: (200, 0), includeElbow: i % 2 == 0, t: Double(i) * 0.1)
            // The wrist is stuck on the image edge in the frames where the elbow is lost.
            frame.joints[.leftWrist] = JointPoint(x: 3, y: 600, confidence: 0.9)
            engine.ingest(frame)
        }
        XCTAssertEqual(engine.finish(), .rejected(.outOfFrame))
    }

    func testSummaryReportsBestAndAverage() throws {
        let summary = ArmRaiseSummary(leftAttempts: [80, 90, 100], rightAttempts: [60])
        XCTAssertEqual(summary.left, ArmRaiseSummary.SideResult(best: 100, average: 90))
        XCTAssertEqual(summary.right, ArmRaiseSummary.SideResult(best: 60, average: 60))
        XCTAssertNil(ArmRaiseSummary(leftAttempts: [], rightAttempts: [1]).left)
    }
}

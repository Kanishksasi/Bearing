import XCTest
@testable import Bearing

final class BalanceEngineTests: XCTestCase {
    // Leg length is 500 px (hip at y 600, planted ankle at y 100). 0.2 of that is 100 px.
    private let planted = 100.0
    private let liftedY = 200.0

    private func result(_ outcome: TrialOutcome) -> (foot: Side, hold: Double, sway: Double)? {
        if case .accepted(.balance(let foot, let hold, let sway)) = outcome { return (foot, hold, sway) }
        return nil
    }

    /// Runs frames at 10 per second while `ankleY(t)` says where the right ankle is.
    private func run(seconds: Double, hipSway: Double = 0, rightAnkleY: (Double) -> Double) -> (TrialOutcome, BalanceEngine) {
        let engine = BalanceEngine()
        engine.start()
        var i = 0
        while Double(i) * 0.1 <= seconds + 0.0001 {
            let t = Double(i) * 0.1
            let jitter = i % 2 == 0 ? hipSway : -hipSway
            engine.ingest(Synthetic.standingFrame(rightAnkleY: rightAnkleY(t), hipJitter: jitter, t: t))
            if engine.isComplete { break }
            i += 1
        }
        return (engine.finish(), engine)
    }

    func testHigherAnkleIsTheLiftedFoot() throws {
        let (outcome, _) = run(seconds: 3) { _ in self.liftedY }
        XCTAssertEqual(try XCTUnwrap(result(outcome)).foot, .right)
    }

    func testLeftFootLiftIsFoundToo() throws {
        let engine = BalanceEngine()
        engine.start()
        for i in 0..<30 {
            // Left ankle lifted by 100 px, right ankle planted at 100 px.
            let frame = Synthetic.frame([
                .leftShoulder: (250, 950), .rightShoulder: (350, 950),
                .leftHip: (260, 600), .rightHip: (340, 600),
                .leftAnkle: (260, 200), .rightAnkle: (340, 100)
            ], t: Double(i) * 0.1)
            engine.ingest(frame)
        }
        XCTAssertEqual(try XCTUnwrap(result(engine.finish())).foot, .left)
    }

    func testHoldIsCappedAtTenSecondsAndEngineCompletes() throws {
        let (outcome, engine) = run(seconds: 20) { _ in self.liftedY }
        XCTAssertTrue(engine.isComplete)
        XCTAssertEqual(try XCTUnwrap(result(outcome)).hold, 10, accuracy: 0.0001)
    }

    func testHoldEndsWhenFootComesDown() throws {
        let (outcome, engine) = run(seconds: 8) { t in t < 3.0 ? self.liftedY : self.planted }
        XCTAssertTrue(engine.isComplete)
        XCTAssertEqual(try XCTUnwrap(result(outcome)).hold, 3.0, accuracy: 0.0001)
    }

    func testSwayIsStandardDeviationOfHipXOverShoulderWidth() throws {
        // Hip center x swings 5 px either side. Shoulders are 100 px apart. 5 / 100 is 0.05.
        let (outcome, _) = run(seconds: 10, hipSway: 5) { _ in self.liftedY }
        XCTAssertEqual(try XCTUnwrap(result(outcome)).sway, 0.05, accuracy: 0.001)
    }

    func testStillBodyHasZeroSway() throws {
        let (outcome, _) = run(seconds: 5) { _ in self.liftedY }
        XCTAssertEqual(try XCTUnwrap(result(outcome)).sway, 0, accuracy: 0.0001)
    }

    func testSmallAnkleDifferenceIsNotALift() {
        // 40 px of 500 is 0.08, under the 0.12 start line.
        let (outcome, _) = run(seconds: 5) { _ in 140 }
        XCTAssertNil(result(outcome))
    }

    func testFootThatNeverLiftsEndsAfterTheWaitLimit() {
        let (_, engine) = run(seconds: 16) { _ in self.planted }
        XCTAssertTrue(engine.isComplete)
    }

    func testTiltDuringHoldIsRejected() {
        let engine = BalanceEngine()
        engine.start()
        for i in 0..<30 {
            engine.ingest(Synthetic.standingFrame(rightAnkleY: liftedY, t: Double(i) * 0.1, tilt: i == 10 ? 6 : 0))
        }
        XCTAssertEqual(engine.finish(), .rejected(.tilt))
    }
}

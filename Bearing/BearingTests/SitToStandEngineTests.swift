import XCTest
@testable import Bearing

final class SitToStandEngineTests: XCTestCase {
    private let seatedY = 400.0
    // 300 px torso, so 0.35 torso lengths is 105 px and 0.15 is 45 px.
    private func standingY(rise: Double) -> Double { seatedY + rise * 300 }

    /// Feeds one hip height per tenth of a second.
    private func run(_ hipHeights: [Double]) -> (TrialOutcome, SitToStandEngine) {
        let engine = SitToStandEngine()
        engine.start()
        for (i, y) in hipHeights.enumerated() {
            engine.ingest(Synthetic.sitFrame(hipY: y, t: Double(i) * 0.1))
        }
        return (engine.finish(), engine)
    }

    private func count(_ outcome: TrialOutcome) -> Int? {
        if case .accepted(.sitToStand(let n)) = outcome { return n }
        return nil
    }

    private func seated(_ frames: Int) -> [Double] { Array(repeating: seatedY, count: frames) }
    private func standing(_ frames: Int, rise: Double = 0.4) -> [Double] {
        Array(repeating: standingY(rise: rise), count: frames)
    }

    func testThreeFullStandsAreCountedAsThree() {
        let cycle = seated(20) + standing(20)
        let (outcome, _) = run(seated(10) + cycle + cycle + cycle + seated(10))
        XCTAssertEqual(count(outcome), 3)
    }

    func testNoMovementCountsZero() {
        XCTAssertEqual(count(run(seated(100)).0), 0)
    }

    func testSmallRiseBelowStandThresholdIsNotCounted() {
        XCTAssertEqual(count(run(seated(15) + standing(20, rise: 0.30) + seated(10)).0), 0)
    }

    func testWobbleBetweenThresholdsCountsOnlyOnce() {
        // Stand up, then drift between 0.36 and 0.20 torso lengths. The drop line is 0.15, so it stays one stand.
        var heights = seated(15) + standing(10, rise: 0.4)
        for i in 0..<30 { heights.append(standingY(rise: i % 2 == 0 ? 0.36 : 0.20)) }
        XCTAssertEqual(count(run(heights).0), 1)
    }

    func testHipHeightIsNormalizedByTorsoLength() {
        // Same movement filmed from twice as far away: torso 150 px, hips rise 0.4 * 150 = 60 px.
        let engine = SitToStandEngine()
        engine.start()
        func small(_ hipY: Double, _ t: Double) -> PoseFrame {
            Synthetic.frame([.leftShoulder: (300, hipY + 150), .rightShoulder: (420, hipY + 150),
                             .leftHip: (300, hipY), .rightHip: (420, hipY)], t: t)
        }
        var t = 0.0
        for _ in 0..<15 { engine.ingest(small(200, t)); t += 0.1 }
        for _ in 0..<15 { engine.ingest(small(260, t)); t += 0.1 }
        XCTAssertEqual(count(engine.finish()), 1)
    }

    func testCompletesAfterThirtySeconds() {
        let engine = SitToStandEngine()
        engine.start()
        engine.ingest(Synthetic.sitFrame(hipY: seatedY, t: 0))
        XCTAssertFalse(engine.isComplete)
        engine.ingest(Synthetic.sitFrame(hipY: seatedY, t: 29.9))
        XCTAssertFalse(engine.isComplete)
        engine.ingest(Synthetic.sitFrame(hipY: seatedY, t: 30.0))
        XCTAssertTrue(engine.isComplete)
    }

    func testLostTrackingIsRejected() {
        let engine = SitToStandEngine()
        engine.start()
        for i in 0..<40 {
            engine.ingest(i % 2 == 0 ? Synthetic.sitFrame(hipY: seatedY, t: Double(i) * 0.1)
                                     : Synthetic.frame([:], t: Double(i) * 0.1))
        }
        XCTAssertEqual(engine.finish(), .rejected(.lowConfidence))
    }

    func testTooFewFramesToFindSeatedHeightIsRejected() {
        XCTAssertEqual(run(seated(5)).0, .rejected(.lowConfidence))
    }
}

import XCTest
@testable import Bearing

final class AlignmentCheckerTests: XCTestCase {
    private let checker = AlignmentChecker()

    func testWellPlacedBodyCanStart() {
        let status = checker.check(Synthetic.standingFrame(), for: .balance)
        XCTAssertTrue(status.canStart)
        XCTAssertEqual(status.hint, "Ready. Tap Start.")
    }

    func testTiltOverFiveDegreesBlocksStart() {
        let status = checker.check(Synthetic.standingFrame(tilt: 5.1), for: .balance)
        XCTAssertFalse(status.tiltWithinLimit)
        XCTAssertFalse(status.canStart)
    }

    func testTiltOfExactlyFiveDegreesIsAllowed() {
        XCTAssertTrue(checker.check(Synthetic.standingFrame(tilt: 5.0), for: .balance).canStart)
    }

    func testMissingJointBlocksStart() {
        var frame = Synthetic.standingFrame()
        frame.joints[.leftAnkle] = nil
        let status = checker.check(frame, for: .balance)
        XCTAssertFalse(status.jointsInFrame)
        XCTAssertFalse(status.canStart)
    }

    func testJointOnImageEdgeCountsAsOutOfFrame() {
        var frame = Synthetic.standingFrame()
        frame.joints[.leftAnkle] = JointPoint(x: 260, y: 5, confidence: 0.9)
        XCTAssertFalse(checker.check(frame, for: .balance).jointsInFrame)
    }

    func testUnlevelShouldersBlockStart() {
        var frame = Synthetic.standingFrame()
        // 20 px over 100 px is about 11 degrees.
        frame.joints[.rightShoulder] = JointPoint(x: 350, y: 970, confidence: 0.9)
        let status = checker.check(frame, for: .balance)
        XCTAssertFalse(status.shouldersLevel)
        XCTAssertFalse(status.canStart)
    }

    func testLevelShouldersPassWhenLeftShoulderIsOnTheImageRight() {
        // On an unmirrored front camera the person's left shoulder appears on the right of the image.
        var frame = Synthetic.standingFrame()
        frame.joints[.leftShoulder] = JointPoint(x: 350, y: 950, confidence: 0.9)
        frame.joints[.rightShoulder] = JointPoint(x: 250, y: 950, confidence: 0.9)
        XCTAssertTrue(checker.check(frame, for: .balance).shouldersLevel)
    }

    func testBodyTooSmallIsTooFarAway() {
        let small = Synthetic.frame([
            .leftShoulder: (330, 700), .rightShoulder: (390, 700),
            .leftHip: (335, 550), .rightHip: (385, 550),
            .leftAnkle: (335, 300), .rightAnkle: (385, 300)
        ])
        let status = checker.check(small, for: .balance)
        XCTAssertFalse(status.distanceRight)
        XCTAssertFalse(status.canStart)
    }

    func testBodyTooTallIsTooClose() {
        let big = Synthetic.frame([
            .leftShoulder: (250, 1250), .rightShoulder: (350, 1250),
            .leftHip: (260, 700), .rightHip: (340, 700),
            .leftAnkle: (260, 40), .rightAnkle: (340, 40)
        ])
        XCTAssertFalse(checker.check(big, for: .balance).distanceRight)
    }

    func testEachRoutineHasItsOwnRequiredJoints() {
        XCTAssertTrue(Exercise.balance.requiredJoints.contains(.leftAnkle))
        XCTAssertFalse(Exercise.sitToStand.requiredJoints.contains(.leftAnkle))
        XCTAssertTrue(Exercise.armRaise.requiredJoints.contains(.rightElbow))
    }

    func testSafetyMessageIsRequiredForSitToStandAndBalanceOnly() {
        XCTAssertTrue(Exercise.sitToStand.needsSafetyMessage)
        XCTAssertTrue(Exercise.balance.needsSafetyMessage)
        XCTAssertFalse(Exercise.armRaise.needsSafetyMessage)
    }

    func testSafetyMessageCoversSupportReachAndStopRules() {
        let text = SafetyText.message.lowercased()
        XCTAssertTrue(text.contains("stable support"))
        XCTAssertTrue(text.contains("arm's reach"))
        XCTAssertTrue(text.contains("dizzy"))
        XCTAssertTrue(text.contains("pain"))
        XCTAssertTrue(text.contains("unsteady"))
    }
}

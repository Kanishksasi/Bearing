import XCTest
import AVFoundation
@testable import Bearing

final class CaregiverTests: XCTestCase {
    func testHoldToStartNeedsOneSecond() {
        XCTAssertEqual(HoldToStartButton.holdSeconds, 1.0)
    }

    func testHoldButtonIsAtLeastFortyFourPointsAcross() {
        XCTAssertGreaterThanOrEqual(HoldToStartButton.diameter, 44)
    }

    @MainActor
    func testCaregiverModeUsesTheRearCameraAndDoesNotMirror() {
        let caregiver = TrialViewModel(exercise: .armRaise, caregiverMode: true, spokenPrompts: false)
        XCTAssertTrue(caregiver.caregiverMode)
        XCTAssertFalse(caregiver.mirrorPreview)
        XCTAssertEqual(caregiver.camera.position, .back)

        let normal = TrialViewModel(exercise: .armRaise, caregiverMode: false, spokenPrompts: false)
        XCTAssertFalse(normal.caregiverMode)
        XCTAssertTrue(normal.mirrorPreview)
        XCTAssertEqual(normal.camera.position, .front)
    }

    @MainActor
    func testStartIsBlockedUntilAlignedEvenInCaregiverMode() {
        let model = TrialViewModel(exercise: .armRaise, caregiverMode: true, spokenPrompts: false)
        model.startTrial()
        XCTAssertNotEqual(model.phase, .running)
    }
}

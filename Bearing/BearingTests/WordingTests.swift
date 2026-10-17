import XCTest
@testable import Bearing

/// Checks the words people read in the app against the banned list.
final class WordingTests: XCTestCase {
    private let banned = ["diagnose", "diagnosis", "detect", "assess", "evaluate", "treat",
                          "clinical", "screening", "patient", "normal", "abnormal", "good", "poor", "pass", "fail"]

    private func bannedWords(in text: String) -> [String] {
        let words = text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        return banned.filter { banned in words.contains { $0.hasPrefix(banned) } }
    }

    private var allUserText: [String] {
        var text: [String] = [SafetyText.message, IntroText.title, IntroText.button] + IntroText.lines
        text += Exercise.allCases.map(\.title)
        text += [RejectReason.tilt, .lowConfidence, .outOfFrame, .trunkLean, .noLift].map(\.message)
        let statuses = [
            AlignmentStatus(jointsInFrame: true, shouldersLevel: true, distanceRight: true, tiltWithinLimit: false),
            AlignmentStatus(jointsInFrame: false, shouldersLevel: true, distanceRight: true, tiltWithinLimit: true),
            AlignmentStatus(jointsInFrame: true, shouldersLevel: true, distanceRight: false, tiltWithinLimit: true),
            AlignmentStatus(jointsInFrame: true, shouldersLevel: false, distanceRight: true, tiltWithinLimit: true),
            AlignmentStatus(jointsInFrame: true, shouldersLevel: true, distanceRight: true, tiltWithinLimit: true)
        ]
        text += statuses.map(\.hint)
        for (baseline, current) in [(80.0, 95.0), (95.0, 80.0), (80.0, 80.0)] {
            text.append(MetricComparison(label: "x", unit: "degrees", baseline: baseline, current: current).text)
        }
        let session = Session(exercise: .armRaise, acceptedTrials: 1, rejectedTrials: 0)
        session.leftBest = 1; session.leftAverage = 1; session.rightBest = 1; session.rightAverage = 1
        text += session.metrics.map(\.label)
        let sit = Session(exercise: .sitToStand, acceptedTrials: 1, rejectedTrials: 0)
        sit.standCount = 1
        text += sit.metrics.map(\.label)
        let balance = Session(exercise: .balance, acceptedTrials: 1, rejectedTrials: 0)
        balance.holdSeconds = 1; balance.swayRatio = 1
        text += balance.metrics.flatMap { [$0.label, $0.unit] }
        return text
    }

    func testNoBannedWordsInAppText() {
        for text in allUserText {
            XCTAssertEqual(bannedWords(in: text), [], "Banned word in: \(text)")
        }
    }

    func testBannedWordCheckCatchesWordsAndStaysQuietOtherwise() {
        XCTAssertEqual(bannedWords(in: "A good result"), ["good"])
        XCTAssertEqual(bannedWords(in: "Share with your clinician"), [])
    }

    func testIntroHasThreeShortLinesAboutWhatItDoesPrivacyAndTracking() {
        XCTAssertEqual(IntroText.lines.count, 3)
        for line in IntroText.lines {
            XCTAssertLessThanOrEqual(line.split(separator: " ").count, 12, "Too long for a quick read: \(line)")
        }
        XCTAssertTrue(IntroText.lines[1].contains("never leaves this phone"))
        XCTAssertTrue(IntroText.lines[1].contains("never saved"))
        XCTAssertTrue(IntroText.lines[2].contains("personal tracking only"))
        XCTAssertEqual(IntroText.button, "Get started")
    }
}

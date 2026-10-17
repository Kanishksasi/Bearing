import XCTest
@testable import Bearing

final class BaselineServiceTests: XCTestCase {
    /// Arm raise session whose "Left arm best" is `best`. Other metrics follow it.
    private func arm(daysAgo: Double, best: Double) -> Session {
        let s = Session(date: Date(timeIntervalSinceNow: -daysAgo * 86_400),
                        exercise: .armRaise, acceptedTrials: 6, rejectedTrials: 0)
        s.leftBest = best
        s.leftAverage = best - 10
        s.rightBest = best + 5
        s.rightAverage = best - 5
        return s
    }

    private func change(_ session: Session, _ history: [Session], _ label: String = "Left arm best") -> MetricComparison? {
        BaselineService.compare(session, with: history).first { $0.label == label }
    }

    // MARK: Median

    func testMedianOfOddAndEvenCounts() {
        XCTAssertEqual(BaselineService.median([90, 80, 100]), 90)
        XCTAssertEqual(BaselineService.median([80, 100]), 90)
        XCTAssertEqual(BaselineService.median([70]), 70)
        XCTAssertNil(BaselineService.median([]))
    }

    // MARK: 1, 2, 3, and 5 sessions

    func testOneSessionIsItsOwnStartingPointAndComparesWithNothing() {
        let only = arm(daysAgo: 0, best: 80)
        XCTAssertTrue(BaselineService.isInBaselineSet(only, in: [only]))
        XCTAssertTrue(BaselineService.compare(only, with: [only]).isEmpty)
        XCTAssertEqual(BaselineService.baselineValues(for: .armRaise, in: [only])["Left arm best"], 80)
    }

    func testTwoSessionsUseTheMedianOfBothAndBothCompareWithNothing() {
        let a = arm(daysAgo: 5, best: 80)
        let b = arm(daysAgo: 0, best: 100)
        let history = [a, b]
        XCTAssertEqual(BaselineService.baselineValues(for: .armRaise, in: history)["Left arm best"], 90)
        XCTAssertTrue(BaselineService.compare(a, with: history).isEmpty)
        XCTAssertTrue(BaselineService.compare(b, with: history).isEmpty)
    }

    func testThreeSessionsUseTheMiddleValueAndAllThreeCompareWithNothing() {
        let a = arm(daysAgo: 6, best: 70)
        let b = arm(daysAgo: 3, best: 100)
        let c = arm(daysAgo: 0, best: 90)
        let history = [a, b, c]
        XCTAssertEqual(BaselineService.baselineValues(for: .armRaise, in: history)["Left arm best"], 90)
        for session in history { XCTAssertTrue(BaselineService.compare(session, with: history).isEmpty) }
    }

    func testFiveSessionsComparesOnlyTheLastTwoWithTheMedianOfTheFirstThree() throws {
        let s1 = arm(daysAgo: 10, best: 80)
        let s2 = arm(daysAgo: 9, best: 90)
        let s3 = arm(daysAgo: 8, best: 100)
        let s4 = arm(daysAgo: 2, best: 95)
        let s5 = arm(daysAgo: 1, best: 85)
        let history = [s1, s2, s3, s4, s5]

        for session in [s1, s2, s3] { XCTAssertTrue(BaselineService.compare(session, with: history).isEmpty) }

        let up = try XCTUnwrap(change(s4, history))
        XCTAssertEqual(up.baseline, 90)
        XCTAssertEqual(up.difference, 5, accuracy: 0.0001)
        XCTAssertEqual(up.text, "Up 5.0 from your starting point")

        let down = try XCTUnwrap(change(s5, history))
        XCTAssertEqual(down.difference, -5, accuracy: 0.0001)
        XCTAssertEqual(down.text, "Down 5.0 from your starting point")
    }

    func testLaterSessionsNeverChangeTheStartingPoint() {
        let first = (0..<3).map { arm(daysAgo: 10 - Double($0), best: 80 + Double($0) * 10) }
        let later = arm(daysAgo: 0, best: 500)
        XCTAssertEqual(BaselineService.baselineValues(for: .armRaise, in: first + [later])["Left arm best"], 90)
    }

    // MARK: Out of order dates

    func testHistoryInTheWrongOrderStillUsesTheThreeEarliestDates() throws {
        // The earliest session is listed last and the newest is listed first.
        let newest = arm(daysAgo: 1, best: 200)
        let fourth = arm(daysAgo: 4, best: 150)
        let third = arm(daysAgo: 7, best: 100)
        let second = arm(daysAgo: 8, best: 90)
        let earliest = arm(daysAgo: 9, best: 80)
        let history = [newest, fourth, third, second, earliest]

        XCTAssertEqual(BaselineService.baselineSet(for: .armRaise, in: history).map { $0.leftBest },
                       [80, 90, 100])
        XCTAssertTrue(BaselineService.isInBaselineSet(earliest, in: history))
        XCTAssertFalse(BaselineService.isInBaselineSet(fourth, in: history))
        XCTAssertEqual(try XCTUnwrap(change(newest, history)).baseline, 90)
        XCTAssertEqual(try XCTUnwrap(change(fourth, history)).baseline, 90)
    }

    // MARK: Per routine and per metric

    func testEachRoutineHasItsOwnStartingPoint() throws {
        func sit(_ daysAgo: Double, _ stands: Int) -> Session {
            let s = Session(date: Date(timeIntervalSinceNow: -daysAgo * 86_400),
                            exercise: .sitToStand, acceptedTrials: 1, rejectedTrials: 0)
            s.standCount = stands
            return s
        }
        let armSessions = (0..<3).map { arm(daysAgo: 20 - Double($0), best: 80) }
        let sits = [sit(10, 8), sit(9, 10), sit(8, 12), sit(1, 15)]
        let history = armSessions + sits
        let change = try XCTUnwrap(BaselineService.compare(sits[3], with: history).first)
        XCTAssertEqual(change.baseline, 10)
        XCTAssertEqual(change.text, "Up 5 from your starting point")
    }

    func testMetricMissingFromOneBaselineSessionUsesTheOthers() {
        let a = arm(daysAgo: 6, best: 80)
        let b = arm(daysAgo: 5, best: 100)
        let c = arm(daysAgo: 4, best: 60)
        c.rightBest = nil
        c.rightAverage = nil
        // Right arm best was 85 and 105 in the two sessions that have it, so the median is 95.
        let values = BaselineService.baselineValues(for: .armRaise, in: [a, b, c])
        XCTAssertEqual(values["Right arm best"], 95)
        XCTAssertEqual(values["Left arm best"], 80)
    }

    func testNoDifferenceIsSaidPlainly() {
        XCTAssertEqual(MetricComparison(label: "x", unit: "degrees", baseline: 80, current: 80).text,
                       "Same as your starting point")
    }

    func testOldWordingIsGone() {
        let texts = [MetricComparison(label: "x", unit: "degrees", baseline: 1, current: 2).text,
                     MetricComparison(label: "x", unit: "degrees", baseline: 2, current: 1).text]
        for text in texts { XCTAssertFalse(text.contains("first session")) }
    }
}

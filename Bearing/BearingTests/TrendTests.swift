import XCTest
import Accessibility
@testable import Bearing

final class TrendTests: XCTestCase {
    private func arm(daysAgo: Double, best: Double) -> Session {
        let s = Session(date: Date(timeIntervalSinceNow: -daysAgo * 86_400),
                        exercise: .armRaise, acceptedTrials: 6, rejectedTrials: 0)
        s.leftBest = best
        s.leftAverage = best - 10
        return s
    }

    private func sessions(_ values: [Double]) -> [Session] {
        values.enumerated().map { arm(daysAgo: Double(values.count - $0.offset), best: $0.element) }
    }

    private func trend(_ label: String, in trends: [MetricTrend]) throws -> MetricTrend {
        try XCTUnwrap(trends.first { $0.label == label })
    }

    func testOnlyTheLastTenSessionsAreKeptInOrder() throws {
        let all = sessions((1...12).map { Double($0) * 10 })
        let t = try trend("Left arm best", in: TrendService.trends(for: .armRaise, in: all, last: 10))
        XCTAssertEqual(t.values, [30, 40, 50, 60, 70, 80, 90, 100, 110, 120])
    }

    func testStartingPointComesFromTheFirstThreeSessionsNotTheTrimmedList() throws {
        let all = sessions((1...12).map { Double($0) * 10 })
        let t = try trend("Left arm best", in: TrendService.trends(for: .armRaise, in: all, last: 10))
        XCTAssertEqual(t.baseline, 20, "median of 10, 20, 30")
    }

    func testChartIsHiddenUntilTwoSessionsExist() throws {
        let one = TrendService.trends(for: .armRaise, in: sessions([80]), last: 10)
        XCTAssertFalse(try trend("Left arm best", in: one).isChartable)
        let two = TrendService.trends(for: .armRaise, in: sessions([80, 85]), last: 10)
        XCTAssertTrue(try trend("Left arm best", in: two).isChartable)
    }

    func testNoSessionsGivesNoTrends() {
        XCTAssertTrue(TrendService.trends(for: .balance, in: sessions([80, 90]), last: 10).isEmpty)
    }

    func testEachMetricGetsItsOwnTrend() {
        let trends = TrendService.trends(for: .armRaise, in: sessions([80, 90]), last: 10)
        XCTAssertEqual(trends.map(\.label), ["Left arm best", "Left arm average"])
    }

    func testSessionsInTheWrongOrderAreSortedByDate() throws {
        let newer = arm(daysAgo: 1, best: 100)
        let older = arm(daysAgo: 5, best: 70)
        let t = try trend("Left arm best", in: TrendService.trends(for: .armRaise, in: [newer, older], last: 10))
        XCTAssertEqual(t.values, [70, 100])
    }

    // MARK: VoiceOver chart

    func testChartDescriptorListsEveryValueForVoiceOver() throws {
        let t = MetricTrend(exercise: .armRaise, label: "Left arm best", unit: "degrees",
                            values: [80, 90, 100], baseline: 90)
        let descriptor = TrendChartDescriptor(trend: t).makeChartDescriptor()
        let series = try XCTUnwrap(descriptor.series.first)
        // AXDataPointValue compares by object identity, so read the numbers out.
        XCTAssertEqual(series.dataPoints.map { $0.xValue.__number }, [1, 2, 3])
        XCTAssertEqual(series.dataPoints.map { $0.yValue?.__number }, [80, 90, 100])
        XCTAssertEqual(descriptor.summary, "Starting point 90.0")
        XCTAssertEqual(series.name, "Left arm best")
    }

    func testChartDescriptorHandlesIdenticalValuesWithoutAnEmptyRange() throws {
        let t = MetricTrend(exercise: .armRaise, label: "x", unit: "degrees", values: [80, 80], baseline: nil)
        let descriptor = TrendChartDescriptor(trend: t).makeChartDescriptor()
        let y = try XCTUnwrap(descriptor.yAxis)
        XCTAssertLessThan(y.range.lowerBound, y.range.upperBound)
        XCTAssertTrue(y.range.contains(80))
        XCTAssertNil(descriptor.summary)
    }
}

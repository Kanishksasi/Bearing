import XCTest
import SwiftData
import PDFKit
@testable import Bearing

@MainActor
final class StorageAndReportTests: XCTestCase {
    private func makeStore() throws -> SessionStore {
        let container = try SessionStore.makeContainer(inMemory: true)
        return SessionStore(context: ModelContext(container))
    }

    private func armSession(daysAgo: Double, leftBest: Double, rejected: Int = 0) -> Session {
        let s = Session(date: Date(timeIntervalSinceNow: -daysAgo * 86_400),
                        exercise: .armRaise, acceptedTrials: 6, rejectedTrials: rejected)
        s.leftBest = leftBest
        s.leftAverage = leftBest - 10
        s.rightBest = leftBest + 5
        s.rightAverage = leftBest - 5
        return s
    }

    // MARK: Data

    func testOnlySessionAndUserSettingsAreStored() throws {
        let names = Schema([Session.self, UserSettings.self]).entities.map(\.name).sorted()
        XCTAssertEqual(names, ["Session", "UserSettings"])
    }

    func testSavedSessionComesBack() throws {
        let store = try makeStore()
        try store.save(armSession(daysAgo: 1, leftBest: 90, rejected: 2))
        let loaded = try store.sessions()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].leftBest, 90)
        XCTAssertEqual(loaded[0].rejectedTrials, 2)
    }

    func testDeleteAllMyDataRemovesEverything() throws {
        let store = try makeStore()
        try store.save(armSession(daysAgo: 2, leftBest: 80))
        try store.save(armSession(daysAgo: 1, leftBest: 85))
        _ = try store.settings()
        try store.deleteAllData()
        XCTAssertEqual(try store.sessions().count, 0)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<UserSettings>()).count, 0)
    }

    func testDeleteAllMyDataAlsoRemovesTheExportedPDF() throws {
        let store = try makeStore()
        let url = try ReportFile.write(ReportBuilder.makePDF(latest: [], history: []))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try store.deleteAllData()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testSettingsDefaultToFrontCameraAndSpokenPrompts() throws {
        let settings = try makeStore().settings()
        XCTAssertFalse(settings.caregiverMode)
        XCTAssertTrue(settings.spokenPrompts)
    }

    func testRejectedTrialsAreCountedInTheSession() {
        XCTAssertEqual(armSession(daysAgo: 0, leftBest: 80, rejected: 3).rejectedTrials, 3)
    }

    // MARK: PDF

    private func pdfText(_ data: Data) throws -> (pages: Int, text: String) {
        let document = try XCTUnwrap(PDFDocument(data: data))
        let text = (document.string ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return (document.pageCount, text)
    }

    func testReportIsOnePageAndShowsTheExactDisclaimer() throws {
        let sessions = [armSession(daysAgo: 7, leftBest: 80), armSession(daysAgo: 0, leftBest: 95)]
        let sit = Session(exercise: .sitToStand, acceptedTrials: 1, rejectedTrials: 0)
        sit.standCount = 12
        let balance = Session(exercise: .balance, acceptedTrials: 1, rejectedTrials: 1)
        balance.holdSeconds = 10
        balance.swayRatio = 0.04
        let latest = [sessions[1], sit, balance]
        let (pages, text) = try pdfText(ReportBuilder.makePDF(latest: latest, history: sessions + [sit, balance]))
        XCTAssertEqual(pages, 1)
        XCTAssertTrue(text.contains(Disclaimer.text), "PDF text was: \(text)")
    }

    func testReportShowsNumbersBeforeTheDisclaimer() throws {
        let latest = armSession(daysAgo: 0, leftBest: 95)
        let (_, text) = try pdfText(ReportBuilder.makePDF(latest: [latest], history: [latest]))
        let number = try XCTUnwrap(text.range(of: "95.0 degrees"))
        let disclaimer = try XCTUnwrap(text.range(of: Disclaimer.text))
        XCTAssertLessThan(number.lowerBound, disclaimer.lowerBound)
    }

    func testEmptyReportStillMakesOnePageWithDisclaimer() throws {
        let (pages, text) = try pdfText(ReportBuilder.makePDF(latest: [], history: []))
        XCTAssertEqual(pages, 1)
        XCTAssertTrue(text.contains(Disclaimer.text))
    }

    func testDisclaimerTextIsExact() {
        XCTAssertEqual(Disclaimer.text,
                       "For personal tracking only. Not medical advice or a diagnosis. Share with your clinician.")
    }

    // MARK: PDF trend line

    func testSparklineStaysInsideItsBoxAndRunsLeftToRight() throws {
        let rect = CGRect(x: 100, y: 50, width: 80, height: 20)
        let path = try XCTUnwrap(ReportBuilder.sparklinePath(values: [10, 20, 15, 30, 25], in: rect))
        XCTAssertEqual(path.bounds.minX, 100, accuracy: 0.001)
        XCTAssertEqual(path.bounds.maxX, 180, accuracy: 0.001)
        XCTAssertEqual(path.bounds.minY, 50, accuracy: 0.001)
        XCTAssertEqual(path.bounds.maxY, 70, accuracy: 0.001)
        // Highest value is drawn at the top. In PDF drawing space the top has the smaller y.
        XCTAssertEqual(path.currentPoint.y, 70 - 20 * (25.0 - 10.0) / 20.0, accuracy: 0.001)
    }

    func testSparklineNeedsTwoValuesAndFlatSeriesIsDrawnInTheMiddle() throws {
        let rect = CGRect(x: 0, y: 0, width: 80, height: 20)
        XCTAssertNil(ReportBuilder.sparklinePath(values: [], in: rect))
        XCTAssertNil(ReportBuilder.sparklinePath(values: [5], in: rect))
        let flat = try XCTUnwrap(ReportBuilder.sparklinePath(values: [7, 7, 7], in: rect))
        XCTAssertEqual(flat.bounds.minY, 10, accuracy: 0.001)
        XCTAssertEqual(flat.bounds.maxY, 10, accuracy: 0.001)
    }

    func testReportStaysOnePageWithThreeRoutinesAndTenSessionsEach() throws {
        var history: [Session] = []
        for i in 0..<10 {
            let age = Double(10 - i)
            let arm = armSession(daysAgo: age, leftBest: 80 + Double(i) * 2, rejected: i % 3)
            let sit = Session(date: Date(timeIntervalSinceNow: -age * 86_400), exercise: .sitToStand,
                              acceptedTrials: 1, rejectedTrials: 0)
            sit.standCount = 8 + i
            let balance = Session(date: Date(timeIntervalSinceNow: -age * 86_400), exercise: .balance,
                                  acceptedTrials: 1, rejectedTrials: 1)
            balance.holdSeconds = 4 + Double(i) * 0.5
            balance.swayRatio = 0.05 - Double(i) * 0.002
            history += [arm, sit, balance]
        }
        let latest = Exercise.allCases.compactMap { exercise in
            history.filter { $0.exercise == exercise }.max { $0.date < $1.date }
        }
        XCTAssertEqual(latest.count, 3)
        let (pages, text) = try pdfText(ReportBuilder.makePDF(latest: latest, history: history))
        XCTAssertEqual(history.count, 30)
        XCTAssertEqual(pages, 1)
        XCTAssertTrue(text.contains(Disclaimer.text))
        XCTAssertTrue(text.contains("from your starting point"))
        XCTAssertFalse(text.contains("first session"))
    }
}

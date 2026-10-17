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

    // MARK: Baseline

    func testBaselineIsYourOwnEarliestSession() throws {
        let first = armSession(daysAgo: 10, leftBest: 80)
        let middle = armSession(daysAgo: 5, leftBest: 85)
        let latest = armSession(daysAgo: 0, leftBest: 95)
        XCTAssertTrue(BaselineService.baseline(for: latest, in: [middle, first, latest]) === first)
        XCTAssertNil(BaselineService.baseline(for: first, in: [middle, first, latest]))
    }

    func testComparisonShowsPlainDifference() throws {
        let first = armSession(daysAgo: 10, leftBest: 80)
        let latest = armSession(daysAgo: 0, leftBest: 95)
        let comparisons = BaselineService.compare(latest, with: [first, latest])
        let best = try XCTUnwrap(comparisons.first { $0.label == "Left arm best" })
        XCTAssertEqual(best.difference, 15, accuracy: 0.0001)
        XCTAssertEqual(best.text, "Up 15.0 from your first session")
    }

    func testNoComparisonOnTheFirstSession() {
        let only = armSession(daysAgo: 0, leftBest: 80)
        XCTAssertTrue(BaselineService.compare(only, with: [only]).isEmpty)
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
}

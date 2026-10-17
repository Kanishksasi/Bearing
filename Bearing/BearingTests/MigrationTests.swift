import XCTest
import SwiftData
@testable import Bearing

/// The shape of the saved data before hasSeenIntro was added.
private enum LegacyV1 {
    @Model final class Session {
        var date: Date
        var exerciseRaw: String
        var leftBest: Double?
        var leftAverage: Double?
        var rightBest: Double?
        var rightAverage: Double?
        var standCount: Int?
        var holdSeconds: Double?
        var swayRatio: Double?
        var liftedFootRaw: String?
        var acceptedTrials: Int
        var rejectedTrials: Int

        init(date: Date, exerciseRaw: String, acceptedTrials: Int, rejectedTrials: Int) {
            self.date = date
            self.exerciseRaw = exerciseRaw
            self.acceptedTrials = acceptedTrials
            self.rejectedTrials = rejectedTrials
        }
    }

    @Model final class UserSettings {
        var caregiverMode: Bool
        var spokenPrompts: Bool

        init(caregiverMode: Bool, spokenPrompts: Bool) {
            self.caregiverMode = caregiverMode
            self.spokenPrompts = spokenPrompts
        }
    }
}

@MainActor
final class MigrationTests: XCTestCase {
    func testNewSettingsStartWithTheIntroNotSeen() {
        XCTAssertFalse(UserSettings().hasSeenIntro)
    }

    func testOlderSavedDataOpensWithNothingLostAndTheIntroNotSeen() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("bearing-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("store.sqlite")
        let when = Date(timeIntervalSince1970: 1_700_000_000)

        do {
            let oldSchema = Schema([LegacyV1.Session.self, LegacyV1.UserSettings.self])
            let old = try ModelContainer(for: oldSchema, configurations: [ModelConfiguration(schema: oldSchema, url: url)])
            let context = ModelContext(old)
            let session = LegacyV1.Session(date: when, exerciseRaw: "sitToStand", acceptedTrials: 1, rejectedTrials: 2)
            session.standCount = 11
            context.insert(session)
            context.insert(LegacyV1.UserSettings(caregiverMode: true, spokenPrompts: false))
            try context.save()
        }

        let container = try SessionStore.makeContainer(url: url)
        let context = ModelContext(container)
        let sessions = try context.fetch(FetchDescriptor<Bearing.Session>())
        let settings = try context.fetch(FetchDescriptor<Bearing.UserSettings>())

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.standCount, 11)
        XCTAssertEqual(sessions.first?.rejectedTrials, 2)
        XCTAssertEqual(sessions.first?.date, when)
        XCTAssertEqual(settings.count, 1)
        XCTAssertEqual(settings.first?.caregiverMode, true, "old settings must be kept")
        XCTAssertEqual(settings.first?.spokenPrompts, false, "old settings must be kept")
        XCTAssertEqual(settings.first?.hasSeenIntro, false, "the new field takes its default")
    }
}

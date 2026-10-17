import Foundation
import SwiftData

@MainActor
struct SessionStore {
    let context: ModelContext

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([Session.self, UserSettings.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func save(_ session: Session) throws {
        context.insert(session)
        try context.save()
    }

    func sessions(for exercise: Exercise? = nil) throws -> [Session] {
        let all = try context.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\.date)]))
        guard let exercise else { return all }
        return all.filter { $0.exercise == exercise }
    }

    func settings() throws -> UserSettings {
        if let existing = try context.fetch(FetchDescriptor<UserSettings>()).first { return existing }
        let created = UserSettings()
        context.insert(created)
        try context.save()
        return created
    }

    /// Removes every saved session and the settings.
    func deleteAllData() throws {
        try context.delete(model: Session.self)
        try context.delete(model: UserSettings.self)
        try context.save()
    }
}

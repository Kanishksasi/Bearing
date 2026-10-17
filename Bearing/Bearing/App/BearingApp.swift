import SwiftUI
import SwiftData

@main
struct BearingApp: App {
    private let container: ModelContainer?
    private let startupError: String?

    init() {
        do {
            container = try SessionStore.makeContainer()
            startupError = nil
        } catch {
            container = nil
            startupError = "Bearing could not open its saved data. Restart the app. If this keeps happening, delete and reinstall it."
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                HomeView().modelContainer(container)
            } else {
                Text(startupError ?? "")
                    .padding(24)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

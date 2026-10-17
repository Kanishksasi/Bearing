import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [UserSettings]
    @State private var confirmDelete = false
    @State private var deleteFailed = false

    var body: some View {
        Form {
            if let settings = settingsList.first {
                Section {
                    Toggle("Caregiver mode", isOn: Binding(get: { settings.caregiverMode },
                                                           set: { settings.caregiverMode = $0 }))
                        .frame(minHeight: 44)
                    Toggle("Spoken instructions", isOn: Binding(get: { settings.spokenPrompts },
                                                                set: { settings.spokenPrompts = $0 }))
                        .frame(minHeight: 44)
                } footer: {
                    Text("Caregiver mode uses the back camera so someone else can hold the phone.")
                }
            }

            Section {
                Button("Delete all my data", role: .destructive) { confirmDelete = true }
                    .frame(minHeight: 44)
            } footer: {
                Text("Removes every saved session from this phone. Bearing never saves video or pictures.")
            }
        }
        .navigationTitle("Settings")
        .task { ensureSettings() }
        .confirmationDialog("Delete all your data?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete all my data", role: .destructive) { deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .alert("Could not delete", isPresented: $deleteFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
    }

    private func ensureSettings() {
        if settingsList.isEmpty { _ = try? SessionStore(context: modelContext).settings() }
    }

    private func deleteAll() {
        do {
            let store = SessionStore(context: modelContext)
            try store.deleteAllData()
            // Settings come back with the intro marked as seen, so deleting data does not interrupt the person.
            let fresh = try store.settings()
            fresh.hasSeenIntro = true
            try modelContext.save()
        } catch {
            deleteFailed = true
        }
    }
}

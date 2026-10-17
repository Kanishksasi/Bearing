import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Personal movement tracking. Everything stays on your phone.")
                        .font(.subheadline)
                }
                Section("Pick a routine") {
                    ForEach(Exercise.allCases) { exercise in
                        NavigationLink {
                            ExerciseFlowLoader(exercise: exercise)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.title).font(.headline)
                                Text(blurb(exercise)).font(.subheadline).foregroundStyle(.secondary)
                            }
                            .frame(minHeight: 44)
                        }
                        .accessibilityHint("Opens the camera")
                    }
                }
                Section {
                    NavigationLink("History and report") { HistoryView() }
                        .frame(minHeight: 44)
                    NavigationLink("Settings") { SettingsView() }
                        .frame(minHeight: 44)
                }
            }
            .navigationTitle("Bearing")
        }
    }

    private func blurb(_ exercise: Exercise) -> String {
        switch exercise {
        case .armRaise: return "Raise each arm to the side. Three tries on each side."
        case .sitToStand: return "Stand up and sit down for 30 seconds with arms crossed."
        case .balance: return "Lift one foot and hold for up to 10 seconds."
        }
    }
}

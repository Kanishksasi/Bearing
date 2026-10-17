import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    private var latestPerRoutine: [Session] {
        Exercise.allCases.compactMap { exercise in sessions.first { $0.exercise == exercise } }
    }

    var body: some View {
        List {
            if sessions.isEmpty {
                Text("No sessions yet. Pick a routine on the home screen.")
            } else {
                Section {
                    ReportShareButton(latest: latestPerRoutine, history: sessions)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    DisclaimerView()
                }
                Section("Past sessions") {
                    ForEach(sessions) { session in
                        NavigationLink {
                            ResultView(session: session, history: sessions)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(session.exercise.title).font(.headline)
                                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
    }
}

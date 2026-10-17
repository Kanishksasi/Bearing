import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    private var latestPerRoutine: [Session] {
        Exercise.allCases.compactMap { exercise in sessions.first { $0.exercise == exercise } }
    }

    /// Only metrics with at least two sessions get a chart.
    private var chartableTrends: [MetricTrend] {
        Exercise.allCases
            .flatMap { TrendService.trends(for: $0, in: sessions, last: 10) }
            .filter(\.isChartable)
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
                if !chartableTrends.isEmpty {
                    Section {
                        ForEach(chartableTrends, id: \.label) { TrendChart(trend: $0) }
                    } header: {
                        Text("Your last 10 sessions")
                    } footer: {
                        Text("The dashed line is your starting point.")
                    }
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

import Foundation

/// The recent values of one metric, oldest first, plus the starting point for that metric.
struct MetricTrend: Equatable, Sendable {
    var exercise: Exercise
    var label: String
    var unit: String
    var values: [Double]
    var baseline: Double?

    /// A line needs two points. Anything less stays hidden.
    var isChartable: Bool { values.count >= 2 }
}

enum TrendService {
    /// One trend per metric of a routine. `count` keeps only the most recent values.
    /// The starting point always comes from the earliest sessions, not from the trimmed list.
    static func trends(for exercise: Exercise, in sessions: [Session], last count: Int) -> [MetricTrend] {
        let ordered = sessions.filter { $0.exercise == exercise }.sorted { $0.date < $1.date }
        let baseline = BaselineService.baselineValues(for: exercise, in: sessions)

        var labels: [String] = []
        var units: [String: String] = [:]
        var values: [String: [Double]] = [:]
        for session in ordered {
            for metric in session.metrics {
                if units[metric.label] == nil { labels.append(metric.label) }
                units[metric.label] = metric.unit
                values[metric.label, default: []].append(metric.value)
            }
        }
        return labels.map { label in
            MetricTrend(exercise: exercise,
                        label: label,
                        unit: units[label] ?? "",
                        values: Array((values[label] ?? []).suffix(count)),
                        baseline: baseline[label])
        }
    }
}

import Foundation

struct MetricComparison: Equatable, Sendable {
    var label: String
    var unit: String
    var baseline: Double
    var current: Double

    var difference: Double { current - baseline }

    /// Plain wording with no judgment.
    var text: String {
        let amount = abs(difference)
        let shown = unit == "stands" ? String(Int(amount.rounded())) : String(format: "%.1f", amount)
        if amount < 0.05 { return "Same as your starting point" }
        return "\(difference > 0 ? "Up" : "Down") \(shown) from your starting point"
    }
}

enum BaselineService {
    static let baselineSessionCount = 3

    /// The earliest sessions of one routine that set the starting point. Oldest date first.
    static func baselineSet(for exercise: Exercise, in history: [Session]) -> [Session] {
        Array(history
            .filter { $0.exercise == exercise }
            .sorted { $0.date < $1.date }
            .prefix(baselineSessionCount))
    }

    /// True when this session is one of the sessions that set the starting point.
    static func isInBaselineSet(_ session: Session, in history: [Session]) -> Bool {
        baselineSet(for: session.exercise, in: history).contains { $0 === session }
    }

    /// The median of each metric over the baseline set, keyed by metric label.
    static func baselineValues(for exercise: Exercise, in history: [Session]) -> [String: Double] {
        var values: [String: [Double]] = [:]
        for session in baselineSet(for: exercise, in: history) {
            for metric in session.metrics { values[metric.label, default: []].append(metric.value) }
        }
        return values.compactMapValues { median($0) }
    }

    /// Sessions in the baseline set compare with nothing.
    static func compare(_ session: Session, with history: [Session]) -> [MetricComparison] {
        guard !isInBaselineSet(session, in: history) else { return [] }
        let base = baselineValues(for: session.exercise, in: history)
        return session.metrics.compactMap { metric in
            guard let start = base[metric.label] else { return nil }
            return MetricComparison(label: metric.label, unit: metric.unit, baseline: start, current: metric.value)
        }
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
    }
}

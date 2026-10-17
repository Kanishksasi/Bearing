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
        if amount < 0.05 { return "Same as your first session" }
        return "\(difference > 0 ? "Up" : "Down") \(shown) from your first session"
    }
}

enum BaselineService {
    /// Your baseline is your own earliest session of the same routine.
    static func baseline(for session: Session, in history: [Session]) -> Session? {
        history
            .filter { $0.exercise == session.exercise && $0.date < session.date }
            .min { $0.date < $1.date }
    }

    static func compare(_ session: Session, with history: [Session]) -> [MetricComparison] {
        guard let base = baseline(for: session, in: history) else { return [] }
        return session.metrics.compactMap { metric in
            guard let earlier = base.metrics.first(where: { $0.label == metric.label }) else { return nil }
            return MetricComparison(label: metric.label,
                                    unit: metric.unit,
                                    baseline: earlier.value,
                                    current: metric.value)
        }
    }
}

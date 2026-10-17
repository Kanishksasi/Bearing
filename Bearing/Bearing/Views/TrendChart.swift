import SwiftUI
import Charts
import Accessibility

/// A small line chart of the last sessions for one metric, with a dashed line at the starting point.
/// One neutral color and no thresholds: the chart does not say whether a value is better or worse.
struct TrendChart: View {
    let trend: MetricTrend

    private var summary: String {
        var text = "\(trend.label), last \(trend.values.count) sessions."
        if let baseline = trend.baseline {
            text += " Starting point \(format(baseline)) \(trend.unit)."
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(trend.label) (\(trend.unit))")
                .font(.subheadline)
            Chart {
                ForEach(Array(trend.values.enumerated()), id: \.offset) { index, value in
                    LineMark(x: .value("Session", index + 1), y: .value(trend.label, value))
                        .foregroundStyle(Color.primary)
                    PointMark(x: .value("Session", index + 1), y: .value(trend.label, value))
                        .foregroundStyle(Color.primary)
                }
                if let baseline = trend.baseline {
                    RuleMark(y: .value("Starting point", baseline))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(Color.secondary)
                }
            }
            .chartXScale(domain: 1...max(2, trend.values.count))
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 110)
            .accessibilityLabel(summary)
            .accessibilityChartDescriptor(TrendChartDescriptor(trend: trend))
        }
        .padding(.vertical, 4)
    }

    private func format(_ value: Double) -> String {
        trend.unit == "stands" ? String(Int(value.rounded())) : String(format: "%.1f", value)
    }
}

/// Lets VoiceOver read each value in a chart.
struct TrendChartDescriptor: AXChartDescriptorRepresentable {
    let trend: MetricTrend

    func makeChartDescriptor() -> AXChartDescriptor {
        let count = max(2, trend.values.count)
        let low = trend.values.min() ?? 0
        let high = trend.values.max() ?? 1
        // The range must not be empty, even when every value is the same.
        let padding = max((high - low) * 0.1, 0.5)

        let xAxis = AXNumericDataAxisDescriptor(title: "Session",
                                                range: 1...Double(count),
                                                gridlinePositions: []) { "Session \(Int($0))" }
        let yAxis = AXNumericDataAxisDescriptor(title: "\(trend.label) in \(trend.unit)",
                                                range: (low - padding)...(high + padding),
                                                gridlinePositions: []) { String(format: "%.1f", $0) }
        let series = AXDataSeriesDescriptor(name: trend.label,
                                            isContinuous: true,
                                            dataPoints: trend.values.enumerated().map {
                                                AXDataPoint(x: Double($0.offset + 1), y: $0.element)
                                            })
        return AXChartDescriptor(title: trend.label,
                                 summary: trend.baseline.map { String(format: "Starting point %.1f", $0) },
                                 xAxis: xAxis,
                                 yAxis: yAxis,
                                 additionalAxes: [],
                                 series: [series])
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {}
}

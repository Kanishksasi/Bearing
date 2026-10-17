import UIKit

/// Builds a one-page PDF on the device. Numbers come first. Nothing leaves the phone
/// until the person chooses to share the file.
enum ReportBuilder {
    private static let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 48

    /// `latest` holds the newest session for each routine. `history` is everything saved.
    static func makePDF(latest: [Session], history: [Session], now: Date = Date()) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            context.beginPage()
            var y = margin

            y = draw("Bearing movement report", font: .boldSystemFont(ofSize: 24), at: y)
            y = draw(now.formatted(date: .long, time: .omitted), font: .systemFont(ofSize: 12), at: y + 2, color: .darkGray)
            y += 14

            let ordered = latest.sorted { $0.exerciseRaw < $1.exerciseRaw }
            if ordered.isEmpty {
                y = draw("No sessions yet.", font: .systemFont(ofSize: 14), at: y)
            }
            for session in ordered {
                guard y < page.height - 170 else { break }
                y = draw(session.exercise.title, font: .boldSystemFont(ofSize: 15), at: y)
                let comparisons = BaselineService.compare(session, with: history)
                // The line shows the five sessions up to this one, so an older report never shows later values.
                let upToThisSession = history.filter { $0.date <= session.date }
                let trends = TrendService.trends(for: session.exercise, in: upToThisSession, last: 5)
                for metric in session.metrics {
                    let note = comparisons.first { $0.label == metric.label }?.text ?? ""
                    let recent = trends.first { $0.label == metric.label }?.values ?? []
                    y = drawRow(label: metric.label,
                                value: "\(metric.text) \(metric.unit)",
                                note: note,
                                trend: recent,
                                at: y)
                }
                let counts = "Tries kept: \(session.acceptedTrials). Tries not counted: \(session.rejectedTrials)."
                y = draw(counts, font: .systemFont(ofSize: 11), at: y + 2, color: .darkGray)
                y += 14
            }

            _ = draw(Disclaimer.text,
                     font: .italicSystemFont(ofSize: 11),
                     at: page.height - margin - 16)
        }
    }

    private static let sparkSize = CGSize(width: 84, height: 22)

    private static func drawRow(label: String, value: String, note: String, trend: [Double], at y: CGFloat) -> CGFloat {
        let valueFont = UIFont.boldSystemFont(ofSize: 22)
        let width = page.width - margin * 2
        value.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: valueFont])

        let detailX = margin + 170
        let detailWidth = width - 170 - sparkSize.width - 12
        let detail = note.isEmpty ? label : "\(label). \(note)"
        detail.draw(in: CGRect(x: detailX, y: y + 2, width: detailWidth, height: 26),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 10.5), .foregroundColor: UIColor.darkGray])

        let sparkRect = CGRect(x: page.width - margin - sparkSize.width, y: y + 4,
                               width: sparkSize.width, height: sparkSize.height)
        if let path = sparklinePath(values: trend, in: sparkRect) {
            UIColor.darkGray.setStroke()
            path.lineWidth = 1.5
            path.lineJoinStyle = .round
            path.stroke()
        }
        return y + 30
    }

    /// A line through the values, scaled to fit the rectangle. Needs at least two values.
    /// A flat series is drawn across the middle.
    static func sparklinePath(values: [Double], in rect: CGRect) -> UIBezierPath? {
        guard values.count >= 2, let low = values.min(), let high = values.max() else { return nil }
        let span = high - low
        let path = UIBezierPath()
        for (index, value) in values.enumerated() {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(values.count - 1)
            let fraction = span > 0 ? CGFloat((value - low) / span) : 0.5
            let point = CGPoint(x: x, y: rect.maxY - rect.height * fraction)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    @discardableResult
    private static func draw(_ text: String, font: UIFont, at y: CGFloat, color: UIColor = .black) -> CGFloat {
        let width = page.width - margin * 2
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let bounds = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                     options: .usesLineFragmentOrigin,
                                                     attributes: attributes,
                                                     context: nil)
        text.draw(in: CGRect(x: margin, y: y, width: width, height: ceil(bounds.height)), withAttributes: attributes)
        return y + ceil(bounds.height) + 4
    }
}

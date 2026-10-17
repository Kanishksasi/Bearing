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
                for metric in session.metrics {
                    let note = comparisons.first { $0.label == metric.label }?.text ?? ""
                    y = drawRow(label: metric.label,
                                value: "\(metric.text) \(metric.unit)",
                                note: note,
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

    private static func drawRow(label: String, value: String, note: String, at y: CGFloat) -> CGFloat {
        let valueFont = UIFont.boldSystemFont(ofSize: 22)
        let width = page.width - margin * 2
        value.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: valueFont])
        let detail = note.isEmpty ? label : "\(label). \(note)"
        detail.draw(in: CGRect(x: margin + 170, y: y + 5, width: width - 170, height: 18),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.darkGray])
        return y + 30
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

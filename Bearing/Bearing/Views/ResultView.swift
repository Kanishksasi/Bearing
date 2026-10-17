import SwiftUI

/// Result screen. Numbers first, then the comparison with your own first session.
struct ResultView: View {
    let session: Session
    let history: [Session]

    private var comparisons: [MetricComparison] {
        BaselineService.compare(session, with: history)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(session.exercise.title)
                    .font(.title2.bold())
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)

                ForEach(session.metrics, id: \.label) { metric in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(metric.text) \(metric.unit)")
                            .font(.system(.largeTitle, design: .rounded).bold())
                            .minimumScaleFactor(0.6)
                        Text(metric.label)
                            .font(.subheadline)
                        if let note = comparisons.first(where: { $0.label == metric.label }) {
                            Text(note.text)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }

                Text("Tries kept: \(session.acceptedTrials). Tries not counted: \(session.rejectedTrials).")
                    .font(.subheadline)

                ReportShareButton(latest: [session], history: history)

                DisclaimerView()
            }
            .padding(16)
        }
    }
}

/// Builds the PDF on the phone and offers it to the share sheet.
struct ReportShareButton: View {
    let latest: [Session]
    let history: [Session]
    @State private var fileURL: URL?

    var body: some View {
        Group {
            if let fileURL {
                ShareLink(item: fileURL) {
                    Label("Share with your clinician", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            } else {
                ProgressView()
            }
        }
        .task(id: latest.count + history.count) { fileURL = makeFile() }
    }

    private func makeFile() -> URL? {
        let data = ReportBuilder.makePDF(latest: latest, history: history)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Bearing-report.pdf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

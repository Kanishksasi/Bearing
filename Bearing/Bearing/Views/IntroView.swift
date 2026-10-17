import SwiftUI

enum IntroText {
    static let title = "Welcome to Bearing"
    static let lines = [
        "Bearing measures how you move, using your phone camera.",
        "Your video never leaves this phone and is never saved.",
        "This is for personal tracking only."
    ]
    static let button = "Get started"
}

/// Shown once, the first time the app opens.
struct IntroView: View {
    let getStarted: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(IntroText.title)
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                ForEach(IntroText.lines, id: \.self) { line in
                    Text(line).font(.title3)
                }
                DisclaimerView()
                Button(action: getStarted) {
                    Text(IntroText.button).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(24)
        }
    }
}

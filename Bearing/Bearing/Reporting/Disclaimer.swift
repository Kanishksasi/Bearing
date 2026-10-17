import SwiftUI

enum Disclaimer {
    static let text = "For personal tracking only. Not medical advice or a diagnosis. Share with your clinician."
}

/// Shown on every result screen.
struct DisclaimerView: View {
    var body: some View {
        Text(Disclaimer.text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("disclaimer")
    }
}

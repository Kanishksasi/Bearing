import SwiftUI

/// Caregiver mode start button. It needs a one second press and hold, shown by a filling ring,
/// so a stray touch cannot start a trial while someone is setting up the phone.
struct HoldToStartButton: View {
    static let holdSeconds = 1.0
    static let diameter: CGFloat = 96

    let isEnabled: Bool
    let action: () -> Void
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("Hold to start")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(16)
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .contentShape(Circle())
        .opacity(isEnabled ? 1 : 0.4)
        .onLongPressGesture(minimumDuration: Self.holdSeconds, maximumDistance: 60) {
            progress = 0
            if isEnabled { action() }
        } onPressingChanged: { pressing in
            guard isEnabled else { return }
            if pressing {
                withAnimation(.linear(duration: Self.holdSeconds)) { progress = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.15)) { progress = 0 }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Press and hold to start")
        .accessibilityValue(isEnabled ? "" : "Not ready yet")
        .accessibilityAddTraits(.isButton)
        // VoiceOver users cannot hold a button, so they get a direct action.
        .accessibilityAction { if isEnabled { action() } }
    }
}

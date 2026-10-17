import UIKit

/// Small taps for key moments. The system turns these off by itself when the person has
/// switched off haptics, so there is no setting for them here.
@MainActor
enum Haptics {
    /// A trial starts.
    static func trialStarted() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// A try was saved.
    static func trySaved() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// A try was not counted.
    static func tryNotCounted() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

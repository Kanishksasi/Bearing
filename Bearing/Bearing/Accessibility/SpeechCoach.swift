import AVFoundation

/// Speaks short prompts. Remembers the last one so a Repeat button can say it again.
@MainActor
final class SpeechCoach {
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var lastPrompt: String?
    var isEnabled = true

    func speak(_ text: String) {
        lastPrompt = text
        guard isEnabled else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    func repeatLast() {
        guard let lastPrompt else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: lastPrompt)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

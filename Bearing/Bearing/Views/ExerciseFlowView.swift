import SwiftUI
import SwiftData

/// Looks up settings, then hands off to the screen that runs the routine.
struct ExerciseFlowLoader: View {
    let exercise: Exercise
    @Query private var settings: [UserSettings]

    var body: some View {
        ExerciseFlowView(exercise: exercise,
                         caregiverMode: settings.first?.caregiverMode ?? false,
                         spokenPrompts: settings.first?.spokenPrompts ?? true)
    }
}

struct ExerciseFlowView: View {
    @StateObject private var model: TrialViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.date) private var history: [Session]
    @State private var savedSession: Session?

    init(exercise: Exercise, caregiverMode: Bool, spokenPrompts: Bool) {
        _model = StateObject(wrappedValue: TrialViewModel(exercise: exercise,
                                                          caregiverMode: caregiverMode,
                                                          spokenPrompts: spokenPrompts))
    }

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView("Starting the camera")
            case .denied:
                CameraDeniedView()
            case .safety:
                SafetyView { model.acknowledgeSafety() }
            case .finished:
                finishedView
            default:
                trialView
            }
        }
        .navigationTitle(model.exercise.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.begin() }
        .onDisappear { model.shutDown() }
        .onChange(of: model.phase) { _, phase in
            if phase == .finished { saveIfNeeded() }
        }
    }

    // MARK: Trial

    private var trialView: some View {
        VStack(spacing: 12) {
            ZStack {
                CameraPreviewView(session: model.camera.session, mirrored: model.mirrorPreview)
                SkeletonOverlay(frame: model.latestFrame, mirrored: model.mirrorPreview)
            }
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Camera view")

            statusText
            controls
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder private var statusText: some View {
        switch model.phase {
        case .aligning:
            Text(model.alignment.hint)
                .font(.headline)
                .multilineTextAlignment(.center)
        case .running:
            Text("Time: \(Int(model.elapsed)) seconds")
                .font(.headline)
                .monospacedDigit()
        case .attemptResult:
            VStack(spacing: 4) {
                if let reason = model.lastRejection {
                    Text("Try not counted").font(.headline)
                    Text(reason.message).multilineTextAlignment(.center)
                } else {
                    Text("Try saved").font(.headline)
                }
            }
        default:
            EmptyView()
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            switch model.phase {
            case .aligning:
                Button("Start") { model.startTrial() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.alignment.canStart)
            case .running:
                Button("Stop") { model.stopTrial() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            case .attemptResult:
                Button("Next try") { model.nextAttempt() }
                    .buttonStyle(.borderedProminent)
            default:
                EmptyView()
            }
            Button {
                model.repeatPrompt()
            } label: {
                Label("Repeat instructions", systemImage: "speaker.wave.2")
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }

    // MARK: Finished

    @ViewBuilder private var finishedView: some View {
        if let session = savedSession {
            ResultView(session: session, history: history)
        } else if model.hasAnyNumbers {
            ProgressView()
        } else {
            NoNumbersView(reason: model.lastRejection)
        }
    }

    private func saveIfNeeded() {
        guard savedSession == nil, model.hasAnyNumbers else { return }
        let session = model.makeSession()
        do {
            try SessionStore(context: modelContext).save(session)
            savedSession = session
        } catch {
            savedSession = nil
        }
    }

}

private struct NoNumbersView: View {
    let reason: RejectReason?

    var body: some View {
        VStack(spacing: 16) {
            Text("No numbers this time")
                .font(.title2.bold())
            Text(reason?.message ?? "Go back and try again with your whole body in the picture.")
                .multilineTextAlignment(.center)
            DisclaimerView()
        }
        .padding(16)
    }
}

private struct SafetyView: View {
    let acknowledge: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Stay safe")
                .font(.title.bold())
            Text(SafetyText.message)
                .font(.title3)
                .multilineTextAlignment(.leading)
            Button("I understand", action: acknowledge)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(24)
    }
}

private struct CameraDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .accessibilityHidden(true)
            Text("Bearing needs the camera to measure your movement. Video stays on your phone and is never saved.")
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
    }
}

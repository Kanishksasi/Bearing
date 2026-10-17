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
    @State private var pendingSession: Session?
    @State private var saveFailed = false

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
                SafetyView(caregiverMode: model.caregiverMode) { model.acknowledgeSafety() }
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

    /// Prompt text is one size larger in caregiver mode.
    private var promptFont: Font { model.caregiverMode ? .title2 : .headline }
    private var detailFont: Font { model.caregiverMode ? .title3 : .body }

    @ViewBuilder private var statusText: some View {
        switch model.phase {
        case .aligning:
            Text(model.alignment.hint)
                .font(promptFont)
                .multilineTextAlignment(.center)
        case .running:
            Text("Time: \(Int(model.elapsed)) seconds")
                .font(promptFont)
                .monospacedDigit()
        case .attemptResult:
            VStack(spacing: 4) {
                if let reason = model.lastRejection {
                    Text("Try not counted").font(promptFont)
                    Text(reason.message).font(detailFont).multilineTextAlignment(.center)
                } else {
                    Text("Try saved").font(promptFont)
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
                if model.caregiverMode {
                    HoldToStartButton(isEnabled: model.alignment.canStart) { model.startTrial() }
                } else {
                    Button("Start") { model.startTrial() }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                        .disabled(!model.alignment.canStart)
                }
            case .running:
                Button("Stop") { model.stopTrial() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .frame(minHeight: 44)
            case .attemptResult:
                Button("Next try") { model.nextAttempt() }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
            default:
                EmptyView()
            }
            Button {
                model.repeatPrompt()
            } label: {
                Label("Repeat instructions", systemImage: "speaker.wave.2")
                    .font(detailFont)
            }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
        }
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }

    // MARK: Finished

    @ViewBuilder private var finishedView: some View {
        if let session = savedSession {
            ResultView(session: session, history: history)
        } else if saveFailed, let session = pendingSession {
            SaveFailedView(session: session) { saveIfNeeded() }
        } else if model.hasAnyNumbers {
            ProgressView()
        } else {
            NoNumbersView(reason: model.lastRejection)
        }
    }

    /// Keeps the same unsaved session between tries, so the numbers are never lost.
    private func saveIfNeeded() {
        guard savedSession == nil, model.hasAnyNumbers else { return }
        let session = pendingSession ?? model.makeSession()
        pendingSession = session
        do {
            try SessionStore(context: modelContext).save(session)
            savedSession = session
            saveFailed = false
        } catch {
            saveFailed = true
        }
    }
}

/// Shown when saving fails. The numbers stay on screen and the person can try again.
private struct SaveFailedView: View {
    let session: Session
    let retry: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("We could not save this session.")
                    .font(.title2.bold())
                ForEach(session.metrics, id: \.label) { metric in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(metric.text) \(metric.unit)")
                            .font(.system(.largeTitle, design: .rounded).bold())
                            .minimumScaleFactor(0.6)
                        Text(metric.label).font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)
                }
                Text("Tries kept: \(session.acceptedTrials). Tries not counted: \(session.rejectedTrials).")
                    .font(.subheadline)
                Button("Try again", action: retry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                DisclaimerView()
            }
            .padding(16)
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
    let caregiverMode: Bool
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
                .font(caregiverMode ? .title2 : .title3)
                .multilineTextAlignment(.leading)
            Button("I understand", action: acknowledge)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: 44)
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

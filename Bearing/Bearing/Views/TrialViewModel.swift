import SwiftUI
import Combine

@MainActor
final class TrialViewModel: ObservableObject {
    enum Phase: Equatable {
        case loading, denied, safety, aligning, running, attemptResult, finished
    }

    let exercise: Exercise
    let camera: CameraService
    let mirrorPreview: Bool
    let caregiverMode: Bool

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var alignment = AlignmentStatus.blocked
    @Published private(set) var latestFrame: PoseFrame?
    @Published private(set) var prompt = ""
    @Published private(set) var lastRejection: RejectReason?
    @Published private(set) var attemptIndex = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var acceptedTrials = 0
    @Published private(set) var rejectedTrials = 0

    private let config = PoseConfig.standard
    private let pose = PoseService()
    private let tilt = TiltMonitor()
    private let speech = SpeechCoach()
    private let checker = AlignmentChecker()
    private let attempts: [Side?]
    private var engine: MovementEngine
    private var runStart: TimeInterval?
    private var leftPeaks: [Double] = []
    private var rightPeaks: [Double] = []
    private var standCount: Int?
    private var balanceResult: (foot: Side, hold: Double, sway: Double)?

    init(exercise: Exercise, caregiverMode: Bool, spokenPrompts: Bool) {
        self.exercise = exercise
        self.camera = CameraService(caregiverMode: caregiverMode)
        self.mirrorPreview = !caregiverMode
        self.caregiverMode = caregiverMode
        speech.isEnabled = spokenPrompts
        switch exercise {
        case .armRaise:
            let perSide = PoseConfig.standard.armRaiseAttemptsPerSide
            attempts = Array(repeating: Side.left, count: perSide) + Array(repeating: Side.right, count: perSide)
        default:
            attempts = [nil]
        }
        engine = Self.makeEngine(exercise, side: attempts[0], config: PoseConfig.standard)
    }

    var attemptCount: Int { attempts.count }
    var currentSide: Side? { attempts[attemptIndex] }

    private static func makeEngine(_ exercise: Exercise, side: Side?, config: PoseConfig) -> MovementEngine {
        switch exercise {
        case .armRaise: return ArmRaiseEngine(side: side ?? .left, config: config)
        case .sitToStand: return SitToStandEngine(config: config)
        case .balance: return BalanceEngine(config: config)
        }
    }

    // MARK: Flow

    func begin() async {
        switch CameraAccess.current {
        case .allowed:
            break
        case .notAsked:
            guard await CameraAccess.request() else { phase = .denied; return }
        case .denied:
            phase = .denied
            return
        }

        let pose = self.pose
        let tilt = self.tilt
        camera.onFrame = { [weak self] buffer, timestamp in
            guard let frame = pose.process(buffer, timestamp: timestamp, tiltDegrees: tilt.currentDegrees) else { return }
            Task { @MainActor [weak self] in self?.handle(frame) }
        }
        tilt.start()
        camera.start()

        if exercise.needsSafetyMessage {
            phase = .safety
            say(SafetyText.message)
        } else {
            enterAligning()
        }
    }

    func acknowledgeSafety() {
        enterAligning()
    }

    func startTrial() {
        guard phase == .aligning, alignment.canStart else { return }
        engine.start()
        runStart = nil
        elapsed = 0
        lastRejection = nil
        phase = .running
        Haptics.trialStarted()
        say("Go.")
    }

    /// Arm raise ends on Stop. The other routines end on their own, so Stop cancels them.
    func stopTrial() {
        guard phase == .running else { return }
        if exercise == .armRaise {
            finishAttempt()
        } else {
            enterAligning()
        }
    }

    func nextAttempt() {
        attemptIndex += 1
        engine = Self.makeEngine(exercise, side: attempts[attemptIndex], config: config)
        enterAligning()
    }

    func repeatPrompt() {
        speech.repeatLast()
    }

    func shutDown() {
        camera.onFrame = nil
        camera.stop()
        tilt.stop()
        speech.stop()
    }

    // MARK: Frames

    private func handle(_ frame: PoseFrame) {
        latestFrame = frame
        switch phase {
        case .aligning:
            alignment = checker.check(frame, for: exercise)
        case .running:
            if runStart == nil { runStart = frame.timestamp }
            elapsed = frame.timestamp - (runStart ?? frame.timestamp)
            engine.ingest(frame)
            if engine.isComplete { finishAttempt() }
        default:
            break
        }
    }

    private func finishAttempt() {
        switch engine.finish() {
        case .accepted(let metrics):
            acceptedTrials += 1
            record(metrics)
            lastRejection = nil
            Haptics.trySaved()
            say("Done.")
        case .rejected(let reason):
            rejectedTrials += 1
            lastRejection = reason
            Haptics.tryNotCounted()
            say(reason.message)
        }
        phase = attemptIndex + 1 < attempts.count ? .attemptResult : .finished
    }

    private func record(_ metrics: MovementMetrics) {
        switch metrics {
        case .armRaise(let side, let peak):
            if side == .left { leftPeaks.append(peak) } else { rightPeaks.append(peak) }
        case .sitToStand(let count):
            standCount = count
        case .balance(let foot, let hold, let sway):
            balanceResult = (foot, hold, sway)
        }
    }

    private func enterAligning() {
        alignment = .blocked
        elapsed = 0
        phase = .aligning
        say(aligningPrompt)
    }

    private var aligningPrompt: String {
        switch exercise {
        case .armRaise:
            let side = currentSide == .right ? "right" : "left"
            return "Try \(attemptIndex % config.armRaiseAttemptsPerSide + 1). Raise your \(side) arm out to the side. Stand so your whole body fits, then tap Start."
        case .sitToStand:
            return "Sit in the chair and cross your arms. Stand up and sit down for 30 seconds. Tap Start when you are ready."
        case .balance:
            return "Stand tall. Tap Start, then lift one foot and hold it."
        }
    }

    private func say(_ text: String) {
        prompt = text
        speech.speak(text)
    }

    // MARK: Result

    func makeSession() -> Session {
        let session = Session(exercise: exercise, acceptedTrials: acceptedTrials, rejectedTrials: rejectedTrials)
        switch exercise {
        case .armRaise:
            let summary = ArmRaiseSummary(leftAttempts: leftPeaks, rightAttempts: rightPeaks)
            session.leftBest = summary.left?.best
            session.leftAverage = summary.left?.average
            session.rightBest = summary.right?.best
            session.rightAverage = summary.right?.average
        case .sitToStand:
            session.standCount = standCount
        case .balance:
            session.holdSeconds = balanceResult?.hold
            session.swayRatio = balanceResult?.sway
            session.liftedFootRaw = balanceResult?.foot.rawValue
        }
        return session
    }

    var hasAnyNumbers: Bool { !makeSession().metrics.isEmpty }
}

enum SafetyText {
    static let message = "Before you start. Stand next to a stable support. Keep a person within arm's reach. Stop if you feel dizzy, have pain, or feel unsteady."
}

import Foundation

/// Front view, arms crossed, 30 seconds. Hip height is divided by torso length so the
/// count does not depend on how far the person stands from the camera.
final class SitToStandEngine: MovementEngine {
    let requiredJoints: Set<Joint> = Exercise.sitToStand.requiredJoints
    private let config: PoseConfig
    private var tracker: TrialTracker
    private var calibration: [Double] = []
    private var seatedHeight: Double?
    private var isStanding = false
    private var stands = 0

    init(config: PoseConfig = .standard) {
        self.config = config
        self.tracker = TrialTracker(required: Exercise.sitToStand.requiredJoints, config: config)
    }

    var isComplete: Bool { tracker.elapsed >= config.sitToStandSeconds }

    func start() {
        tracker = TrialTracker(required: requiredJoints, config: config)
        calibration = []
        seatedHeight = nil
        isStanding = false
        stands = 0
    }

    func ingest(_ frame: PoseFrame) {
        guard tracker.record(frame),
              let ls = frame.joints[.leftShoulder], let rs = frame.joints[.rightShoulder],
              let lh = frame.joints[.leftHip], let rh = frame.joints[.rightHip] else { return }

        let shoulderCenter = Geometry.midpoint(ls, rs)
        let hipCenter = Geometry.midpoint(lh, rh)
        let torsoLength = Geometry.distance(shoulderCenter, hipCenter)
        guard torsoLength > 0 else { return }
        let height = hipCenter.y / torsoLength

        guard let seated = seatedHeight else {
            calibration.append(height)
            if calibration.count >= config.seatedCalibrationFrames {
                seatedHeight = calibration.reduce(0, +) / Double(calibration.count)
            }
            return
        }

        let rise = height - seated
        // Two thresholds so small wobble near one line cannot count extra stands.
        if !isStanding, rise >= config.standRiseTorsoLengths {
            isStanding = true
            stands += 1
        } else if isStanding, rise <= config.sitDropTorsoLengths {
            isStanding = false
        }
    }

    func finish() -> TrialOutcome {
        if let reason = tracker.rejection() { return .rejected(reason) }
        guard seatedHeight != nil else { return .rejected(.lowConfidence) }
        return .accepted(.sitToStand(standCount: stands))
    }
}

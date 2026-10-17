import Foundation

/// One attempt on one side. The angle is between the torso vector (shoulder to hip)
/// and the upper arm vector (shoulder to elbow): about 0 with the arm down, 90 at shoulder height.
final class ArmRaiseEngine: MovementEngine {
    let side: Side
    let requiredJoints: Set<Joint>
    private let config: PoseConfig
    private var tracker: TrialTracker
    private var peak: Double?
    private var maxLean = 0.0

    init(side: Side, config: PoseConfig = .standard) {
        self.side = side
        self.config = config
        let required: Set<Joint> = [.leftShoulder, .rightShoulder,
                                    Joint.elbow(side), Joint.hip(side)]
        self.requiredJoints = required
        self.tracker = TrialTracker(required: required, config: config)
    }

    var isComplete: Bool { tracker.elapsed >= config.armRaiseMaxSeconds }

    func start() {
        tracker = TrialTracker(required: requiredJoints, config: config)
        peak = nil
        maxLean = 0
    }

    func ingest(_ frame: PoseFrame) {
        guard tracker.record(frame),
              let shoulder = frame.joints[Joint.shoulder(side)],
              let elbow = frame.joints[Joint.elbow(side)],
              let hip = frame.joints[Joint.hip(side)] else { return }

        let torso = Vec2(from: shoulder, to: hip)
        let arm = Vec2(from: shoulder, to: elbow)
        if let angle = Geometry.angleDegrees(torso, arm) {
            peak = max(peak ?? angle, angle)
        }
        // Straight down in image terms, since Y grows upward.
        if let lean = Geometry.angleDegrees(torso, Vec2(0, -1)) {
            maxLean = max(maxLean, lean)
        }
    }

    func finish() -> TrialOutcome {
        if let reason = tracker.rejection() { return .rejected(reason) }
        if maxLean > config.maxTrunkLeanDegrees { return .rejected(.trunkLean) }
        guard let peak else { return .rejected(.lowConfidence) }
        return .accepted(.armRaise(side: side, peakDegrees: peak))
    }
}

/// Best and average over the accepted attempts on each side.
struct ArmRaiseSummary: Equatable, Sendable {
    struct SideResult: Equatable, Sendable {
        var best: Double
        var average: Double
    }

    var left: SideResult?
    var right: SideResult?

    init(leftAttempts: [Double], rightAttempts: [Double]) {
        left = Self.result(leftAttempts)
        right = Self.result(rightAttempts)
    }

    private static func result(_ values: [Double]) -> SideResult? {
        guard let best = values.max() else { return nil }
        return SideResult(best: best, average: values.reduce(0, +) / Double(values.count))
    }
}

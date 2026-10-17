import Foundation

/// The lifted foot is the one whose ankle is higher, measured as a fraction of leg length.
/// Hold time stops at 10 seconds. Sway is the standard deviation of hip center x
/// divided by shoulder width.
final class BalanceEngine: MovementEngine {
    let requiredJoints: Set<Joint> = Exercise.balance.requiredJoints
    private let config: PoseConfig
    private var tracker: TrialTracker
    private var holdStart: TimeInterval?
    private var holdEnd: TimeInterval?
    private var liftedFoot: Side?
    private var hipCenterX: [Double] = []
    private var shoulderWidths: [Double] = []

    init(config: PoseConfig = .standard) {
        self.config = config
        self.tracker = TrialTracker(required: Exercise.balance.requiredJoints, config: config)
    }

    var isComplete: Bool {
        if holdEnd != nil { return true }
        if let start = holdStart { return tracker.lastTimestamp - start >= config.balanceHoldCapSeconds }
        return tracker.elapsed >= config.balanceMaxWaitSeconds
    }

    func start() {
        tracker = TrialTracker(required: requiredJoints, config: config)
        holdStart = nil
        holdEnd = nil
        liftedFoot = nil
        hipCenterX = []
        shoulderWidths = []
    }

    func ingest(_ frame: PoseFrame) {
        guard tracker.record(frame), holdEnd == nil,
              let ls = frame.joints[.leftShoulder], let rs = frame.joints[.rightShoulder],
              let lh = frame.joints[.leftHip], let rh = frame.joints[.rightHip],
              let la = frame.joints[.leftAnkle], let ra = frame.joints[.rightAnkle] else { return }

        let side: Side = la.y > ra.y ? .left : .right
        let lifted = side == .left ? la : ra
        let planted = side == .left ? ra : la
        let plantedHip = side == .left ? rh : lh
        let legLength = Geometry.distance(plantedHip, planted)
        guard legLength > 0 else { return }
        let ratio = (lifted.y - planted.y) / legLength

        if holdStart == nil {
            guard ratio >= config.balanceLiftStart else { return }
            holdStart = frame.timestamp
            liftedFoot = side
        } else if ratio < config.balanceLiftEnd {
            holdEnd = frame.timestamp
            return
        }

        hipCenterX.append(Geometry.midpoint(lh, rh).x)
        shoulderWidths.append(Geometry.distance(ls, rs))
    }

    func finish() -> TrialOutcome {
        if let reason = tracker.rejection() { return .rejected(reason) }
        guard let start = holdStart, let foot = liftedFoot, !shoulderWidths.isEmpty else {
            return .rejected(.lowConfidence)
        }
        let end = holdEnd ?? tracker.lastTimestamp
        let hold = min(end - start, config.balanceHoldCapSeconds)
        let meanWidth = shoulderWidths.reduce(0, +) / Double(shoulderWidths.count)
        guard meanWidth > 0 else { return .rejected(.lowConfidence) }
        let sway = Geometry.standardDeviation(hipCenterX) / meanWidth
        return .accepted(.balance(liftedFoot: foot, holdSeconds: hold, swayRatio: sway))
    }
}

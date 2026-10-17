import Foundation

enum RejectReason: String, Codable, Sendable {
    case tilt
    case lowConfidence
    case outOfFrame
    case trunkLean
    case noLift

    var message: String {
        switch self {
        case .tilt: return "The phone moved. Stand it up straight and try again."
        case .lowConfidence: return "The camera could not see you well. Try better light."
        case .outOfFrame: return "Part of your body left the picture. Step back and try again."
        case .trunkLean: return "Your body leaned too far. Stand tall and try again."
        case .noLift: return "We did not see a foot lift. Lift one foot off the floor and try again."
        }
    }
}

/// A trial is either accepted with numbers or rejected with a reason. There is no score.
enum TrialOutcome: Equatable, Sendable {
    case accepted(MovementMetrics)
    case rejected(RejectReason)
}

enum MovementMetrics: Equatable, Sendable {
    case armRaise(side: Side, peakDegrees: Double)
    case sitToStand(standCount: Int)
    case balance(liftedFoot: Side, holdSeconds: Double, swayRatio: Double)
}

protocol MovementEngine: AnyObject {
    var requiredJoints: Set<Joint> { get }
    /// True when the engine has all it needs and the trial can end.
    var isComplete: Bool { get }
    func start()
    func ingest(_ frame: PoseFrame)
    func finish() -> TrialOutcome
}

/// Shared bookkeeping: counts valid frames and notes tilt and edge problems.
struct TrialTracker {
    let config: PoseConfig
    let required: Set<Joint>
    private(set) var totalFrames = 0
    private(set) var validFrames = 0
    private(set) var edgeFrames = 0
    private(set) var tiltExceeded = false
    private(set) var firstTimestamp: TimeInterval?
    private(set) var lastTimestamp: TimeInterval = 0

    init(required: Set<Joint>, config: PoseConfig = .standard) {
        self.required = required
        self.config = config
    }

    var elapsed: TimeInterval { (firstTimestamp.map { lastTimestamp - $0 }) ?? 0 }

    /// Returns true when the frame has every required joint.
    mutating func record(_ frame: PoseFrame) -> Bool {
        if firstTimestamp == nil { firstTimestamp = frame.timestamp }
        lastTimestamp = frame.timestamp
        totalFrames += 1
        if frame.tiltDegrees > config.maxTiltDegrees { tiltExceeded = true }
        let valid = frame.has(required)
        if valid { validFrames += 1 }
        // Any joint on the edge counts: a cut-off body usually loses its required joints entirely.
        if frame.hasJointNearEdge(Set(frame.joints.keys), margin: config.edgeMarginFraction) { edgeFrames += 1 }
        return valid
    }

    /// Nil when the trial has enough good frames. Otherwise the reason to reject.
    func rejection() -> RejectReason? {
        if tiltExceeded { return .tilt }
        guard totalFrames > 0 else { return .lowConfidence }
        let fraction = Double(validFrames) / Double(totalFrames)
        if fraction < config.minValidFrameFraction {
            let invalid = totalFrames - validFrames
            return edgeFrames * 2 >= invalid ? .outOfFrame : .lowConfidence
        }
        return nil
    }
}

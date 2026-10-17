import Foundation

enum Side: String, Codable, CaseIterable, Sendable {
    case left, right

    var other: Side { self == .left ? .right : .left }
}

/// Anatomical joint names. Left means the person's left, never the image's left.
enum Joint: String, CaseIterable, Hashable, Sendable {
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle

    func minConfidence(_ config: PoseConfig = .standard) -> Double {
        switch self {
        case .leftShoulder, .rightShoulder, .leftHip, .rightHip:
            return config.shoulderHipConfidence
        default:
            return config.limbConfidence
        }
    }

    static func shoulder(_ side: Side) -> Joint { side == .left ? .leftShoulder : .rightShoulder }
    static func elbow(_ side: Side) -> Joint { side == .left ? .leftElbow : .rightElbow }
    static func hip(_ side: Side) -> Joint { side == .left ? .leftHip : .rightHip }
    static func ankle(_ side: Side) -> Joint { side == .left ? .leftAnkle : .rightAnkle }
}

/// A joint position in image pixels. Y grows upward, as Vision reports it.
/// Y is flipped only when drawing.
struct JointPoint: Equatable, Sendable {
    var x: Double
    var y: Double
    var confidence: Double
}

struct PoseFrame: Sendable {
    var timestamp: TimeInterval
    var imageWidth: Double
    var imageHeight: Double
    var joints: [Joint: JointPoint]
    /// Largest of the sideways and forward tilt of the phone at capture time.
    var tiltDegrees: Double

    init(timestamp: TimeInterval,
         imageWidth: Double,
         imageHeight: Double,
         joints: [Joint: JointPoint],
         tiltDegrees: Double = 0) {
        self.timestamp = timestamp
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.joints = joints
        self.tiltDegrees = tiltDegrees
    }

    func has(_ required: Set<Joint>) -> Bool {
        required.allSatisfy { joints[$0] != nil }
    }

    /// True when a present joint sits on the image edge, so the body is probably cut off.
    func hasJointNearEdge(_ required: Set<Joint>, margin: Double) -> Bool {
        let mx = imageWidth * margin
        let my = imageHeight * margin
        return required.contains { joint in
            guard let p = joints[joint] else { return false }
            return p.x < mx || p.x > imageWidth - mx || p.y < my || p.y > imageHeight - my
        }
    }
}

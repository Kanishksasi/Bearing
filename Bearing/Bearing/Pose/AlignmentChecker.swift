import Foundation

enum Exercise: String, Codable, CaseIterable, Identifiable, Sendable {
    case armRaise, sitToStand, balance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .armRaise: return "Arm raise"
        case .sitToStand: return "Sit to stand"
        case .balance: return "One-leg balance"
        }
    }

    var needsSafetyMessage: Bool { self != .armRaise }

    var requiredJoints: Set<Joint> {
        switch self {
        case .armRaise:
            return [.leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftHip, .rightHip]
        case .sitToStand:
            return [.leftShoulder, .rightShoulder, .leftHip, .rightHip]
        case .balance:
            return [.leftShoulder, .rightShoulder, .leftHip, .rightHip, .leftAnkle, .rightAnkle]
        }
    }

    /// Share of the image height the tracked body should fill.
    var bodyHeightRange: ClosedRange<Double> {
        switch self {
        case .armRaise, .sitToStand: return 0.2...0.55
        case .balance: return 0.5...0.9
        }
    }
}

struct AlignmentStatus: Equatable, Sendable {
    var jointsInFrame: Bool
    var shouldersLevel: Bool
    var distanceRight: Bool
    var tiltWithinLimit: Bool

    var canStart: Bool { jointsInFrame && shouldersLevel && distanceRight && tiltWithinLimit }

    static let blocked = AlignmentStatus(jointsInFrame: false,
                                         shouldersLevel: false,
                                         distanceRight: false,
                                         tiltWithinLimit: false)

    /// One short sentence that says what to fix first.
    var hint: String {
        if !tiltWithinLimit { return "Stand the phone up straight." }
        if !jointsInFrame { return "Step back so your whole body fits." }
        if !distanceRight { return "Move closer or farther until the box fills." }
        if !shouldersLevel { return "Level your shoulders." }
        return "Ready. Tap Start."
    }
}

/// Gates the Start button. Tilt is only checked here and during the trial. It is never corrected.
struct AlignmentChecker {
    let config: PoseConfig

    init(config: PoseConfig = .standard) {
        self.config = config
    }

    func check(_ frame: PoseFrame, for exercise: Exercise) -> AlignmentStatus {
        let required = exercise.requiredJoints
        let tiltOK = frame.tiltDegrees <= config.maxTiltDegrees
        let inFrame = frame.has(required)
            && !frame.hasJointNearEdge(required, margin: config.edgeMarginFraction)
        guard inFrame,
              let left = frame.joints[.leftShoulder],
              let right = frame.joints[.rightShoulder] else {
            return AlignmentStatus(jointsInFrame: false,
                                   shouldersLevel: false,
                                   distanceRight: false,
                                   tiltWithinLimit: tiltOK)
        }

        let slope = abs(atan2(right.y - left.y, right.x - left.x) * 180 / .pi)
        // A flat line reads 0 or 180 depending on which shoulder is on the left of the image.
        let tilt = min(slope, 180 - slope)

        let ys = required.compactMap { frame.joints[$0]?.y }
        let span = ((ys.max() ?? 0) - (ys.min() ?? 0)) / frame.imageHeight

        return AlignmentStatus(jointsInFrame: true,
                               shouldersLevel: tilt <= config.maxShoulderSlopeDegrees,
                               distanceRight: exercise.bodyHeightRange.contains(span),
                               tiltWithinLimit: tiltOK)
    }
}

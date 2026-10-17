import Foundation
@testable import Bearing

/// Builds synthetic frames. Coordinates are image pixels with Y up, in a 720 by 1280 image.
enum Synthetic {
    static let width = 720.0
    static let height = 1280.0

    static func frame(_ joints: [Joint: (Double, Double)],
                      t: TimeInterval = 0,
                      tilt: Double = 0,
                      confidence: Double = 0.9) -> PoseFrame {
        var map: [Joint: JointPoint] = [:]
        for (joint, p) in joints {
            map[joint] = JointPoint(x: p.0, y: p.1, confidence: confidence)
        }
        return PoseFrame(timestamp: t, imageWidth: width, imageHeight: height, joints: map, tiltDegrees: tilt)
    }

    /// Torso of 300 px: left shoulder (300, 800), left hip (300, 500). The left arm points where `elbow` says.
    static func armFrame(elbowOffset: (Double, Double),
                         hipShiftX: Double = 0,
                         includeElbow: Bool = true,
                         t: TimeInterval,
                         tilt: Double = 0) -> PoseFrame {
        var joints: [Joint: (Double, Double)] = [
            .leftShoulder: (300, 800), .rightShoulder: (420, 800),
            .leftHip: (300 + hipShiftX, 500), .rightHip: (420 + hipShiftX, 500)
        ]
        if includeElbow { joints[.leftElbow] = (300 + elbowOffset.0, 800 + elbowOffset.1) }
        return frame(joints, t: t, tilt: tilt)
    }

    /// Standing person for alignment and balance. Right ankle height is adjustable.
    static func standingFrame(rightAnkleY: Double = 100,
                              hipJitter: Double = 0,
                              t: TimeInterval = 0,
                              tilt: Double = 0) -> PoseFrame {
        frame([
            .leftShoulder: (250, 950), .rightShoulder: (350, 950),
            .leftHip: (260 + hipJitter, 600), .rightHip: (340 + hipJitter, 600),
            .leftAnkle: (260, 100), .rightAnkle: (340, rightAnkleY)
        ], t: t, tilt: tilt)
    }

    /// A seated or standing torso for sit to stand. Torso is 300 px.
    static func sitFrame(hipY: Double, t: TimeInterval) -> PoseFrame {
        frame([
            .leftShoulder: (300, hipY + 300), .rightShoulder: (420, hipY + 300),
            .leftHip: (300, hipY), .rightHip: (420, hipY)
        ], t: t)
    }
}

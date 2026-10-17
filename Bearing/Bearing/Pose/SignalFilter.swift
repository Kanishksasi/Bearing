import Foundation

/// Smooths joints with an exponential moving average.
/// A joint that drops out is held at its last good position for a few frames,
/// then removed, which makes any engine that needs it treat the frame as invalid.
struct SignalFilter {
    private let config: PoseConfig
    private var smoothed: [Joint: JointPoint] = [:]
    private var missedFrames: [Joint: Int] = [:]

    init(config: PoseConfig = .standard) {
        self.config = config
    }

    mutating func reset() {
        smoothed.removeAll()
        missedFrames.removeAll()
    }

    /// `raw` holds every joint Vision returned, with confidence, in image pixels.
    mutating func process(raw: [Joint: JointPoint],
                          timestamp: TimeInterval,
                          imageWidth: Double,
                          imageHeight: Double,
                          tiltDegrees: Double = 0) -> PoseFrame {
        for joint in Joint.allCases {
            if let point = raw[joint], point.confidence >= joint.minConfidence(config) {
                if let previous = smoothed[joint] {
                    let a = config.emaAlpha
                    smoothed[joint] = JointPoint(x: a * point.x + (1 - a) * previous.x,
                                                 y: a * point.y + (1 - a) * previous.y,
                                                 confidence: point.confidence)
                } else {
                    smoothed[joint] = point
                }
                missedFrames[joint] = 0
            } else if smoothed[joint] != nil {
                let missed = (missedFrames[joint] ?? 0) + 1
                missedFrames[joint] = missed
                if missed > config.maxHeldFrames {
                    smoothed[joint] = nil
                    missedFrames[joint] = nil
                }
            }
        }
        return PoseFrame(timestamp: timestamp,
                         imageWidth: imageWidth,
                         imageHeight: imageHeight,
                         joints: smoothed,
                         tiltDegrees: tiltDegrees)
    }
}

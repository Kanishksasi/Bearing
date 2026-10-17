import CoreVideo
import Vision

/// Runs Vision on one frame and returns smoothed joints in image pixels.
/// Call `process` only from the video queue: the filter and the request are not thread safe.
final class PoseService: @unchecked Sendable {
    // One request, reused for every frame.
    private let request = VNDetectHumanBodyPoseRequest()
    private var filter: SignalFilter

    private static let jointNames: [(Joint, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .leftShoulder), (.rightShoulder, .rightShoulder),
        (.leftElbow, .leftElbow), (.rightElbow, .rightElbow),
        (.leftWrist, .leftWrist), (.rightWrist, .rightWrist),
        (.leftHip, .leftHip), (.rightHip, .rightHip),
        (.leftKnee, .leftKnee), (.rightKnee, .rightKnee),
        (.leftAnkle, .leftAnkle), (.rightAnkle, .rightAnkle)
    ]

    init(config: PoseConfig = .standard) {
        filter = SignalFilter(config: config)
    }

    func reset() {
        filter.reset()
    }

    /// The buffer must already be upright, so no orientation is passed to Vision.
    func process(_ buffer: CVPixelBuffer, timestamp: TimeInterval, tiltDegrees: Double) -> PoseFrame? {
        let width = Double(CVPixelBufferGetWidth(buffer))
        let height = Double(CVPixelBufferGetHeight(buffer))
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        var raw: [Joint: JointPoint] = [:]
        if let observation = request.results?.first {
            for (joint, name) in Self.jointNames {
                guard let point = try? observation.recognizedPoint(name) else { continue }
                // Normalized to pixels before any angle math.
                raw[joint] = JointPoint(x: Double(point.location.x) * width,
                                        y: Double(point.location.y) * height,
                                        confidence: Double(point.confidence))
            }
        }
        return filter.process(raw: raw,
                              timestamp: timestamp,
                              imageWidth: width,
                              imageHeight: height,
                              tiltDegrees: tiltDegrees)
    }
}

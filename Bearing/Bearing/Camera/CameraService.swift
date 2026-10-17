import AVFoundation

enum CameraAccess {
    case notAsked, allowed, denied

    static var current: CameraAccess {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .allowed
        case .notDetermined: return .notAsked
        default: return .denied
        }
    }

    static func request() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}

/// Owns the capture session. Frames arrive on one dedicated serial queue and late frames are dropped.
final class CameraService: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()
    let position: AVCaptureDevice.Position

    /// Runs on the video queue for every frame.
    var onFrame: (@Sendable (CVPixelBuffer, TimeInterval) -> Void)?

    private let sessionQueue = DispatchQueue(label: "bearing.camera.session")
    private let videoQueue = DispatchQueue(label: "bearing.camera.video")
    private let output = AVCaptureVideoDataOutput()
    private var isConfigured = false

    /// Front camera by default. The rear camera is for caregiver mode.
    init(caregiverMode: Bool) {
        position = caregiverMode ? .back : .front
        super.init()
    }

    func start() {
        sessionQueue.async { [self] in
            if !isConfigured { configure() }
            if isConfigured, !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            // Upright, unmirrored data. Mirroring is done only for display.
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }

        let target = PoseConfig.standard.targetFramesPerSecond
        if (try? device.lockForConfiguration()) != nil {
            let supported = device.activeFormat.videoSupportedFrameRateRanges
                .contains { $0.minFrameRate <= target && target <= $0.maxFrameRate }
            if supported {
                let duration = CMTime(value: 1, timescale: CMTimeScale(target))
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
            }
            device.unlockForConfiguration()
        }
        isConfigured = true
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(buffer, CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds)
    }
}

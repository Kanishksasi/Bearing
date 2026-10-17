import Foundation

/// The only place thresholds live. Every engine and checker reads from here.
struct PoseConfig: Sendable {
    static let standard = PoseConfig()

    // Confidence tiers per joint
    var shoulderHipConfidence = 0.3
    var limbConfidence = 0.5

    // Smoothing
    var emaAlpha = 0.4
    var maxHeldFrames = 2

    // Trial validity
    var minValidFrameFraction = 0.8
    var edgeMarginFraction = 0.02

    // Pipeline
    var targetFramesPerSecond = 24.0

    // Alignment gate
    var maxTiltDegrees = 5.0
    var maxShoulderSlopeDegrees = 5.0

    // Arm raise
    var maxTrunkLeanDegrees = 15.0
    var armRaiseAttemptsPerSide = 3
    var armRaiseMaxSeconds = 8.0

    // Sit to stand (hip height measured in torso lengths above the seated start)
    var sitToStandSeconds = 30.0
    var standRiseTorsoLengths = 0.35
    var sitDropTorsoLengths = 0.15
    var seatedCalibrationFrames = 10

    // Balance (fractions of leg length)
    var balanceLiftStart = 0.12
    var balanceLiftEnd = 0.06
    var balanceHoldCapSeconds = 10.0
    var balanceMaxWaitSeconds = 15.0
}

import CoreMotion
import os

enum Tilt {
    /// Tilt of an upright phone from gravity, in degrees. Returns (sideways, forward and back).
    /// Upright in portrait means gravity points along the phone's negative y axis.
    static func degrees(gravityX x: Double, gravityY y: Double, gravityZ z: Double) -> (roll: Double, pitch: Double) {
        let roll = atan2(x, -y) * 180 / .pi
        let pitch = atan2(z, -y) * 180 / .pi
        return (abs(roll), abs(pitch))
    }
}

/// Reads phone tilt from CoreMotion. The latest value can be read from any thread.
final class TiltMonitor: @unchecked Sendable {
    private let motion = CMMotionManager()
    private let latest = OSAllocatedUnfairLock(initialState: 0.0)

    /// The larger of the sideways and forward tilt, in degrees.
    var currentDegrees: Double { latest.withLock { $0 } }

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let g = data?.gravity else { return }
            let t = Tilt.degrees(gravityX: g.x, gravityY: g.y, gravityZ: g.z)
            self.latest.withLock { $0 = max(t.roll, t.pitch) }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }
}

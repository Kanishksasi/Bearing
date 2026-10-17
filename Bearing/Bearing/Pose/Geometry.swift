import Foundation

struct Vec2: Equatable, Sendable {
    var x: Double
    var y: Double

    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    init(from a: JointPoint, to b: JointPoint) {
        self.init(b.x - a.x, b.y - a.y)
    }

    var length: Double { (x * x + y * y).squareRoot() }
}

enum Geometry {
    /// Angle between two vectors in degrees, 0 to 180. Returns nil for a zero-length vector.
    static func angleDegrees(_ a: Vec2, _ b: Vec2) -> Double? {
        let la = a.length
        let lb = b.length
        guard la > 0, lb > 0 else { return nil }
        let cosine = max(-1, min(1, (a.x * b.x + a.y * b.y) / (la * lb)))
        return acos(cosine) * 180 / .pi
    }

    static func distance(_ a: JointPoint, _ b: JointPoint) -> Double {
        Vec2(from: a, to: b).length
    }

    static func midpoint(_ a: JointPoint, _ b: JointPoint) -> JointPoint {
        JointPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, confidence: min(a.confidence, b.confidence))
    }

    static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance.squareRoot()
    }
}

/// Maps image pixels to view points. This is the only place x is mirrored and y is flipped.
enum DisplayMapper {
    static func point(_ p: JointPoint,
                      imageWidth: Double,
                      imageHeight: Double,
                      viewWidth: Double,
                      viewHeight: Double,
                      mirrored: Bool) -> (x: Double, y: Double) {
        var x = p.x / imageWidth * viewWidth
        if mirrored { x = viewWidth - x }
        let y = (1 - p.y / imageHeight) * viewHeight
        return (x, y)
    }
}

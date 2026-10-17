import SwiftUI

/// Draws the joints over the preview. Mirroring and the Y flip happen here through DisplayMapper.
struct SkeletonOverlay: View {
    let frame: PoseFrame?
    let mirrored: Bool

    private static let bones: [(Joint, Joint)] = [
        (.leftShoulder, .rightShoulder), (.leftHip, .rightHip),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
    ]

    var body: some View {
        Canvas { context, size in
            guard let frame else { return }
            func point(_ joint: Joint) -> CGPoint? {
                guard let p = frame.joints[joint] else { return nil }
                let mapped = DisplayMapper.point(p,
                                                 imageWidth: frame.imageWidth,
                                                 imageHeight: frame.imageHeight,
                                                 viewWidth: size.width,
                                                 viewHeight: size.height,
                                                 mirrored: mirrored)
                return CGPoint(x: mapped.x, y: mapped.y)
            }
            for (a, b) in Self.bones {
                guard let pa = point(a), let pb = point(b) else { continue }
                var path = Path()
                path.move(to: pa)
                path.addLine(to: pb)
                context.stroke(path, with: .color(.green), lineWidth: 3)
            }
            for joint in Joint.allCases {
                guard let p = point(joint) else { continue }
                context.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(.white))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

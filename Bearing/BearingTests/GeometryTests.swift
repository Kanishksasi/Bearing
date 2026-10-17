import XCTest
@testable import Bearing

final class GeometryTests: XCTestCase {
    func testPerpendicularVectorsAre90Degrees() throws {
        let angle = try XCTUnwrap(Geometry.angleDegrees(Vec2(0, -300), Vec2(200, 0)))
        XCTAssertEqual(angle, 90, accuracy: 0.0001)
    }

    func testSameDirectionIsZeroAndOppositeIs180() throws {
        XCTAssertEqual(try XCTUnwrap(Geometry.angleDegrees(Vec2(0, -1), Vec2(0, -5))), 0, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(Geometry.angleDegrees(Vec2(0, -1), Vec2(0, 5))), 180, accuracy: 0.0001)
    }

    func testFortyFiveDegrees() throws {
        let angle = try XCTUnwrap(Geometry.angleDegrees(Vec2(0, -300), Vec2(200, -200)))
        XCTAssertEqual(angle, 45, accuracy: 0.0001)
    }

    func testZeroLengthVectorGivesNil() {
        XCTAssertNil(Geometry.angleDegrees(Vec2(0, 0), Vec2(1, 0)))
    }

    func testStandardDeviation() {
        XCTAssertEqual(Geometry.standardDeviation([2, 4, 4, 4, 5, 5, 7, 9]), 2, accuracy: 0.0001)
        XCTAssertEqual(Geometry.standardDeviation([5]), 0)
    }

    func testDisplayMapperFlipsYAndMirrorsXOnce() {
        let p = JointPoint(x: 100, y: 1000, confidence: 1)
        let plain = DisplayMapper.point(p, imageWidth: 720, imageHeight: 1280, viewWidth: 360, viewHeight: 640, mirrored: false)
        XCTAssertEqual(plain.x, 50, accuracy: 0.0001)
        XCTAssertEqual(plain.y, (1 - 1000.0 / 1280.0) * 640, accuracy: 0.0001)
        let mirrored = DisplayMapper.point(p, imageWidth: 720, imageHeight: 1280, viewWidth: 360, viewHeight: 640, mirrored: true)
        XCTAssertEqual(mirrored.x, 310, accuracy: 0.0001)
        XCTAssertEqual(mirrored.y, plain.y, accuracy: 0.0001)
    }

    func testTiltFromGravity() {
        let upright = Tilt.degrees(gravityX: 0, gravityY: -1, gravityZ: 0)
        XCTAssertEqual(upright.roll, 0, accuracy: 0.0001)
        XCTAssertEqual(upright.pitch, 0, accuracy: 0.0001)

        let r = 10.0 * .pi / 180
        let rolled = Tilt.degrees(gravityX: sin(r), gravityY: -cos(r), gravityZ: 0)
        XCTAssertEqual(rolled.roll, 10, accuracy: 0.0001)

        let p = 7.0 * .pi / 180
        let leaned = Tilt.degrees(gravityX: 0, gravityY: -cos(p), gravityZ: sin(p))
        XCTAssertEqual(leaned.pitch, 7, accuracy: 0.0001)
    }

    func testConfidenceTiersLiveInOneConfig() {
        let config = PoseConfig.standard
        XCTAssertEqual(Joint.leftShoulder.minConfidence(config), 0.3)
        XCTAssertEqual(Joint.rightHip.minConfidence(config), 0.3)
        for joint in [Joint.leftElbow, .rightWrist, .leftKnee, .rightAnkle] {
            XCTAssertEqual(joint.minConfidence(config), 0.5)
        }
        XCTAssertEqual(config.emaAlpha, 0.4)
        XCTAssertEqual(config.maxHeldFrames, 2)
        XCTAssertEqual(config.minValidFrameFraction, 0.8)
    }
}

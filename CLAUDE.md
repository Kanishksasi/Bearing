# Bearing

Bearing is an offline iPhone app for the Congressional App Challenge, Arkansas 3rd District. A user films a short guided routine (arm raise, sit to stand, single-leg balance). The app measures movement on the device, compares it with the user's own baseline, and exports a one-page PDF to share with a clinician. It is a personal tracking tool, not a medical device.

## Stack
iOS 17, Swift 5.9 or later, SwiftUI, AVFoundation, Vision (VNDetectHumanBodyPoseRequest), CoreMotion, SwiftData, AVSpeechSynthesizer, UIGraphicsPDFRenderer, Swift Charts, XCTest. No third-party packages. No network code.

## Folders
App, Camera, Pose, Engines, Storage, Reporting, Accessibility, Views, Tests.

## Modules
CameraService, PoseService, SignalFilter, AlignmentChecker, MovementEngine (protocol: start, ingest(frame), finish, returns metrics), ArmRaiseEngine, SitToStandEngine, BalanceEngine, SessionStore, BaselineService, ReportBuilder, SpeechCoach, Views.

## Locked rules
- Compute all metrics from Vision anatomical joint names (leftShoulder, rightShoulder, and so on). Mirroring is display only and happens in exactly one place, the overlay and preview. Never flip x twice.
- Convert Vision normalized points to pixels with the frame size before any angle math. Flip Y only for drawing.
- Confidence tiers per joint: 0.3 for shoulders and hips, 0.5 for elbows, knees, wrists, ankles. A trial is valid only if required joints pass in at least 80 percent of frames. Keep these values in one config struct.
- Smoothing: exponential moving average, alpha 0.4. For a dropped joint, hold the last good position for at most two frames, then mark the frame invalid.
- Pipeline: one reused Vision request, a dedicated serial queue, alwaysDiscardsLateVideoFrames = true, UI state on the main actor. Target 24 frames per second.
- Front camera by default. Rear camera in caregiver mode.
- Alignment gate: Start stays disabled until required joints are in frame, shoulders are level, body height is in the target range, and device roll and pitch are within 5 degrees (CoreMotion). Gate on tilt. Do not compensate for it later.
- Trial quality is reject or accept only. No numeric score. Reject for tilt over 5 degrees, low confidence, body out of frame, or (arm raise) trunk lean over a set limit.
- Arm raise: angle between torso vector (shoulder to hip) and upper arm vector (shoulder to elbow), left and right, three attempts per side, report best and average as a range.
- Sit to stand: front view, arms crossed, 30 seconds, hip height normalized by torso length, hysteresis on up and down thresholds.
- Balance: lifted foot found by ankle height difference as a fraction of leg length. Hold capped at 10 seconds. Sway is the standard deviation of hip center x divided by shoulder width.
- Safety: sit to stand and balance show a message first: stand next to a stable support, keep a person within arm's reach, stop for dizziness, pain, or unsteadiness.
- Data: SwiftData models Session and UserSettings only. Never store video, images, location, or device identifiers. Frames live in memory and are discarded. Include a "delete all my data" action.

## Words in app text
Use: personal movement tracking, measures, tracks, compare with your own baseline, share with your clinician.
Never use: diagnose, diagnosis, detect (clinical sense), assess, evaluate, treat, clinical, screening, patient, normal, abnormal, good, poor, pass, fail.
Every result screen and the PDF must show exactly: "For personal tracking only. Not medical advice or a diagnosis. Share with your clinician."
App text should be at a sixth-grade reading level. No thresholds, no normal ranges, no health claims.

## Code rules
- Complete, compiling code. State any assumption about types.
- Comments only where the reason is not obvious.
- Every piece of pose logic gets XCTests using synthetic joint sets with known angles, or recorded joint sequences (coordinates only, never video).
- Do not add accounts, analytics, networking, or packages. Do not expand scope.
- Do not use em dashes in any text you write.
- After each task, give a three sentence plain explanation a student can say to a judge.

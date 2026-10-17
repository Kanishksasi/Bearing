import Foundation
import SwiftData

/// One finished routine. Holds numbers only: no video, images, location, or device identifiers.
@Model
final class Session {
    var date: Date
    var exerciseRaw: String
    var leftBest: Double?
    var leftAverage: Double?
    var rightBest: Double?
    var rightAverage: Double?
    var standCount: Int?
    var holdSeconds: Double?
    var swayRatio: Double?
    var liftedFootRaw: String?
    var acceptedTrials: Int
    var rejectedTrials: Int

    init(date: Date = Date(),
         exercise: Exercise,
         acceptedTrials: Int,
         rejectedTrials: Int) {
        self.date = date
        self.exerciseRaw = exercise.rawValue
        self.acceptedTrials = acceptedTrials
        self.rejectedTrials = rejectedTrials
    }

    var exercise: Exercise { Exercise(rawValue: exerciseRaw) ?? .armRaise }

    /// Numbers to show, in order. Used by the result screen, the PDF, and the baseline compare.
    var metrics: [SessionMetric] {
        switch exercise {
        case .armRaise:
            var list: [SessionMetric] = []
            if let b = leftBest, let a = leftAverage {
                list.append(SessionMetric(label: "Left arm best", value: b, unit: "degrees"))
                list.append(SessionMetric(label: "Left arm average", value: a, unit: "degrees"))
            }
            if let b = rightBest, let a = rightAverage {
                list.append(SessionMetric(label: "Right arm best", value: b, unit: "degrees"))
                list.append(SessionMetric(label: "Right arm average", value: a, unit: "degrees"))
            }
            return list
        case .sitToStand:
            return standCount.map { [SessionMetric(label: "Stands in 30 seconds", value: Double($0), unit: "stands")] } ?? []
        case .balance:
            var list: [SessionMetric] = []
            if let h = holdSeconds { list.append(SessionMetric(label: "Hold time", value: h, unit: "seconds")) }
            if let s = swayRatio { list.append(SessionMetric(label: "Sway", value: s, unit: "of shoulder width")) }
            return list
        }
    }
}

struct SessionMetric: Equatable, Sendable {
    var label: String
    var value: Double
    var unit: String

    var text: String {
        unit == "stands" ? String(Int(value)) : String(format: unit == "of shoulder width" ? "%.2f" : "%.1f", value)
    }
}

@Model
final class UserSettings {
    var caregiverMode: Bool
    var spokenPrompts: Bool

    init(caregiverMode: Bool = false, spokenPrompts: Bool = true) {
        self.caregiverMode = caregiverMode
        self.spokenPrompts = spokenPrompts
    }
}

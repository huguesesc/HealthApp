import Foundation
import SwiftData

/// A cross-module action worth rewarding or reminding on. Many modules emit these
/// (logged a meal, completed a workout, stayed under a screen-time budget); the
/// `RewardsEngine` consumes the stream to compute streaks and rewards. Keeping this
/// as one shared event log — rather than reward logic embedded in each feature —
/// is what keeps the rewards system from becoming tangled later.
@Model
final class ActivityEvent {
    var timestamp: Date
    /// Stored as the raw value of `ActivityEventType` for forward compatibility.
    var typeRaw: String
    /// Optional human-readable context (e.g. the meal text or workout type).
    var detail: String?

    init(timestamp: Date = .now, type: ActivityEventType, detail: String? = nil) {
        self.timestamp = timestamp
        self.typeRaw = type.rawValue
        self.detail = detail
    }

    var type: ActivityEventType? { ActivityEventType(rawValue: typeRaw) }
}

enum ActivityEventType: String, Codable, CaseIterable {
    case mealLogged
    case workoutCompleted
    case sleepLogged
    case checkInCompleted
    case screenTimeUnderBudget
    case screenTimeOverride
}

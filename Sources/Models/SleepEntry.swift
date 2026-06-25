import Foundation
import SwiftData

/// Manually entered sleep data. HealthKit may populate this automatically later.
@Model
final class SleepEntry {
    /// The night this entry covers (the calendar day of waking).
    var date: Date
    var bedtime: Date?
    var wakeTime: Date?
    /// Perceived quality, 1–5.
    var perceivedQuality: Int?
    var napMinutes: Int?
    /// Tiredness on waking, 1–5.
    var tiredness: Int?

    init(date: Date = .now, bedtime: Date? = nil, wakeTime: Date? = nil,
         perceivedQuality: Int? = nil, napMinutes: Int? = nil, tiredness: Int? = nil) {
        self.date = date
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.perceivedQuality = perceivedQuality
        self.napMinutes = napMinutes
        self.tiredness = tiredness
    }
}

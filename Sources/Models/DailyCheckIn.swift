import Foundation
import SwiftData

/// A short daily self-report. All fields 1–5 unless noted.
@Model
final class DailyCheckIn {
    var date: Date
    var energy: Int?
    var mood: Int?
    var hunger: Int?
    var soreness: Int?
    var focus: Int?
    var stress: Int?
    /// Subjective sense of screen-time, independent of the Screen Time API.
    var screenTimeFeeling: Int?
    /// Free-text note for the day.
    var note: String?

    init(date: Date = .now, energy: Int? = nil, mood: Int? = nil, hunger: Int? = nil,
         soreness: Int? = nil, focus: Int? = nil, stress: Int? = nil,
         screenTimeFeeling: Int? = nil, note: String? = nil) {
        self.date = date
        self.energy = energy
        self.mood = mood
        self.hunger = hunger
        self.soreness = soreness
        self.focus = focus
        self.stress = stress
        self.screenTimeFeeling = screenTimeFeeling
        self.note = note
    }
}

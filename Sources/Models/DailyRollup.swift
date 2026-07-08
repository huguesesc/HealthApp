import Foundation
import SwiftData

/// A compact, structured per-day summary. This is the "cheap history" layer: the
/// central assistant and trend views read these small records over weeks instead of
/// re-reading thousands of raw rows, which keeps AI token cost low.
///
/// One row per calendar day (the repository normalises `date` to start-of-day and
/// upserts). `summaryText` optionally holds the AI-generated daily summary.
@Model
final class DailyRollup {
    /// Start-of-day for the day this rollup covers.
    var date: Date

    var mealsLogged: Int
    var totalCalories: Int?

    var workoutCompleted: Bool
    var workoutType: String?

    var sleepHours: Double?
    var sleepQuality: Int?

    var energy: Int?
    var mood: Int?

    /// Read-only Apple Health imports. These are compact daily aggregates, not raw
    /// HealthKit samples.
    var healthStepCount: Int?
    var healthActiveEnergyKcal: Int?
    var healthExerciseMinutes: Int?
    var healthWorkoutCount: Int?
    var healthWorkoutSummary: String?
    var healthSleepHours: Double?
    var healthRestingHeartRate: Int?

    /// Coarse screen-time signal for the day (see ScreenTimeSnapshot / architecture).
    var screenTimeExceeded: Bool?

    /// AI-generated narrative summary, if one has been produced.
    var summaryText: String?
    /// The model that produced `summaryText`, for traceability.
    var modelUsed: String?

    init(
        date: Date,
        mealsLogged: Int = 0,
        totalCalories: Int? = nil,
        workoutCompleted: Bool = false,
        workoutType: String? = nil,
        sleepHours: Double? = nil,
        sleepQuality: Int? = nil,
        energy: Int? = nil,
        mood: Int? = nil,
        healthStepCount: Int? = nil,
        healthActiveEnergyKcal: Int? = nil,
        healthExerciseMinutes: Int? = nil,
        healthWorkoutCount: Int? = nil,
        healthWorkoutSummary: String? = nil,
        healthSleepHours: Double? = nil,
        healthRestingHeartRate: Int? = nil,
        screenTimeExceeded: Bool? = nil,
        summaryText: String? = nil,
        modelUsed: String? = nil
    ) {
        self.date = date
        self.mealsLogged = mealsLogged
        self.totalCalories = totalCalories
        self.workoutCompleted = workoutCompleted
        self.workoutType = workoutType
        self.sleepHours = sleepHours
        self.sleepQuality = sleepQuality
        self.energy = energy
        self.mood = mood
        self.healthStepCount = healthStepCount
        self.healthActiveEnergyKcal = healthActiveEnergyKcal
        self.healthExerciseMinutes = healthExerciseMinutes
        self.healthWorkoutCount = healthWorkoutCount
        self.healthWorkoutSummary = healthWorkoutSummary
        self.healthSleepHours = healthSleepHours
        self.healthRestingHeartRate = healthRestingHeartRate
        self.screenTimeExceeded = screenTimeExceeded
        self.summaryText = summaryText
        self.modelUsed = modelUsed
    }
}

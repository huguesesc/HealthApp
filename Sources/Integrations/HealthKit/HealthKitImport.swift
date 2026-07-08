import Foundation

/// Compact per-day HealthKit import. This is the only shape that leaves the
/// HealthKit layer: raw samples stay local to the sync service.
struct HealthKitDailyImport: Codable, Equatable, Sendable {
    var date: Date
    var stepCount: Int?
    var activeEnergyKcal: Int?
    var exerciseMinutes: Int?
    var workoutCount: Int?
    var workoutSummary: String?
    var sleepHours: Double?
    var restingHeartRate: Int?

    init(
        date: Date,
        stepCount: Int? = nil,
        activeEnergyKcal: Int? = nil,
        exerciseMinutes: Int? = nil,
        workoutCount: Int? = nil,
        workoutSummary: String? = nil,
        sleepHours: Double? = nil,
        restingHeartRate: Int? = nil
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.stepCount = stepCount
        self.activeEnergyKcal = activeEnergyKcal
        self.exerciseMinutes = exerciseMinutes
        self.workoutCount = workoutCount
        self.workoutSummary = workoutSummary
        self.sleepHours = sleepHours
        self.restingHeartRate = restingHeartRate
    }
}

enum HealthKitImportMerger {
    static func apply(_ imported: HealthKitDailyImport, to rollup: DailyRollup) {
        rollup.healthStepCount = imported.stepCount
        rollup.healthActiveEnergyKcal = imported.activeEnergyKcal
        rollup.healthExerciseMinutes = imported.exerciseMinutes
        rollup.healthWorkoutCount = imported.workoutCount
        rollup.healthWorkoutSummary = imported.workoutSummary
        rollup.healthSleepHours = imported.sleepHours
        rollup.healthRestingHeartRate = imported.restingHeartRate
    }
}

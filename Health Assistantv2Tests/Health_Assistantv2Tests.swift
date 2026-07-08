import Foundation
import Testing
@testable import Health_Assistantv2

struct Health_Assistantv2Tests {
    @Test func healthKitImportFillsHealthFieldsWithoutOverwritingManualRollupData() async throws {
        let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_788_739_200))
        let rollup = DailyRollup(
            date: day,
            mealsLogged: 2,
            totalCalories: 640,
            workoutCompleted: true,
            workoutType: "Push",
            sleepHours: nil,
            sleepQuality: 4,
            energy: 3,
            mood: 4
        )

        let imported = HealthKitDailyImport(
            date: day,
            stepCount: 8_420,
            activeEnergyKcal: 430,
            exerciseMinutes: 36,
            workoutCount: 1,
            workoutSummary: "Outdoor run, 32 min",
            sleepHours: 7.25,
            restingHeartRate: 58
        )

        HealthKitImportMerger.apply(imported, to: rollup)

        #expect(rollup.mealsLogged == 2)
        #expect(rollup.totalCalories == 640)
        #expect(rollup.workoutCompleted)
        #expect(rollup.workoutType == "Push")
        #expect(rollup.sleepQuality == 4)
        #expect(rollup.energy == 3)
        #expect(rollup.mood == 4)

        #expect(rollup.healthStepCount == 8_420)
        #expect(rollup.healthActiveEnergyKcal == 430)
        #expect(rollup.healthExerciseMinutes == 36)
        #expect(rollup.healthWorkoutCount == 1)
        #expect(rollup.healthWorkoutSummary == "Outdoor run, 32 min")
        #expect(rollup.healthSleepHours == 7.25)
        #expect(rollup.healthRestingHeartRate == 58)
    }
}

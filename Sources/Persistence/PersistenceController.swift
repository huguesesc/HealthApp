import Foundation
import SwiftData

/// Owns the SwiftData container. One shared instance for the app, one in-memory
/// instance for previews and tests.
struct PersistenceController {
    static let shared = PersistenceController()
    static let preview = PersistenceController(inMemory: true)

    let container: ModelContainer

    private static let schema = Schema([
        Meal.self,
        WorkoutSession.self,
        ExerciseSet.self,
        SleepEntry.self,
        DailyCheckIn.self,
        DailyRollup.self,
        ActivityEvent.self,
        ScreenTimeSnapshot.self,
        HealthProfile.self,
        HealthConsideration.self,
        BodyMetricEntry.self,
        WorkoutLocation.self,
        EquipmentItem.self,
        WorkoutPlan.self,
        WorkoutStep.self,
        ActiveWorkoutSession.self,
        ActiveWorkoutStep.self,
    ])

    init(inMemory: Bool = false) {
        let config = ModelConfiguration(
            schema: Self.schema,
            isStoredInMemoryOnly: inMemory
        )
        container = Self.makeContainer(config)
    }

    private static func makeContainer(_ configuration: ModelConfiguration) -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}

import Foundation
import SwiftData

/// Owns the SwiftData container. One shared instance for the app, one in-memory
/// instance for previews and tests.
struct PersistenceController {
    static let shared = PersistenceController()
    static let preview = PersistenceController(inMemory: true)

    let container: ModelContainer

    private static let schema = Schema(versionedSchema: HealthAppSchemaV2.self)

    init(inMemory: Bool = false) {
        let config = ModelConfiguration(
            schema: Self.schema,
            isStoredInMemoryOnly: inMemory
        )
        container = Self.makeContainer(config)
    }

    /// Opens an explicitly located store. The app does not use this path in
    /// production; migration tests use it to copy and open immutable fixtures.
    init(storeURL: URL) throws {
        let config = ModelConfiguration(
            "HealthApp",
            schema: Self.schema,
            url: storeURL
        )
        container = try ModelContainer(for: Self.schema, configurations: config)
    }

    private static func makeContainer(_ configuration: ModelConfiguration) -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}

/// The original app store used SwiftData's implicit 1.0.0 schema. Version 2 is
/// deliberately additive: its only changes are optional scalar properties, so
/// SwiftData can perform an inferred lightweight migration without rewriting
/// historical values.
enum HealthAppSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
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
            MovementFeedbackEntry.self,
        ]
    }
}

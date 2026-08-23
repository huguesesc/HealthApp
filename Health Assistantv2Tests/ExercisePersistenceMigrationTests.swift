import Foundation
import SwiftData
import XCTest
@testable import Health_Assistantv2

@MainActor
final class ExercisePersistenceMigrationTests: XCTestCase {
    func testPriorSchemaStoreOpensReopensAndPreservesSnapshots() throws {
        try withCopiedPriorStore { storeURL in
            do {
                let controller = try PersistenceController(storeURL: storeURL)
                let context = controller.container.mainContext

                let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<HealthProfile>()).first)
                XCTAssertEqual(profile.notes, "T16 prior-schema profile")
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutLocation>()), 1)
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<EquipmentItem>()), 1)

                let plan = try XCTUnwrap(try context.fetch(FetchDescriptor<WorkoutPlan>()).first)
                XCTAssertEqual(plan.title, "T16 Prior Plan")
                XCTAssertEqual(plan.orderedSteps.map(\.title), [
                    "Goblet squat",
                    "Coach's custom reach",
                ])
                XCTAssertEqual(plan.orderedSteps.map(\.instruction), [
                    "Historical goblet instruction",
                    "Historical custom instruction",
                ])
                XCTAssertTrue(plan.orderedSteps.allSatisfy { $0.exerciseIDSnapshot == nil })

                let active = try XCTUnwrap(
                    try context.fetch(FetchDescriptor<ActiveWorkoutSession>()).first
                )
                XCTAssertEqual(active.status, .inProgress)
                XCTAssertEqual(active.accumulatedActiveSeconds, 73)
                XCTAssertEqual(active.currentStep?.title, "Goblet squat")
                XCTAssertEqual(active.currentStep?.completedSets, 1)
                XCTAssertTrue(active.orderedSteps.allSatisfy { $0.exerciseIDSnapshot == nil })

                let history = try XCTUnwrap(
                    try context.fetch(FetchDescriptor<WorkoutSession>()).first
                )
                XCTAssertEqual(history.type, "T16 Historical Session")
                XCTAssertEqual(history.sets.sorted(by: { $0.order < $1.order }).map(\.exerciseName), [
                    "Retired exercise name",
                    "User custom exercise",
                ])
                XCTAssertTrue(history.sets.allSatisfy { $0.exerciseIDSnapshot == nil })
            }

            do {
                let reopened = try PersistenceController(storeURL: storeURL)
                let context = reopened.container.mainContext
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutPlan>()), 1)
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<ActiveWorkoutSession>()), 1)
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 1)
            }
        }
    }

    func testMigratedWorkoutResumesBackfillsExactOnlyAndCompletesExactlyOnce() throws {
        try withCopiedPriorStore { storeURL in
            do {
                let controller = try PersistenceController(storeURL: storeURL)
                let context = controller.container.mainContext
                let repository = HealthDataRepository(context: context)
                let report = try repository.backfillLegacyExerciseIDs(
                    using: [gobletSquat(displayName: "Goblet squat")]
                )

                XCTAssertEqual(report.workoutStepsUpdated, 1)
                XCTAssertEqual(report.activeWorkoutStepsUpdated, 1)
                XCTAssertEqual(report.exerciseSetsUpdated, 0)
                XCTAssertEqual(report.totalUpdated, 2)
                XCTAssertEqual(report.ambiguousReferences, 0)
                XCTAssertEqual(report.unresolvedReferences, 4)

                let plan = try XCTUnwrap(try context.fetch(FetchDescriptor<WorkoutPlan>()).first)
                XCTAssertEqual(plan.orderedSteps[0].exerciseIDSnapshot, "dumbbell.goblet_squat")
                XCTAssertNil(plan.orderedSteps[1].exerciseIDSnapshot)
                XCTAssertEqual(plan.orderedSteps[0].title, "Goblet squat")
                XCTAssertEqual(plan.orderedSteps[0].instruction, "Historical goblet instruction")

                let session = try XCTUnwrap(
                    try context.fetch(FetchDescriptor<ActiveWorkoutSession>()).first
                )
                let goblet = try XCTUnwrap(session.currentStep)
                XCTAssertEqual(goblet.exerciseIDSnapshot, "dumbbell.goblet_squat")
                XCTAssertEqual(goblet.completedSets, 1)
                XCTAssertTrue(
                    repository.completeActiveWorkoutSet(
                        goblet,
                        reps: 8,
                        weightKilograms: 12
                    )
                )

                let custom = try XCTUnwrap(session.currentStep)
                XCTAssertEqual(custom.title, "Coach's custom reach")
                XCTAssertNil(custom.exerciseIDSnapshot)
                XCTAssertTrue(
                    repository.completeActiveWorkoutSet(
                        custom,
                        reps: 5,
                        weightKilograms: nil
                    )
                )

                repository.finishActiveWorkout(session, actualEffort: 6, notes: "Migrated finish")
                repository.finishActiveWorkout(session, actualEffort: 6, notes: "Duplicate finish")

                XCTAssertEqual(repository.allWorkouts().count, 2)
                let completed = try XCTUnwrap(
                    repository.allWorkouts().first { $0.type == "T16 Prior Plan" }
                )
                let completedSets = completed.sets.sorted { $0.order < $1.order }
                XCTAssertEqual(completedSets.map(\.exerciseName), [
                    "Goblet squat",
                    "Goblet squat",
                    "Coach's custom reach",
                ])
                XCTAssertEqual(completedSets.map(\.exerciseIDSnapshot), [
                    "dumbbell.goblet_squat",
                    "dumbbell.goblet_squat",
                    nil,
                ])

                let renamedDefinition = gobletSquat(displayName: "Goblet squat renamed")
                XCTAssertEqual(renamedDefinition.id.rawValue, "dumbbell.goblet_squat")
                XCTAssertEqual(completedSets[0].exerciseName, "Goblet squat")
            }

            do {
                let reopened = try PersistenceController(storeURL: storeURL)
                let context = reopened.container.mainContext
                let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
                XCTAssertEqual(sessions.count, 2)
                XCTAssertEqual(
                    sessions.first { $0.type == "T16 Historical Session" }?.sets
                        .sorted(by: { $0.order < $1.order })
                        .map(\.exerciseName),
                    ["Retired exercise name", "User custom exercise"]
                )
                let active = try XCTUnwrap(
                    try context.fetch(FetchDescriptor<ActiveWorkoutSession>()).first
                )
                XCTAssertEqual(active.status, .completed)
                XCTAssertTrue(active.workoutLogCreated)
            }
        }
    }

    func testNewCanonicalReferencePropagatesPlanToActiveToHistory() throws {
        let controller = PersistenceController(inMemory: true)
        let repository = HealthDataRepository(context: controller.container.mainContext)
        let plan = WorkoutPlan(title: "Canonical plan")
        repository.addWorkoutPlan(plan)
        repository.addWorkoutStep(
            WorkoutStep(
                order: 0,
                type: .exercise,
                exerciseIDSnapshot: "dumbbell.goblet_squat",
                title: "Historical display snapshot",
                instruction: "Historical instruction snapshot",
                sets: 1,
                reps: 8
            ),
            to: plan
        )

        let active = try XCTUnwrap(repository.startActiveWorkout(from: plan))
        let step = try XCTUnwrap(active.currentStep)
        XCTAssertEqual(step.exerciseIDSnapshot, "dumbbell.goblet_squat")
        XCTAssertEqual(step.title, "Historical display snapshot")
        XCTAssertTrue(
            repository.completeActiveWorkoutSet(
                step,
                reps: 8,
                weightKilograms: nil
            )
        )
        repository.finishActiveWorkout(active, actualEffort: nil, notes: nil)

        let set = try XCTUnwrap(repository.allWorkouts().first?.sets.first)
        XCTAssertEqual(set.exerciseIDSnapshot, "dumbbell.goblet_squat")
        XCTAssertEqual(set.exerciseName, "Historical display snapshot")

        let snapshot = try XCTUnwrap(repository.workoutPlanSnapshots().first?.steps.first)
        XCTAssertEqual(snapshot.exerciseIDSnapshot, "dumbbell.goblet_squat")
        XCTAssertEqual(snapshot.title, "Historical display snapshot")
        XCTAssertEqual(snapshot.instruction, "Historical instruction snapshot")
    }

    private func withCopiedPriorStore(
        _ body: (URL) throws -> Void
    ) throws {
        let sourceFilePath = #filePath.removingPercentEncoding ?? #filePath
        let fixtureDirectory = URL(fileURLWithPath: sourceFilePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("T16PriorSchema", isDirectory: true)
        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: workingDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: workingDirectory) }

        let storeURL = workingDirectory.appendingPathComponent("HealthApp.store")
        for suffix in ["", "-wal", "-shm"] {
            try FileManager.default.copyItem(
                at: fixtureDirectory.appendingPathComponent("HealthApp.store" + suffix),
                to: workingDirectory.appendingPathComponent("HealthApp.store" + suffix)
            )
        }
        try body(storeURL)
    }

    private func gobletSquat(displayName: String) -> ExerciseDefinition {
        ExerciseDefinition(
            id: ExerciseID(rawValue: "dumbbell.goblet_squat")!,
            schemaVersion: 1,
            displayName: displayName,
            category: ExerciseCategory(rawValue: "strength"),
            movementPattern: ExerciseMovementPattern(rawValue: "squat"),
            exerciseType: ExerciseType(rawValue: "repetition"),
            equipment: ExerciseEquipmentRequirements(
                required: [
                    ExerciseEquipmentClause(
                        id: ExerciseEquipmentID(rawValue: "dumbbell"),
                        quantity: 1
                    ),
                ]
            ),
            trackingMode: ExerciseTrackingMode(rawValue: "reps"),
            instructions: ["Current catalogue instruction."],
            lifecycle: ExerciseLifecycle(status: .active, replacementExerciseID: nil),
            media: nil,
            aliases: nil,
            legacyIDs: nil,
            guidance: nil,
            environmentRequirements: nil,
            legacyNames: nil
        )
    }
}

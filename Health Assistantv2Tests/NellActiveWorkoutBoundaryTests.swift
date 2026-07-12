import SwiftData
import Testing
@testable import Health_Assistantv2

@MainActor
struct NellActiveWorkoutBoundaryTests {
    @Test func resolvingLastStepDoesNotCompleteOrLogWorkoutBeforeConfirmation() throws {
        let controller = PersistenceController(inMemory: true)
        let repository = HealthDataRepository(context: controller.container.mainContext)

        let plan = WorkoutPlan(title: "Boundary test")
        repository.addWorkoutPlan(plan)
        repository.addWorkoutStep(
            WorkoutStep(
                order: 0,
                type: .mobility,
                title: "Side stretch",
                durationSeconds: 30
            ),
            to: plan
        )

        let session = try #require(repository.startActiveWorkout(from: plan))
        let step = try #require(session.currentStep)

        repository.completeActiveWorkoutStep(step)

        #expect(session.progressFraction == 1)
        #expect(session.currentStep == nil)
        #expect(session.status == .inProgress)
        #expect(!session.workoutLogCreated)
        #expect(repository.allWorkouts().isEmpty)

        repository.finishActiveWorkout(session, actualEffort: 5, notes: nil)

        #expect(session.status == .completed)
        #expect(session.workoutLogCreated)
        #expect(repository.allWorkouts().count == 1)
    }
}

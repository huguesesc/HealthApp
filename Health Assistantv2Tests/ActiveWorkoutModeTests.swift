import Foundation
import SwiftData
import Testing
@testable import Health_Assistantv2

@MainActor
struct ActiveWorkoutModeTests {
    private func makeContext() -> ModelContext {
        ModelContext(PersistenceController(inMemory: true).container)
    }

    private func makePlan(repo: HealthDataRepository) -> WorkoutPlan {
        let plan = WorkoutPlan(
            title: "Home strength",
            goalText: "Controlled strength",
            estimatedDurationMinutes: 30,
            targetEffort: 6,
            locationNameSnapshot: "Home"
        )
        repo.addWorkoutPlan(plan)
        repo.addWorkoutStep(
            WorkoutStep(
                order: 0,
                type: .exercise,
                title: "Goblet squat",
                sets: 2,
                reps: 8,
                targetWeightKilograms: 12,
                restSeconds: 60,
                equipmentNameSnapshot: "Dumbbells"
            ),
            to: plan
        )
        repo.addWorkoutStep(
            WorkoutStep(
                order: 1,
                type: .cooldown,
                title: "Easy mobility",
                durationSeconds: 180
            ),
            to: plan
        )
        return plan
    }

    @Test func startCreatesDurableOrderedSnapshot() throws {
        let context = makeContext()
        let repo = HealthDataRepository(context: context)
        let plan = makePlan(repo: repo)

        let session = try #require(repo.startActiveWorkout(from: plan))

        #expect(session.sourcePlanIDSnapshot == plan.id)
        #expect(session.titleSnapshot == "Home strength")
        #expect(session.locationNameSnapshot == "Home")
        #expect(session.status == .inProgress)
        #expect(session.orderedSteps.map(\.title) == ["Goblet squat", "Easy mobility"])
        #expect(session.currentStep?.status == .active)
        #expect(session.orderedSteps[0].plannedSets == 2)
        #expect(session.orderedSteps[0].plannedWeightKilograms == 12)
    }

    @Test func completingSetsStartsRestAndAdvancesAfterFinalSet() throws {
        let context = makeContext()
        let repo = HealthDataRepository(context: context)
        let session = try #require(repo.startActiveWorkout(from: makePlan(repo: repo)))
        let squat = try #require(session.currentStep)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let firstFinishedStep = repo.completeActiveWorkoutSet(
            squat,
            reps: 8,
            weightKilograms: 14,
            at: now
        )

        #expect(!firstFinishedStep)
        #expect(squat.completedSets == 1)
        #expect(squat.status == .active)
        #expect(session.restDurationSeconds == 60)
        #expect(session.remainingRestSeconds(at: now) == 60)

        repo.clearRestTimer(for: session)
        let secondFinishedStep = repo.completeActiveWorkoutSet(
            squat,
            reps: 7,
            weightKilograms: 14,
            at: now.addingTimeInterval(90)
        )

        #expect(secondFinishedStep)
        #expect(squat.status == .completed)
        #expect(squat.completedSets == 2)
        #expect(squat.actualReps == 7)
        #expect(squat.actualWeightKilograms == 14)
        #expect(session.currentStep?.title == "Easy mobility")
        #expect(session.currentStep?.status == .active)
    }

    @Test func dateBasedTimersRecoverAndPauseDeterministically() throws {
        let context = makeContext()
        let repo = HealthDataRepository(context: context)
        let session = try #require(repo.startActiveWorkout(from: makePlan(repo: repo)))
        let timedStep = session.orderedSteps[1]
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        repo.startActiveStepTimer(timedStep, at: start)
        #expect(timedStep.timerElapsedSeconds(at: start.addingTimeInterval(45)) == 45)
        #expect(timedStep.timerRemainingSeconds(at: start.addingTimeInterval(45)) == 135)

        repo.pauseActiveStepTimer(timedStep, at: start.addingTimeInterval(45))
        #expect(!timedStep.timerIsRunning)
        #expect(timedStep.timerAccumulatedSeconds == 45)
        #expect(timedStep.actualDurationSeconds == 45)
    }

    @Test func pauseAndResumePreserveElapsedWorkoutTime() throws {
        let context = makeContext()
        let repo = HealthDataRepository(context: context)
        let session = try #require(repo.startActiveWorkout(from: makePlan(repo: repo)))
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        session.activeSegmentStartedAt = start
        session.accumulatedActiveSeconds = 0

        repo.pauseActiveWorkout(session, at: start.addingTimeInterval(90))
        #expect(session.status == .paused)
        #expect(session.accumulatedActiveSeconds == 90)
        #expect(session.elapsedSeconds(at: start.addingTimeInterval(300)) == 90)

        repo.resumeActiveWorkout(session, at: start.addingTimeInterval(120))
        #expect(session.status == .inProgress)
        #expect(session.elapsedSeconds(at: start.addingTimeInterval(150)) == 120)
    }

    @Test func finishingWritesExactlyOneExistingWorkoutLog() throws {
        let context = makeContext()
        let repo = HealthDataRepository(context: context)
        let session = try #require(repo.startActiveWorkout(from: makePlan(repo: repo)))
        let squat = try #require(session.currentStep)

        _ = repo.completeActiveWorkoutSet(squat, reps: 8, weightKilograms: 12)
        _ = repo.completeActiveWorkoutSet(squat, reps: 8, weightKilograms: 12)
        if let cooldown = session.currentStep {
            repo.completeActiveWorkoutStep(cooldown)
        }

        repo.finishActiveWorkout(session, actualEffort: 7, notes: "Felt controlled")
        repo.finishActiveWorkout(session, actualEffort: 7, notes: "Duplicate attempt")

        #expect(session.status == .completed)
        #expect(session.workoutLogCreated)
        #expect(session.actualEffort == 7)
        #expect(repo.allWorkouts().count == 1)
        #expect(repo.allWorkouts().first?.type == "Home strength")
        #expect(repo.allWorkouts().first?.sets.count == 2)
    }

    @Test func endingEarlyDoesNotCreateCompletedWorkoutLog() throws {
        let context = makeContext()
        let repo = HealthDataRepository(context: context)
        let session = try #require(repo.startActiveWorkout(from: makePlan(repo: repo)))

        repo.abandonActiveWorkout(session)

        #expect(session.status == .abandoned)
        #expect(repo.allWorkouts().isEmpty)
    }
}

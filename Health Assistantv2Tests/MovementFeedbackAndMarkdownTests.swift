import Foundation
import SwiftData
import Testing
@testable import Health_Assistantv2

@MainActor
struct MovementFeedbackAndMarkdownTests {
    private func makeContext() -> ModelContext {
        ModelContext(PersistenceController(inMemory: true).container)
    }

    private func makeActiveWorkout(
        context: ModelContext,
        stepCount: Int = 1
    ) throws -> (HealthDataRepository, ActiveWorkoutSession) {
        let repo = HealthDataRepository(context: context)
        let plan = WorkoutPlan(title: "Control session")
        repo.addWorkoutPlan(plan)

        for index in 0..<stepCount {
            repo.addWorkoutStep(
                WorkoutStep(
                    order: index,
                    type: .exercise,
                    title: index == 0 ? "Split squat" : "Step-down",
                    sets: 3,
                    reps: 8,
                    targetWeightKilograms: 12,
                    restSeconds: 60,
                    side: .both
                ),
                to: plan
            )
        }

        return (repo, try #require(repo.startActiveWorkout(from: plan)))
    }

    @Test func feedbackKeepsExactUserReportedExecutionContext() throws {
        let context = makeContext()
        let (repo, session) = try makeActiveWorkout(context: context)
        let step = try #require(session.currentStep)
        step.actualReps = 6
        step.actualWeightKilograms = 10

        let saved = repo.addMovementFeedback(
            for: session,
            step: step,
            setNumber: 1,
            signal: .unsteady,
            bodyArea: .knee,
            side: .left,
            impact: .changedMovement,
            action: .usedMoreSupport,
            note: "Used the wall for the final reps."
        )

        #expect(saved.userReported)
        #expect(saved.sessionIDSnapshot == session.id)
        #expect(saved.stepIDSnapshot == step.id)
        #expect(saved.setNumberSnapshot == 1)
        #expect(saved.signal == .unsteady)
        #expect(saved.bodyArea == .knee)
        #expect(saved.side == .left)
        #expect(saved.plannedRepsSnapshot == 8)
        #expect(saved.actualRepsSnapshot == 6)
        #expect(saved.plannedWeightKilogramsSnapshot == 12)
        #expect(saved.actualWeightKilogramsSnapshot == 10)

        let snapshots = repo.recentMovementFeedbackSnapshots(limit: 10)
        #expect(snapshots.count == 1)
        #expect(snapshots[0].exercise == "Split squat")
        #expect(snapshots[0].signal == "Felt unsteady")
        #expect(snapshots[0].adjustment == "Used a more stable setup")
    }

    @Test func skippedStepAdjustmentAdvancesWorkout() throws {
        let context = makeContext()
        let (repo, session) = try makeActiveWorkout(context: context, stepCount: 2)
        let first = try #require(session.currentStep)

        repo.addMovementFeedback(
            for: session,
            step: first,
            setNumber: 1,
            signal: .equipmentIssue,
            bodyArea: nil,
            side: nil,
            impact: .stoppedExercise,
            action: .skippedStep,
            note: "Bench was unavailable."
        )

        #expect(first.status == .skipped)
        #expect(session.currentStepIndex == 1)
        #expect(session.currentStep?.title == "Step-down")
        #expect(repo.movementFeedback(for: session).count == 1)
    }

    @Test func assistantMarkdownIsParsedBeforeDisplay() {
        let rendered = ChatMarkdownRenderer.attributedString(
            from: "**Strong** guidance with [details](https://example.com)."
        )

        #expect(String(rendered.characters) == "Strong guidance with details.")
    }
}

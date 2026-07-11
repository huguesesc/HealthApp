import Foundation
import SwiftData
import Testing
@testable import Health_Assistantv2

@MainActor
struct StructuredWorkoutPlanTests {
    private func makeContext() -> ModelContext {
        ModelContext(PersistenceController(inMemory: true).container)
    }

    @Test func repositoryPersistsAndReordersPlanSteps() throws {
        let context = makeContext()
        let repo = HealthDataRepository(context: context)
        let plan = WorkoutPlan(title: "Home strength", estimatedDurationMinutes: 35)
        repo.addWorkoutPlan(plan)

        repo.addWorkoutStep(
            WorkoutStep(order: 0, type: .warmUp, title: "Warm-up", durationSeconds: 300),
            to: plan
        )
        repo.addWorkoutStep(
            WorkoutStep(order: 1, type: .exercise, title: "Goblet squat", sets: 3, reps: 8),
            to: plan
        )
        repo.addWorkoutStep(
            WorkoutStep(order: 2, type: .cooldown, title: "Easy mobility", durationSeconds: 240),
            to: plan
        )

        #expect(plan.orderedSteps.map(\.title) == ["Warm-up", "Goblet squat", "Easy mobility"])

        repo.moveWorkoutSteps(in: plan, from: IndexSet(integer: 0), to: 3)

        #expect(plan.orderedSteps.map(\.title) == ["Goblet squat", "Easy mobility", "Warm-up"])
        #expect(plan.orderedSteps.map(\.order) == [0, 1, 2])

        let fetched = repo.activeWorkoutPlans()
        #expect(fetched.count == 1)
        #expect(fetched.first?.steps.count == 3)
    }

    @Test func locationSnapshotIncludesOnlyAvailableEquipment() throws {
        let context = makeContext()
        let repo = HealthDataRepository(context: context)
        let location = WorkoutLocation(name: "Home", category: .home)
        repo.addLocation(location)
        repo.addEquipment(
            EquipmentItem(name: "Dumbbells", category: .dumbbells, isAvailable: true),
            to: location
        )
        repo.addEquipment(
            EquipmentItem(name: "Wobble board", category: .wobbleBoard, isAvailable: false),
            to: location
        )

        let plan = WorkoutPlan(title: "Home plan")
        repo.addWorkoutPlan(plan)
        repo.applyWorkoutLocationSnapshot(location, to: plan)

        #expect(plan.locationNameSnapshot == "Home")
        #expect(plan.equipmentSummarySnapshot == "Dumbbells")
        #expect(repo.isEquipmentNameAvailable("Dumbbells", at: location))
        #expect(!repo.isEquipmentNameAvailable("Wobble board", at: location))
    }

    @Test func assistantPlanConfirmationRequiresUserActionAndFiltersEquipment() throws {
        let context = makeContext()
        let repo = HealthDataRepository(context: context)
        let location = WorkoutLocation(name: "Home", category: .home)
        repo.addLocation(location)
        repo.addEquipment(
            EquipmentItem(name: "Dumbbells", category: .dumbbells, isAvailable: true),
            to: location
        )
        repo.addEquipment(
            EquipmentItem(name: "Stationary bike", category: .stationaryBike, isAvailable: false),
            to: location
        )

        let draft = WorkoutPlanProposal(
            title: "Home strength",
            goal: "Build strength with controlled movements",
            estimatedDurationMinutes: 30,
            targetEffort: 6,
            location: "Home",
            notes: nil,
            steps: [
                WorkoutPlanStepProposal(
                    type: WorkoutStepType.exercise.rawValue,
                    title: "Goblet squat",
                    instruction: nil,
                    sets: 3,
                    reps: 8,
                    durationSeconds: nil,
                    distanceMeters: nil,
                    targetWeightKilograms: 12,
                    restSeconds: 75,
                    side: WorkoutStepSide.both.rawValue,
                    equipment: "Dumbbells",
                    notes: nil
                ),
                WorkoutPlanStepProposal(
                    type: WorkoutStepType.cardio.rawValue,
                    title: "Easy bike",
                    instruction: nil,
                    sets: nil,
                    reps: nil,
                    durationSeconds: 300,
                    distanceMeters: nil,
                    targetWeightKilograms: nil,
                    restSeconds: nil,
                    side: nil,
                    equipment: "Stationary bike",
                    notes: nil
                ),
            ]
        )

        let proposal = ChatProposal(kind: .workoutPlan(draft))
        let engine = ChatEngine(modelContext: context)

        #expect(repo.activeWorkoutPlans().isEmpty)
        engine.confirm(proposal)

        let saved = try #require(repo.activeWorkoutPlans().first)
        #expect(proposal.status == .saved)
        #expect(saved.source == .assistant)
        #expect(saved.locationNameSnapshot == "Home")
        #expect(saved.orderedSteps.count == 2)
        #expect(saved.orderedSteps[0].equipmentNameSnapshot == "Dumbbells")
        #expect(saved.orderedSteps[1].equipmentNameSnapshot == nil)
    }

    @Test func assistantExposesPlanToolsAndSafetyInstructions() {
        let toolNames = Set(ChatEngine.tools.map(\.name))
        #expect(toolNames.contains("propose_workout_plan"))
        #expect(toolNames.contains("get_workout_plans"))
        #expect(toolNames.contains("get_health_profile"))
        #expect(toolNames.contains("get_workout_locations"))

        let prompt = ChatEngine.systemPrompt.lowercased()
        #expect(prompt.contains("user's own reports"))
        #expect(prompt.contains("never diagnose"))
        #expect(prompt.contains("only equipment marked available"))
        #expect(prompt.contains("save plan"))
    }
}
import Foundation
import Testing
@testable import Health_Assistantv2

struct NellNavigationAndWorkoutMotionTests {
    @Test func workoutMovementIdentifiersAreUnique() {
        let identifiers = WorkoutMotionRegistry.definitions.map(\.movementID)
        #expect(Set(identifiers).count == identifiers.count)
    }

    @Test func approvedMovementAliasesResolveToStableDefinitions() {
        #expect(WorkoutMotionRegistry.definition(for: "Goblet squat").movementID == "goblet_squat")
        #expect(WorkoutMotionRegistry.definition(for: "Shoulder press").movementID == "overhead_press")
        #expect(WorkoutMotionRegistry.definition(for: "Renegade row").movementID == "plank_row")
        #expect(WorkoutMotionRegistry.definition(for: "Tree pose").movementID == "yoga_balance")
    }

    @Test func unknownMovementReceivesSafeGenericFallback() {
        let definition = WorkoutMotionRegistry.definition(
            for: "Seated custom movement",
            type: .mobility
        )

        #expect(definition.movementID == "generic_seated_custom_movement")
        #expect(definition.startPose == .sideStretchStart)
        #expect(definition.endPose == nil)
        #expect(definition.characterStyleID == WorkoutAvatarStyleRegistry.defaultStyleID)
    }

    @Test func workoutMotionDefinitionsRoundTripThroughJSON() throws {
        let original = WorkoutMotionRegistry.definition(for: "Bent-over row")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorkoutMotionDefinition.self, from: data)

        #expect(decoded == original)
    }

    @Test func initialCharacterStyleRemainsReplaceableByIdentifier() {
        let defaultStyle = WorkoutAvatarStyleRegistry.style(id: nil)
        let registeredStyle = WorkoutAvatarStyleRegistry.style(id: "nell_neutral_01")
        let missingStyle = WorkoutAvatarStyleRegistry.style(id: "future_character_pack")

        #expect(defaultStyle.id == "nell_neutral_01")
        #expect(registeredStyle.id == defaultStyle.id)
        #expect(missingStyle.id == defaultStyle.id)
    }

    @Test func allApprovedDefinitionsHaveAStartPoseAndAccessibleName() {
        for definition in WorkoutMotionRegistry.definitions {
            #expect(!definition.displayName.isEmpty)
            #expect(!definition.movementID.isEmpty)
            #expect(!definition.characterStyleID.isEmpty)
        }
    }
}

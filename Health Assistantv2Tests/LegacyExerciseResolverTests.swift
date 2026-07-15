import Foundation
import Testing
@testable import Health_Assistantv2

struct LegacyExerciseResolverTests {
    @Test func resolvesStableLegacyDisplayNameAndAliasWithExplicitMatchKinds() {
        let squat = exercise(
            id: "bodyweight.squat",
            displayName: "Bodyweight squat",
            aliases: ["Air squat"],
            legacyIDs: ["bodyweight.air_squat"]
        )
        let resolver = LegacyExerciseResolver(definitions: [squat])

        assertResolved(
            resolver.resolve("bodyweight.squat"),
            id: squat.id,
            match: .stableID
        )
        assertResolved(
            resolver.resolve("bodyweight.air_squat"),
            id: squat.id,
            match: .legacyID
        )
        assertResolved(
            resolver.resolve("  BODYWEIGHT-SQUAT "),
            id: squat.id,
            match: .normalizedReference
        )
        assertResolved(
            resolver.resolve("air_squat"),
            id: squat.id,
            match: .normalizedReference
        )
    }

    @Test func ambiguousExactAliasesReturnSortedCandidatesAndDiagnostic() {
        let first = exercise(
            id: "bodyweight.squat",
            displayName: "Bodyweight squat",
            aliases: ["Supported movement"]
        )
        let second = exercise(
            id: "bodyweight.forward_lunge",
            displayName: "Forward lunge",
            aliases: ["supported-movement"]
        )
        var diagnostics: [LegacyExerciseDiagnostic] = []
        let resolver = LegacyExerciseResolver(definitions: [second, first]) {
            diagnostics.append($0)
        }

        let resolution = resolver.resolve("Supported movement")
        let expectedIDs = [first.id, second.id].sorted {
            $0.rawValue < $1.rawValue
        }

        #expect(resolution == .ambiguous(
            reference: "Supported movement",
            candidateIDs: expectedIDs
        ))
        #expect(diagnostics == [.ambiguous(
            reference: "Supported movement",
            candidateIDs: expectedIDs
        )])
    }

    @Test func substringAndUnknownCustomReferencesRemainUnresolved() {
        let curl = exercise(
            id: "dumbbell.biceps_curl",
            displayName: "Dumbbell biceps curl",
            aliases: ["Arm curl"]
        )
        var diagnostics: [LegacyExerciseDiagnostic] = []
        let resolver = LegacyExerciseResolver(definitions: [curl]) {
            diagnostics.append($0)
        }

        #expect(resolver.resolve("curl") == .unresolved(reference: "curl"))
        #expect(
            resolver.resolve("My custom arm curl finisher")
                == .unresolved(reference: "My custom arm curl finisher")
        )
        #expect(diagnostics == [
            .unresolved(reference: "curl"),
            .unresolved(reference: "My custom arm curl finisher")
        ])
    }

    @Test func workoutRegistryBridgesResolvedCanonicalExerciseToLegacyVectorPose() {
        let bodyweightSquat = exercise(
            id: "bodyweight.squat",
            displayName: "Bodyweight squat"
        )
        let gobletSquat = exercise(
            id: "dumbbell.goblet_squat",
            displayName: "Goblet squat",
            requiredEquipment: [("dumbbell", 1)]
        )
        let resolver = LegacyExerciseResolver(definitions: [bodyweightSquat, gobletSquat])

        let bodyweightMotion = WorkoutMotionRegistry.definition(
            for: "bodyweight.squat",
            using: resolver
        )
        let gobletMotion = WorkoutMotionRegistry.definition(
            for: "goblet squat",
            using: resolver
        )

        #expect(bodyweightMotion.movementID == "goblet_squat")
        #expect(bodyweightMotion.displayName == "Bodyweight squat")
        #expect(bodyweightMotion.startPose == .standing)
        #expect(bodyweightMotion.endPose == .gobletSquat)
        #expect(bodyweightMotion.equipment == .none)
        #expect(gobletMotion.movementID == "goblet_squat")
        #expect(gobletMotion.equipment == .gobletWeight)
    }

    @Test func unresolvedOrAmbiguousCanonicalReferencesUseGenericVectorFallback() {
        let first = exercise(
            id: "bodyweight.squat",
            displayName: "Squat",
            aliases: ["Shared movement"]
        )
        let second = exercise(
            id: "bodyweight.forward_lunge",
            displayName: "Lunge",
            aliases: ["Shared movement"]
        )
        let resolver = LegacyExerciseResolver(definitions: [first, second])

        let ambiguous = WorkoutMotionRegistry.definition(
            for: "Shared movement",
            using: resolver
        )
        let custom = WorkoutMotionRegistry.definition(
            for: "Seated custom movement",
            using: resolver,
            type: .mobility
        )

        #expect(ambiguous.movementID == "generic_shared_movement")
        #expect(custom.movementID == "generic_seated_custom_movement")
        #expect(custom.startPose == .sideStretchStart)
    }

    @Test func legacyEquipmentAdapterPreservesSupportedVectorEquipmentOnly() {
        let goblet = exercise(
            id: "dumbbell.goblet_squat",
            displayName: "Goblet squat",
            requiredEquipment: [("dumbbell", 1)]
        )
        let row = exercise(
            id: "dumbbell.bent_over_row",
            displayName: "Bent-over row",
            requiredEquipment: [("dumbbell", 2)]
        )
        let barbell = exercise(
            id: "barbell.deadlift",
            displayName: "Barbell deadlift",
            requiredEquipment: [("barbell", 1)]
        )

        #expect(LegacyEquipmentAdapter.avatarEquipment(for: goblet) == .gobletWeight)
        #expect(LegacyEquipmentAdapter.avatarEquipment(for: row) == .dumbbells)
        #expect(LegacyEquipmentAdapter.avatarEquipment(for: barbell) == .none)
    }

    @Test func legacyVectorRegistryNeverUsesPartialAliases() {
        let partial = WorkoutMotionRegistry.definition(for: "Custom squat finisher")

        #expect(partial.movementID == "generic_custom_squat_finisher")
        #expect(partial.endPose == nil)
    }

    @Test func allEightLegacyDisplayNamesStillResolveExactly() {
        for definition in WorkoutMotionRegistry.definitions {
            let resolved = WorkoutMotionRegistry.definition(for: definition.displayName)
            #expect(resolved.movementID == definition.movementID)
        }
    }

    @Test func productionCatalogueStableIDsResolveWithoutEnablingSubstrings() throws {
        let url = try #require(Bundle.main.url(forResource: "catalog", withExtension: "json"))
        let manifest = try JSONDecoder().decode(
            ExerciseCatalogManifest.self,
            from: Data(contentsOf: url)
        )
        let resolver = LegacyExerciseResolver(definitions: manifest.exercises)

        for exercise in manifest.exercises {
            assertResolved(
                resolver.resolve(exercise.id.rawValue),
                id: exercise.id,
                match: .stableID
            )
        }
        #expect(resolver.resolve("squat") == .unresolved(reference: "squat"))
    }

    private func assertResolved(
        _ resolution: LegacyExerciseResolution,
        id: ExerciseID,
        match: LegacyExerciseMatch
    ) {
        guard case .resolved(let definition, let actualMatch) = resolution else {
            Issue.record("Expected a resolved legacy exercise reference.")
            return
        }
        #expect(definition.id == id)
        #expect(actualMatch == match)
    }

    private func exercise(
        id: String,
        displayName: String,
        aliases: [String]? = nil,
        legacyIDs: [String]? = nil,
        requiredEquipment: [(id: String, quantity: Int)] = [("none", 1)]
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: ExerciseID(rawValue: id)!,
            schemaVersion: 1,
            displayName: displayName,
            category: ExerciseCategory(rawValue: "strength"),
            movementPattern: ExerciseMovementPattern(rawValue: "test"),
            exerciseType: ExerciseType(rawValue: "repetition"),
            equipment: ExerciseEquipmentRequirements(
                required: requiredEquipment.map {
                    ExerciseEquipmentClause(
                        id: ExerciseEquipmentID(rawValue: $0.id),
                        quantity: $0.quantity
                    )
                }
            ),
            trackingMode: ExerciseTrackingMode(rawValue: "reps"),
            instructions: ["Follow the written exercise instructions."],
            lifecycle: ExerciseLifecycle(status: .active, replacementExerciseID: nil),
            media: nil,
            aliases: aliases,
            legacyIDs: legacyIDs?.compactMap(ExerciseID.init(rawValue:)),
            guidance: nil,
            environmentRequirements: nil
        )
    }
}

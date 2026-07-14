import Foundation
import Testing
@testable import Health_Assistantv2

struct ExerciseCatalogEligibilityTests {
    @Test func environmentTaxonomyDecodesInitialPresetsAndContextOverlaysDefaults() throws {
        let taxonomy = try loadInitialEnvironmentTaxonomy()
        let expectedIDs: Set<String> = ["home", "gym", "hotel", "outdoors", "sport_venue", "custom"]

        #expect(taxonomy.schemaVersion == 1)
        #expect(Set(taxonomy.environments.map(\.id.rawValue)) == expectedIDs)
        #expect(Set(taxonomy.environments.flatMap(\.defaultCapabilities).map(\.rawValue)) == Set([
            "floor_space", "wall_access", "anchor_point", "machine_access", "jumping_allowed", "quiet_space"
        ]))

        let expectedDefaults: [String: Set<String>] = [
            "home": ["floor_space", "wall_access"],
            "gym": ["floor_space", "wall_access", "anchor_point", "machine_access", "jumping_allowed"],
            "hotel": ["floor_space", "wall_access", "quiet_space"]
        ]

        for (presetID, defaults) in expectedDefaults {
            let context = ExerciseEnvironmentContext(presetID: environmentID(presetID))
            let resolved = context.resolvedCapabilities(in: taxonomy)
            #expect(Set(resolved.compactMap { $0.value ? $0.key.rawValue : nil }) == defaults)
        }

        let homeWithNoFloorSpace = ExerciseEnvironmentContext(
            presetID: environmentID("home"),
            capabilityOverrides: [capability("floor_space"): false]
        )
        #expect(homeWithNoFloorSpace.resolvedCapabilities(in: taxonomy)[capability("floor_space")] == false)
        #expect(homeWithNoFloorSpace.resolvedCapabilities(in: taxonomy)[capability("wall_access")] == true)
    }

    @Test func homeGymAndHotelResolveFloorWallAnchorAndMachineRequirements() throws {
        let evaluator = try makeEvaluator()
        let inventory = EquipmentInventory(quantities: [:])

        let home = ExerciseEnvironmentContext(presetID: environmentID("home"))
        #expect(evaluator.evaluate(exercise: exercise(requiring: ["floor_space"]), environment: home, inventory: inventory).isEligible)
        #expect(evaluator.evaluate(exercise: exercise(requiring: ["wall_access"]), environment: home, inventory: inventory).isEligible)
        #expect(evaluator.evaluate(exercise: exercise(requiring: ["anchor_point"]), environment: home, inventory: inventory).reasons == [
            .missingRequiredEnvironmentCapability(capability("anchor_point"))
        ])
        #expect(evaluator.evaluate(exercise: exercise(requiring: ["machine_access"]), environment: home, inventory: inventory).reasons == [
            .missingRequiredEnvironmentCapability(capability("machine_access"))
        ])

        let gym = ExerciseEnvironmentContext(presetID: environmentID("gym"))
        #expect(evaluator.evaluate(exercise: exercise(requiring: ["anchor_point"]), environment: gym, inventory: inventory).isEligible)
        #expect(evaluator.evaluate(exercise: exercise(requiring: ["machine_access"]), environment: gym, inventory: inventory).isEligible)

        let hotel = ExerciseEnvironmentContext(presetID: environmentID("hotel"))
        #expect(evaluator.evaluate(exercise: exercise(requiring: ["floor_space"]), environment: hotel, inventory: inventory).isEligible)
        #expect(evaluator.evaluate(exercise: exercise(requiring: ["wall_access"]), environment: hotel, inventory: inventory).isEligible)
        #expect(evaluator.evaluate(exercise: exercise(requiring: ["anchor_point"]), environment: hotel, inventory: inventory).reasons == [
            .missingRequiredEnvironmentCapability(capability("anchor_point"))
        ])
        #expect(evaluator.evaluate(exercise: exercise(requiring: ["machine_access"]), environment: hotel, inventory: inventory).reasons == [
            .missingRequiredEnvironmentCapability(capability("machine_access"))
        ])
    }

    @Test func explicitFalseRejectsJumpingAndPresentProhibitedCapabilityRejectsExercise() throws {
        let evaluator = try makeEvaluator()
        let jumpingExercise = exercise(requiring: ["jumping_allowed"])
        let noJumping = ExerciseEnvironmentContext(
            presetID: environmentID("gym"),
            capabilityOverrides: [capability("jumping_allowed"): false]
        )

        #expect(evaluator.evaluate(
            exercise: jumpingExercise,
            environment: noJumping,
            inventory: EquipmentInventory(quantities: [:])
        ).reasons == [
            .missingRequiredEnvironmentCapability(capability("jumping_allowed"))
        ])

        let quietOnly = ExerciseEnvironmentContext(
            presetID: environmentID("custom"),
            capabilityOverrides: [capability("quiet_space"): true]
        )
        let loudExercise = exercise(prohibiting: ["quiet_space"])

        #expect(evaluator.evaluate(
            exercise: loudExercise,
            environment: quietOnly,
            inventory: EquipmentInventory(quantities: [:])
        ).reasons == [
            .prohibitedEnvironmentCapabilityPresent(capability("quiet_space"))
        ])
    }

    @Test func machineAccessNeverSatisfiesSpecificMachineEquipmentRequirement() throws {
        let evaluator = try makeEvaluator()
        let legPress = exercise(
            equipment: ExerciseEquipmentRequirements(required: [
                ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "leg_press_machine"), quantity: 1)
            ])
        )
        let gym = ExerciseEnvironmentContext(presetID: environmentID("gym"))

        #expect(evaluator.evaluate(
            exercise: legPress,
            environment: gym,
            inventory: EquipmentInventory(quantities: [
                ExerciseEquipmentID(rawValue: "machine_access"): 1
            ])
        ).reasons == [.unmetEquipmentRequirements])

        #expect(evaluator.evaluate(
            exercise: legPress,
            environment: gym,
            inventory: EquipmentInventory(quantities: [
                ExerciseEquipmentID(rawValue: "leg_press_machine"): 1
            ])
        ).isEligible)
    }

    @Test func multiFailureReasonCodesAreStableAndDeterministic() throws {
        let evaluator = try makeEvaluator()
        let constrainedExercise = exercise(
            requiring: ["wall_access", "anchor_point", "floor_space"],
            prohibiting: ["quiet_space", "jumping_allowed"],
            equipment: ExerciseEquipmentRequirements(required: [
                ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "leg_press_machine"), quantity: 1)
            ])
        )
        let context = ExerciseEnvironmentContext(
            presetID: environmentID("custom"),
            capabilityOverrides: [
                capability("quiet_space"): true,
                capability("jumping_allowed"): true
            ]
        )

        let result = evaluator.evaluate(
            exercise: constrainedExercise,
            environment: context,
            inventory: EquipmentInventory(quantities: [:])
        )

        #expect(result.reasons == [
            .unmetEquipmentRequirements,
            .missingRequiredEnvironmentCapability(capability("anchor_point")),
            .missingRequiredEnvironmentCapability(capability("floor_space")),
            .missingRequiredEnvironmentCapability(capability("wall_access")),
            .prohibitedEnvironmentCapabilityPresent(capability("jumping_allowed")),
            .prohibitedEnvironmentCapabilityPresent(capability("quiet_space"))
        ])
        #expect(!result.isEligible)
    }

    @Test func requirementsAreHardConstraintsRatherThanPresetLabelGuesses() throws {
        let evaluator = try makeEvaluator()
        let requiresMachineAccess = exercise(requiring: ["machine_access"])
        let customWithMachineAccess = ExerciseEnvironmentContext(
            presetID: environmentID("custom"),
            capabilityOverrides: [capability("machine_access"): true]
        )
        let gymWithoutMachineAccess = ExerciseEnvironmentContext(
            presetID: environmentID("gym"),
            capabilityOverrides: [capability("machine_access"): false]
        )

        #expect(evaluator.evaluate(
            exercise: requiresMachineAccess,
            environment: customWithMachineAccess,
            inventory: EquipmentInventory(quantities: [:])
        ).isEligible)
        #expect(evaluator.evaluate(
            exercise: requiresMachineAccess,
            environment: gymWithoutMachineAccess,
            inventory: EquipmentInventory(quantities: [:])
        ).reasons == [
            .missingRequiredEnvironmentCapability(capability("machine_access"))
        ])
    }

    @Test func invalidEquipmentRequirementsReturnAnExplicitNonEligibleReason() throws {
        let evaluator = try makeEvaluator()
        let invalidExercise = exercise(equipment: ExerciseEquipmentRequirements(required: []))

        #expect(evaluator.evaluate(
            exercise: invalidExercise,
            environment: ExerciseEnvironmentContext(presetID: environmentID("home")),
            inventory: EquipmentInventory(quantities: [:])
        ).reasons == [
            .invalidEquipmentRequirementData([
                .emptyRequirementGroup(group: .required)
            ])
        ])
    }

    private func loadInitialEnvironmentTaxonomy() throws -> ExerciseEnvironmentTaxonomy {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let resourceURL = testDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("Health Assistantv2/ExerciseCatalog/Resources/Authoring/environments.json")
        return try JSONDecoder().decode(ExerciseEnvironmentTaxonomy.self, from: Data(contentsOf: resourceURL))
    }

    private func makeEvaluator() throws -> ExerciseEligibilityEvaluator {
        ExerciseEligibilityEvaluator(
            equipmentTaxonomy: EquipmentTaxonomy(schemaVersion: 1, equipment: [
                equipment("none"),
                equipment("leg_press_machine")
            ]),
            environmentTaxonomy: try loadInitialEnvironmentTaxonomy()
        )
    }

    private func exercise(
        requiring requiredCapabilities: [String] = [],
        prohibiting prohibitedCapabilities: [String] = [],
        equipment: ExerciseEquipmentRequirements = ExerciseEquipmentRequirements(required: [
            ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "none"), quantity: 1)
        ])
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: ExerciseID(rawValue: "bodyweight.catalog_test")!,
            schemaVersion: 1,
            displayName: "Catalog Test",
            category: ExerciseCategory(rawValue: "test"),
            movementPattern: ExerciseMovementPattern(rawValue: "test"),
            exerciseType: ExerciseType(rawValue: "test"),
            equipment: equipment,
            trackingMode: ExerciseTrackingMode(rawValue: "test"),
            instructions: [],
            lifecycle: ExerciseLifecycle(status: .active, replacementExerciseID: nil),
            media: nil,
            aliases: nil,
            legacyIDs: nil,
            guidance: nil,
            environmentRequirements: ExerciseEnvironmentRequirements(
                required: requiredCapabilities.map { ExerciseEnvironmentRequirement(rawValue: $0) },
                prohibited: prohibitedCapabilities.isEmpty
                    ? nil
                    : prohibitedCapabilities.map { ExerciseEnvironmentRequirement(rawValue: $0) }
            )
        )
    }

    private func equipment(_ id: String) -> EquipmentDefinition {
        EquipmentDefinition(
            id: ExerciseEquipmentID(rawValue: id),
            displayName: id,
            category: ExerciseEquipmentCategory(rawValue: "test"),
            lifecycle: EquipmentLifecycle(status: .active)
        )
    }

    private func environmentID(_ rawValue: String) -> ExerciseEnvironmentID {
        ExerciseEnvironmentID(rawValue: rawValue)
    }

    private func capability(_ rawValue: String) -> ExerciseEnvironmentCapabilityID {
        ExerciseEnvironmentCapabilityID(rawValue: rawValue)
    }
}

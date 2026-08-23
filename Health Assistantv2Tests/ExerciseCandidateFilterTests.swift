import Foundation
import Testing
@testable import Health_Assistantv2

@MainActor
struct ExerciseCandidateFilterTests {
    @Test func homeWithoutEquipmentExcludesWeightedAndMachineExercises() {
        let filter = makeFilter()
        let context = ExerciseCandidateContext(
            environment: ExerciseEnvironmentContext(
                presetID: ExerciseEnvironmentID(rawValue: "home")
            ),
            inventory: EquipmentInventory(quantities: [:]),
            goal: "Build strength",
            durationMinutes: 30
        )

        let candidates = filter.candidates(
            from: [
                exercise("bodyweight.squat", equipmentID: "none"),
                exercise("dumbbell.row", equipmentID: "dumbbell", quantity: 2),
                exercise(
                    "machine.leg_press",
                    equipmentID: "leg_press_machine",
                    requiredCapability: "machine_access"
                ),
            ],
            context: context
        )

        #expect(candidates.map(\.id) == ["bodyweight.squat"])
    }

    @Test func gymInventoryRequiresSpecificEquipmentDespiteMachineCapability() {
        let filter = makeFilter()
        let gym = ExerciseEnvironmentContext(
            presetID: ExerciseEnvironmentID(rawValue: "gym")
        )
        let definitions = [
            exercise(
                "machine.leg_press",
                equipmentID: "leg_press_machine",
                requiredCapability: "machine_access"
            ),
            exercise(
                "machine.lat_pulldown",
                equipmentID: "lat_pulldown_machine",
                requiredCapability: "machine_access"
            ),
        ]
        let context = ExerciseCandidateContext(
            environment: gym,
            inventory: EquipmentInventory(quantities: [
                ExerciseEquipmentID(rawValue: "leg_press_machine"): 1,
            ])
        )

        #expect(filter.candidates(from: definitions, context: context).map(\.id) == [
            "machine.leg_press",
        ])
    }

    @Test func rankingIsDeterministicGoalAwareDurationBoundedAndPatternBalanced() {
        let filter = makeFilter()
        let definitions = [
            exercise("strength.squat_b", category: "strength", pattern: "squat"),
            exercise("conditioning.jump", category: "conditioning", pattern: "jump"),
            exercise("strength.hinge", category: "strength", pattern: "hinge"),
            exercise("strength.squat_a", category: "strength", pattern: "squat"),
            exercise("strength.push", category: "strength", pattern: "push"),
            exercise("strength.pull", category: "strength", pattern: "pull"),
            exercise("strength.lunge", category: "strength", pattern: "lunge"),
            exercise("strength.carry", category: "strength", pattern: "carry"),
        ]
        let context = ExerciseCandidateContext(
            environment: ExerciseEnvironmentContext(
                presetID: ExerciseEnvironmentID(rawValue: "gym")
            ),
            inventory: EquipmentInventory(quantities: [:]),
            goal: "Build strength",
            durationMinutes: 15,
            maximumCandidates: 20
        )

        let first = filter.candidates(from: definitions, context: context)
        let second = filter.candidates(from: Array(definitions.reversed()), context: context)

        #expect(first == second)
        #expect(first.count == 6)
        #expect(!first.map(\.id).contains("conditioning.jump"))
        #expect(first.prefix(5).map(\.movementPattern) == [
            "carry", "hinge", "lunge", "pull", "push",
        ])
    }

    @Test func inactiveDefinitionsAndMediaNeverAffectEligibilityOrPayload() throws {
        let filter = makeFilter()
        let context = ExerciseCandidateContext(
            environment: ExerciseEnvironmentContext(
                presetID: ExerciseEnvironmentID(rawValue: "home")
            ),
            inventory: EquipmentInventory(quantities: [:])
        )
        let withoutMedia = exercise("bodyweight.squat", media: nil)
        let withMedia = exercise(
            "bodyweight.squat",
            media: [
                ExerciseMediaDefinition(
                    key: "exercise.bodyweight_squat.hero",
                    role: .thumbnail,
                    sequence: 0,
                    variant: nil,
                    appearance: nil,
                    accessibilityDescription: "Squat"
                ),
            ]
        )
        let deprecated = exercise("bodyweight.old", status: .deprecated)

        let first = filter.candidates(from: [withoutMedia, deprecated], context: context)
        let second = filter.candidates(from: [withMedia, deprecated], context: context)
        let encoded = try JSONEncoder().encode(second)
        let json = try #require(String(data: encoded, encoding: .utf8))

        #expect(first == second)
        #expect(!json.contains("media"))
        #expect(!json.contains("instructions"))
        #expect(encoded.count < 600)
    }

    @Test func legacyAdapterMapsLocationEquipmentAndExcludesUnavailableItems() {
        let location = WorkoutLocation(name: "Hotel room", category: .travel)
        location.equipment = [
            EquipmentItem(name: "Dumbbells", category: .dumbbells, quantity: 1),
            EquipmentItem(
                name: "Cable station",
                category: .cableStation,
                isAvailable: false
            ),
        ]
        let adapter = LegacyWorkoutCandidateContextAdapter()
        let context = adapter.context(
            for: location,
            equipmentTaxonomy: equipmentTaxonomy(),
            goal: nil,
            durationMinutes: nil
        )

        #expect(context.environment.presetID?.rawValue == "hotel")
        #expect(
            context.inventory.availableQuantity(
                of: ExerciseEquipmentID(rawValue: "dumbbell"),
                in: equipmentTaxonomy()
            ) == 2
        )
        #expect(
            context.inventory.availableQuantity(
                of: ExerciseEquipmentID(rawValue: "cable_station"),
                in: equipmentTaxonomy()
            ) == 0
        )
    }

    @Test func productionCatalogueHomeGymAndNoEquipmentPayloadsStayHardFiltered() throws {
        let resources = try productionResources()
        let filter = ExerciseCandidateFilter(
            eligibilityEvaluator: ExerciseEligibilityEvaluator(
                equipmentTaxonomy: resources.equipment,
                environmentTaxonomy: resources.environments
            )
        )
        let home = ExerciseCandidateContext(
            environment: ExerciseEnvironmentContext(
                presetID: ExerciseEnvironmentID(rawValue: "home")
            ),
            inventory: EquipmentInventory(quantities: [:]),
            maximumCandidates: 30
        )
        let gymWithoutEquipment = ExerciseCandidateContext(
            environment: ExerciseEnvironmentContext(
                presetID: ExerciseEnvironmentID(rawValue: "gym")
            ),
            inventory: EquipmentInventory(quantities: [:]),
            maximumCandidates: 30
        )
        let gymWithLegPress = ExerciseCandidateContext(
            environment: gymWithoutEquipment.environment,
            inventory: EquipmentInventory(quantities: [
                ExerciseEquipmentID(rawValue: "leg_press_machine"): 1,
            ]),
            maximumCandidates: 30
        )

        let homeCandidates = filter.candidates(
            from: resources.catalog.exercises,
            context: home
        )
        let emptyGymCandidates = filter.candidates(
            from: resources.catalog.exercises,
            context: gymWithoutEquipment
        )
        let equippedGymCandidates = filter.candidates(
            from: resources.catalog.exercises,
            context: gymWithLegPress
        )
        let homeIDs = Set(homeCandidates.map(\.id))
        let emptyGymIDs = Set(emptyGymCandidates.map(\.id))
        let equippedGymIDs = Set(equippedGymCandidates.map(\.id))
        let encoded = try JSONEncoder().encode(homeCandidates)

        #expect(homeIDs.contains("bodyweight.squat"))
        #expect(!homeIDs.contains("bodyweight.jumping_jack"))
        #expect(homeIDs.allSatisfy { $0.hasPrefix("bodyweight.") })
        #expect(emptyGymIDs.contains("bodyweight.jumping_jack"))
        #expect(!emptyGymIDs.contains("machine.leg_press"))
        #expect(equippedGymIDs.contains("machine.leg_press"))
        #expect(encoded.count < 5_000)
    }

    private func makeFilter() -> ExerciseCandidateFilter {
        ExerciseCandidateFilter(
            eligibilityEvaluator: ExerciseEligibilityEvaluator(
                equipmentTaxonomy: equipmentTaxonomy(),
                environmentTaxonomy: environmentTaxonomy()
            )
        )
    }

    private func equipmentTaxonomy() -> EquipmentTaxonomy {
        EquipmentTaxonomy(schemaVersion: 1, equipment: [
            equipment("none"),
            equipment("dumbbell"),
            EquipmentDefinition(
                id: ExerciseEquipmentID(rawValue: "pair_of_dumbbells"),
                displayName: "Pair of dumbbells",
                category: ExerciseEquipmentCategory(rawValue: "free_weight"),
                fulfills: [
                    EquipmentFulfillment(
                        id: ExerciseEquipmentID(rawValue: "dumbbell"),
                        quantityPerUnit: 2
                    ),
                ],
                lifecycle: EquipmentLifecycle(status: .active)
            ),
            equipment("leg_press_machine"),
            equipment("lat_pulldown_machine"),
            equipment("cable_station"),
        ])
    }

    private func environmentTaxonomy() -> ExerciseEnvironmentTaxonomy {
        ExerciseEnvironmentTaxonomy(schemaVersion: 1, environments: [
            environment("home", capabilities: ["floor_space", "wall_access"]),
            environment(
                "gym",
                capabilities: ["floor_space", "machine_access", "jumping_allowed"]
            ),
            environment("hotel", capabilities: ["floor_space", "quiet_space"]),
        ])
    }

    private func exercise(
        _ id: String,
        category: String = "strength",
        pattern: String = "squat",
        equipmentID: String = "none",
        quantity: Int = 1,
        requiredCapability: String? = nil,
        status: ExerciseLifecycleStatus = .active,
        media: [ExerciseMediaDefinition]? = nil
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: ExerciseID(rawValue: id)!,
            schemaVersion: 1,
            displayName: id,
            category: ExerciseCategory(rawValue: category),
            movementPattern: ExerciseMovementPattern(rawValue: pattern),
            exerciseType: ExerciseType(rawValue: "repetition"),
            equipment: ExerciseEquipmentRequirements(required: [
                ExerciseEquipmentClause(
                    id: ExerciseEquipmentID(rawValue: equipmentID),
                    quantity: quantity
                ),
            ]),
            trackingMode: ExerciseTrackingMode(rawValue: "reps"),
            instructions: ["Long instruction deliberately omitted from compact payload."],
            lifecycle: ExerciseLifecycle(status: status, replacementExerciseID: nil),
            media: media,
            aliases: nil,
            legacyIDs: nil,
            guidance: nil,
            environmentRequirements: requiredCapability.map {
                ExerciseEnvironmentRequirements(
                    required: [ExerciseEnvironmentRequirement(rawValue: $0)],
                    prohibited: nil
                )
            },
            legacyNames: nil
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

    private func environment(
        _ id: String,
        capabilities: [String]
    ) -> ExerciseEnvironmentDefinition {
        ExerciseEnvironmentDefinition(
            id: ExerciseEnvironmentID(rawValue: id),
            displayName: id,
            defaultCapabilities: capabilities.map(ExerciseEnvironmentCapabilityID.init(rawValue:)),
            rankingTags: [id],
            lifecycle: ExerciseEnvironmentLifecycle(status: .active)
        )
    }

    private func productionResources() throws -> (
        catalog: ExerciseCatalogManifest,
        equipment: EquipmentTaxonomy,
        environments: ExerciseEnvironmentTaxonomy
    ) {
        let sourcePath = #filePath.removingPercentEncoding ?? #filePath
        let authoring = URL(fileURLWithPath: sourcePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Health Assistantv2", isDirectory: true)
            .appendingPathComponent("ExerciseCatalog", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("Authoring", isDirectory: true)
        let decoder = JSONDecoder()
        return (
            try decoder.decode(
                ExerciseCatalogManifest.self,
                from: Data(contentsOf: authoring.appendingPathComponent("catalog.json"))
            ),
            try decoder.decode(
                EquipmentTaxonomy.self,
                from: Data(contentsOf: authoring.appendingPathComponent("equipment.json"))
            ),
            try decoder.decode(
                ExerciseEnvironmentTaxonomy.self,
                from: Data(contentsOf: authoring.appendingPathComponent("environments.json"))
            )
        )
    }
}

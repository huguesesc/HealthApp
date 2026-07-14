import Foundation
import Testing
@testable import Health_Assistantv2

struct ExerciseCatalogEquipmentTests {
    @Test func taxonomyDecodesEvidenceDerivedInitialEquipmentIDs() throws {
        let taxonomy = try loadInitialTaxonomy()
        let expectedIDs: Set<String> = [
            "none", "yoga_mat", "stability_ball", "mini_resistance_band",
            "long_resistance_band", "resistance_band", "foam_balance_pad",
            "wobble_board", "balance_disc", "bosu_trainer", "slant_board",
            "dumbbell", "pair_of_dumbbells", "kettlebell", "barbell",
            "weight_plate", "squat_rack", "bench", "step", "cable_station",
            "leg_press_machine", "lat_pulldown_machine", "leg_extension_machine",
            "lying_leg_curl_machine", "seated_calf_raise_machine", "rowing_machine",
            "stationary_bike", "treadmill"
        ]

        #expect(taxonomy.schemaVersion == 1)
        #expect(Set(taxonomy.equipment.map(\.id.rawValue)) == expectedIDs)
        let pair = try #require(taxonomy.definition(for: ExerciseEquipmentID(rawValue: "pair_of_dumbbells")))
        #expect(pair.fulfills == [
            EquipmentFulfillment(
                id: ExerciseEquipmentID(rawValue: "dumbbell"),
                quantityPerUnit: 2
            )
        ])
    }

    @Test func requirementsRequireEveryPrimaryClauseOrOneCompleteAlternativeGroup() {
        let taxonomy = fixtureTaxonomy()
        let requirements = ExerciseEquipmentRequirements(
            required: [
                ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "dumbbell"), quantity: 2),
                ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "yoga_mat"), quantity: 1)
            ],
            alternatives: [[
                ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "kettlebell"), quantity: 1),
                ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "bench"), quantity: 1)
            ]]
        )

        #expect(requirements.isSatisfied(
            by: EquipmentInventory(quantities: [
                ExerciseEquipmentID(rawValue: "dumbbell"): 2,
                ExerciseEquipmentID(rawValue: "yoga_mat"): 1
            ]),
            in: taxonomy
        ))
        #expect(!requirements.isSatisfied(
            by: EquipmentInventory(quantities: [
                ExerciseEquipmentID(rawValue: "dumbbell"): 1,
                ExerciseEquipmentID(rawValue: "yoga_mat"): 1
            ]),
            in: taxonomy
        ))
        #expect(requirements.isSatisfied(
            by: EquipmentInventory(quantities: [
                ExerciseEquipmentID(rawValue: "kettlebell"): 1,
                ExerciseEquipmentID(rawValue: "bench"): 1
            ]),
            in: taxonomy
        ))
        #expect(!requirements.isSatisfied(
            by: EquipmentInventory(quantities: [
                ExerciseEquipmentID(rawValue: "kettlebell"): 1
            ]),
            in: taxonomy
        ))
    }

    @Test func pairOfDumbbellsFulfillsTwoGenericDumbbellsAndNotUnrelatedEquipment() throws {
        let taxonomy = try loadInitialTaxonomy()
        let inventory = EquipmentInventory(quantities: [
            ExerciseEquipmentID(rawValue: "pair_of_dumbbells"): 1
        ])

        #expect(ExerciseEquipmentRequirements(
            required: [ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "dumbbell"), quantity: 2)],
            alternatives: []
        ).isSatisfied(by: inventory, in: taxonomy))
        #expect(!ExerciseEquipmentRequirements(
            required: [ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "kettlebell"), quantity: 1)],
            alternatives: []
        ).isSatisfied(by: inventory, in: taxonomy))
    }

    @Test func environmentLabelDoesNotSatisfySpecificMachineRequirement() throws {
        let taxonomy = try loadInitialTaxonomy()
        let requirements = ExerciseEquipmentRequirements(
            required: [ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "leg_press_machine"), quantity: 1)],
            alternatives: []
        )

        #expect(!requirements.isSatisfied(
            by: EquipmentInventory(quantities: [ExerciseEquipmentID(rawValue: "machine_access"): 1]),
            in: taxonomy
        ))
    }

    @Test func noneAloneIsSatisfiedButCannotBeCombinedInARequirementGroup() throws {
        let taxonomy = try loadInitialTaxonomy()
        let none = ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "none"), quantity: 1)

        #expect(ExerciseEquipmentRequirements(required: [none], alternatives: []).isSatisfied(
            by: EquipmentInventory(quantities: [:]),
            in: taxonomy
        ))
        #expect(taxonomy.validationErrors(for: ExerciseEquipmentRequirements(
            required: [none, ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "yoga_mat"), quantity: 1)],
            alternatives: []
        )) == [
            .noneCombinedWithOtherClauses(
                group: .required,
                clauseIDs: [ExerciseEquipmentID(rawValue: "none"), ExerciseEquipmentID(rawValue: "yoga_mat")]
            )
        ])
    }

    @Test func taxonomyValidationReportsUnknownParentsCyclesAndUnknownFulfillmentTargetsDeterministically() {
        let taxonomy = EquipmentTaxonomy(schemaVersion: 1, equipment: [
            EquipmentDefinition(
                id: ExerciseEquipmentID(rawValue: "alpha"),
                displayName: "Alpha",
                category: EquipmentCategory(rawValue: "test"),
                parentID: ExerciseEquipmentID(rawValue: "missing_parent"),
                lifecycle: EquipmentLifecycle(status: .active)
            ),
            EquipmentDefinition(
                id: ExerciseEquipmentID(rawValue: "bravo"),
                displayName: "Bravo",
                category: EquipmentCategory(rawValue: "test"),
                parentID: ExerciseEquipmentID(rawValue: "charlie"),
                lifecycle: EquipmentLifecycle(status: .active)
            ),
            EquipmentDefinition(
                id: ExerciseEquipmentID(rawValue: "charlie"),
                displayName: "Charlie",
                category: EquipmentCategory(rawValue: "test"),
                parentID: ExerciseEquipmentID(rawValue: "bravo"),
                lifecycle: EquipmentLifecycle(status: .active)
            ),
            EquipmentDefinition(
                id: ExerciseEquipmentID(rawValue: "delta"),
                displayName: "Delta",
                category: EquipmentCategory(rawValue: "test"),
                fulfills: [EquipmentFulfillment(
                    id: ExerciseEquipmentID(rawValue: "missing_target"),
                    quantityPerUnit: 1
                )],
                lifecycle: EquipmentLifecycle(status: .active)
            )
        ])

        #expect(taxonomy.validationErrors() == [
            .unknownParent(
                equipmentID: ExerciseEquipmentID(rawValue: "alpha"),
                parentID: ExerciseEquipmentID(rawValue: "missing_parent")
            ),
            .parentCycle(ids: [
                ExerciseEquipmentID(rawValue: "bravo"),
                ExerciseEquipmentID(rawValue: "charlie")
            ]),
            .unknownFulfillmentTarget(
                equipmentID: ExerciseEquipmentID(rawValue: "delta"),
                targetID: ExerciseEquipmentID(rawValue: "missing_target")
            )
        ])
    }

    private func loadInitialTaxonomy() throws -> EquipmentTaxonomy {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let resourceURL = testDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("Health Assistantv2/ExerciseCatalog/Resources/Authoring/equipment.json")
        return try JSONDecoder().decode(EquipmentTaxonomy.self, from: Data(contentsOf: resourceURL))
    }

    private func fixtureTaxonomy() -> EquipmentTaxonomy {
        EquipmentTaxonomy(schemaVersion: 1, equipment: [
            equipment("dumbbell"), equipment("yoga_mat"), equipment("kettlebell"), equipment("bench")
        ])
    }

    private func equipment(_ id: String) -> EquipmentDefinition {
        EquipmentDefinition(
            id: ExerciseEquipmentID(rawValue: id),
            displayName: id,
            category: EquipmentCategory(rawValue: "test"),
            lifecycle: EquipmentLifecycle(status: .active)
        )
    }
}

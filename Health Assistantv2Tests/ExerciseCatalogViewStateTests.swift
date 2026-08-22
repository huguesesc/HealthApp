import Foundation
import Testing
@testable import Health_Assistantv2

struct ExerciseCatalogViewStateTests {
    @Test func searchMatchesDisplayNamesAndAliasesCaseAndDiacriticInsensitively() {
        let squat = exercise(
            "bodyweight.squat",
            name: "Bodyweight squat",
            aliases: ["Flexión à terre"]
        )
        let row = exercise("dumbbell.row", name: "Bent-over row", equipmentID: "dumbbell")
        let content = catalog([squat, row])

        #expect(ExerciseCatalogFilter(query: "SQUAT").results(in: content).map(\.id) == [squat.id])
        #expect(ExerciseCatalogFilter(query: "flexion").results(in: content).map(\.id) == [squat.id])
        #expect(ExerciseCatalogFilter(query: "over row").results(in: content).map(\.id) == [row.id])
        #expect(ExerciseCatalogFilter(query: "not present").results(in: content).isEmpty)
    }

    @Test func categoryAndEquipmentFiltersCanBeCombined() {
        let squat = exercise("bodyweight.squat", name: "Bodyweight squat")
        let row = exercise("dumbbell.row", name: "Dumbbell row", equipmentID: "dumbbell")
        let carry = exercise(
            "dumbbell.carry",
            name: "Dumbbell carry",
            category: "conditioning",
            equipmentID: "dumbbell"
        )
        let content = catalog([squat, row, carry])

        let filter = ExerciseCatalogFilter(
            categoryID: "strength",
            equipmentID: "dumbbell"
        )
        #expect(filter.results(in: content).map(\.id) == [row.id])
        #expect(
            ExerciseCatalogFilter(equipmentID: "none")
                .results(in: content)
                .map(\.id) == [squat.id]
        )
    }

    @Test func locationFilterHonorsRequiredAndProhibitedCapabilities() {
        let floor = exercise(
            "bodyweight.floor",
            name: "Floor exercise",
            requiredEnvironment: ["floor_space"]
        )
        let quiet = exercise(
            "bodyweight.quiet",
            name: "Quiet exercise",
            prohibitedEnvironment: ["jumping_allowed"]
        )
        let anywhere = exercise("bodyweight.anywhere", name: "Anywhere exercise")
        let content = catalog([floor, quiet, anywhere])

        #expect(
            ExerciseCatalogFilter(environmentID: "home")
                .results(in: content)
                .map(\.id) == [anywhere.id, floor.id, quiet.id]
        )
        #expect(
            ExerciseCatalogFilter(environmentID: "outdoors")
                .results(in: content)
                .map(\.id) == [anywhere.id, floor.id]
        )
    }

    @Test func activeEntriesSortBeforeDeprecatedAndDisabledWithStableTieBreaking() {
        let disabled = exercise("bodyweight.disabled", name: "Alpha", status: .disabled)
        let deprecated = exercise("bodyweight.deprecated", name: "Beta", status: .deprecated)
        let activeB = exercise("bodyweight.beta", name: "Same")
        let activeA = exercise("bodyweight.alpha", name: "Same")

        #expect(
            ExerciseCatalogFilter().results(
                in: catalog([disabled, deprecated, activeB, activeA])
            ).map(\.id) == [activeA.id, activeB.id, deprecated.id, disabled.id]
        )
    }

    private func catalog(_ exercises: [ExerciseDefinition]) -> ExerciseCatalogContent {
        ExerciseCatalogContent(
            exercises: exercises,
            equipmentTaxonomy: EquipmentTaxonomy(
                schemaVersion: 1,
                equipment: [
                    equipment("none", name: "No equipment"),
                    equipment("dumbbell", name: "Dumbbell"),
                ]
            ),
            environmentTaxonomy: ExerciseEnvironmentTaxonomy(
                schemaVersion: 1,
                environments: [
                    environment("home", name: "Home", capabilities: ["floor_space"]),
                    environment(
                        "outdoors",
                        name: "Outdoors",
                        capabilities: ["floor_space", "jumping_allowed"]
                    ),
                ]
            )
        )
    }

    private func exercise(
        _ id: String,
        name: String,
        category: String = "strength",
        equipmentID: String = "none",
        status: ExerciseLifecycleStatus = .active,
        aliases: [String]? = nil,
        requiredEnvironment: [String] = [],
        prohibitedEnvironment: [String] = []
    ) -> ExerciseDefinition {
        let environmentRequirements: ExerciseEnvironmentRequirements? =
            requiredEnvironment.isEmpty && prohibitedEnvironment.isEmpty
            ? nil
            : ExerciseEnvironmentRequirements(
                required: requiredEnvironment.map(ExerciseEnvironmentRequirement.init(rawValue:)),
                prohibited: prohibitedEnvironment.isEmpty
                    ? nil
                    : prohibitedEnvironment.map(ExerciseEnvironmentRequirement.init(rawValue:))
            )
        return ExerciseDefinition(
            id: ExerciseID(rawValue: id)!,
            schemaVersion: 1,
            displayName: name,
            category: ExerciseCategory(rawValue: category),
            movementPattern: ExerciseMovementPattern(rawValue: "squat"),
            exerciseType: ExerciseType(rawValue: "repetition"),
            equipment: ExerciseEquipmentRequirements(required: [
                ExerciseEquipmentClause(
                    id: ExerciseEquipmentID(rawValue: equipmentID),
                    quantity: 1
                ),
            ]),
            trackingMode: ExerciseTrackingMode(rawValue: "reps"),
            instructions: ["Move with control."],
            lifecycle: ExerciseLifecycle(status: status, replacementExerciseID: nil),
            media: nil,
            aliases: aliases,
            legacyIDs: nil,
            guidance: nil,
            environmentRequirements: environmentRequirements,
            legacyNames: nil
        )
    }

    private func equipment(_ id: String, name: String) -> EquipmentDefinition {
        EquipmentDefinition(
            id: ExerciseEquipmentID(rawValue: id),
            displayName: name,
            category: ExerciseEquipmentCategory(rawValue: "test"),
            lifecycle: EquipmentLifecycle(status: .active)
        )
    }

    private func environment(
        _ id: String,
        name: String,
        capabilities: [String]
    ) -> ExerciseEnvironmentDefinition {
        ExerciseEnvironmentDefinition(
            id: ExerciseEnvironmentID(rawValue: id),
            displayName: name,
            defaultCapabilities: capabilities.map(ExerciseEnvironmentCapabilityID.init(rawValue:)),
            rankingTags: [],
            lifecycle: ExerciseEnvironmentLifecycle(status: .active)
        )
    }
}

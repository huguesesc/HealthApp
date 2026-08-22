import Foundation
import Testing
@testable import Health_Assistantv2

/// Conceptual equipment/location compatibility matrix from the Windows-phase
/// missions, evaluated against the REAL checked-in equipment and environment
/// taxonomies and catalogue so taxonomy drift fails loudly here first.
struct EquipmentLocationCompatibilityTests {
    private let equipmentTaxonomy: EquipmentTaxonomy
    private let environmentTaxonomy: ExerciseEnvironmentTaxonomy
    private let evaluator: ExerciseEligibilityEvaluator

    init() throws {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Health Assistantv2/ExerciseCatalog/Resources/Authoring")
        equipmentTaxonomy = try JSONDecoder().decode(
            EquipmentTaxonomy.self,
            from: Data(contentsOf: base.appendingPathComponent("equipment.json"))
        )
        environmentTaxonomy = try JSONDecoder().decode(
            ExerciseEnvironmentTaxonomy.self,
            from: Data(contentsOf: base.appendingPathComponent("environments.json"))
        )
        evaluator = ExerciseEligibilityEvaluator(
            equipmentTaxonomy: equipmentTaxonomy,
            environmentTaxonomy: environmentTaxonomy
        )
    }

    // MARK: Helpers

    private func preset(_ id: String) -> ExerciseEnvironmentContext {
        ExerciseEnvironmentContext(presetID: ExerciseEnvironmentID(rawValue: id))
    }

    private func inventory(_ quantities: [String: Int]) -> EquipmentInventory {
        EquipmentInventory(quantities: Dictionary(
            uniqueKeysWithValues: quantities.map { key, value in
                (ExerciseEquipmentID(rawValue: key), value)
            }
        ))
    }

    private func fixture(
        equipmentID: String,
        quantity: Int = 1,
        alternatives: [[ExerciseEquipmentClause]] = [],
        requiredCapabilities: [String] = [],
        prohibitedCapabilities: [String] = []
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: ExerciseID(rawValue: "bodyweight.compatibility_fixture")!,
            schemaVersion: 1,
            displayName: "Compatibility fixture",
            category: ExerciseCategory(rawValue: "strength"),
            movementPattern: ExerciseMovementPattern(rawValue: "squat"),
            exerciseType: ExerciseType(rawValue: "repetition"),
            equipment: ExerciseEquipmentRequirements(
                required: [
                    ExerciseEquipmentClause(
                        id: ExerciseEquipmentID(rawValue: equipmentID),
                        quantity: quantity
                    ),
                ],
                alternatives: alternatives
            ),
            trackingMode: ExerciseTrackingMode(rawValue: "reps"),
            instructions: ["Move with control."],
            lifecycle: ExerciseLifecycle(status: .active, replacementExerciseID: nil),
            media: nil,
            aliases: nil,
            legacyIDs: nil,
            guidance: nil,
            environmentRequirements: ExerciseEnvironmentRequirements(
                required: requiredCapabilities.map(ExerciseEnvironmentRequirement.init(rawValue:)),
                prohibited: prohibitedCapabilities.isEmpty
                    ? nil
                    : prohibitedCapabilities.map(ExerciseEnvironmentRequirement.init(rawValue:))
            ),
            legacyNames: nil
        )
    }

    private func production(_ id: String) throws -> ExerciseDefinition {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Health Assistantv2/ExerciseCatalog/Resources/Authoring/catalog.json"
            )
        let manifest = try JSONDecoder().decode(
            ExerciseCatalogManifest.self,
            from: Data(contentsOf: base)
        )
        guard let match = manifest.exercises.first(where: { $0.id.rawValue == id }) else {
            throw NotFound(id: id)
        }
        return match
    }

    private struct NotFound: Error {
        let id: String
    }

    private func reasons(_ result: ExerciseEligibilityResult) -> Set<ExerciseEligibilityReason> {
        Set(result.reasons)
    }

    // MARK: Home scenarios

    @Test func homeWithMatAndMiniBandRunsBandLateralSquatFromProductionCatalogue() throws {
        let lateralSquat = try production("band.lateral_squat")
        let result = evaluator.evaluate(
            exercise: lateralSquat,
            environment: preset("home"),
            inventory: inventory(["yoga_mat": 1, "mini_resistance_band": 1])
        )
        #expect(result.isEligible)
    }

    @Test func matAloneNeverSubstitutesForABand() throws {
        let lateralSquat = try production("band.lateral_squat")
        let result = evaluator.evaluate(
            exercise: lateralSquat,
            environment: preset("home"),
            inventory: inventory(["yoga_mat": 1])
        )
        #expect(!result.isEligible)
        #expect(reasons(result) == [.unmetEquipmentRequirements])
    }

    @Test func adjustableDumbbellsPairSatisfiesTwoDumbbellRowRequirement() throws {
        let row = try production("dumbbell.bent_over_row")
        let withPair = evaluator.evaluate(
            exercise: row,
            environment: preset("home"),
            inventory: inventory(["pair_of_dumbbells": 1])
        )
        let withSingle = evaluator.evaluate(
            exercise: row,
            environment: preset("home"),
            inventory: inventory(["dumbbell": 1])
        )
        #expect(withPair.isEligible)
        #expect(reasons(withSingle) == [.unmetEquipmentRequirements])
    }

    @Test func benchEnablesBulgarianStyleSetupButNotWithoutWeights() {
        let benchFixture = fixture(
            equipmentID: "bench",
            quantity: 1,
            alternatives: []
        )
        #expect(evaluator.evaluate(
            exercise: benchFixture,
            environment: preset("home"),
            inventory: inventory(["bench": 1])
        ).isEligible)

        let benchPlusDumbbells = fixture(
            equipmentID: "dumbbell",
            quantity: 2,
            alternatives: []
        )
        #expect(evaluator.evaluate(
            exercise: benchPlusDumbbells,
            environment: preset("home"),
            inventory: inventory(["pair_of_dumbbells": 1, "bench": 1])
        ).isEligible)
    }

    // MARK: Gym scenarios

    @Test func fullGymMachineAccessNeverProvesASpecificMachineExists() throws {
        let legPress = try production("machine.leg_press")
        let result = evaluator.evaluate(
            exercise: legPress,
            environment: preset("gym"),
            inventory: inventory([:])
        )
        #expect(!result.isEligible)
        #expect(reasons(result) == [.unmetEquipmentRequirements])

        let equipped = evaluator.evaluate(
            exercise: legPress,
            environment: preset("gym"),
            inventory: inventory(["leg_press_machine": 1])
        )
        #expect(equipped.isEligible)
    }

    @Test func cableStationRequirementIsDistinctFromGenericMachineAccess() throws {
        let pushdown = try production("cable.triceps_pushdown")
        let withoutStation = evaluator.evaluate(
            exercise: pushdown,
            environment: preset("gym"),
            inventory: inventory(["leg_press_machine": 1])
        )
        let withStation = evaluator.evaluate(
            exercise: pushdown,
            environment: preset("gym"),
            inventory: inventory(["cable_station": 1])
        )
        #expect(!withoutStation.isEligible)
        #expect(withStation.isEligible)
    }

    // MARK: Outdoors scenarios

    @Test func outdoorsOpenSpaceCoversFloorAndJumpingButNotAnchoredWork() {
        let anchored = fixture(
            equipmentID: "none",
            requiredCapabilities: ["anchor_point"]
        )
        let result = evaluator.evaluate(
            exercise: anchored,
            environment: preset("outdoors"),
            inventory: inventory(["none": 1])
        )
        #expect(!result.isEligible)
        #expect(reasons(result) == [
            .missingRequiredEnvironmentCapability(
                ExerciseEnvironmentCapabilityID(rawValue: "anchor_point")
            ),
        ])

        let jumper = fixture(
            equipmentID: "none",
            requiredCapabilities: ["jumping_allowed"]
        )
        #expect(evaluator.evaluate(
            exercise: jumper,
            environment: preset("outdoors"),
            inventory: inventory(["none": 1])
        ).isEligible)
    }

    @Test func explicitlyOwnedOutdoorPullUpBarProvidesAnchorPoint() {
        let anchored = fixture(
            equipmentID: "none",
            requiredCapabilities: ["anchor_point"]
        )
        let outdoorBar = ExerciseEnvironmentContext(
            presetID: ExerciseEnvironmentID(rawValue: "outdoors"),
            capabilityOverrides: [
                ExerciseEnvironmentCapabilityID(rawValue: "anchor_point"): true,
            ]
        )
        let result = evaluator.evaluate(
            exercise: anchored,
            environment: outdoorBar,
            inventory: inventory(["none": 1])
        )
        #expect(result.isEligible)

        // The system never claims the user owns equipment implicitly:
        // removing the explicit override removes eligibility again.
        let revoked = ExerciseEnvironmentContext(
            presetID: ExerciseEnvironmentID(rawValue: "outdoors"),
            capabilityOverrides: [
                ExerciseEnvironmentCapabilityID(rawValue: "anchor_point"): false,
            ]
        )
        #expect(!evaluator.evaluate(
            exercise: anchored,
            environment: revoked,
            inventory: inventory(["none": 1])
        ).isEligible)
    }

    // MARK: Unspecified location

    @Test func unspecifiedLocationFailsClosedForCapabilityRequirements() {
        let floorWork = fixture(
            equipmentID: "none",
            requiredCapabilities: ["floor_space"]
        )
        let plain = fixture(equipmentID: "none")

        let floorResult = evaluator.evaluate(
            exercise: floorWork,
            environment: ExerciseEnvironmentContext(),
            inventory: inventory(["none": 1])
        )
        let plainResult = evaluator.evaluate(
            exercise: plain,
            environment: ExerciseEnvironmentContext(),
            inventory: inventory(["none": 1])
        )
        #expect(!floorResult.isEligible)
        #expect(floorResult.reasons == [
            .missingRequiredEnvironmentCapability(
                ExerciseEnvironmentCapabilityID(rawValue: "floor_space")
            ),
        ])
        #expect(plainResult.isEligible)
    }

    @Test func unknownPresetResolvesNoDefaultCapabilities() {
        let floorWork = fixture(
            equipmentID: "none",
            requiredCapabilities: ["floor_space"]
        )
        let result = evaluator.evaluate(
            exercise: floorWork,
            environment: ExerciseEnvironmentContext(
                presetID: ExerciseEnvironmentID(rawValue: "space_station")
            ),
            inventory: inventory(["none": 1])
        )
        #expect(!result.isEligible)
    }

    // MARK: Unknown and prohibited conditions

    @Test func unknownEquipmentIDsAreInertAndNeverCrashOrCorruptPlans() {
        let plain = fixture(equipmentID: "none")
        let weighted = fixture(equipmentID: "dumbbell", quantity: 1)

        let ghostInventory = inventory(["mythical_resistance_cloud": 3])
        #expect(evaluator.evaluate(
            exercise: plain,
            environment: preset("home"),
            inventory: ghostInventory
        ).isEligible)
        #expect(!evaluator.evaluate(
            exercise: weighted,
            environment: preset("home"),
            inventory: ghostInventory
        ).isEligible)
    }

    @Test func prohibitedCapabilityBlocksEvenWhereRequiredGroupsPass() {
        let quietMovement = fixture(
            equipmentID: "none",
            requiredCapabilities: [],
            prohibitedCapabilities: ["jumping_allowed"]
        )
        #expect(!evaluator.evaluate(
            exercise: quietMovement,
            environment: preset("gym"),
            inventory: inventory(["none": 1])
        ).isEligible)
        #expect(evaluator.evaluate(
            exercise: quietMovement,
            environment: preset("hotel"),
            inventory: inventory(["none": 1])
        ).isEligible)
    }
}

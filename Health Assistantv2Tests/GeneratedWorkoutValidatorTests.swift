import Foundation
import Testing
@testable import Health_Assistantv2

struct GeneratedWorkoutValidatorTests {
    @Test func stableAuthorizedExerciseValidatesAndNormalizesSnapshots() throws {
        let squat = exercise("bodyweight.squat", name: "Bodyweight squat")
        let outcome = validator.validate(
            plan(step: movementStep(id: squat.id.rawValue, title: "Wrong model title")),
            context: context(definitions: [squat], authorized: [squat.id])
        )

        let validated = try #require(outcome.proposal)
        #expect(outcome.errors.isEmpty)
        #expect(outcome.repairs.isEmpty)
        #expect(validated.steps[0].exerciseID == "bodyweight.squat")
        #expect(validated.steps[0].title == "Bodyweight squat")
    }

    @Test func nonexistentAmbiguousDeprecatedAndDisabledReferencesAreRejected() {
        let ambiguousA = exercise("bodyweight.alpha", name: "Shared name")
        let ambiguousB = exercise("bodyweight.beta", name: "Shared name")
        let deprecated = exercise(
            "bodyweight.old",
            name: "Old movement",
            status: .deprecated
        )
        let disabled = exercise(
            "bodyweight.disabled",
            name: "Disabled movement",
            status: .disabled
        )
        let definitions = [ambiguousA, ambiguousB, deprecated, disabled]
        let validationContext = context(
            definitions: definitions,
            authorized: Set(definitions.map(\.id))
        )

        #expect(validator.validate(
            plan(step: movementStep(id: "missing.exercise", title: "Missing")),
            context: validationContext
        ).errors == [.unresolvedReference(step: 1, reference: "missing.exercise")])
        #expect(validator.validate(
            plan(step: movementStep(id: nil, title: "Shared name")),
            context: validationContext
        ).errors == [.ambiguousReference(step: 1, reference: "Shared name")])
        #expect(validator.validate(
            plan(step: movementStep(id: deprecated.id.rawValue, title: deprecated.displayName)),
            context: validationContext
        ).errors == [
            .inactiveExercise(step: 1, id: deprecated.id.rawValue, status: .deprecated),
        ])
        #expect(validator.validate(
            plan(step: movementStep(id: disabled.id.rawValue, title: disabled.displayName)),
            context: validationContext
        ).errors == [
            .inactiveExercise(step: 1, id: disabled.id.rawValue, status: .disabled),
        ])
    }

    @Test func ineligibleAndEligibleButUnauthorizedExercisesAreRejectedSeparately() {
        let weighted = exercise(
            "dumbbell.row",
            name: "Dumbbell row",
            equipmentID: "dumbbell",
            quantity: 2
        )
        let squat = exercise("bodyweight.squat", name: "Bodyweight squat")
        let validationContext = context(
            definitions: [weighted, squat],
            authorized: [weighted.id]
        )

        #expect(validator.validate(
            plan(step: movementStep(id: weighted.id.rawValue, title: weighted.displayName)),
            context: validationContext
        ).errors == [.ineligibleExercise(step: 1, id: weighted.id.rawValue)])
        #expect(validator.validate(
            plan(step: movementStep(id: squat.id.rawValue, title: squat.displayName)),
            context: validationContext
        ).errors == [.unauthorizedCandidate(step: 1, id: squat.id.rawValue)])
    }

    @Test func exactLegacyIDAndUniqueAliasRepairToStableIDWithAudit() throws {
        let squat = exercise(
            "bodyweight.squat",
            name: "Bodyweight squat",
            aliases: ["Air squat"],
            legacyIDs: [ExerciseID(rawValue: "legacy.squat")!]
        )
        let validationContext = context(definitions: [squat], authorized: [squat.id])

        let legacy = validator.validate(
            plan(step: movementStep(id: "legacy.squat", title: "Legacy")),
            context: validationContext
        )
        let alias = validator.validate(
            plan(step: movementStep(id: nil, title: "Air squat")),
            context: validationContext
        )

        #expect(legacy.proposal?.steps[0].exerciseID == squat.id.rawValue)
        #expect(legacy.repairs == [
            GeneratedWorkoutRepair(
                step: 1,
                suppliedReference: "legacy.squat",
                stableID: squat.id.rawValue,
                match: .legacyID
            ),
        ])
        #expect(alias.proposal?.steps[0].exerciseID == squat.id.rawValue)
        #expect(alias.repairs.first?.match == .normalizedReference)
    }

    @Test func customExercisesMustBeExplicitInstructionalAndIDFree() throws {
        let validationContext = context(definitions: [], authorized: [])
        var custom = movementStep(id: nil, title: "Coach custom reach")
        custom.customExercise = true

        #expect(validator.validate(
            plan(step: custom),
            context: validationContext
        ).isValid)

        var claimsID = custom
        claimsID.exerciseID = "bodyweight.squat"
        #expect(validator.validate(
            plan(step: claimsID),
            context: validationContext
        ).errors == [.customExerciseClaimsCatalogueID(step: 1)])

        var missingInstruction = custom
        missingInstruction.instruction = "  "
        #expect(validator.validate(
            plan(step: missingInstruction),
            context: validationContext
        ).errors == [.missingInstruction(step: 1)])

        #expect(validator.validate(
            plan(step: movementStep(id: nil, title: "Unmarked custom")),
            context: validationContext
        ).errors == [.unresolvedReference(step: 1, reference: "Unmarked custom")])
    }

    @Test func instructionsAndTrackingFieldsAreValidatedBeforePreview() {
        let reps = exercise("bodyweight.squat", name: "Bodyweight squat")
        let duration = exercise(
            "bodyweight.plank",
            name: "Plank",
            trackingMode: "duration"
        )
        let validationContext = context(
            definitions: [reps, duration],
            authorized: [reps.id, duration.id]
        )
        var noInstruction = movementStep(id: reps.id.rawValue, title: reps.displayName)
        noInstruction.instruction = nil
        var noReps = movementStep(id: reps.id.rawValue, title: reps.displayName)
        noReps.reps = nil
        var noDuration = movementStep(id: duration.id.rawValue, title: duration.displayName)
        noDuration.durationSeconds = nil

        #expect(validator.validate(
            plan(step: noInstruction),
            context: validationContext
        ).errors == [.missingInstruction(step: 1)])
        #expect(validator.validate(
            plan(step: noReps),
            context: validationContext
        ).errors == [.missingRepetitionTracking(step: 1, id: reps.id.rawValue)])
        #expect(validator.validate(
            plan(step: noDuration),
            context: validationContext
        ).errors == [.missingDurationTracking(step: 1, id: duration.id.rawValue)])
    }

    private let validator = GeneratedWorkoutValidator()

    private func plan(step: WorkoutPlanStepProposal) -> WorkoutPlanProposal {
        WorkoutPlanProposal(
            title: "Validated plan",
            goal: "Build strength",
            estimatedDurationMinutes: 30,
            targetEffort: 6,
            location: "Home",
            notes: nil,
            steps: [step]
        )
    }

    private func movementStep(
        id: String?,
        title: String
    ) -> WorkoutPlanStepProposal {
        WorkoutPlanStepProposal(
            type: WorkoutStepType.exercise.rawValue,
            exerciseID: id,
            title: title,
            instruction: "Move with control.",
            sets: 3,
            reps: 8,
            durationSeconds: 30,
            distanceMeters: nil,
            targetWeightKilograms: nil,
            restSeconds: 60,
            side: nil,
            equipment: nil,
            notes: nil
        )
    }

    private func context(
        definitions: [ExerciseDefinition],
        authorized: Set<ExerciseID>
    ) -> GeneratedWorkoutValidationContext {
        let equipment = EquipmentTaxonomy(schemaVersion: 1, equipment: [
            EquipmentDefinition(
                id: ExerciseEquipmentID(rawValue: "none"),
                displayName: "No equipment",
                category: ExerciseEquipmentCategory(rawValue: "none"),
                lifecycle: EquipmentLifecycle(status: .active)
            ),
            EquipmentDefinition(
                id: ExerciseEquipmentID(rawValue: "dumbbell"),
                displayName: "Dumbbell",
                category: ExerciseEquipmentCategory(rawValue: "free_weight"),
                lifecycle: EquipmentLifecycle(status: .active)
            ),
        ])
        let environments = ExerciseEnvironmentTaxonomy(
            schemaVersion: 1,
            environments: [
                ExerciseEnvironmentDefinition(
                    id: ExerciseEnvironmentID(rawValue: "home"),
                    displayName: "Home",
                    defaultCapabilities: [ExerciseEnvironmentCapabilityID(rawValue: "floor_space")],
                    rankingTags: ["home"],
                    lifecycle: ExerciseEnvironmentLifecycle(status: .active)
                ),
            ]
        )
        return GeneratedWorkoutValidationContext(
            locationName: "Home",
            definitions: definitions,
            authorizedCandidateIDs: authorized,
            eligibilityEvaluator: ExerciseEligibilityEvaluator(
                equipmentTaxonomy: equipment,
                environmentTaxonomy: environments
            ),
            environment: ExerciseEnvironmentContext(
                presetID: ExerciseEnvironmentID(rawValue: "home")
            ),
            inventory: EquipmentInventory(quantities: [:])
        )
    }

    private func exercise(
        _ id: String,
        name: String,
        equipmentID: String = "none",
        quantity: Int = 1,
        trackingMode: String = "reps",
        status: ExerciseLifecycleStatus = .active,
        aliases: [String]? = nil,
        legacyIDs: [ExerciseID]? = nil
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: ExerciseID(rawValue: id)!,
            schemaVersion: 1,
            displayName: name,
            category: ExerciseCategory(rawValue: "strength"),
            movementPattern: ExerciseMovementPattern(rawValue: "squat"),
            exerciseType: ExerciseType(rawValue: "repetition"),
            equipment: ExerciseEquipmentRequirements(required: [
                ExerciseEquipmentClause(
                    id: ExerciseEquipmentID(rawValue: equipmentID),
                    quantity: quantity
                ),
            ]),
            trackingMode: ExerciseTrackingMode(rawValue: trackingMode),
            instructions: ["Move with control."],
            lifecycle: ExerciseLifecycle(status: status, replacementExerciseID: nil),
            media: nil,
            aliases: aliases,
            legacyIDs: legacyIDs,
            guidance: nil,
            environmentRequirements: nil
        )
    }
}

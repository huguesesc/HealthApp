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

    @Test func unresolvableReferencesArePreservedAsExplicitCustomExercises() throws {
        let validationContext = context(definitions: [], authorized: [])

        let outcome = validator.validate(
            plan(step: movementStep(id: nil, title: "Unmarked custom")),
            context: validationContext
        )

        let validated = try #require(outcome.proposal)
        #expect(outcome.errors.isEmpty)
        #expect(validated.steps[0].customExercise == true)
        #expect(validated.steps[0].exerciseID == nil)
        #expect(validated.steps[0].title == "Unmarked custom")
        #expect(
            outcome.demotions == [
                GeneratedWorkoutDemotion(
                    step: 1,
                    suppliedReference: "Unmarked custom",
                    reason: .unresolvedReference
                ),
            ]
        )
    }

    @Test func ambiguousAndInactiveReferencesArePreservedWithoutCatalogueEndorsement() throws {
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

        let ambiguous = validator.validate(
            plan(step: movementStep(id: nil, title: "Shared name")),
            context: validationContext
        )
        let deprecatedOutcome = validator.validate(
            plan(step: movementStep(id: deprecated.id.rawValue, title: deprecated.displayName)),
            context: validationContext
        )
        let disabledOutcome = validator.validate(
            plan(step: movementStep(id: disabled.id.rawValue, title: disabled.displayName)),
            context: validationContext
        )

        for outcome in [ambiguous, deprecatedOutcome, disabledOutcome] {
            let validated = try #require(outcome.proposal)
            #expect(outcome.errors.isEmpty)
            #expect(validated.steps[0].customExercise == true)
            #expect(validated.steps[0].exerciseID == nil)
            #expect(!outcome.demotions.isEmpty)
        }
        #expect(ambiguous.demotions[0].reason == .ambiguousReference)
        #expect(deprecatedOutcome.demotions[0].reason == .inactiveLifecycle(.deprecated))
        #expect(disabledOutcome.demotions[0].reason == .inactiveLifecycle(.disabled))
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

        let unmarked = validator.validate(
            plan(step: movementStep(id: nil, title: "Unmarked custom")),
            context: validationContext
        )
        #expect(unmarked.isValid)
        #expect(unmarked.proposal?.steps[0].customExercise == true)

        var unresolvableWithoutInstruction = movementStep(id: nil, title: "Mystery move")
        unresolvableWithoutInstruction.instruction = " "
        #expect(validator.validate(
            plan(step: unresolvableWithoutInstruction),
            context: validationContext
        ).errors == [.missingInstruction(step: 1)])
    }

    @Test func boundedNormalizationResolvesMessyInputsToExactEntries() throws {
        let squat = exercise("bodyweight.squat", name: "Bodyweight squat")
        let rdl = exercise(
            "barbell.romanian_deadlift",
            name: "Barbell Romanian deadlift",
            aliases: ["RDL", "Romanian deadlift", "Barbell RDL"]
        )
        let curl = exercise(
            "dumbbell.biceps_curl",
            name: "Dumbbell biceps curl",
            legacyNames: ["Dumbell biceps curl"]
        )
        let validationContext = context(
            definitions: [squat, rdl, curl],
            authorized: [squat.id, rdl.id, curl.id]
        )

        func resolvedTitle(_ raw: String) -> String {
            let outcome = validator.validate(
                plan(step: movementStep(id: nil, title: raw)),
                context: validationContext
            )
            #expect(outcome.demotions.isEmpty)
            guard let validated = outcome.proposal else { return "<rejected>" }
            return validated.steps[0].exerciseID ?? "<custom>"
        }

        #expect(resolvedTitle("  Bodyweight  SQUAT!! ") == "bodyweight.squat")
        #expect(resolvedTitle("body-weight-squat") == "bodyweight.squat")
        #expect(resolvedTitle("rdl") == "barbell.romanian_deadlift")
        #expect(resolvedTitle("Romanian Deadlift.") == "barbell.romanian_deadlift")
        #expect(resolvedTitle("BARBELL RDL!") == "barbell.romanian_deadlift")
        #expect(resolvedTitle("dumbell BICEPS CURL") == "dumbbell.biceps_curl")

        let unilateral = validator.validate(
            plan(step: movementStep(id: nil, title: "Single-leg bodyweight squat variation")),
            context: validationContext
        )
        #expect(unilateral.proposal?.steps[0].exerciseID == nil)
        #expect(unilateral.proposal?.steps[0].title == "Single-leg bodyweight squat variation")
        #expect(unilateral.demotions.count == 1)
    }

    @Test func demotionTouchesOnlyTheOffendingStepAndIsDeterministic() {
        let squat = exercise("bodyweight.squat", name: "Bodyweight squat")
        let validationContext = context(definitions: [squat], authorized: [squat.id])

        var first = movementStep(id: squat.id.rawValue, title: squat.displayName)
        first.instruction = "Squat with control."
        var second = movementStep(id: nil, title: "Mystery machine flow")
        second.instruction = "Move however the machine allows."
        var third = movementStep(id: squat.id.rawValue, title: squat.displayName)
        third.instruction = "Finish with control."
        let proposal = WorkoutPlanProposal(
            title: "Multi-step",
            goal: "Build strength",
            estimatedDurationMinutes: 20,
            targetEffort: 5,
            location: "Home",
            notes: "Keep it easy",
            steps: [first, second, third]
        )

        let outcomeOne = validator.validate(proposal, context: validationContext)
        let outcomeTwo = validator.validate(proposal, context: validationContext)

        #expect(outcomeOne.proposal?.steps[0].exerciseID == "bodyweight.squat")
        #expect(outcomeOne.proposal?.steps[0].title == "Bodyweight squat")
        #expect(outcomeOne.proposal?.steps[2].exerciseID == "bodyweight.squat")

        #expect(outcomeOne.proposal?.steps[1].customExercise == true)
        #expect(outcomeOne.proposal?.steps[1].exerciseID == nil)
        #expect(outcomeOne.proposal?.steps[1].title == "Mystery machine flow")
        #expect(outcomeOne.demotions == [
            GeneratedWorkoutDemotion(
                step: 2,
                suppliedReference: "Mystery machine flow",
                reason: .unresolvedReference
            ),
        ])
        #expect(outcomeOne.repairs.isEmpty)

        // Deterministic: identical input produces an identical outcome.
        #expect(outcomeOne.proposal == outcomeTwo.proposal)
        #expect(outcomeOne.demotions == outcomeTwo.demotions)
        #expect(outcomeOne.errors == outcomeTwo.errors)
    }

    @Test func demotionPreservesNeighbouringStepsVerbatim() throws {
        let squat = exercise("bodyweight.squat", name: "Bodyweight squat")
        let validationContext = context(definitions: [squat], authorized: [squat.id])

        let neighbourBefore = movementStep(id: squat.id.rawValue, title: squat.displayName)
        var offender = movementStep(id: nil, title: "Unknown band sequence")
        offender.instruction = "Follow the band sequence."
        offender.notes = "keep these notes"
        let neighbourAfter = movementStep(id: squat.id.rawValue, title: squat.displayName)

        let outcome = validator.validate(
            WorkoutPlanProposal(
                title: "Three steps",
                goal: nil,
                estimatedDurationMinutes: nil,
                targetEffort: nil,
                location: "Home",
                notes: nil,
                steps: [neighbourBefore, offender, neighbourAfter]
            ),
            context: validationContext
        )

        let validated = try #require(outcome.proposal)
        #expect(validated.steps.count == 3)
        #expect(validated.steps[0].title == "Bodyweight squat")
        #expect(validated.steps[0].customExercise == false)
        #expect(validated.steps[2].title == "Bodyweight squat")
        #expect(validated.steps[2].customExercise == false)

        #expect(validated.steps[1].title == "Unknown band sequence")
        #expect(validated.steps[1].instruction == "Follow the band sequence.")
        #expect(validated.steps[1].notes == "keep these notes")
        #expect(validated.steps[1].exerciseID == nil)
        #expect(validated.steps[1].customExercise == true)
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
        legacyIDs: [ExerciseID]? = nil,
        legacyNames: [String]? = nil
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
            environmentRequirements: nil,
            legacyNames: legacyNames
        )
    }
}

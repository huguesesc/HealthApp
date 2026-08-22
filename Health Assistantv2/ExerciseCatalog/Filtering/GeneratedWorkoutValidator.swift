import Foundation

struct GeneratedWorkoutValidationContext: Sendable {
    let locationName: String
    let definitions: [ExerciseDefinition]
    let authorizedCandidateIDs: Set<ExerciseID>
    let eligibilityEvaluator: ExerciseEligibilityEvaluator
    let environment: ExerciseEnvironmentContext
    let inventory: EquipmentInventory
}

enum GeneratedWorkoutValidationError: Error, Equatable, Sendable {
    case missingExerciseReference(step: Int)
    case customExerciseClaimsCatalogueID(step: Int)
    case unresolvedReference(step: Int, reference: String)
    case ambiguousReference(step: Int, reference: String)
    case inactiveExercise(step: Int, id: String, status: ExerciseLifecycleStatus)
    case ineligibleExercise(step: Int, id: String)
    case unauthorizedCandidate(step: Int, id: String)
    case missingInstruction(step: Int)
    case missingRepetitionTracking(step: Int, id: String)
    case missingDurationTracking(step: Int, id: String)

    var message: String {
        switch self {
        case .missingExerciseReference(let step):
            "step \(step) needs exercise_id or custom_exercise=true"
        case .customExerciseClaimsCatalogueID(let step):
            "step \(step) is custom and cannot claim exercise_id"
        case .unresolvedReference(let step, let reference):
            "step \(step) has unknown exercise reference \(reference)"
        case .ambiguousReference(let step, let reference):
            "step \(step) has ambiguous exercise reference \(reference)"
        case .inactiveExercise(let step, let id, let status):
            "step \(step) uses \(status.rawValue) exercise \(id)"
        case .ineligibleExercise(let step, let id):
            "step \(step) uses ineligible exercise \(id)"
        case .unauthorizedCandidate(let step, let id):
            "step \(step) uses exercise \(id) that was not in the authorized candidate payload"
        case .missingInstruction(let step):
            "step \(step) needs a nonempty instruction"
        case .missingRepetitionTracking(let step, let id):
            "step \(step) for \(id) needs positive sets and reps"
        case .missingDurationTracking(let step, let id):
            "step \(step) for \(id) needs positive duration_seconds"
        }
    }
}

struct GeneratedWorkoutRepair: Equatable, Sendable {
    let step: Int
    let suppliedReference: String
    let stableID: String
    let match: LegacyExerciseMatch
}

enum GeneratedWorkoutDemotionReason: Equatable, Sendable {
    case unresolvedReference
    case ambiguousReference
    case inactiveLifecycle(ExerciseLifecycleStatus)
}

/// A movement step whose catalogue reference could not be exactly resolved or
/// is not active. The step is preserved verbatim as an explicit custom
/// exercise so no user-visible movement is ever dropped; the demotion is
/// recorded for audit and surfaced to the model/user.
struct GeneratedWorkoutDemotion: Equatable, Sendable {
    let step: Int
    let suppliedReference: String
    let reason: GeneratedWorkoutDemotionReason
}

struct GeneratedWorkoutValidationOutcome: Sendable {
    let proposal: WorkoutPlanProposal?
    let repairs: [GeneratedWorkoutRepair]
    let demotions: [GeneratedWorkoutDemotion]
    let errors: [GeneratedWorkoutValidationError]

    init(
        proposal: WorkoutPlanProposal?,
        repairs: [GeneratedWorkoutRepair],
        demotions: [GeneratedWorkoutDemotion] = [],
        errors: [GeneratedWorkoutValidationError]
    ) {
        self.proposal = proposal
        self.repairs = repairs
        self.demotions = demotions
        self.errors = errors
    }

    var isValid: Bool {
        proposal != nil && errors.isEmpty
    }
}

struct GeneratedWorkoutValidator: Sendable {
    func validate(
        _ proposal: WorkoutPlanProposal,
        context: GeneratedWorkoutValidationContext
    ) -> GeneratedWorkoutValidationOutcome {
        let resolver = LegacyExerciseResolver(
            definitions: context.definitions,
            diagnosticHandler: { _ in }
        )
        var validated = proposal
        var repairs: [GeneratedWorkoutRepair] = []
        var demotions: [GeneratedWorkoutDemotion] = []
        var errors: [GeneratedWorkoutValidationError] = []

        for index in validated.steps.indices {
            var step = validated.steps[index]
            let position = index + 1
            let suppliedID = step.exerciseID?.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasSuppliedID = suppliedID?.isEmpty == false
            let requiresReference = Self.requiresExerciseReference(step.type)

            if step.customExercise == true {
                if hasSuppliedID {
                    errors.append(.customExerciseClaimsCatalogueID(step: position))
                }
                if step.instruction?.trimmed.isEmpty != false {
                    errors.append(.missingInstruction(step: position))
                }
                step.exerciseID = nil
                validated.steps[index] = step
                continue
            }

            guard hasSuppliedID || requiresReference else {
                validated.steps[index] = step
                continue
            }
            let reference = hasSuppliedID ? suppliedID! : step.title.trimmed
            guard !reference.isEmpty else {
                errors.append(.missingExerciseReference(step: position))
                continue
            }

            let definition: ExerciseDefinition
            let match: LegacyExerciseMatch
            switch resolver.resolve(reference) {
            case .resolved(let resolved, let resolvedMatch):
                definition = resolved
                match = resolvedMatch
            case .ambiguous:
                if let demotionError = demote(
                    &validated.steps[index],
                    position: position,
                    reference: reference,
                    reason: .ambiguousReference,
                    demotions: &demotions,
                    errors: &errors
                ) {
                    errors.append(demotionError)
                }
                continue
            case .unresolved:
                if let demotionError = demote(
                    &validated.steps[index],
                    position: position,
                    reference: reference,
                    reason: .unresolvedReference,
                    demotions: &demotions,
                    errors: &errors
                ) {
                    errors.append(demotionError)
                }
                continue
            }

            guard definition.lifecycle.status == .active else {
                if let demotionError = demote(
                    &validated.steps[index],
                    position: position,
                    reference: reference,
                    reason: .inactiveLifecycle(definition.lifecycle.status),
                    demotions: &demotions,
                    errors: &errors
                ) {
                    errors.append(demotionError)
                }
                continue
            }
            guard context.eligibilityEvaluator.evaluate(
                exercise: definition,
                environment: context.environment,
                inventory: context.inventory
            ).isEligible else {
                errors.append(.ineligibleExercise(step: position, id: definition.id.rawValue))
                continue
            }
            guard context.authorizedCandidateIDs.contains(definition.id) else {
                errors.append(
                    .unauthorizedCandidate(step: position, id: definition.id.rawValue)
                )
                continue
            }
            guard step.instruction?.trimmed.isEmpty == false else {
                errors.append(.missingInstruction(step: position))
                continue
            }

            if definition.trackingMode.rawValue == "reps",
               !(Self.isPositive(step.sets) && Self.isPositive(step.reps)) {
                errors.append(
                    .missingRepetitionTracking(step: position, id: definition.id.rawValue)
                )
                continue
            }
            if definition.trackingMode.rawValue == "duration",
               !Self.isPositive(step.durationSeconds) {
                errors.append(
                    .missingDurationTracking(step: position, id: definition.id.rawValue)
                )
                continue
            }

            if reference != definition.id.rawValue || match != .stableID {
                repairs.append(
                    GeneratedWorkoutRepair(
                        step: position,
                        suppliedReference: reference,
                        stableID: definition.id.rawValue,
                        match: match
                    )
                )
            }
            step.exerciseID = definition.id.rawValue
            step.customExercise = false
            step.title = definition.displayName
            validated.steps[index] = step
        }

        guard errors.isEmpty else {
            return GeneratedWorkoutValidationOutcome(
                proposal: nil,
                repairs: repairs,
                demotions: demotions,
                errors: errors
            )
        }
        return GeneratedWorkoutValidationOutcome(
            proposal: validated,
            repairs: repairs,
            demotions: demotions,
            errors: []
        )
    }

    /// Preserves an unresolvable movement as an explicit custom exercise.
    /// Returns the error to record when preservation is impossible because the
    /// step carries no written instruction; a movement without text cannot be
    /// kept honestly, and inventing one is forbidden.
    private static func demote(
        _ step: inout WorkoutPlanStepProposal,
        position: Int,
        reference: String,
        reason: GeneratedWorkoutDemotionReason,
        demotions: inout [GeneratedWorkoutDemotion],
        errors: inout [GeneratedWorkoutValidationError]
    ) -> GeneratedWorkoutValidationError? {
        guard step.instruction?.trimmed.isEmpty == false else {
            return .missingInstruction(step: position)
        }
        step.exerciseID = nil
        step.customExercise = true
        demotions.append(
            GeneratedWorkoutDemotion(
                step: position,
                suppliedReference: reference,
                reason: reason
            )
        )
        return nil
    }

    private static func requiresExerciseReference(_ rawType: String) -> Bool {
        switch WorkoutStepType(rawValue: rawType) ?? .freeform {
        case .exercise, .mobility, .hold, .cardio, .interval, .distance:
            true
        case .warmUp, .rest, .cooldown, .freeform:
            false
        }
    }

    private static func isPositive(_ value: Int?) -> Bool {
        guard let value else { return false }
        return value > 0
    }
}

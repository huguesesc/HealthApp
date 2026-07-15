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

struct GeneratedWorkoutValidationOutcome: Sendable {
    let proposal: WorkoutPlanProposal?
    let repairs: [GeneratedWorkoutRepair]
    let errors: [GeneratedWorkoutValidationError]

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
                errors.append(.ambiguousReference(step: position, reference: reference))
                continue
            case .unresolved:
                errors.append(.unresolvedReference(step: position, reference: reference))
                continue
            }

            guard definition.lifecycle.status == .active else {
                errors.append(
                    .inactiveExercise(
                        step: position,
                        id: definition.id.rawValue,
                        status: definition.lifecycle.status
                    )
                )
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
                errors: errors
            )
        }
        return GeneratedWorkoutValidationOutcome(
            proposal: validated,
            repairs: repairs,
            errors: []
        )
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

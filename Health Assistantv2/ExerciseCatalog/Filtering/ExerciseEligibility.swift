import Foundation

struct ExerciseEnvironmentContext: Hashable, Sendable {
    let presetID: ExerciseEnvironmentID?
    let capabilityOverrides: [ExerciseEnvironmentCapabilityID: Bool]

    init(
        presetID: ExerciseEnvironmentID? = nil,
        capabilityOverrides: [ExerciseEnvironmentCapabilityID: Bool] = [:]
    ) {
        self.presetID = presetID
        self.capabilityOverrides = capabilityOverrides
    }

    func resolvedCapabilities(
        in taxonomy: ExerciseEnvironmentTaxonomy
    ) -> [ExerciseEnvironmentCapabilityID: Bool] {
        var capabilities: [ExerciseEnvironmentCapabilityID: Bool] = [:]

        if let presetID, let preset = taxonomy.definition(for: presetID) {
            for capability in preset.defaultCapabilities {
                capabilities[capability] = true
            }
        }
        for (capability, value) in capabilityOverrides {
            capabilities[capability] = value
        }

        return capabilities
    }
}

enum ExerciseEligibilityReason: Hashable, Sendable {
    case invalidEquipmentRequirementData([EquipmentTaxonomyValidationError])
    case unmetEquipmentRequirements
    case missingRequiredEnvironmentCapability(ExerciseEnvironmentCapabilityID)
    case prohibitedEnvironmentCapabilityPresent(ExerciseEnvironmentCapabilityID)
}

struct ExerciseEligibilityResult: Hashable, Sendable {
    let reasons: [ExerciseEligibilityReason]

    var isEligible: Bool {
        reasons.isEmpty
    }
}

struct ExerciseEligibilityEvaluator: Sendable {
    let equipmentTaxonomy: EquipmentTaxonomy
    let environmentTaxonomy: ExerciseEnvironmentTaxonomy

    func evaluate(
        exercise: ExerciseDefinition,
        environment: ExerciseEnvironmentContext,
        inventory: EquipmentInventory
    ) -> ExerciseEligibilityResult {
        let invalidEquipmentReasons = exercise.equipment.structuralValidationErrors()
        guard invalidEquipmentReasons.isEmpty else {
            return ExerciseEligibilityResult(reasons: [
                .invalidEquipmentRequirementData(invalidEquipmentReasons)
            ])
        }

        var reasons: [ExerciseEligibilityReason] = []
        if !exercise.equipment.isSatisfied(by: inventory, in: equipmentTaxonomy) {
            reasons.append(.unmetEquipmentRequirements)
        }

        // Presets only provide defaults. Explicit overrides determine the final value.
        let capabilities = environment.resolvedCapabilities(in: environmentTaxonomy)
        let requirements = exercise.environmentRequirements

        for requirement in uniqueSortedCapabilityIDs(requirements?.required ?? [])
            where capabilities[requirement] != true {
            reasons.append(.missingRequiredEnvironmentCapability(requirement))
        }

        for requirement in uniqueSortedCapabilityIDs(requirements?.prohibited ?? [])
            where capabilities[requirement] == true {
            reasons.append(.prohibitedEnvironmentCapabilityPresent(requirement))
        }

        return ExerciseEligibilityResult(reasons: reasons)
    }

    private func uniqueSortedCapabilityIDs(
        _ requirements: [ExerciseEnvironmentRequirement]
    ) -> [ExerciseEnvironmentCapabilityID] {
        Set(requirements.map { ExerciseEnvironmentCapabilityID(rawValue: $0.rawValue) })
            .sorted { $0.rawValue < $1.rawValue }
    }
}

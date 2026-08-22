import Foundation

struct ExerciseDefinition: Codable, Hashable, Sendable {
    let id: ExerciseID
    let schemaVersion: Int
    let displayName: String
    let category: ExerciseCategory
    let movementPattern: ExerciseMovementPattern
    let exerciseType: ExerciseType
    let equipment: ExerciseEquipmentRequirements
    let trackingMode: ExerciseTrackingMode
    let instructions: [String]
    let lifecycle: ExerciseLifecycle
    let media: [ExerciseMediaDefinition]?

    let aliases: [String]?
    let legacyIDs: [ExerciseID]?
    let guidance: [String]?
    let environmentRequirements: ExerciseEnvironmentRequirements?
    let legacyNames: [String]?
}

struct ExerciseEquipmentRequirements: Codable, Hashable, Sendable {
    let required: [ExerciseEquipmentClause]
    let alternatives: [[ExerciseEquipmentClause]]

    init(required: [ExerciseEquipmentClause], alternatives: [[ExerciseEquipmentClause]] = []) {
        self.required = required
        self.alternatives = alternatives
    }

    func isSatisfied(by inventory: EquipmentInventory, in taxonomy: EquipmentTaxonomy) -> Bool {
        guard structuralValidationErrors().isEmpty else {
            return false
        }
        if isSatisfied(required, by: inventory, in: taxonomy) {
            return true
        }
        return alternatives.contains { isSatisfied($0, by: inventory, in: taxonomy) }
    }

    private func isSatisfied(
        _ group: [ExerciseEquipmentClause],
        by inventory: EquipmentInventory,
        in taxonomy: EquipmentTaxonomy
    ) -> Bool {
        if group.count == 1, group[0].id.rawValue == "none" {
            return true
        }
        return group.allSatisfy {
            inventory.availableQuantity(of: $0.id, in: taxonomy) >= $0.quantity
        }
    }

    func structuralValidationErrors() -> [EquipmentTaxonomyValidationError] {
        var errors: [EquipmentTaxonomyValidationError] = []

        for entry in requirementGroups() {
            let group = entry.0
            let clauses = entry.1
            guard !clauses.isEmpty else {
                errors.append(.emptyRequirementGroup(group: group))
                continue
            }

            for clause in clauses where clause.quantity <= 0 {
                errors.append(
                    .nonpositiveRequirementQuantity(
                        group: group,
                        equipmentID: clause.id,
                        quantity: clause.quantity
                    )
                )
            }
            if clauses.count > 1, clauses.contains(where: { $0.id.rawValue == "none" }) {
                errors.append(
                    .noneCombinedWithOtherClauses(
                        group: group,
                        clauseIDs: clauses.map(\.id).sorted { $0.rawValue < $1.rawValue }
                    )
                )
            }
        }
        return errors
    }

    private func requirementGroups() -> [(ExerciseEquipmentRequirementGroup, [ExerciseEquipmentClause])] {
        var groups: [(ExerciseEquipmentRequirementGroup, [ExerciseEquipmentClause])] = [
            (.required, required)
        ]
        groups.append(contentsOf: alternatives.enumerated().map {
            (.alternative(index: $0.offset), $0.element)
        })
        return groups
    }
}

struct ExerciseEquipmentClause: Codable, Hashable, Sendable {
    let id: ExerciseEquipmentID
    let quantity: Int
}

struct EquipmentInventory: Hashable, Sendable {
    let quantities: [ExerciseEquipmentID: Int]

    init(quantities: [ExerciseEquipmentID: Int]) {
        self.quantities = quantities.filter { $0.value > 0 }
    }

    func availableQuantity(of requiredID: ExerciseEquipmentID, in taxonomy: EquipmentTaxonomy) -> Int {
        guard requiredID.rawValue != "none" else {
            return .max
        }

        return quantities.reduce(into: 0) { total, entry in
            let stockedID = entry.key
            let stockedQuantity = entry.value
            guard let stockedDefinition = taxonomy.definition(for: stockedID) else {
                return
            }

            if stockedID == requiredID {
                total += stockedQuantity
                return
            }
            let fulfillments = stockedDefinition.fulfills.filter { $0.id == requiredID }
            guard fulfillments.count == 1, let fulfillment = fulfillments.first,
                  fulfillment.quantityPerUnit > 0 else {
                return
            }
            total += stockedQuantity * fulfillment.quantityPerUnit
        }
    }
}

struct ExerciseEnvironmentRequirements: Codable, Hashable, Sendable {
    let required: [ExerciseEnvironmentRequirement]
    let prohibited: [ExerciseEnvironmentRequirement]?
}

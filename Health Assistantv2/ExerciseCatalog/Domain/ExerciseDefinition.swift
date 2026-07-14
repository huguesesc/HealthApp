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

    let aliases: [String]?
    let legacyIDs: [ExerciseID]?
    let guidance: [String]?
    let environmentRequirements: ExerciseEnvironmentRequirements?
}

struct ExerciseEquipmentRequirements: Codable, Hashable, Sendable {
    let required: [ExerciseEquipmentClause]
    let alternatives: [[ExerciseEquipmentClause]]

    init(required: [ExerciseEquipmentClause], alternatives: [[ExerciseEquipmentClause]] = []) {
        self.required = required
        self.alternatives = alternatives
    }

    func isSatisfied(by inventory: EquipmentInventory, in taxonomy: EquipmentTaxonomy) -> Bool {
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
        guard !group.contains(where: { $0.id.rawValue == "none" }) else {
            return false
        }
        return group.allSatisfy {
            inventory.availableQuantity(of: $0.id, in: taxonomy) >= $0.quantity
        }
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
            let quantityPerUnit = stockedDefinition.fulfills
                .filter { $0.id == requiredID }
                .reduce(0) { $0 + $1.quantityPerUnit }
            total += stockedQuantity * quantityPerUnit
        }
    }
}

struct ExerciseEnvironmentRequirements: Codable, Hashable, Sendable {
    let required: [ExerciseEnvironmentRequirement]
    let prohibited: [ExerciseEnvironmentRequirement]?
}

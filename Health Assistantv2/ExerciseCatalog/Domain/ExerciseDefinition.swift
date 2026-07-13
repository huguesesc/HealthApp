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
    let guidance: [String]?
    let environmentRequirements: [ExerciseEnvironmentRequirement]?
}

struct ExerciseEquipmentRequirements: Codable, Hashable, Sendable {
    let required: [ExerciseEquipmentRequirementGroup]
    let alternatives: [ExerciseEquipmentRequirementGroup]
}

struct ExerciseEquipmentRequirementGroup: Codable, Hashable, Sendable {
    let equipmentIDs: [ExerciseEquipmentID]

    init(equipmentIDs: [ExerciseEquipmentID]) {
        self.equipmentIDs = equipmentIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        equipmentIDs = try container.decode([ExerciseEquipmentID].self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(equipmentIDs)
    }
}

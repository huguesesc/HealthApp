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
    let required: [ExerciseEquipmentClause]
    let alternatives: [[ExerciseEquipmentClause]]
}

struct ExerciseEquipmentClause: Codable, Hashable, Sendable {
    let id: ExerciseEquipmentID
    let quantity: Int
}

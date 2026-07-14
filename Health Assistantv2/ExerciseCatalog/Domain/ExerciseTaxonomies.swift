import Foundation

struct ExerciseID: Codable, Hashable, Sendable {
    private static let stableIDPattern = "^[a-z0-9]+(?:_[a-z0-9]+)*\\.[a-z0-9]+(?:_[a-z0-9]+)*(?:\\.[a-z0-9]+(?:_[a-z0-9]+)*)?$"

    let rawValue: String

    init?(rawValue: String) {
        guard rawValue.range(of: Self.stableIDPattern, options: .regularExpression) != nil else {
            return nil
        }
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let identifier = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Exercise ID must match the stable dot-ID format."
            )
        }
        self = identifier
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct ExerciseCategory: Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct ExerciseMovementPattern: Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct ExerciseType: Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct ExerciseEquipmentID: Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct EquipmentCategory: Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct EquipmentLifecycle: Codable, Hashable, Sendable {
    let status: ExerciseLifecycleStatus
}

struct EquipmentFulfillment: Codable, Hashable, Sendable {
    let id: ExerciseEquipmentID
    let quantityPerUnit: Int
}

struct EquipmentDefinition: Codable, Hashable, Sendable {
    let id: ExerciseEquipmentID
    let displayName: String
    let aliases: [String]
    let category: EquipmentCategory
    let parentID: ExerciseEquipmentID?
    let fulfills: [EquipmentFulfillment]
    let lifecycle: EquipmentLifecycle

    init(
        id: ExerciseEquipmentID,
        displayName: String,
        aliases: [String] = [],
        category: EquipmentCategory,
        parentID: ExerciseEquipmentID? = nil,
        fulfills: [EquipmentFulfillment] = [],
        lifecycle: EquipmentLifecycle
    ) {
        self.id = id
        self.displayName = displayName
        self.aliases = aliases
        self.category = category
        self.parentID = parentID
        self.fulfills = fulfills
        self.lifecycle = lifecycle
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case aliases
        case category
        case parentID
        case fulfills
        case lifecycle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(ExerciseEquipmentID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        category = try container.decode(EquipmentCategory.self, forKey: .category)
        parentID = try container.decodeIfPresent(ExerciseEquipmentID.self, forKey: .parentID)
        fulfills = try container.decodeIfPresent([EquipmentFulfillment].self, forKey: .fulfills) ?? []
        lifecycle = try container.decode(EquipmentLifecycle.self, forKey: .lifecycle)
    }
}

struct EquipmentTaxonomy: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let equipment: [EquipmentDefinition]

    init(schemaVersion: Int, equipment: [EquipmentDefinition]) {
        self.schemaVersion = schemaVersion
        self.equipment = equipment
    }

    func definition(for id: ExerciseEquipmentID) -> EquipmentDefinition? {
        equipment.first { $0.id == id }
    }

    func validationErrors(
        for requirements: ExerciseEquipmentRequirements? = nil
    ) -> [EquipmentTaxonomyValidationError] {
        let definitionsByID = Dictionary(
            equipment.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let orderedDefinitions = equipment.sorted { $0.id.rawValue < $1.id.rawValue }
        var errors: [EquipmentTaxonomyValidationError] = []

        for definition in orderedDefinitions {
            guard let parentID = definition.parentID, definitionsByID[parentID] == nil else {
                continue
            }
            errors.append(.unknownParent(equipmentID: definition.id, parentID: parentID))
        }

        errors.append(contentsOf: parentCycleErrors(in: definitionsByID))

        for definition in orderedDefinitions {
            for fulfillment in definition.fulfills.sorted(by: fulfillmentOrder) where definitionsByID[fulfillment.id] == nil {
                errors.append(
                    .unknownFulfillmentTarget(
                        equipmentID: definition.id,
                        targetID: fulfillment.id
                    )
                )
            }
        }

        if let requirements {
            errors.append(contentsOf: noneCombinationErrors(in: requirements))
        }
        return errors
    }

    private func parentCycleErrors(
        in definitionsByID: [ExerciseEquipmentID: EquipmentDefinition]
    ) -> [EquipmentTaxonomyValidationError] {
        let orderedIDs = definitionsByID.keys.sorted { $0.rawValue < $1.rawValue }
        var visited: Set<ExerciseEquipmentID> = []
        var errors: [EquipmentTaxonomyValidationError] = []

        for startingID in orderedIDs where !visited.contains(startingID) {
            var path: [ExerciseEquipmentID] = []
            var positions: [ExerciseEquipmentID: Int] = [:]
            var currentID: ExerciseEquipmentID? = startingID

            while let id = currentID, definitionsByID[id] != nil {
                if let cycleStart = positions[id] {
                    let cycle = canonicalCycle(Array(path[cycleStart...]))
                    errors.append(.parentCycle(ids: cycle))
                    break
                }
                if visited.contains(id) {
                    break
                }

                positions[id] = path.count
                path.append(id)
                currentID = definitionsByID[id]?.parentID
            }
            visited.formUnion(path)
        }
        return errors
    }

    private func canonicalCycle(_ ids: [ExerciseEquipmentID]) -> [ExerciseEquipmentID] {
        guard let firstIndex = ids.indices.min(by: { ids[$0].rawValue < ids[$1].rawValue }) else {
            return []
        }
        return Array(ids[firstIndex...]) + Array(ids[..<firstIndex])
    }

    private func noneCombinationErrors(
        in requirements: ExerciseEquipmentRequirements
    ) -> [EquipmentTaxonomyValidationError] {
        var groups: [(ExerciseEquipmentRequirementGroup, [ExerciseEquipmentClause])] = [
            (.required, requirements.required)
        ]
        groups.append(contentsOf: requirements.alternatives.enumerated().map {
            (.alternative(index: $0.offset), $0.element)
        })

        return groups.compactMap { group, clauses in
            guard clauses.count > 1, clauses.contains(where: { $0.id.rawValue == "none" }) else {
                return nil
            }
            return .noneCombinedWithOtherClauses(
                group: group,
                clauseIDs: clauses.map(\.id).sorted { $0.rawValue < $1.rawValue }
            )
        }
    }

    private func fulfillmentOrder(
        _ lhs: EquipmentFulfillment,
        _ rhs: EquipmentFulfillment
    ) -> Bool {
        if lhs.id.rawValue != rhs.id.rawValue {
            return lhs.id.rawValue < rhs.id.rawValue
        }
        return lhs.quantityPerUnit < rhs.quantityPerUnit
    }
}

enum ExerciseEquipmentRequirementGroup: Hashable, Sendable {
    case required
    case alternative(index: Int)
}

enum EquipmentTaxonomyValidationError: Error, Hashable, Sendable {
    case unknownParent(equipmentID: ExerciseEquipmentID, parentID: ExerciseEquipmentID)
    case parentCycle(ids: [ExerciseEquipmentID])
    case unknownFulfillmentTarget(equipmentID: ExerciseEquipmentID, targetID: ExerciseEquipmentID)
    case noneCombinedWithOtherClauses(
        group: ExerciseEquipmentRequirementGroup,
        clauseIDs: [ExerciseEquipmentID]
    )
}

struct ExerciseTrackingMode: Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct ExerciseLifecycle: Codable, Hashable, Sendable {
    let status: ExerciseLifecycleStatus
    let replacementExerciseID: ExerciseID?
}

enum ExerciseLifecycleStatus: String, Codable, Hashable, Sendable {
    case active
    case deprecated
    case disabled
}

struct ExerciseEnvironmentRequirement: Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

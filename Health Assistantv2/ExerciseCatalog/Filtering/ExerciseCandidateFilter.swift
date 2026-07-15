import Foundation

struct ExerciseCandidateContext: Hashable, Sendable {
    let environment: ExerciseEnvironmentContext
    let inventory: EquipmentInventory
    let goal: String?
    let durationMinutes: Int?
    let maximumCandidates: Int

    init(
        environment: ExerciseEnvironmentContext,
        inventory: EquipmentInventory,
        goal: String? = nil,
        durationMinutes: Int? = nil,
        maximumCandidates: Int = 14
    ) {
        self.environment = environment
        self.inventory = inventory
        self.goal = goal
        self.durationMinutes = durationMinutes
        self.maximumCandidates = max(maximumCandidates, 0)
    }
}

struct CompactExerciseEquipment: Codable, Equatable, Hashable, Sendable {
    let id: String
    let quantity: Int
}

struct CompactExerciseCandidate: Codable, Equatable, Hashable, Sendable {
    let id: String
    let name: String
    let category: String
    let movementPattern: String
    let trackingMode: String
    let equipmentOptions: [[CompactExerciseEquipment]]
}

struct ExerciseCandidatePayload: Codable, Equatable, Sendable {
    let location: String
    let goal: String?
    let durationMinutes: Int?
    let candidates: [CompactExerciseCandidate]
    let customExercisePolicy: String

    enum CodingKeys: String, CodingKey {
        case location
        case goal
        case durationMinutes = "duration_minutes"
        case candidates
        case customExercisePolicy = "custom_exercise_policy"
    }
}

struct ExerciseCandidateFilter: Sendable {
    let eligibilityEvaluator: ExerciseEligibilityEvaluator

    func candidates(
        from definitions: [ExerciseDefinition],
        context: ExerciseCandidateContext
    ) -> [CompactExerciseCandidate] {
        var remaining = definitions.filter {
            $0.lifecycle.status == .active
                && eligibilityEvaluator.evaluate(
                    exercise: $0,
                    environment: context.environment,
                    inventory: context.inventory
                ).isEligible
        }
        let limit = min(context.maximumCandidates, durationLimit(context.durationMinutes))
        var selected: [ExerciseDefinition] = []
        var movementPatternCounts: [String: Int] = [:]

        while selected.count < limit, !remaining.isEmpty {
            remaining.sort {
                rankingKey(
                    for: $0,
                    goal: context.goal,
                    movementPatternCounts: movementPatternCounts
                ) < rankingKey(
                    for: $1,
                    goal: context.goal,
                    movementPatternCounts: movementPatternCounts
                )
            }
            let next = remaining.removeFirst()
            selected.append(next)
            movementPatternCounts[next.movementPattern.rawValue, default: 0] += 1
        }

        return selected.map(Self.compactCandidate)
    }

    private func rankingKey(
        for definition: ExerciseDefinition,
        goal: String?,
        movementPatternCounts: [String: Int]
    ) -> (Int, Int, String) {
        (
            goalRank(definition, goal: goal),
            movementPatternCounts[definition.movementPattern.rawValue, default: 0],
            definition.id.rawValue
        )
    }

    private func goalRank(_ definition: ExerciseDefinition, goal: String?) -> Int {
        let normalizedGoal = Self.normalized(goal)
        let category = definition.category.rawValue

        if normalizedGoal.contains("endurance") || normalizedGoal.contains("fat") {
            return category == "conditioning" ? 0 : 1
        }
        if normalizedGoal.contains("strength") || normalizedGoal.contains("muscle") {
            return category == "strength" ? 0 : 1
        }
        if normalizedGoal.contains("mobility") {
            return category == "mobility" ? 0 : 1
        }
        return 0
    }

    private func durationLimit(_ durationMinutes: Int?) -> Int {
        guard let durationMinutes else { return 14 }
        if durationMinutes <= 15 { return 6 }
        if durationMinutes <= 30 { return 10 }
        return 14
    }

    private static func compactCandidate(
        _ definition: ExerciseDefinition
    ) -> CompactExerciseCandidate {
        let groups = [definition.equipment.required] + definition.equipment.alternatives
        return CompactExerciseCandidate(
            id: definition.id.rawValue,
            name: definition.displayName,
            category: definition.category.rawValue,
            movementPattern: definition.movementPattern.rawValue,
            trackingMode: definition.trackingMode.rawValue,
            equipmentOptions: groups.map { group in
                group.map {
                    CompactExerciseEquipment(id: $0.id.rawValue, quantity: $0.quantity)
                }
            }
        )
    }

    private static func normalized(_ value: String?) -> String {
        let locale = Locale(identifier: "en_US_POSIX")
        return value?
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
            .lowercased(with: locale) ?? ""
    }
}

struct LegacyWorkoutCandidateContextAdapter: Sendable {
    func context(
        for location: WorkoutLocation,
        equipmentTaxonomy: EquipmentTaxonomy,
        goal: String?,
        durationMinutes: Int?
    ) -> ExerciseCandidateContext {
        ExerciseCandidateContext(
            environment: ExerciseEnvironmentContext(
                presetID: ExerciseEnvironmentID(rawValue: environmentID(for: location.category))
            ),
            inventory: inventory(for: location, equipmentTaxonomy: equipmentTaxonomy),
            goal: goal,
            durationMinutes: durationMinutes
        )
    }

    private func environmentID(for category: WorkoutLocationCategory) -> String {
        switch category {
        case .home: "home"
        case .gym: "gym"
        case .outdoors: "outdoors"
        case .travel: "hotel"
        case .sportVenue: "sport_venue"
        case .custom: "custom"
        }
    }

    private func inventory(
        for location: WorkoutLocation,
        equipmentTaxonomy: EquipmentTaxonomy
    ) -> EquipmentInventory {
        var quantities: [ExerciseEquipmentID: Int] = [:]
        for item in location.equipment where item.isAvailable {
            guard let id = equipmentID(for: item, taxonomy: equipmentTaxonomy) else {
                continue
            }
            quantities[id, default: 0] += max(item.quantity, 1)
        }
        return EquipmentInventory(quantities: quantities)
    }

    private func equipmentID(
        for item: EquipmentItem,
        taxonomy: EquipmentTaxonomy
    ) -> ExerciseEquipmentID? {
        let mappedID: String?
        switch item.category {
        case .bodyweight: mappedID = nil
        case .yogaMat: mappedID = "yoga_mat"
        case .stabilityBall: mappedID = "stability_ball"
        case .miniResistanceBands: mappedID = "mini_resistance_band"
        case .longResistanceBands: mappedID = "long_resistance_band"
        case .foamBalancePad: mappedID = "foam_balance_pad"
        case .wobbleBoard: mappedID = "wobble_board"
        case .balanceDisc: mappedID = "balance_disc"
        case .bosuTrainer: mappedID = "bosu_trainer"
        case .slantBoard: mappedID = "slant_board"
        case .dumbbells: mappedID = "pair_of_dumbbells"
        case .kettlebells: mappedID = "kettlebell"
        case .barbell: mappedID = "barbell"
        case .squatRack: mappedID = "squat_rack"
        case .cableStation: mappedID = "cable_station"
        case .legPress: mappedID = "leg_press_machine"
        case .hamstringCurl: mappedID = "lying_leg_curl_machine"
        case .stationaryBike: mappedID = "stationary_bike"
        case .treadmill: mappedID = "treadmill"
        case .rowingMachine: mappedID = "rowing_machine"
        case .custom:
            return exactEquipmentID(named: item.name, taxonomy: taxonomy)
        }
        return mappedID.map(ExerciseEquipmentID.init(rawValue:))
    }

    private func exactEquipmentID(
        named name: String,
        taxonomy: EquipmentTaxonomy
    ) -> ExerciseEquipmentID? {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return taxonomy.equipment.first {
            $0.lifecycle.status == .active
                && ([$0.displayName] + $0.aliases).contains {
                    $0.caseInsensitiveCompare(cleaned) == .orderedSame
                }
        }?.id
    }
}

enum BundledExerciseCandidateTaxonomyError: Error {
    case resourceNotFound(String)
    case decodingFailed(String)
}

struct BundledExerciseCandidateTaxonomies {
    let equipment: EquipmentTaxonomy
    let environments: ExerciseEnvironmentTaxonomy

    static func load(bundle: Bundle = .main) throws -> Self {
        let equipment = try decode(
            EquipmentTaxonomy.self,
            resourceName: "equipment",
            bundle: bundle
        )
        let environments = try decode(
            ExerciseEnvironmentTaxonomy.self,
            resourceName: "environments",
            bundle: bundle
        )
        guard equipment.schemaVersion == 1,
              equipment.validationErrors().isEmpty,
              environments.schemaVersion == 1 else {
            throw BundledExerciseCandidateTaxonomyError.decodingFailed("taxonomy validation")
        }
        return Self(equipment: equipment, environments: environments)
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        resourceName: String,
        bundle: Bundle
    ) throws -> T {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw BundledExerciseCandidateTaxonomyError.resourceNotFound(resourceName)
        }
        do {
            return try JSONDecoder().decode(type, from: Data(contentsOf: url))
        } catch {
            throw BundledExerciseCandidateTaxonomyError.decodingFailed(resourceName)
        }
    }
}

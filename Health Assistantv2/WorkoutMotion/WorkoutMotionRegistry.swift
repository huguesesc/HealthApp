import Foundation

struct WorkoutMotionDefinition: Identifiable, Hashable, Codable, Sendable {
    let movementID: String
    let displayName: String
    let startPose: WorkoutAvatarPose
    let endPose: WorkoutAvatarPose?
    let equipment: WorkoutAvatarEquipment
    let characterStyleID: String
    let aliases: [String]

    var id: String { movementID }
    var hasTwoPoses: Bool { endPose != nil }
}

enum WorkoutMotionRegistry {
    static let definitions: [WorkoutMotionDefinition] = [
        WorkoutMotionDefinition(
            movementID: "goblet_squat",
            displayName: "Goblet Squat",
            startPose: .standing,
            endPose: .gobletSquat,
            equipment: .gobletWeight,
            characterStyleID: WorkoutAvatarStyleRegistry.defaultStyleID,
            aliases: ["goblet squat", "squat", "air squat", "bodyweight squat"]
        ),
        WorkoutMotionDefinition(
            movementID: "bent_over_row",
            displayName: "Bent-Over Row",
            startPose: .hipHinge,
            endPose: .bentOverRow,
            equipment: .dumbbells,
            characterStyleID: WorkoutAvatarStyleRegistry.defaultStyleID,
            aliases: ["bent over row", "bent-over row", "dumbbell row", "row"]
        ),
        WorkoutMotionDefinition(
            movementID: "overhead_press",
            displayName: "Overhead Press",
            startPose: .overheadStart,
            endPose: .overheadFinish,
            equipment: .dumbbells,
            characterStyleID: WorkoutAvatarStyleRegistry.defaultStyleID,
            aliases: ["overhead press", "shoulder press", "dumbbell press", "military press"]
        ),
        WorkoutMotionDefinition(
            movementID: "split_squat",
            displayName: "Split Squat",
            startPose: .standing,
            endPose: .splitSquat,
            equipment: .none,
            characterStyleID: WorkoutAvatarStyleRegistry.defaultStyleID,
            aliases: ["split squat", "lunge", "reverse lunge", "forward lunge"]
        ),
        WorkoutMotionDefinition(
            movementID: "plank_row",
            displayName: "Plank Row",
            startPose: .plank,
            endPose: .plankRow,
            equipment: .dumbbells,
            characterStyleID: WorkoutAvatarStyleRegistry.defaultStyleID,
            aliases: ["plank row", "renegade row", "plank"]
        ),
        WorkoutMotionDefinition(
            movementID: "hip_hinge",
            displayName: "Hip Hinge",
            startPose: .standing,
            endPose: .hipHinge,
            equipment: .none,
            characterStyleID: WorkoutAvatarStyleRegistry.defaultStyleID,
            aliases: ["hip hinge", "good morning", "romanian deadlift", "rdl", "deadlift"]
        ),
        WorkoutMotionDefinition(
            movementID: "side_stretch",
            displayName: "Side Stretch",
            startPose: .sideStretchStart,
            endPose: .sideStretchFinish,
            equipment: .none,
            characterStyleID: WorkoutAvatarStyleRegistry.defaultStyleID,
            aliases: ["side stretch", "lateral stretch", "standing side bend"]
        ),
        WorkoutMotionDefinition(
            movementID: "yoga_balance",
            displayName: "Yoga Balance",
            startPose: .treeBalanceStart,
            endPose: .treeBalanceFinish,
            equipment: .none,
            characterStyleID: WorkoutAvatarStyleRegistry.defaultStyleID,
            aliases: ["yoga balance", "tree pose", "balance", "single leg balance"]
        )
    ]

    private static let definitionsByID: [String: WorkoutMotionDefinition] =
        Dictionary(uniqueKeysWithValues: definitions.map { ($0.movementID, $0) })

    private static let aliases: [String: String] = {
        var result: [String: String] = [:]
        for definition in definitions {
            result[normalise(definition.movementID)] = definition.movementID
            result[normalise(definition.displayName)] = definition.movementID
            for alias in definition.aliases {
                result[normalise(alias)] = definition.movementID
            }
        }
        return result
    }()

    static func definition(movementID: String) -> WorkoutMotionDefinition? {
        definitionsByID[movementID]
    }

    static func definition(for title: String, type: WorkoutStepType? = nil) -> WorkoutMotionDefinition {
        let key = normalise(title)

        if let exactID = aliases[key], let exact = definitionsByID[exactID] {
            return exact
        }

        if let partial = definitions.first(where: { definition in
            definition.aliases.contains { alias in
                let normalisedAlias = normalise(alias)
                return key.contains(normalisedAlias) || normalisedAlias.contains(key)
            }
        }) {
            return partial
        }

        return fallbackDefinition(title: title, type: type)
    }

    static func movementID(for title: String, type: WorkoutStepType? = nil) -> String {
        definition(for: title, type: type).movementID
    }

    private static func fallbackDefinition(
        title: String,
        type: WorkoutStepType?
    ) -> WorkoutMotionDefinition {
        let pose: WorkoutAvatarPose
        switch type {
        case .mobility, .warmUp, .cooldown:
            pose = .sideStretchStart
        case .hold:
            pose = .plank
        case .exercise, .interval, .cardio, .distance, .rest, .freeform, .none:
            pose = .standing
        }

        return WorkoutMotionDefinition(
            movementID: "generic_\(slug(title))",
            displayName: title.isEmpty ? "Movement" : title,
            startPose: pose,
            endPose: nil,
            equipment: .none,
            characterStyleID: WorkoutAvatarStyleRegistry.defaultStyleID,
            aliases: []
        )
    }

    private static func normalise(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }

    private static func slug(_ value: String) -> String {
        let candidate = normalise(value).replacingOccurrences(of: " ", with: "_")
        return candidate.isEmpty ? "movement" : candidate
    }
}

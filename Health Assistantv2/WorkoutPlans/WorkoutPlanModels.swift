import Foundation
import SwiftData

// MARK: - Plan enums

enum WorkoutPlanSource: String, CaseIterable, Codable, Identifiable {
    case manual
    case assistant

    var id: String { rawValue }
    var displayName: String { self == .manual ? "Manual" : "Assistant" }
}

enum WorkoutStepType: String, CaseIterable, Codable, Identifiable {
    case warmUp = "warm_up"
    case exercise
    case mobility
    case hold
    case cardio
    case interval
    case distance
    case rest
    case cooldown
    case freeform

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warmUp: "Warm-up"
        case .exercise: "Exercise"
        case .mobility: "Mobility"
        case .hold: "Hold"
        case .cardio: "Cardio"
        case .interval: "Intervals"
        case .distance: "Distance"
        case .rest: "Rest"
        case .cooldown: "Cooldown"
        case .freeform: "Free-form"
        }
    }

    var systemImage: String {
        switch self {
        case .warmUp: "figure.walk.motion"
        case .exercise: "figure.strengthtraining.traditional"
        case .mobility: "figure.flexibility"
        case .hold: "timer"
        case .cardio: "heart.circle"
        case .interval: "repeat.circle"
        case .distance: "point.topleft.down.to.point.bottomright.curvepath"
        case .rest: "pause.circle"
        case .cooldown: "wind"
        case .freeform: "text.alignleft"
        }
    }

    var supportsSets: Bool {
        switch self {
        case .exercise, .mobility, .hold, .interval:
            true
        default:
            false
        }
    }

    var supportsReps: Bool {
        self == .exercise || self == .mobility
    }

    var supportsDuration: Bool {
        switch self {
        case .warmUp, .mobility, .hold, .cardio, .interval, .rest, .cooldown, .freeform:
            true
        case .exercise, .distance:
            false
        }
    }

    var supportsDistance: Bool {
        self == .distance || self == .cardio
    }

    var supportsLoad: Bool {
        self == .exercise
    }

    var supportsRestAfter: Bool {
        self == .exercise || self == .mobility || self == .hold || self == .interval
    }
}

enum WorkoutStepSide: String, CaseIterable, Codable, Identifiable {
    case none
    case left
    case right
    case both
    case alternating

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "Not specified"
        case .left: "Left"
        case .right: "Right"
        case .both: "Both sides"
        case .alternating: "Alternating"
        }
    }
}

// MARK: - SwiftData entities

@Model
final class WorkoutPlan {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var title: String
    var goalText: String?
    var notes: String?
    var estimatedDurationMinutes: Int?
    var targetEffort: Int?
    var locationIDSnapshot: UUID?
    var locationNameSnapshot: String?
    var locationCategoryRawSnapshot: String?
    var equipmentSummarySnapshot: String?
    var sourceRaw: String
    var isArchived: Bool

    @Relationship(deleteRule: .cascade, inverse: \WorkoutStep.plan)
    var steps: [WorkoutStep] = []

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        title: String,
        goalText: String? = nil,
        notes: String? = nil,
        estimatedDurationMinutes: Int? = nil,
        targetEffort: Int? = nil,
        locationIDSnapshot: UUID? = nil,
        locationNameSnapshot: String? = nil,
        locationCategoryRawSnapshot: String? = nil,
        equipmentSummarySnapshot: String? = nil,
        source: WorkoutPlanSource = .manual,
        isArchived: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.goalText = goalText
        self.notes = notes
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.targetEffort = targetEffort
        self.locationIDSnapshot = locationIDSnapshot
        self.locationNameSnapshot = locationNameSnapshot
        self.locationCategoryRawSnapshot = locationCategoryRawSnapshot
        self.equipmentSummarySnapshot = equipmentSummarySnapshot
        self.sourceRaw = source.rawValue
        self.isArchived = isArchived
    }

    var source: WorkoutPlanSource {
        WorkoutPlanSource(rawValue: sourceRaw) ?? .manual
    }

    var orderedSteps: [WorkoutStep] {
        steps.sorted {
            if $0.order == $1.order {
                return $0.createdAt < $1.createdAt
            }
            return $0.order < $1.order
        }
    }
}

@Model
final class WorkoutStep {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var order: Int
    var typeRaw: String
    var title: String
    var instruction: String?
    var sets: Int?
    var reps: Int?
    var durationSeconds: Int?
    var distanceMeters: Double?
    var targetWeightKilograms: Double?
    var restSeconds: Int?
    var sideRaw: String
    var equipmentNameSnapshot: String?
    var notes: String?
    var plan: WorkoutPlan?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        order: Int,
        type: WorkoutStepType,
        title: String,
        instruction: String? = nil,
        sets: Int? = nil,
        reps: Int? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Double? = nil,
        targetWeightKilograms: Double? = nil,
        restSeconds: Int? = nil,
        side: WorkoutStepSide = .none,
        equipmentNameSnapshot: String? = nil,
        notes: String? = nil,
        plan: WorkoutPlan? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.order = max(order, 0)
        self.typeRaw = type.rawValue
        self.title = title
        self.instruction = instruction
        self.sets = sets
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.targetWeightKilograms = targetWeightKilograms
        self.restSeconds = restSeconds
        self.sideRaw = side.rawValue
        self.equipmentNameSnapshot = equipmentNameSnapshot
        self.notes = notes
        self.plan = plan
    }

    var type: WorkoutStepType {
        WorkoutStepType(rawValue: typeRaw) ?? .freeform
    }

    var side: WorkoutStepSide {
        WorkoutStepSide(rawValue: sideRaw) ?? .none
    }
}
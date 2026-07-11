import Foundation
import SwiftData

// MARK: - Execution enums

enum ActiveWorkoutStatus: String, CaseIterable, Codable, Identifiable {
    case inProgress = "in_progress"
    case paused
    case completed
    case abandoned

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .inProgress: "In progress"
        case .paused: "Paused"
        case .completed: "Completed"
        case .abandoned: "Ended early"
        }
    }
}

enum ActiveWorkoutStepStatus: String, CaseIterable, Codable, Identifiable {
    case pending
    case active
    case completed
    case skipped

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending: "Not started"
        case .active: "Current"
        case .completed: "Completed"
        case .skipped: "Skipped"
        }
    }
}

// MARK: - Persisted execution snapshots

/// One execution of a saved workout plan. The plan and step details are copied at
/// start time so later plan edits cannot rewrite workout history.
@Model
final class ActiveWorkoutSession {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var startedAt: Date
    var completedAt: Date?
    var statusRaw: String

    var sourcePlanIDSnapshot: UUID?
    var titleSnapshot: String
    var goalSnapshot: String?
    var locationNameSnapshot: String?
    var targetEffortSnapshot: Int?
    var actualEffort: Int?
    var notes: String?

    var currentStepIndex: Int
    var accumulatedActiveSeconds: Int
    var activeSegmentStartedAt: Date?
    var workoutLogCreated: Bool

    // Rest countdowns use an absolute end date. This lets the timer recover after
    // the app is backgrounded or relaunched without running a background loop.
    var restStartedAt: Date?
    var restEndsAt: Date?
    var restDurationSeconds: Int?

    @Relationship(deleteRule: .cascade, inverse: \ActiveWorkoutStep.session)
    var steps: [ActiveWorkoutStep] = []

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        startedAt: Date = .now,
        status: ActiveWorkoutStatus = .inProgress,
        sourcePlanIDSnapshot: UUID? = nil,
        titleSnapshot: String,
        goalSnapshot: String? = nil,
        locationNameSnapshot: String? = nil,
        targetEffortSnapshot: Int? = nil,
        currentStepIndex: Int = 0,
        accumulatedActiveSeconds: Int = 0,
        activeSegmentStartedAt: Date? = .now,
        workoutLogCreated: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startedAt = startedAt
        self.statusRaw = status.rawValue
        self.sourcePlanIDSnapshot = sourcePlanIDSnapshot
        self.titleSnapshot = titleSnapshot
        self.goalSnapshot = goalSnapshot
        self.locationNameSnapshot = locationNameSnapshot
        self.targetEffortSnapshot = targetEffortSnapshot
        self.currentStepIndex = max(currentStepIndex, 0)
        self.accumulatedActiveSeconds = max(accumulatedActiveSeconds, 0)
        self.activeSegmentStartedAt = activeSegmentStartedAt
        self.workoutLogCreated = workoutLogCreated
    }

    var status: ActiveWorkoutStatus {
        ActiveWorkoutStatus(rawValue: statusRaw) ?? .inProgress
    }

    var orderedSteps: [ActiveWorkoutStep] {
        steps.sorted {
            if $0.order == $1.order { return $0.createdAt < $1.createdAt }
            return $0.order < $1.order
        }
    }

    var currentStep: ActiveWorkoutStep? {
        let ordered = orderedSteps
        guard ordered.indices.contains(currentStepIndex) else { return nil }
        return ordered[currentStepIndex]
    }

    var progressFraction: Double {
        guard !steps.isEmpty else { return 0 }
        let resolved = steps.filter { $0.status == .completed || $0.status == .skipped }.count
        return min(max(Double(resolved) / Double(steps.count), 0), 1)
    }

    func elapsedSeconds(at date: Date = .now) -> Int {
        var total = accumulatedActiveSeconds
        if status == .inProgress, let activeSegmentStartedAt {
            total += max(Int(date.timeIntervalSince(activeSegmentStartedAt)), 0)
        }
        return max(total, 0)
    }

    func remainingRestSeconds(at date: Date = .now) -> Int? {
        guard let restEndsAt else { return nil }
        return max(Int(ceil(restEndsAt.timeIntervalSince(date))), 0)
    }
}

/// Planned-versus-actual state for one ordered workout step.
@Model
final class ActiveWorkoutStep {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var order: Int
    var sourcePlanStepIDSnapshot: UUID?

    var typeRaw: String
    var title: String
    var instruction: String?
    var plannedSets: Int?
    var plannedReps: Int?
    var plannedDurationSeconds: Int?
    var plannedDistanceMeters: Double?
    var plannedWeightKilograms: Double?
    var plannedRestSeconds: Int?
    var sideRaw: String
    var equipmentNameSnapshot: String?
    var plannedNotes: String?

    var statusRaw: String
    var startedAt: Date?
    var completedAt: Date?
    var skippedAt: Date?

    var completedSets: Int
    var actualReps: Int?
    var actualDurationSeconds: Int?
    var actualDistanceMeters: Double?
    var actualWeightKilograms: Double?
    var actualNotes: String?

    var timerStartedAt: Date?
    var timerAccumulatedSeconds: Int
    var timerIsRunning: Bool

    var session: ActiveWorkoutSession?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        order: Int,
        sourcePlanStepIDSnapshot: UUID? = nil,
        type: WorkoutStepType,
        title: String,
        instruction: String? = nil,
        plannedSets: Int? = nil,
        plannedReps: Int? = nil,
        plannedDurationSeconds: Int? = nil,
        plannedDistanceMeters: Double? = nil,
        plannedWeightKilograms: Double? = nil,
        plannedRestSeconds: Int? = nil,
        side: WorkoutStepSide = .none,
        equipmentNameSnapshot: String? = nil,
        plannedNotes: String? = nil,
        status: ActiveWorkoutStepStatus = .pending,
        completedSets: Int = 0,
        timerAccumulatedSeconds: Int = 0,
        timerIsRunning: Bool = false,
        session: ActiveWorkoutSession? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.order = max(order, 0)
        self.sourcePlanStepIDSnapshot = sourcePlanStepIDSnapshot
        self.typeRaw = type.rawValue
        self.title = title
        self.instruction = instruction
        self.plannedSets = plannedSets
        self.plannedReps = plannedReps
        self.plannedDurationSeconds = plannedDurationSeconds
        self.plannedDistanceMeters = plannedDistanceMeters
        self.plannedWeightKilograms = plannedWeightKilograms
        self.plannedRestSeconds = plannedRestSeconds
        self.sideRaw = side.rawValue
        self.equipmentNameSnapshot = equipmentNameSnapshot
        self.plannedNotes = plannedNotes
        self.statusRaw = status.rawValue
        self.completedSets = max(completedSets, 0)
        self.timerAccumulatedSeconds = max(timerAccumulatedSeconds, 0)
        self.timerIsRunning = timerIsRunning
        self.session = session
    }

    var type: WorkoutStepType {
        WorkoutStepType(rawValue: typeRaw) ?? .freeform
    }

    var side: WorkoutStepSide {
        WorkoutStepSide(rawValue: sideRaw) ?? .none
    }

    var status: ActiveWorkoutStepStatus {
        ActiveWorkoutStepStatus(rawValue: statusRaw) ?? .pending
    }

    var plannedSetCount: Int {
        max(plannedSets ?? 1, 1)
    }

    func timerElapsedSeconds(at date: Date = .now) -> Int {
        var total = timerAccumulatedSeconds
        if timerIsRunning, let timerStartedAt {
            total += max(Int(date.timeIntervalSince(timerStartedAt)), 0)
        }
        return max(total, 0)
    }

    func timerRemainingSeconds(at date: Date = .now) -> Int? {
        guard let plannedDurationSeconds else { return nil }
        return max(plannedDurationSeconds - timerElapsedSeconds(at: date), 0)
    }
}

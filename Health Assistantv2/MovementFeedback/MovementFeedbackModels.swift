import Foundation
import SwiftData

// MARK: - Neutral user-reported feedback enums

enum MovementFeedbackSignal: String, CaseIterable, Codable, Identifiable {
    case harderThanExpected = "harder_than_expected"
    case tooEasy = "too_easy"
    case lessControlled = "less_controlled"
    case sideFeltDifferent = "side_felt_different"
    case tight
    case weak
    case unsteady
    case uncomfortable
    case equipmentIssue = "equipment_issue"
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .harderThanExpected: "Harder than expected"
        case .tooEasy: "Too easy"
        case .lessControlled: "Less controlled than usual"
        case .sideFeltDifferent: "One side felt different"
        case .tight: "Felt tight"
        case .weak: "Felt weak"
        case .unsteady: "Felt unsteady"
        case .uncomfortable: "Felt uncomfortable"
        case .equipmentIssue: "Equipment or setup issue"
        case .other: "Something else"
        }
    }

    var systemImage: String {
        switch self {
        case .harderThanExpected: "arrow.up.right"
        case .tooEasy: "arrow.down.right"
        case .lessControlled: "scope"
        case .sideFeltDifferent: "arrow.left.and.right"
        case .tight: "arrow.left.and.right.circle"
        case .weak: "battery.25percent"
        case .unsteady: "figure.stand.line.dotted.figure.stand"
        case .uncomfortable: "exclamationmark.circle"
        case .equipmentIssue: "wrench.and.screwdriver"
        case .other: "ellipsis.circle"
        }
    }

    var suggestsBodyArea: Bool {
        switch self {
        case .sideFeltDifferent, .tight, .weak, .unsteady, .uncomfortable:
            true
        default:
            false
        }
    }
}

enum MovementFeedbackImpact: String, CaseIterable, Codable, Identifiable {
    case noticedOnly = "noticed_only"
    case changedMovement = "changed_movement"
    case stoppedExercise = "stopped_exercise"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noticedOnly: "I noticed it"
        case .changedMovement: "It changed how I moved"
        case .stoppedExercise: "I stopped this exercise"
        }
    }
}

enum MovementAdjustmentAction: String, CaseIterable, Codable, Identifiable {
    case noChange = "no_change"
    case reducedLoad = "reduced_load"
    case reducedRange = "reduced_range"
    case slowedTempo = "slowed_tempo"
    case usedMoreSupport = "used_more_support"
    case changedExercise = "changed_exercise"
    case adjustedEquipment = "adjusted_equipment"
    case skippedStep = "skipped_step"
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noChange: "No change yet"
        case .reducedLoad: "Reduced the load"
        case .reducedRange: "Reduced the range"
        case .slowedTempo: "Slowed the tempo"
        case .usedMoreSupport: "Used a more stable setup"
        case .changedExercise: "Changed the exercise"
        case .adjustedEquipment: "Adjusted the equipment"
        case .skippedStep: "Skipped this step"
        case .other: "Another adjustment"
        }
    }
}

// MARK: - Persisted immutable log

/// A user-reported observation tied to the exact workout, exercise and set context.
/// This is a report, not a diagnosis or model inference. Phase 4 appends entries and
/// does not silently rewrite the health profile.
@Model
final class MovementFeedbackEntry {
    var id: UUID
    var createdAt: Date

    var sessionIDSnapshot: UUID
    var sessionTitleSnapshot: String
    var stepIDSnapshot: UUID
    var stepTitleSnapshot: String
    var stepOrderSnapshot: Int
    var setNumberSnapshot: Int?

    var signalRaw: String
    var bodyAreaRaw: String?
    var sideRaw: String?
    var impactRaw: String
    var actionRaw: String
    var note: String?

    var plannedRepsSnapshot: Int?
    var actualRepsSnapshot: Int?
    var plannedWeightKilogramsSnapshot: Double?
    var actualWeightKilogramsSnapshot: Double?
    var plannedDurationSecondsSnapshot: Int?
    var actualDurationSecondsSnapshot: Int?

    var userReported: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        sessionIDSnapshot: UUID,
        sessionTitleSnapshot: String,
        stepIDSnapshot: UUID,
        stepTitleSnapshot: String,
        stepOrderSnapshot: Int,
        setNumberSnapshot: Int? = nil,
        signal: MovementFeedbackSignal,
        bodyArea: HealthBodyArea? = nil,
        side: BodySide? = nil,
        impact: MovementFeedbackImpact = .noticedOnly,
        action: MovementAdjustmentAction = .noChange,
        note: String? = nil,
        plannedRepsSnapshot: Int? = nil,
        actualRepsSnapshot: Int? = nil,
        plannedWeightKilogramsSnapshot: Double? = nil,
        actualWeightKilogramsSnapshot: Double? = nil,
        plannedDurationSecondsSnapshot: Int? = nil,
        actualDurationSecondsSnapshot: Int? = nil,
        userReported: Bool = true
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sessionIDSnapshot = sessionIDSnapshot
        self.sessionTitleSnapshot = sessionTitleSnapshot
        self.stepIDSnapshot = stepIDSnapshot
        self.stepTitleSnapshot = stepTitleSnapshot
        self.stepOrderSnapshot = max(stepOrderSnapshot, 0)
        self.setNumberSnapshot = setNumberSnapshot
        self.signalRaw = signal.rawValue
        self.bodyAreaRaw = bodyArea?.rawValue
        self.sideRaw = side?.rawValue
        self.impactRaw = impact.rawValue
        self.actionRaw = action.rawValue
        self.note = note
        self.plannedRepsSnapshot = plannedRepsSnapshot
        self.actualRepsSnapshot = actualRepsSnapshot
        self.plannedWeightKilogramsSnapshot = plannedWeightKilogramsSnapshot
        self.actualWeightKilogramsSnapshot = actualWeightKilogramsSnapshot
        self.plannedDurationSecondsSnapshot = plannedDurationSecondsSnapshot
        self.actualDurationSecondsSnapshot = actualDurationSecondsSnapshot
        self.userReported = userReported
    }

    var signal: MovementFeedbackSignal {
        MovementFeedbackSignal(rawValue: signalRaw) ?? .other
    }

    var bodyArea: HealthBodyArea? {
        bodyAreaRaw.flatMap(HealthBodyArea.init(rawValue:))
    }

    var side: BodySide? {
        sideRaw.flatMap(BodySide.init(rawValue:))
    }

    var impact: MovementFeedbackImpact {
        MovementFeedbackImpact(rawValue: impactRaw) ?? .noticedOnly
    }

    var action: MovementAdjustmentAction {
        MovementAdjustmentAction(rawValue: actionRaw) ?? .noChange
    }
}

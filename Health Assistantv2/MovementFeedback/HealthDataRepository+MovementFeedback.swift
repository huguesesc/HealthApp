import Foundation
import SwiftData

struct MovementFeedbackSnapshot: Codable, Equatable {
    var date: Date
    var workout: String
    var exercise: String
    var stepOrder: Int
    var setNumber: Int?
    var signal: String
    var bodyArea: String?
    var side: String?
    var impact: String
    var adjustment: String
    var note: String?
    var plannedReps: Int?
    var actualReps: Int?
    var plannedWeightKilograms: Double?
    var actualWeightKilograms: Double?
}

@MainActor
extension HealthDataRepository {
    @discardableResult
    func addMovementFeedback(
        for session: ActiveWorkoutSession,
        step: ActiveWorkoutStep,
        setNumber: Int?,
        signal: MovementFeedbackSignal,
        bodyArea: HealthBodyArea?,
        side: BodySide?,
        impact: MovementFeedbackImpact,
        action: MovementAdjustmentAction,
        note: String?
    ) -> MovementFeedbackEntry {
        let cleanedNote = note?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfBlank

        let entry = MovementFeedbackEntry(
            sessionIDSnapshot: session.id,
            sessionTitleSnapshot: session.titleSnapshot,
            stepIDSnapshot: step.id,
            stepTitleSnapshot: step.title,
            stepOrderSnapshot: step.order,
            setNumberSnapshot: setNumber,
            signal: signal,
            bodyArea: bodyArea,
            side: side,
            impact: impact,
            action: action,
            note: cleanedNote,
            plannedRepsSnapshot: step.plannedReps,
            actualRepsSnapshot: step.actualReps,
            plannedWeightKilogramsSnapshot: step.plannedWeightKilograms,
            actualWeightKilogramsSnapshot: step.actualWeightKilograms,
            plannedDurationSecondsSnapshot: step.plannedDurationSeconds,
            actualDurationSecondsSnapshot: step.actualDurationSeconds,
            userReported: true
        )
        context.insert(entry)

        if action == .skippedStep,
           session.status == .inProgress,
           step.status != .completed,
           step.status != .skipped {
            skipActiveWorkoutStep(step)
        }

        persistMovementFeedbackChanges()
        return entry
    }

    func movementFeedbackEntries(limit: Int = 100) -> [MovementFeedbackEntry] {
        Array(
            fetchMovementFeedbackModels(
                FetchDescriptor<MovementFeedbackEntry>(
                    sortBy: [SortDescriptor(\MovementFeedbackEntry.createdAt, order: .reverse)]
                )
            ).prefix(max(limit, 0))
        )
    }

    func movementFeedback(for session: ActiveWorkoutSession) -> [MovementFeedbackEntry] {
        movementFeedbackEntries(limit: 500).filter {
            $0.sessionIDSnapshot == session.id && $0.userReported
        }
    }

    func movementFeedback(for step: ActiveWorkoutStep) -> [MovementFeedbackEntry] {
        movementFeedbackEntries(limit: 500).filter {
            $0.stepIDSnapshot == step.id && $0.userReported
        }
    }

    func recentMovementFeedbackSnapshots(limit: Int = 30) -> [MovementFeedbackSnapshot] {
        movementFeedbackEntries(limit: limit)
            .filter(\.userReported)
            .map { entry in
                MovementFeedbackSnapshot(
                    date: entry.createdAt,
                    workout: entry.sessionTitleSnapshot,
                    exercise: entry.stepTitleSnapshot,
                    stepOrder: entry.stepOrderSnapshot,
                    setNumber: entry.setNumberSnapshot,
                    signal: entry.signal.displayName,
                    bodyArea: entry.bodyArea?.displayName,
                    side: entry.side?.displayName,
                    impact: entry.impact.displayName,
                    adjustment: entry.action.displayName,
                    note: entry.note,
                    plannedReps: entry.plannedRepsSnapshot,
                    actualReps: entry.actualRepsSnapshot,
                    plannedWeightKilograms: entry.plannedWeightKilogramsSnapshot,
                    actualWeightKilograms: entry.actualWeightKilogramsSnapshot
                )
            }
    }

    private func fetchMovementFeedbackModels<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>
    ) -> [T] {
        (try? context.fetch(descriptor)) ?? []
    }

    private func persistMovementFeedbackChanges() {
        try? context.save()
    }
}

private extension String {
    var nilIfBlank: String? { isEmpty ? nil : self }
}

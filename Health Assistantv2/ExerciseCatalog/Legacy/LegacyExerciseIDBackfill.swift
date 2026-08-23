import SwiftData

struct LegacyExerciseIDBackfillReport: Equatable, Sendable {
    var workoutStepsUpdated = 0
    var activeWorkoutStepsUpdated = 0
    var exerciseSetsUpdated = 0
    var ambiguousReferences = 0
    var unresolvedReferences = 0

    var totalUpdated: Int {
        workoutStepsUpdated + activeWorkoutStepsUpdated + exerciseSetsUpdated
    }
}

extension HealthDataRepository {
    /// Adds a stable catalogue ID only when the existing immutable snapshot is
    /// an exact unique match. Existing IDs and unresolved/custom snapshots are
    /// never changed.
    @discardableResult
    func backfillLegacyExerciseIDs(
        using definitions: [ExerciseDefinition]
    ) throws -> LegacyExerciseIDBackfillReport {
        let resolver = LegacyExerciseResolver(definitions: definitions)
        var report = LegacyExerciseIDBackfillReport()

        let planSteps = try context.fetch(FetchDescriptor<WorkoutStep>())
        for step in planSteps where step.exerciseIDSnapshot == nil {
            if let id = backfilledExerciseID(
                for: step.title,
                using: resolver,
                report: &report
            ) {
                step.exerciseIDSnapshot = id
                step.updatedAt = .now
                report.workoutStepsUpdated += 1
            }
        }

        let activeSteps = try context.fetch(FetchDescriptor<ActiveWorkoutStep>())
        for step in activeSteps where step.exerciseIDSnapshot == nil {
            if let id = backfilledExerciseID(
                for: step.title,
                using: resolver,
                report: &report
            ) {
                step.exerciseIDSnapshot = id
                step.updatedAt = .now
                report.activeWorkoutStepsUpdated += 1
            }
        }

        let exerciseSets = try context.fetch(FetchDescriptor<ExerciseSet>())
        for exerciseSet in exerciseSets where exerciseSet.exerciseIDSnapshot == nil {
            if let id = backfilledExerciseID(
                for: exerciseSet.exerciseName,
                using: resolver,
                report: &report
            ) {
                exerciseSet.exerciseIDSnapshot = id
                report.exerciseSetsUpdated += 1
            }
        }

        if report.totalUpdated > 0 {
            try context.save()
        }
        return report
    }

    private func backfilledExerciseID(
        for snapshot: String,
        using resolver: LegacyExerciseResolver,
        report: inout LegacyExerciseIDBackfillReport
    ) -> String? {
        switch resolver.resolve(snapshot) {
        case .resolved(let definition, _):
            return definition.id.rawValue
        case .ambiguous:
            report.ambiguousReferences += 1
            return nil
        case .unresolved:
            report.unresolvedReferences += 1
            return nil
        }
    }
}

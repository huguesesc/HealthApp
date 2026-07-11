import Foundation
import SwiftData

@MainActor
extension HealthDataRepository {
    // MARK: - Session lifecycle

    /// Creates a durable execution snapshot from a saved plan. Returns nil for an
    /// empty plan because there is nothing useful to execute.
    @discardableResult
    func startActiveWorkout(from plan: WorkoutPlan) -> ActiveWorkoutSession? {
        let planSteps = plan.orderedSteps
        guard !planSteps.isEmpty else { return nil }

        let now = Date.now
        let session = ActiveWorkoutSession(
            createdAt: now,
            updatedAt: now,
            startedAt: now,
            sourcePlanIDSnapshot: plan.id,
            titleSnapshot: plan.title,
            goalSnapshot: plan.goalText,
            locationNameSnapshot: plan.locationNameSnapshot,
            targetEffortSnapshot: plan.targetEffort,
            activeSegmentStartedAt: now
        )
        context.insert(session)

        var executionSteps: [ActiveWorkoutStep] = []
        for (index, planStep) in planSteps.enumerated() {
            let step = ActiveWorkoutStep(
                order: index,
                sourcePlanStepIDSnapshot: planStep.id,
                type: planStep.type,
                title: planStep.title,
                instruction: planStep.instruction,
                plannedSets: planStep.sets,
                plannedReps: planStep.reps,
                plannedDurationSeconds: planStep.durationSeconds,
                plannedDistanceMeters: planStep.distanceMeters,
                plannedWeightKilograms: planStep.targetWeightKilograms,
                plannedRestSeconds: planStep.restSeconds,
                side: planStep.side,
                equipmentNameSnapshot: planStep.equipmentNameSnapshot,
                plannedNotes: planStep.notes,
                status: index == 0 ? .active : .pending
            )
            context.insert(step)
            executionSteps.append(step)
        }
        session.steps = executionSteps

        persistActiveWorkoutChanges()
        return session
    }

    func activeWorkoutSessions() -> [ActiveWorkoutSession] {
        fetchActiveWorkoutModels(
            FetchDescriptor<ActiveWorkoutSession>(
                sortBy: [SortDescriptor(\ActiveWorkoutSession.updatedAt, order: .reverse)]
            )
        )
    }

    func resumableActiveWorkouts() -> [ActiveWorkoutSession] {
        activeWorkoutSessions().filter {
            $0.status == .inProgress || $0.status == .paused
        }
    }

    func recentFinishedWorkouts(limit: Int = 20) -> [ActiveWorkoutSession] {
        Array(
            activeWorkoutSessions()
                .filter { $0.status == .completed || $0.status == .abandoned }
                .prefix(max(limit, 0))
        )
    }

    func pauseActiveWorkout(_ session: ActiveWorkoutSession, at date: Date = .now) {
        guard session.status == .inProgress else { return }
        captureActiveTime(for: session, at: date)
        session.activeSegmentStartedAt = nil
        session.statusRaw = ActiveWorkoutStatus.paused.rawValue

        if let remaining = session.remainingRestSeconds(at: date), remaining > 0 {
            session.restDurationSeconds = remaining
            session.restEndsAt = nil
        }
        if let current = session.currentStep, current.timerIsRunning {
            pauseActiveStepTimer(current, at: date, save: false)
        }

        session.updatedAt = date
        persistActiveWorkoutChanges()
    }

    func resumeActiveWorkout(_ session: ActiveWorkoutSession, at date: Date = .now) {
        guard session.status == .paused else { return }
        session.statusRaw = ActiveWorkoutStatus.inProgress.rawValue
        session.activeSegmentStartedAt = date

        if session.restStartedAt != nil,
           session.restEndsAt == nil,
           let remaining = session.restDurationSeconds,
           remaining > 0 {
            session.restStartedAt = date
            session.restEndsAt = date.addingTimeInterval(TimeInterval(remaining))
        }

        session.updatedAt = date
        persistActiveWorkoutChanges()
    }

    func abandonActiveWorkout(_ session: ActiveWorkoutSession, at date: Date = .now) {
        guard session.status == .inProgress || session.status == .paused else { return }
        captureActiveTime(for: session, at: date)
        session.statusRaw = ActiveWorkoutStatus.abandoned.rawValue
        session.completedAt = date
        session.activeSegmentStartedAt = nil
        clearRestTimer(for: session, save: false)
        if let current = session.currentStep, current.timerIsRunning {
            pauseActiveStepTimer(current, at: date, save: false)
        }
        session.updatedAt = date
        persistActiveWorkoutChanges()
    }

    /// Completes the execution and writes one legacy WorkoutSession so the existing
    /// dashboard, streak and daily-rollup paths continue to work unchanged.
    func finishActiveWorkout(
        _ session: ActiveWorkoutSession,
        actualEffort: Int?,
        notes: String?,
        at date: Date = .now
    ) {
        guard session.status == .inProgress || session.status == .paused else { return }

        captureActiveTime(for: session, at: date)
        if let current = session.currentStep, current.timerIsRunning {
            pauseActiveStepTimer(current, at: date, save: false)
        }
        clearRestTimer(for: session, save: false)

        session.statusRaw = ActiveWorkoutStatus.completed.rawValue
        session.completedAt = date
        session.activeSegmentStartedAt = nil
        session.actualEffort = actualEffort.map { min(max($0, 1), 10) }
        let cleanedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        session.notes = cleanedNotes?.isEmpty == false ? cleanedNotes : nil
        session.updatedAt = date

        if !session.workoutLogCreated {
            let seconds = session.elapsedSeconds(at: date)
            let durationMinutes = seconds > 0
                ? max(Int((Double(seconds) / 60).rounded()), 1)
                : nil
            let workout = WorkoutSession(
                date: date,
                type: session.titleSnapshot,
                durationMinutes: durationMinutes,
                perceivedEffort: session.actualEffort,
                sets: executionSets(from: session)
            )
            addWorkout(workout)
            session.workoutLogCreated = true
            _ = refreshTodayRollup()
        }

        persistActiveWorkoutChanges()
    }

    // MARK: - Navigation and step state

    func moveActiveWorkout(_ session: ActiveWorkoutSession, to index: Int) {
        let ordered = session.orderedSteps
        guard ordered.indices.contains(index) else { return }

        if let previous = session.currentStep,
           previous.status == .active,
           previous.id != ordered[index].id {
            previous.statusRaw = ActiveWorkoutStepStatus.pending.rawValue
            previous.updatedAt = .now
        }

        session.currentStepIndex = index
        let selected = ordered[index]
        if selected.status == .pending {
            selected.statusRaw = ActiveWorkoutStepStatus.active.rawValue
            selected.startedAt = selected.startedAt ?? .now
            selected.updatedAt = .now
        }
        session.updatedAt = .now
        persistActiveWorkoutChanges()
    }

    func moveToPreviousActiveWorkoutStep(_ session: ActiveWorkoutSession) {
        moveActiveWorkout(session, to: max(session.currentStepIndex - 1, 0))
    }

    func moveToNextActiveWorkoutStep(_ session: ActiveWorkoutSession) {
        let maximum = max(session.orderedSteps.count - 1, 0)
        moveActiveWorkout(session, to: min(session.currentStepIndex + 1, maximum))
    }

    func reopenActiveWorkoutStep(_ step: ActiveWorkoutStep) {
        guard let session = step.session else { return }
        if let active = session.currentStep,
           active.status == .active,
           active.id != step.id {
            active.statusRaw = ActiveWorkoutStepStatus.pending.rawValue
            active.updatedAt = .now
        }
        step.statusRaw = ActiveWorkoutStepStatus.active.rawValue
        step.completedAt = nil
        step.skippedAt = nil
        step.startedAt = step.startedAt ?? .now
        step.updatedAt = .now
        if let index = session.orderedSteps.firstIndex(where: { $0.id == step.id }) {
            session.currentStepIndex = index
        }
        session.updatedAt = .now
        persistActiveWorkoutChanges()
    }

    func activeWorkoutStepDidChange(_ step: ActiveWorkoutStep) {
        step.updatedAt = .now
        step.session?.updatedAt = .now
        persistActiveWorkoutChanges()
    }

    /// Returns true when this set completes the whole step.
    @discardableResult
    func completeActiveWorkoutSet(
        _ step: ActiveWorkoutStep,
        reps: Int?,
        weightKilograms: Double?,
        at date: Date = .now
    ) -> Bool {
        guard let session = step.session,
              session.status == .inProgress,
              step.status == .active || step.status == .pending else { return false }

        step.startedAt = step.startedAt ?? date
        step.statusRaw = ActiveWorkoutStepStatus.active.rawValue
        step.completedSets = min(step.completedSets + 1, step.plannedSetCount)
        step.actualReps = reps.map { max($0, 0) }
        step.actualWeightKilograms = weightKilograms.map { max($0, 0) }
        step.updatedAt = date

        if step.completedSets >= step.plannedSetCount {
            completeActiveWorkoutStep(step, at: date)
            return true
        }

        if let rest = step.plannedRestSeconds, rest > 0 {
            startRestTimer(for: session, seconds: rest, at: date)
        } else {
            persistActiveWorkoutChanges()
        }
        return false
    }

    func completeActiveWorkoutStep(_ step: ActiveWorkoutStep, at date: Date = .now) {
        guard let session = step.session else { return }
        if step.timerIsRunning {
            pauseActiveStepTimer(step, at: date, save: false)
        }
        if step.actualDurationSeconds == nil, step.timerAccumulatedSeconds > 0 {
            step.actualDurationSeconds = step.timerAccumulatedSeconds
        }
        if step.type.supportsSets, step.completedSets == 0 {
            step.completedSets = step.plannedSetCount
        }
        step.statusRaw = ActiveWorkoutStepStatus.completed.rawValue
        step.startedAt = step.startedAt ?? date
        step.completedAt = date
        step.skippedAt = nil
        step.updatedAt = date
        advanceAfterResolving(step, in: session)
        persistActiveWorkoutChanges()
    }

    func skipActiveWorkoutStep(_ step: ActiveWorkoutStep, at date: Date = .now) {
        guard let session = step.session else { return }
        if step.timerIsRunning {
            pauseActiveStepTimer(step, at: date, save: false)
        }
        step.statusRaw = ActiveWorkoutStepStatus.skipped.rawValue
        step.skippedAt = date
        step.completedAt = nil
        step.updatedAt = date
        advanceAfterResolving(step, in: session)
        persistActiveWorkoutChanges()
    }

    // MARK: - Step timer

    func startActiveStepTimer(_ step: ActiveWorkoutStep, at date: Date = .now) {
        guard !step.timerIsRunning,
              step.status != .completed,
              step.status != .skipped,
              step.session?.status == .inProgress else { return }
        step.statusRaw = ActiveWorkoutStepStatus.active.rawValue
        step.startedAt = step.startedAt ?? date
        step.timerStartedAt = date
        step.timerIsRunning = true
        step.updatedAt = date
        step.session?.updatedAt = date
        persistActiveWorkoutChanges()
    }

    func pauseActiveStepTimer(
        _ step: ActiveWorkoutStep,
        at date: Date = .now,
        save: Bool = true
    ) {
        guard step.timerIsRunning else { return }
        if let timerStartedAt = step.timerStartedAt {
            step.timerAccumulatedSeconds += max(Int(date.timeIntervalSince(timerStartedAt)), 0)
        }
        step.timerStartedAt = nil
        step.timerIsRunning = false
        step.actualDurationSeconds = step.timerAccumulatedSeconds
        step.updatedAt = date
        step.session?.updatedAt = date
        if save { persistActiveWorkoutChanges() }
    }

    func resetActiveStepTimer(_ step: ActiveWorkoutStep) {
        step.timerStartedAt = nil
        step.timerAccumulatedSeconds = 0
        step.actualDurationSeconds = nil
        step.timerIsRunning = false
        step.updatedAt = .now
        step.session?.updatedAt = .now
        persistActiveWorkoutChanges()
    }

    // MARK: - Rest timer

    func startRestTimer(
        for session: ActiveWorkoutSession,
        seconds: Int,
        at date: Date = .now
    ) {
        let duration = max(seconds, 1)
        session.restStartedAt = date
        session.restDurationSeconds = duration
        session.restEndsAt = date.addingTimeInterval(TimeInterval(duration))
        session.updatedAt = date
        persistActiveWorkoutChanges()
    }

    func clearRestTimer(for session: ActiveWorkoutSession, save: Bool = true) {
        session.restStartedAt = nil
        session.restEndsAt = nil
        session.restDurationSeconds = nil
        session.updatedAt = .now
        if save { persistActiveWorkoutChanges() }
    }

    // MARK: - Helpers

    private func advanceAfterResolving(
        _ step: ActiveWorkoutStep,
        in session: ActiveWorkoutSession
    ) {
        let ordered = session.orderedSteps
        guard let resolvedIndex = ordered.firstIndex(where: { $0.id == step.id }) else { return }

        let nextIndex = ordered.indices.first {
            $0 > resolvedIndex
                && ordered[$0].status != .completed
                && ordered[$0].status != .skipped
        }
        guard let nextIndex else {
            session.currentStepIndex = ordered.count
            session.updatedAt = .now
            return
        }

        session.currentStepIndex = nextIndex
        let next = ordered[nextIndex]
        next.statusRaw = ActiveWorkoutStepStatus.active.rawValue
        next.startedAt = next.startedAt ?? .now
        next.updatedAt = .now
        session.updatedAt = .now
    }

    private func captureActiveTime(for session: ActiveWorkoutSession, at date: Date) {
        guard session.status == .inProgress,
              let segmentStart = session.activeSegmentStartedAt else { return }
        session.accumulatedActiveSeconds += max(Int(date.timeIntervalSince(segmentStart)), 0)
    }

    private func executionSets(from session: ActiveWorkoutSession) -> [ExerciseSet] {
        var result: [ExerciseSet] = []
        for step in session.orderedSteps where step.status == .completed {
            guard let reps = step.actualReps ?? step.plannedReps, reps >= 0 else { continue }
            let setCount = max(step.completedSets, 1)
            for _ in 0..<setCount {
                result.append(
                    ExerciseSet(
                        exerciseName: step.title,
                        reps: reps,
                        weightKilograms: step.actualWeightKilograms ?? step.plannedWeightKilograms,
                        order: result.count
                    )
                )
            }
        }
        return result
    }

    private func fetchActiveWorkoutModels<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>
    ) -> [T] {
        (try? context.fetch(descriptor)) ?? []
    }

    private func persistActiveWorkoutChanges() {
        try? context.save()
    }
}

import Foundation
import SwiftData
import SwiftUI

// MARK: - History and resume list

struct ActiveWorkoutsView: View {
    @Query(sort: \ActiveWorkoutSession.updatedAt, order: .reverse)
    private var sessions: [ActiveWorkoutSession]

    var body: some View {
        List {
            Section {
                if resumable.isEmpty {
                    Text("No workout is currently in progress.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(resumable, id: \.id) { session in
                        NavigationLink {
                            ActiveWorkoutView(session: session)
                        } label: {
                            sessionRow(session)
                        }
                    }
                }
            } header: {
                Text("Continue")
            } footer: {
                Text("Timers use saved timestamps, so an interrupted workout can resume without losing its place.")
            }

            if !finished.isEmpty {
                Section("Recent") {
                    ForEach(finished.prefix(20), id: \.id) { session in
                        NavigationLink {
                            ActiveWorkoutView(session: session)
                        } label: {
                            sessionRow(session)
                        }
                    }
                }
            }
        }
        .navigationTitle("Active workouts")
    }

    private var resumable: [ActiveWorkoutSession] {
        sessions.filter { $0.status == .inProgress || $0.status == .paused }
    }

    private var finished: [ActiveWorkoutSession] {
        sessions.filter { $0.status == .completed || $0.status == .abandoned }
    }

    private func sessionRow(_ session: ActiveWorkoutSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: session.status == .completed ? "checkmark.circle.fill" : "figure.run.circle")
                .foregroundStyle(session.status == .completed ? Theme.moss : Theme.evergreen)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.titleSnapshot)
                    .font(.headline)
                Text(sessionRowDetail(session))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func sessionRowDetail(_ session: ActiveWorkoutSession) -> String {
        var parts = [session.status.displayName]
        parts.append(activeDurationLabel(session.elapsedSeconds(at: session.completedAt ?? .now)))
        if let location = session.locationNameSnapshot { parts.append(location) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Plan launcher

/// Reuses an unfinished execution for the same plan, otherwise creates a fresh,
/// durable snapshot before presenting the workout screen.
struct ActiveWorkoutLauncherView: View {
    @Environment(\.modelContext) private var modelContext
    let plan: WorkoutPlan

    @State private var session: ActiveWorkoutSession?
    @State private var errorMessage: String?

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    var body: some View {
        Group {
            if let session {
                ActiveWorkoutView(session: session)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Cannot start workout",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("Preparing workout…")
                    .task { prepare() }
            }
        }
    }

    private func prepare() {
        if let existing = repo.resumableActiveWorkouts().first(where: {
            $0.sourcePlanIDSnapshot == plan.id
        }) {
            session = existing
            return
        }

        guard let created = repo.startActiveWorkout(from: plan) else {
            errorMessage = "Add at least one step to this plan before starting it."
            return
        }
        session = created
    }
}

// MARK: - Main execution screen

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: ActiveWorkoutSession

    @State private var showingFinish = false
    @State private var showingAbandonConfirmation = false
    @State private var adjustmentStep: ActiveWorkoutStep?

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    workoutHeader(now: timeline.date)

                    if session.status == .completed || session.status == .abandoned {
                        finishedCard(now: timeline.date)
                    } else {
                        if session.status == .paused {
                            pausedCard
                        }

                        if session.restStartedAt != nil {
                            restCard(now: timeline.date)
                        }

                        if let step = session.currentStep {
                            ActiveWorkoutStepCard(
                                session: session,
                                step: step,
                                now: timeline.date
                            )

                            MovementFeedbackStepSummaryView(stepID: step.id)

                            Button {
                                adjustmentStep = step
                            } label: {
                                Label("Adjust", systemImage: "slider.horizontal.3")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(session.status != .inProgress)
                            .accessibilityHint("Record how this exercise felt and what you changed")

                            navigationControls
                        } else {
                            readyToFinishCard
                        }
                    }
                }
                .padding()
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle(session.titleSnapshot)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingFinish) {
            NavigationStack {
                ActiveWorkoutCompletionView(session: session)
            }
        }
        .sheet(item: $adjustmentStep) { step in
            NavigationStack {
                MovementFeedbackEditorView(session: session, step: step)
            }
        }
        .confirmationDialog(
            "End this workout early?",
            isPresented: $showingAbandonConfirmation,
            titleVisibility: .visible
        ) {
            Button("End without logging", role: .destructive) {
                repo.abandonActiveWorkout(session)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Completed steps remain in the local execution history, but no completed workout is added to the dashboard.")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if session.status == .inProgress {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    repo.pauseActiveWorkout(session)
                } label: {
                    Label("Pause workout", systemImage: "pause.fill")
                }
            }
        } else if session.status == .paused {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    repo.resumeActiveWorkout(session)
                } label: {
                    Label("Resume workout", systemImage: "play.fill")
                }
            }
        }

        if session.status == .inProgress || session.status == .paused {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("End workout early", role: .destructive) {
                        showingAbandonConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func workoutHeader(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.status.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.moss)
                    Text(activeClockLabel(session.elapsedSeconds(at: now)))
                        .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                }
                Spacer()
                Text(stepProgressText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: session.progressFraction)
                .tint(Theme.evergreen)

            HStack(spacing: 12) {
                if let location = session.locationNameSnapshot {
                    Label(location, systemImage: "mappin.and.ellipse")
                }
                if let target = session.targetEffortSnapshot {
                    Label("Target \(target)/10", systemImage: "gauge.with.dots.needle.50percent")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .card()
    }

    private var stepProgressText: String {
        let total = session.orderedSteps.count
        if total == 0 { return "No steps" }
        if session.currentStepIndex >= total { return "\(total) of \(total)" }
        return "Step \(session.currentStepIndex + 1) of \(total)"
    }

    private var pausedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "pause.circle.fill")
                .font(.title2)
                .foregroundStyle(Theme.honey)
            VStack(alignment: .leading, spacing: 2) {
                Text("Workout paused")
                    .font(.headline)
                Text("Resume when you are ready. Elapsed workout time is not increasing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Resume") { repo.resumeActiveWorkout(session) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.evergreen)
        }
        .card()
    }

    private func restCard(now: Date) -> some View {
        let remaining = session.remainingRestSeconds(at: now) ?? 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(remaining > 0 ? "Rest" : "Rest complete", systemImage: "pause.circle")
                    .font(.headline)
                    .foregroundStyle(Theme.honey)
                Spacer()
                Text(activeClockLabel(remaining))
                    .font(.title2.monospacedDigit().weight(.semibold))
            }

            ProgressView(
                value: Double(max((session.restDurationSeconds ?? 1) - remaining, 0)),
                total: Double(max(session.restDurationSeconds ?? 1, 1))
            )
            .tint(Theme.honey)

            Button(remaining > 0 ? "Skip rest" : "Continue") {
                repo.clearRestTimer(for: session)
            }
            .buttonStyle(.bordered)
        }
        .card()
    }

    private var navigationControls: some View {
        HStack(spacing: 10) {
            Button {
                repo.moveToPreviousActiveWorkoutStep(session)
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(session.currentStepIndex <= 0 || session.status == .paused)

            Button {
                repo.moveToNextActiveWorkoutStep(session)
            } label: {
                Label("Next", systemImage: "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(
                session.currentStepIndex >= max(session.orderedSteps.count - 1, 0)
                    || session.status == .paused
            )
        }
    }

    private var readyToFinishCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Plan complete", systemImage: "checkmark.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.moss)
            Text("Review your effort and finish the workout to add it to Today, history, and your streak.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Finish workout") { showingFinish = true }
                .buttonStyle(.borderedProminent)
                .tint(Theme.evergreen)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card()
    }

    private func finishedCard(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                session.status == .completed ? "Workout completed" : "Workout ended early",
                systemImage: session.status == .completed ? "checkmark.seal.fill" : "stop.circle"
            )
            .font(.title3.weight(.semibold))
            .foregroundStyle(session.status == .completed ? Theme.moss : .secondary)

            Text("Duration: \(activeDurationLabel(session.elapsedSeconds(at: session.completedAt ?? now)))")
            if let effort = session.actualEffort {
                Text("Effort: \(effort)/10")
            }
            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .foregroundStyle(.secondary)
            }

            Text("\(session.steps.filter { $0.status == .completed }.count) completed · \(session.steps.filter { $0.status == .skipped }.count) skipped")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.evergreen)
        }
        .card()
    }
}

// MARK: - Current step

private struct ActiveWorkoutStepCard: View {
    @Environment(\.modelContext) private var modelContext
    let session: ActiveWorkoutSession
    @Bindable var step: ActiveWorkoutStep
    let now: Date

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }
    private var isInteractive: Bool { session.status == .inProgress }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeader

            if let instruction = step.instruction, !instruction.isEmpty {
                Text(instruction)
                    .font(.subheadline)
            }

            plannedDetails

            if step.status == .completed || step.status == .skipped {
                resolvedControls
            } else {
                executionControls
                actionControls
            }
        }
        .card()
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.evergreen.opacity(0.22), lineWidth: 1)
        }
    }

    private var stepHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: step.type.systemImage)
                .font(.title2)
                .foregroundStyle(Theme.evergreen)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(step.type.displayName.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.moss)
                Text(step.title)
                    .font(.title3.weight(.semibold))
                if step.side != .none {
                    Text(step.side.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(step.status.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var plannedDetails: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Planned")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(activeStepPlanSummary(step))
                .font(.subheadline)
            if let equipment = step.equipmentNameSnapshot {
                Label(equipment, systemImage: "dumbbell")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let notes = step.plannedNotes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    @ViewBuilder
    private var executionControls: some View {
        if step.type.supportsSets || step.type.supportsReps {
            setControls
        }

        if step.type.supportsDuration {
            timerControls
        }

        if step.type.supportsDistance {
            distanceControls
        }
    }

    private var setControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Set \(min(step.completedSets + 1, step.plannedSetCount)) of \(step.plannedSetCount)")
                    .font(.headline)
                Spacer()
                Text("\(step.completedSets) completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if step.type.supportsReps {
                Stepper(
                    "Reps: \(actualRepsBinding.wrappedValue)",
                    value: actualRepsBinding,
                    in: 0...200
                )
            }

            if step.type.supportsLoad {
                Stepper(
                    "Weight: \(String(format: "%.1f", actualWeightBinding.wrappedValue)) kg",
                    value: actualWeightBinding,
                    in: 0...500,
                    step: 0.5
                )
            }

            Button {
                _ = repo.completeActiveWorkoutSet(
                    step,
                    reps: step.actualReps ?? step.plannedReps,
                    weightKilograms: step.actualWeightKilograms ?? step.plannedWeightKilograms
                )
            } label: {
                Label("Complete set", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.evergreen)
            .disabled(!isInteractive)
        }
    }

    private var timerControls: some View {
        VStack(spacing: 10) {
            Text(timerDisplay)
                .font(.system(size: 42, weight: .semibold, design: .rounded).monospacedDigit())
                .frame(maxWidth: .infinity)

            if let remaining = step.timerRemainingSeconds(at: now), remaining == 0 {
                Text("Target time reached")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.moss)
            }

            HStack(spacing: 10) {
                Button {
                    if step.timerIsRunning {
                        repo.pauseActiveStepTimer(step)
                    } else {
                        repo.startActiveStepTimer(step)
                    }
                } label: {
                    Label(step.timerIsRunning ? "Pause" : "Start", systemImage: step.timerIsRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.evergreen)
                .disabled(!isInteractive)

                Button("Reset") { repo.resetActiveStepTimer(step) }
                    .buttonStyle(.bordered)
                    .disabled(!isInteractive)
            }
        }
    }

    private var distanceControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper(
                "Actual distance: \(activeDistanceLabel(actualDistanceBinding.wrappedValue))",
                value: actualDistanceBinding,
                in: 0...200_000,
                step: distanceIncrement
            )
        }
    }

    private var actionControls: some View {
        HStack(spacing: 10) {
            Button("Skip") { repo.skipActiveWorkoutStep(step) }
                .buttonStyle(.bordered)
                .disabled(!isInteractive)

            Button {
                repo.completeActiveWorkoutStep(step)
            } label: {
                Text(step.type.supportsSets ? "Complete step" : "Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.evergreen)
            .disabled(!isInteractive)
        }
    }

    private var resolvedControls: some View {
        HStack {
            Label(
                step.status.displayName,
                systemImage: step.status == .completed ? "checkmark.circle.fill" : "forward.end.circle"
            )
            .foregroundStyle(step.status == .completed ? Theme.moss : .secondary)
            Spacer()
            Button("Reopen") { repo.reopenActiveWorkoutStep(step) }
                .buttonStyle(.bordered)
                .disabled(!isInteractive)
        }
    }

    private var actualRepsBinding: Binding<Int> {
        Binding(
            get: { step.actualReps ?? step.plannedReps ?? 0 },
            set: {
                step.actualReps = $0
                repo.activeWorkoutStepDidChange(step)
            }
        )
    }

    private var actualWeightBinding: Binding<Double> {
        Binding(
            get: { step.actualWeightKilograms ?? step.plannedWeightKilograms ?? 0 },
            set: {
                step.actualWeightKilograms = $0
                repo.activeWorkoutStepDidChange(step)
            }
        )
    }

    private var actualDistanceBinding: Binding<Double> {
        Binding(
            get: { step.actualDistanceMeters ?? step.plannedDistanceMeters ?? 0 },
            set: {
                step.actualDistanceMeters = $0
                repo.activeWorkoutStepDidChange(step)
            }
        )
    }

    private var distanceIncrement: Double {
        let target = step.plannedDistanceMeters ?? 0
        return target > 0 && target < 1_000 ? 25 : 100
    }

    private var timerDisplay: String {
        if let remaining = step.timerRemainingSeconds(at: now) {
            return activeClockLabel(remaining)
        }
        return activeClockLabel(step.timerElapsedSeconds(at: now))
    }
}

// MARK: - Completion

private struct ActiveWorkoutCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let session: ActiveWorkoutSession

    @State private var effort: Int
    @State private var notes: String

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    init(session: ActiveWorkoutSession) {
        self.session = session
        _effort = State(initialValue: session.actualEffort ?? session.targetEffortSnapshot ?? 6)
        _notes = State(initialValue: session.notes ?? "")
    }

    var body: some View {
        Form {
            Section {
                Label("\(completedCount) completed step(s)", systemImage: "checkmark.circle")
                if skippedCount > 0 {
                    Label("\(skippedCount) skipped step(s)", systemImage: "forward.end.circle")
                }
                Label(
                    activeDurationLabel(session.elapsedSeconds()),
                    systemImage: "clock"
                )
            } header: {
                Text("Summary")
            }

            Section("How hard was it?") {
                Stepper("Effort: \(effort)/10", value: $effort, in: 1...10)
            }

            Section("Notes") {
                TextField("Optional workout notes", text: $notes, axis: .vertical)
                    .lineLimit(3...7)
            }
        }
        .navigationTitle("Finish workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save workout") {
                    repo.finishActiveWorkout(session, actualEffort: effort, notes: notes)
                    dismiss()
                }
            }
        }
    }

    private var completedCount: Int {
        session.steps.filter { $0.status == .completed }.count
    }

    private var skippedCount: Int {
        session.steps.filter { $0.status == .skipped }.count
    }
}

// MARK: - Formatting

private func activeStepPlanSummary(_ step: ActiveWorkoutStep) -> String {
    var parts: [String] = []
    if let sets = step.plannedSets, let reps = step.plannedReps {
        parts.append("\(sets) × \(reps)")
    } else if let sets = step.plannedSets {
        parts.append("\(sets) set(s)")
    } else if let reps = step.plannedReps {
        parts.append("\(reps) reps")
    }
    if let duration = step.plannedDurationSeconds {
        parts.append(activeDurationLabel(duration))
    }
    if let distance = step.plannedDistanceMeters {
        parts.append(activeDistanceLabel(distance))
    }
    if let weight = step.plannedWeightKilograms {
        parts.append(String(format: "%g kg", weight))
    }
    if let rest = step.plannedRestSeconds {
        parts.append("rest \(activeDurationLabel(rest))")
    }
    return parts.isEmpty ? "Complete when ready" : parts.joined(separator: " · ")
}

private func activeClockLabel(_ seconds: Int) -> String {
    let safe = max(seconds, 0)
    let hours = safe / 3_600
    let minutes = (safe % 3_600) / 60
    let remainder = safe % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, remainder)
    }
    return String(format: "%02d:%02d", minutes, remainder)
}

private func activeDurationLabel(_ seconds: Int) -> String {
    let safe = max(seconds, 0)
    if safe < 60 { return "\(safe) sec" }
    let minutes = safe / 60
    let remainder = safe % 60
    return remainder == 0 ? "\(minutes) min" : "\(minutes)m \(remainder)s"
}

private func activeDistanceLabel(_ meters: Double) -> String {
    meters >= 1_000
        ? String(format: "%.2f km", meters / 1_000)
        : String(format: "%.0f m", meters)
}

#Preview {
    NavigationStack { ActiveWorkoutsView() }
        .modelContainer(PersistenceController.preview.container)
}

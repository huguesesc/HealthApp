import SwiftData
import SwiftUI

/// Workout history plus an editable logging sheet. Natural-language parsing uses
/// the lightweight one-shot route and never saves until the user reviews the draft.
struct WorkoutLogView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    @State private var showingAdd: Bool
    private let initialFreeformText: String

    init(initialFreeformText: String? = nil) {
        self.initialFreeformText = initialFreeformText ?? ""
        _showingAdd = State(initialValue: initialFreeformText != nil)
    }

    var body: some View {
        NellScreen {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Workout History")
                        .font(Theme.FontToken.largeScreenTitle)
                        .foregroundStyle(NellPalette.textPrimary)
                    Text("Manual logs and completed active workouts appear together.")
                        .font(Theme.FontToken.secondaryBody)
                        .foregroundStyle(NellPalette.textSecondary)
                }

                Spacer()

                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: NellLayout.minimumTouchTarget, height: NellLayout.minimumTouchTarget)
                        .background(NellPalette.primary, in: Circle())
                        .foregroundStyle(Color.white)
                }
                .accessibilityLabel("Log a workout")
            }

            if sessions.isEmpty {
                NellEmptyState(
                    title: "No workouts yet",
                    message: "Log a completed session or start a saved workout plan.",
                    systemImage: "figure.strengthtraining.traditional",
                    actionTitle: "Log workout"
                ) {
                    showingAdd = true
                }
            } else {
                ForEach(sessions) { session in
                    NellCard {
                        HStack(spacing: Theme.Spacing.sm) {
                            WorkoutMotionView(
                                title: session.sets.first?.exerciseName ?? session.type,
                                type: .exercise,
                                presentation: .compact
                            )
                            .frame(width: 58)

                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text(session.type)
                                    .font(Theme.FontToken.cardTitle)
                                    .foregroundStyle(NellPalette.textPrimary)

                                Text(setsSummary(session))
                                    .font(Theme.FontToken.caption)
                                    .foregroundStyle(NellPalette.textSecondary)

                                Text(session.date, format: .dateTime.month(.abbreviated).day().year())
                                    .font(Theme.FontToken.caption)
                                    .foregroundStyle(NellPalette.textTertiary)
                            }

                            Spacer(minLength: Theme.Spacing.xs)
                        }
                    }
                }
            }
        }
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdd) {
            WorkoutEntryForm(initialFreeformText: initialFreeformText)
        }
    }

    private func setsSummary(_ session: WorkoutSession) -> String {
        var parts = ["\(session.sets.count) set(s)"]
        if let effort = session.perceivedEffort { parts.append("effort \(effort)/10") }
        if let minutes = session.durationMinutes { parts.append("\(minutes) min") }
        return parts.joined(separator: " · ")
    }
}

private struct WorkoutEntryForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var type = ""
    @State private var effort = 5
    @State private var duration = ""

    @State private var draftSets: [DraftSet] = []
    @State private var newExercise = ""
    @State private var newReps = 8
    @State private var newWeight = ""

    @State private var freeformText: String
    @State private var isParsing = false
    @State private var parseError: String?

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }
    private var hasKey: Bool { APIKeyStore.read()?.isEmpty == false }

    init(initialFreeformText: String = "") {
        _freeformText = State(initialValue: initialFreeformText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NellLayout.sectionSpacing) {
                    NellCard {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            NellTextField(
                                title: "Describe it",
                                text: $freeformText,
                                prompt: "e.g. push day — bench 3 × 8 at 60 kg",
                                axis: .vertical,
                                lineLimit: 2...6
                            )

                            Button {
                                parseWithAI()
                            } label: {
                                if isParsing {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        ProgressView().tint(Color.white)
                                        Text("Filling in…")
                                    }
                                } else {
                                    Label("Fill in with AI", systemImage: "sparkles")
                                }
                            }
                            .buttonStyle(.nellPrimary)
                            .disabled(freeformText.trimmed.isEmpty || isParsing)

                            if !hasKey {
                                Text("Manual logging works without a Coach connection.")
                                    .font(Theme.FontToken.caption)
                                    .foregroundStyle(NellPalette.textSecondary)
                            }

                            if let parseError {
                                Label(parseError, systemImage: "exclamationmark.triangle")
                                    .font(Theme.FontToken.caption)
                                    .foregroundStyle(NellPalette.destructive)
                            }
                        }
                    }

                    if !type.trimmed.isEmpty || !draftSets.isEmpty {
                        WorkoutMotionView(
                            title: draftSets.first?.name ?? type,
                            type: .exercise,
                            presentation: .pair,
                            showsLabels: true
                        )
                        .padding(Theme.Spacing.md)
                        .background(
                            NellPalette.elevatedSurface,
                            in: RoundedRectangle(cornerRadius: NellLayout.featuredRadius, style: .continuous)
                        )
                    }

                    NellSectionHeader(title: "Session")
                    NellCard {
                        VStack(spacing: Theme.Spacing.sm) {
                            TextField("Type, e.g. Push / Run", text: $type)
                                .frame(minHeight: NellLayout.minimumTouchTarget)
                            Divider()
                            Stepper("Effort: \(effort)/10", value: $effort, in: 1...10)
                            Divider()
                            TextField("Duration in minutes (optional)", text: $duration)
                                .keyboardType(.numberPad)
                                .frame(minHeight: NellLayout.minimumTouchTarget)
                        }
                    }

                    NellSectionHeader(title: "Add a set")
                    NellCard {
                        VStack(spacing: Theme.Spacing.sm) {
                            TextField("Exercise", text: $newExercise)
                                .frame(minHeight: NellLayout.minimumTouchTarget)
                            Divider()
                            Stepper("Reps: \(newReps)", value: $newReps, in: 1...200)
                            Divider()
                            TextField("Weight kg (optional)", text: $newWeight)
                                .keyboardType(.decimalPad)
                                .frame(minHeight: NellLayout.minimumTouchTarget)
                            Button("Add set", action: addSet)
                                .buttonStyle(.nellSecondary)
                                .disabled(newExercise.trimmed.isEmpty)
                        }
                    }

                    if !draftSets.isEmpty {
                        NellSectionHeader(
                            title: "Sets to save",
                            subtitle: "Review the parsed details before saving."
                        )

                        NellCard(padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(draftSets) { set in
                                    HStack {
                                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                            Text(set.name)
                                                .font(Theme.FontToken.body)
                                            Text(setLabel(set))
                                                .font(Theme.FontToken.caption)
                                                .foregroundStyle(NellPalette.textSecondary)
                                        }
                                        Spacer()
                                        Button(role: .destructive) {
                                            draftSets.removeAll { $0.id == set.id }
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .accessibilityLabel("Remove \(set.name)")
                                    }
                                    .padding(Theme.Spacing.md)
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .padding(NellLayout.screenPadding)
            }
            .background(NellPalette.groupedBackground)
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(type.trimmed.isEmpty)
                }
            }
        }
    }

    private func parseWithAI() {
        parseError = nil
        guard hasKey else {
            parseError = "No Claude API key is saved. Review Coach connection in Settings."
            return
        }

        isParsing = true
        Task { @MainActor in
            do {
                let parsed = try await AIClientFactory.makeDefault()
                    .parseWorkout(text: freeformText.trimmed)
                type = parsed.type
                if let parsedEffort = parsed.perceivedEffort {
                    effort = min(max(parsedEffort, 1), 10)
                }
                draftSets = parsed.sets.map {
                    DraftSet(name: $0.exerciseName, reps: $0.reps, weight: $0.weightKilograms)
                }
            } catch {
                parseError = AIErrorMessage.describe(error, operation: "workout")
            }
            isParsing = false
        }
    }

    private func addSet() {
        draftSets.append(
            DraftSet(name: newExercise.trimmed, reps: newReps, weight: Double(newWeight))
        )
        newExercise = ""
        newReps = 8
        newWeight = ""
    }

    private func setLabel(_ set: DraftSet) -> String {
        if let weight = set.weight {
            return "\(set.reps) reps @ \(String(format: "%g", weight)) kg"
        }
        return "\(set.reps) reps"
    }

    private func save() {
        let session = WorkoutSession(
            type: type.trimmed,
            durationMinutes: Int(duration),
            perceivedEffort: effort
        )
        session.sets = draftSets.enumerated().map { index, draft in
            ExerciseSet(
                exerciseName: draft.name,
                reps: draft.reps,
                weightKilograms: draft.weight,
                order: index
            )
        }
        repo.addWorkout(session)
        dismiss()
    }
}

private struct DraftSet: Identifiable {
    let id = UUID()
    var name: String
    var reps: Int
    var weight: Double?
}

#Preview {
    NavigationStack { WorkoutLogView() }
        .modelContainer(PersistenceController.preview.container)
}

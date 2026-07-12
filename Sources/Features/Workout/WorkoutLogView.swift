import SwiftData
import SwiftUI

/// Workout history plus an add sheet. Natural-language parsing uses the lightweight
/// one-shot AI route and always leaves the result editable before it is saved.
struct WorkoutLogView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @State private var showingAdd = false

    var body: some View {
        List(sessions) { session in
            VStack(alignment: .leading, spacing: 2) {
                Text(session.type).font(.headline)
                Text(setsSummary(session))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(session.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ColorToken.backgroundPrimary)
        .overlay {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No workouts yet",
                    systemImage: "figure.run",
                    description: Text("Tap + to log a session.")
                )
            }
        }
        .navigationTitle("Workout log")
        .toolbar {
            Button { showingAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showingAdd) { WorkoutEntryForm() }
    }

    private func setsSummary(_ session: WorkoutSession) -> String {
        var parts = ["\(session.sets.count) set(s)"]
        if let effort = session.perceivedEffort { parts.append("effort \(effort)/10") }
        if let minutes = session.durationMinutes { parts.append("\(minutes) min") }
        return parts.joined(separator: " · ")
    }
}

/// Editable draft of a workout, presented as a sheet.
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

    @State private var freeformText = ""
    @State private var isParsing = false
    @State private var parseError: String?

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }
    private var hasKey: Bool { APIKeyStore.read()?.isEmpty == false }

    var body: some View {
        NavigationStack {
            Form {
                Section("Describe it") {
                    TextField("e.g. push day — bench 3×8 at 60 kg", text: $freeformText, axis: .vertical)
                    Button {
                        parseWithAI()
                    } label: {
                        if isParsing {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Filling in…")
                            }
                        } else {
                            Label("Fill in with AI", systemImage: "sparkles")
                        }
                    }
                    .disabled(freeformText.trimmed.isEmpty || isParsing)
                    if let parseError {
                        Label(parseError, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(Theme.ColorToken.destructive)
                    }
                }

                Section("Session") {
                    TextField("Type, e.g. Push / Run", text: $type)
                    Stepper("Effort: \(effort)/10", value: $effort, in: 1...10)
                    TextField("Duration min (optional)", text: $duration)
                        .keyboardType(.numberPad)
                }

                Section("Add a set") {
                    TextField("Exercise", text: $newExercise)
                    Stepper("Reps: \(newReps)", value: $newReps, in: 1...50)
                    TextField("Weight kg (optional)", text: $newWeight)
                        .keyboardType(.decimalPad)
                    Button("Add set", action: addSet)
                        .disabled(newExercise.trimmed.isEmpty)
                }

                if !draftSets.isEmpty {
                    Section("Parsed sets — review before saving") {
                        ForEach(draftSets) { set in
                            Text(setLabel(set))
                        }
                        .onDelete { draftSets.remove(atOffsets: $0) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ColorToken.backgroundSecondary)
            .navigationTitle("New Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(type.trimmed.isEmpty)
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
        newExercise = ""; newReps = 8; newWeight = ""
    }

    private func setLabel(_ set: DraftSet) -> String {
        if let weight = set.weight {
            return "\(set.name) — \(set.reps) reps @ \(String(format: "%g", weight)) kg"
        }
        return "\(set.name) — \(set.reps) reps"
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

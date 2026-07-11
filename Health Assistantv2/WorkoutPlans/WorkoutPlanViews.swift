import Foundation
import SwiftData
import SwiftUI

struct WorkoutPlansView: View {
    @Query(sort: \WorkoutPlan.updatedAt, order: .reverse) private var plans: [WorkoutPlan]
    @State private var showingNewPlan = false

    var body: some View {
        List {
            Section {
                if activePlans.isEmpty {
                    ContentUnavailableView(
                        "No workout plans",
                        systemImage: "list.clipboard",
                        description: Text("Create a plan manually or ask the assistant to draft one for review.")
                    )
                } else {
                    ForEach(activePlans, id: \.id) { plan in
                        NavigationLink {
                            WorkoutPlanEditorView(plan: plan)
                        } label: {
                            planRow(plan)
                        }
                    }
                }
            } header: {
                Text("Saved plans")
            } footer: {
                Text("Plans are editable and stored on this device. Starting and timing a workout comes in the next phase.")
            }

            if !archivedPlans.isEmpty {
                Section("Archived") {
                    ForEach(archivedPlans, id: \.id) { plan in
                        NavigationLink {
                            WorkoutPlanEditorView(plan: plan)
                        } label: {
                            planRow(plan)
                        }
                    }
                }
            }
        }
        .navigationTitle("Workout plans")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewPlan = true
                } label: {
                    Label("New plan", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewPlan) {
            NavigationStack { NewWorkoutPlanView() }
        }
    }

    private var activePlans: [WorkoutPlan] { plans.filter { !$0.isArchived } }
    private var archivedPlans: [WorkoutPlan] { plans.filter(\.isArchived) }

    private func planRow(_ plan: WorkoutPlan) -> some View {
        HStack(spacing: 12) {
            Image(systemName: plan.source == .assistant ? "sparkles" : "list.clipboard")
                .foregroundStyle(plan.isArchived ? Color.secondary : Theme.evergreen)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title)
                    .font(.headline)
                Text(planSummary(plan))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private func planSummary(_ plan: WorkoutPlan) -> String {
        var parts = ["\(plan.steps.count) step(s)"]
        if let minutes = plan.estimatedDurationMinutes { parts.append("\(minutes) min") }
        if let location = plan.locationNameSnapshot { parts.append(location) }
        return parts.joined(separator: " · ")
    }
}

private struct NewWorkoutPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutLocation.updatedAt, order: .reverse) private var allLocations: [WorkoutLocation]

    @State private var title = ""
    @State private var goal = ""
    @State private var notes = ""
    @State private var durationMinutes = 45
    @State private var targetEffort = 6
    @State private var selectedLocationID: UUID?

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }
    private var locations: [WorkoutLocation] { allLocations.filter(\.isActive) }

    var body: some View {
        Form {
            Section("Plan") {
                TextField("Title", text: $title)
                TextField("Goal or focus", text: $goal, axis: .vertical)
                    .lineLimit(2...4)
                Stepper("Estimated duration: \(durationMinutes) min", value: $durationMinutes, in: 5...240, step: 5)
                Stepper("Target effort: \(targetEffort)/10", value: $targetEffort, in: 1...10)
            }

            Section("Workout location") {
                Picker("Location", selection: $selectedLocationID) {
                    Text("No location selected").tag(nil as UUID?)
                    ForEach(locations, id: \.id) { location in
                        Text(location.name).tag(Optional(location.id))
                    }
                }
            }

            Section("Notes") {
                TextField("Optional notes", text: $notes, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
        .navigationTitle("New workout plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { createPlan() }
                    .disabled(title.trimmed.isEmpty)
            }
        }
    }

    private func createPlan() {
        let plan = WorkoutPlan(
            title: title.trimmed,
            goalText: goal.optionalPlanText,
            notes: notes.optionalPlanText,
            estimatedDurationMinutes: durationMinutes,
            targetEffort: targetEffort,
            source: .manual
        )
        repo.addWorkoutPlan(plan)
        let selected = locations.first { $0.id == selectedLocationID }
        repo.applyWorkoutLocationSnapshot(selected, to: plan)
        dismiss()
    }
}

struct WorkoutPlanEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutLocation.updatedAt, order: .reverse) private var allLocations: [WorkoutLocation]
    @Bindable var plan: WorkoutPlan

    @State private var showingStepEditor = false
    @State private var editingStep: WorkoutStep?
    @State private var savedMessage: String?

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }
    private var locations: [WorkoutLocation] { allLocations.filter(\.isActive) }

    var body: some View {
        Form {
            Section("Plan") {
                TextField("Title", text: $plan.title)
                TextField("Goal or focus", text: goalBinding, axis: .vertical)
                    .lineLimit(2...4)

                Stepper(
                    "Estimated duration: \(plan.estimatedDurationMinutes ?? 45) min",
                    value: durationBinding,
                    in: 5...240,
                    step: 5
                )
                Stepper(
                    "Target effort: \(plan.targetEffort ?? 6)/10",
                    value: effortBinding,
                    in: 1...10
                )
            }

            Section {
                Picker("Location", selection: $plan.locationIDSnapshot) {
                    Text("No location selected").tag(nil as UUID?)
                    ForEach(locations, id: \.id) { location in
                        Text(location.name).tag(Optional(location.id))
                    }
                }
                .onChange(of: plan.locationIDSnapshot) { _, newValue in
                    let location = locations.first { $0.id == newValue }
                    repo.applyWorkoutLocationSnapshot(location, to: plan)
                }

                if let summary = plan.equipmentSummarySnapshot, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Workout environment")
            } footer: {
                Text("The plan keeps a compact snapshot of the selected location and available equipment.")
            }

            Section {
                if plan.orderedSteps.isEmpty {
                    Text("No steps yet. Add a warm-up, exercise, rest, cardio, mobility, or cooldown step.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(plan.orderedSteps, id: \.id) { step in
                        stepRow(step)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    repo.removeWorkoutStep(step)
                                }
                            }
                    }
                    .onMove { source, destination in
                        repo.moveWorkoutSteps(in: plan, from: source, to: destination)
                    }
                }

                Button {
                    editingStep = nil
                    showingStepEditor = true
                } label: {
                    Label("Add step", systemImage: "plus")
                }
            } header: {
                HStack {
                    Text("Steps")
                    Spacer()
                    EditButton()
                }
            } footer: {
                Text("Drag while editing to reorder. Active workout timers and completion tracking are deliberately deferred.")
            }

            Section("Notes") {
                TextField("Plan notes", text: notesBinding, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                Button(plan.isArchived ? "Restore plan" : "Archive plan") {
                    if plan.isArchived {
                        repo.restoreWorkoutPlan(plan)
                    } else {
                        repo.archiveWorkoutPlan(plan)
                    }
                }
                .foregroundStyle(plan.isArchived ? Theme.evergreen : Theme.clay)
            }

            if let savedMessage {
                Section {
                    Label(savedMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(Theme.moss)
                }
            }
        }
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    repo.workoutPlanDidChange(plan)
                    savedMessage = "Plan saved on this device."
                }
                .disabled(plan.title.trimmed.isEmpty)
            }
        }
        .sheet(isPresented: $showingStepEditor) {
            NavigationStack {
                WorkoutStepEditorView(plan: plan, step: editingStep)
            }
        }
    }

    private var durationBinding: Binding<Int> {
        Binding(
            get: { plan.estimatedDurationMinutes ?? 45 },
            set: { plan.estimatedDurationMinutes = $0 }
        )
    }

    private var effortBinding: Binding<Int> {
        Binding(
            get: { plan.targetEffort ?? 6 },
            set: { plan.targetEffort = $0 }
        )
    }

    private var goalBinding: Binding<String> {
        Binding(
            get: { plan.goalText ?? "" },
            set: { plan.goalText = $0.optionalPlanText }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { plan.notes ?? "" },
            set: { plan.notes = $0.optionalPlanText }
        )
    }

    private func stepRow(_ step: WorkoutStep) -> some View {
        Button {
            editingStep = step
            showingStepEditor = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: step.type.systemImage)
                    .foregroundStyle(Theme.moss)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(step.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(stepSummary(step))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Text("\(step.order + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private func stepSummary(_ step: WorkoutStep) -> String {
        var parts = [step.type.displayName]
        if let sets = step.sets, let reps = step.reps { parts.append("\(sets) × \(reps)") }
        else if let sets = step.sets { parts.append("\(sets) set(s)") }
        else if let reps = step.reps { parts.append("\(reps) reps") }
        if let seconds = step.durationSeconds { parts.append(durationLabel(seconds)) }
        if let meters = step.distanceMeters { parts.append(distanceLabel(meters)) }
        if let weight = step.targetWeightKilograms { parts.append(String(format: "%g kg", weight)) }
        if let equipment = step.equipmentNameSnapshot { parts.append(equipment) }
        if let rest = step.restSeconds { parts.append("rest \(durationLabel(rest))") }
        return parts.joined(separator: " · ")
    }
}

private struct WorkoutStepEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let plan: WorkoutPlan
    let step: WorkoutStep?

    @State private var typeRaw: String
    @State private var title: String
    @State private var instruction: String
    @State private var sets: Int
    @State private var reps: Int
    @State private var durationMinutes: Int
    @State private var durationSecondsRemainder: Int
    @State private var distanceText: String
    @State private var weightText: String
    @State private var restSeconds: Int
    @State private var sideRaw: String
    @State private var equipment: String
    @State private var notes: String
    @State private var validationMessage: String?

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }
    private var type: WorkoutStepType { WorkoutStepType(rawValue: typeRaw) ?? .freeform }

    init(plan: WorkoutPlan, step: WorkoutStep?) {
        self.plan = plan
        self.step = step
        let totalSeconds = step?.durationSeconds ?? 0
        _typeRaw = State(initialValue: step?.typeRaw ?? WorkoutStepType.exercise.rawValue)
        _title = State(initialValue: step?.title ?? "")
        _instruction = State(initialValue: step?.instruction ?? "")
        _sets = State(initialValue: step?.sets ?? 3)
        _reps = State(initialValue: step?.reps ?? 8)
        _durationMinutes = State(initialValue: totalSeconds / 60)
        _durationSecondsRemainder = State(initialValue: totalSeconds % 60)
        _distanceText = State(initialValue: step?.distanceMeters.map { String(format: "%g", $0) } ?? "")
        _weightText = State(initialValue: step?.targetWeightKilograms.map { String(format: "%g", $0) } ?? "")
        _restSeconds = State(initialValue: step?.restSeconds ?? 60)
        _sideRaw = State(initialValue: step?.sideRaw ?? WorkoutStepSide.none.rawValue)
        _equipment = State(initialValue: step?.equipmentNameSnapshot ?? "")
        _notes = State(initialValue: step?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Step") {
                Picker("Type", selection: $typeRaw) {
                    ForEach(WorkoutStepType.allCases) { type in
                        Label(type.displayName, systemImage: type.systemImage).tag(type.rawValue)
                    }
                }
                TextField("Title", text: $title)
                TextField("Instructions", text: $instruction, axis: .vertical)
                    .lineLimit(2...5)
            }

            if type.supportsSets || type.supportsReps {
                Section("Volume") {
                    if type.supportsSets {
                        Stepper("Sets: \(sets)", value: $sets, in: 1...20)
                    }
                    if type.supportsReps {
                        Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                    }
                    Picker("Side", selection: $sideRaw) {
                        ForEach(WorkoutStepSide.allCases) { side in
                            Text(side.displayName).tag(side.rawValue)
                        }
                    }
                }
            }

            if type.supportsDuration {
                Section("Duration") {
                    Stepper("Minutes: \(durationMinutes)", value: $durationMinutes, in: 0...180)
                    Stepper("Seconds: \(durationSecondsRemainder)", value: $durationSecondsRemainder, in: 0...59, step: 5)
                }
            }

            if type.supportsDistance {
                Section("Distance") {
                    TextField("Distance in meters", text: $distanceText)
                        .keyboardType(.decimalPad)
                }
            }

            if type.supportsLoad || type.supportsRestAfter {
                Section("Load and recovery") {
                    if type.supportsLoad {
                        TextField("Target weight (kg), optional", text: $weightText)
                            .keyboardType(.decimalPad)
                    }
                    if type.supportsRestAfter {
                        Stepper("Rest after: \(restSeconds) sec", value: $restSeconds, in: 0...600, step: 15)
                    }
                }
            }

            Section("Equipment and notes") {
                TextField("Equipment, optional", text: $equipment)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...5)
            }

            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundStyle(Theme.clay)
                }
            }
        }
        .navigationTitle(step == nil ? "Add step" : "Edit step")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(title.trimmed.isEmpty)
            }
        }
    }

    private func save() {
        let duration = durationMinutes * 60 + durationSecondsRemainder
        let parsedDistance = parseNumber(distanceText)
        let parsedWeight = parseNumber(weightText)
        if let parsedDistance, parsedDistance <= 0 {
            validationMessage = "Distance must be greater than zero."
            return
        }
        if let parsedWeight, parsedWeight < 0 {
            validationMessage = "Weight cannot be negative."
            return
        }

        let stepType = type
        let resolvedSets = stepType.supportsSets ? sets : nil
        let resolvedReps = stepType.supportsReps ? reps : nil
        let resolvedDuration = stepType.supportsDuration && duration > 0 ? duration : nil
        let resolvedDistance = stepType.supportsDistance ? parsedDistance : nil
        let resolvedWeight = stepType.supportsLoad ? parsedWeight : nil
        let resolvedRest = stepType.supportsRestAfter && restSeconds > 0 ? restSeconds : nil
        let resolvedSide = WorkoutStepSide(rawValue: sideRaw) ?? .none

        if let step {
            step.typeRaw = stepType.rawValue
            step.title = title.trimmed
            step.instruction = instruction.optionalPlanText
            step.sets = resolvedSets
            step.reps = resolvedReps
            step.durationSeconds = resolvedDuration
            step.distanceMeters = resolvedDistance
            step.targetWeightKilograms = resolvedWeight
            step.restSeconds = resolvedRest
            step.sideRaw = resolvedSide.rawValue
            step.equipmentNameSnapshot = equipment.optionalPlanText
            step.notes = notes.optionalPlanText
            repo.workoutStepDidChange(step)
        } else {
            repo.addWorkoutStep(
                WorkoutStep(
                    order: plan.steps.count,
                    type: stepType,
                    title: title.trimmed,
                    instruction: instruction.optionalPlanText,
                    sets: resolvedSets,
                    reps: resolvedReps,
                    durationSeconds: resolvedDuration,
                    distanceMeters: resolvedDistance,
                    targetWeightKilograms: resolvedWeight,
                    restSeconds: resolvedRest,
                    side: resolvedSide,
                    equipmentNameSnapshot: equipment.optionalPlanText,
                    notes: notes.optionalPlanText
                ),
                to: plan
            )
        }
        dismiss()
    }

    private func parseNumber(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: ".").trimmed)
    }
}

private func durationLabel(_ seconds: Int) -> String {
    if seconds < 60 { return "\(seconds) sec" }
    let minutes = seconds / 60
    let remainder = seconds % 60
    return remainder == 0 ? "\(minutes) min" : "\(minutes)m \(remainder)s"
}

private func distanceLabel(_ meters: Double) -> String {
    meters >= 1_000
        ? String(format: "%.1f km", meters / 1_000)
        : String(format: "%g m", meters)
}

private extension String {
    var optionalPlanText: String? {
        let cleaned = trimmed
        return cleaned.isEmpty ? nil : cleaned
    }
}

#Preview {
    NavigationStack { WorkoutPlansView() }
        .modelContainer(PersistenceController.preview.container)
}
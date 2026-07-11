import SwiftData
import SwiftUI

struct MovementFeedbackEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let session: ActiveWorkoutSession
    let step: ActiveWorkoutStep

    @State private var signalRaw = MovementFeedbackSignal.lessControlled.rawValue
    @State private var bodyAreaRaw = ""
    @State private var sideRaw = BodySide.unspecified.rawValue
    @State private var impactRaw = MovementFeedbackImpact.noticedOnly.rawValue
    @State private var actionRaw = MovementAdjustmentAction.noChange.rawValue
    @State private var note = ""

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    private var signal: MovementFeedbackSignal {
        MovementFeedbackSignal(rawValue: signalRaw) ?? .other
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Workout", value: session.titleSnapshot)
                LabeledContent("Exercise", value: step.title)
                if let setNumber {
                    LabeledContent("Set", value: "\(setNumber) of \(step.plannedSetCount)")
                }
            } header: {
                Text("Context")
            } footer: {
                Text("This observation is attached to the exact workout and exercise. It does not change your long-term profile automatically.")
            }

            Section("How did that feel?") {
                Picker("Observation", selection: $signalRaw) {
                    ForEach(MovementFeedbackSignal.allCases) { option in
                        Label(option.displayName, systemImage: option.systemImage)
                            .tag(option.rawValue)
                    }
                }

                Picker("Impact", selection: $impactRaw) {
                    ForEach(MovementFeedbackImpact.allCases) { option in
                        Text(option.displayName).tag(option.rawValue)
                    }
                }
            }

            if signal.suggestsBodyArea {
                Section("Where?") {
                    Picker("Body area", selection: $bodyAreaRaw) {
                        Text("Not specified").tag("")
                        ForEach(HealthBodyArea.allCases) { area in
                            Text(area.displayName).tag(area.rawValue)
                        }
                    }

                    Picker("Side", selection: $sideRaw) {
                        ForEach(BodySide.allCases) { side in
                            Text(side.displayName).tag(side.rawValue)
                        }
                    }
                }
            }

            Section {
                Picker("Adjustment", selection: $actionRaw) {
                    ForEach(MovementAdjustmentAction.allCases) { option in
                        Text(option.displayName).tag(option.rawValue)
                    }
                }
            } header: {
                Text("What did you change?")
            } footer: {
                if actionRaw == MovementAdjustmentAction.skippedStep.rawValue {
                    Text("Saving will also mark this step as skipped and advance the workout.")
                } else {
                    Text("Use the normal reps, load, timer and navigation controls to apply the adjustment to the workout.")
                }
            }

            Section("Optional note") {
                TextField("What was different?", text: $note, axis: .vertical)
                    .lineLimit(3...7)
            }

            Section {
                Text("These are your own observations, not a medical assessment. The app does not diagnose a condition or prescribe treatment.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Adjust")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
    }

    private var setNumber: Int? {
        guard step.type.supportsSets || step.type.supportsReps else { return nil }
        return min(max(step.completedSets + 1, 1), step.plannedSetCount)
    }

    private func save() {
        let bodyArea = bodyAreaRaw.isEmpty ? nil : HealthBodyArea(rawValue: bodyAreaRaw)
        let selectedSide = bodyArea == nil ? nil : BodySide(rawValue: sideRaw)

        repo.addMovementFeedback(
            for: session,
            step: step,
            setNumber: setNumber,
            signal: signal,
            bodyArea: bodyArea,
            side: selectedSide,
            impact: MovementFeedbackImpact(rawValue: impactRaw) ?? .noticedOnly,
            action: MovementAdjustmentAction(rawValue: actionRaw) ?? .noChange,
            note: note
        )
        dismiss()
    }
}

struct MovementFeedbackStepSummaryView: View {
    @Query(sort: \MovementFeedbackEntry.createdAt, order: .reverse)
    private var entries: [MovementFeedbackEntry]

    let stepID: UUID

    private var matchingEntries: [MovementFeedbackEntry] {
        entries.filter { $0.stepIDSnapshot == stepID && $0.userReported }
    }

    var body: some View {
        if let latest = matchingEntries.first {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Theme.honey)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Latest adjustment")
                        .font(.caption.weight(.semibold))
                    Text(summary(latest))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if matchingEntries.count > 1 {
                    Text("\(matchingEntries.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(
                Theme.honey.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
    }

    private func summary(_ entry: MovementFeedbackEntry) -> String {
        var parts = [entry.signal.displayName]
        if let area = entry.bodyArea {
            let side = entry.side?.displayName
            parts.append([side, area.displayName].compactMap { $0 }.joined(separator: " "))
        }
        if entry.action != .noChange {
            parts.append(entry.action.displayName)
        }
        return parts.joined(separator: " · ")
    }
}

struct MovementFeedbackHistoryView: View {
    @Query(sort: \MovementFeedbackEntry.createdAt, order: .reverse)
    private var entries: [MovementFeedbackEntry]

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No movement feedback",
                    systemImage: "slider.horizontal.3",
                    description: Text("During an active workout, tap Adjust to record how an exercise felt and what you changed.")
                )
            } else {
                Section {
                    ForEach(entries, id: \.id) { entry in
                        NavigationLink {
                            MovementFeedbackDetailView(entry: entry)
                        } label: {
                            feedbackRow(entry)
                        }
                    }
                } footer: {
                    Text("Feedback entries are user-reported workout observations. They are kept as history and do not silently modify your health profile.")
                }
            }
        }
        .navigationTitle("Movement feedback")
    }

    private func feedbackRow(_ entry: MovementFeedbackEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.signal.systemImage)
                .foregroundStyle(Theme.honey)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.signal.displayName)
                    .font(.headline)
                Text("\(entry.stepTitleSnapshot) · \(entry.sessionTitleSnapshot)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(entry.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct MovementFeedbackDetailView: View {
    let entry: MovementFeedbackEntry

    var body: some View {
        Form {
            Section("Workout context") {
                LabeledContent("Workout", value: entry.sessionTitleSnapshot)
                LabeledContent("Exercise", value: entry.stepTitleSnapshot)
                LabeledContent("Step", value: "\(entry.stepOrderSnapshot + 1)")
                if let set = entry.setNumberSnapshot {
                    LabeledContent("Set", value: "\(set)")
                }
                LabeledContent("Recorded") {
                    Text(entry.createdAt, format: .dateTime.year().month().day().hour().minute())
                }
            }

            Section("Observation") {
                LabeledContent("Felt", value: entry.signal.displayName)
                LabeledContent("Impact", value: entry.impact.displayName)
                if let area = entry.bodyArea {
                    LabeledContent("Body area", value: area.displayName)
                }
                if let side = entry.side {
                    LabeledContent("Side", value: side.displayName)
                }
                LabeledContent("Adjustment", value: entry.action.displayName)
            }

            if let comparison = plannedActualSummary {
                Section("Planned and actual") {
                    Text(comparison)
                }
            }

            if let note = entry.note, !note.isEmpty {
                Section("Your note") {
                    Text(note)
                }
            }

            Section {
                Text("This entry records what you reported during the workout. It is not a diagnosis or medical recommendation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Feedback detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var plannedActualSummary: String? {
        var rows: [String] = []
        if entry.plannedRepsSnapshot != nil || entry.actualRepsSnapshot != nil {
            rows.append("Reps: planned \(entry.plannedRepsSnapshot.map(String.init) ?? "—"), actual \(entry.actualRepsSnapshot.map(String.init) ?? "—")")
        }
        if entry.plannedWeightKilogramsSnapshot != nil || entry.actualWeightKilogramsSnapshot != nil {
            rows.append(
                "Load: planned \(weight(entry.plannedWeightKilogramsSnapshot)), actual \(weight(entry.actualWeightKilogramsSnapshot))"
            )
        }
        if entry.plannedDurationSecondsSnapshot != nil || entry.actualDurationSecondsSnapshot != nil {
            rows.append(
                "Time: planned \(duration(entry.plannedDurationSecondsSnapshot)), actual \(duration(entry.actualDurationSecondsSnapshot))"
            )
        }
        return rows.isEmpty ? nil : rows.joined(separator: "\n")
    }

    private func weight(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%g kg", value)
    }

    private func duration(_ value: Int?) -> String {
        guard let value else { return "—" }
        let minutes = value / 60
        let seconds = value % 60
        return minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
    }
}

#Preview {
    NavigationStack { MovementFeedbackHistoryView() }
        .modelContainer(PersistenceController.preview.container)
}

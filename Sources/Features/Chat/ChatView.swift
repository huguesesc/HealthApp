import SwiftData
import SwiftUI

/// The app's front door: a chat with the assistant. Freeform logging renders inline
/// confirmation cards; future workout-plan requests render editable saved-plan drafts.
struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var engine: ChatEngine?
    @State private var draft = ""

    var body: some View {
        Group {
            if let engine {
                conversation(engine)
            } else {
                Color.clear
            }
        }
        .navigationTitle("Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if engine == nil {
                engine = ChatEngine(modelContext: modelContext)
            }
        }
    }

    private func conversation(_ engine: ChatEngine) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if engine.items.isEmpty {
                        ChatEmptyState(hasKey: engine.hasKey)
                    }
                    ForEach(engine.items) { item in
                        itemView(item, engine: engine)
                    }
                    if engine.isThinking {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Thinking…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                    if let error = engine.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(Theme.clay)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: engine.items.count) {
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .safeAreaInset(edge: .bottom) {
                composer(engine)
            }
        }
    }

    @ViewBuilder
    private func itemView(_ item: ChatItem, engine: ChatEngine) -> some View {
        switch item {
        case .user(_, let text):
            HStack {
                Spacer(minLength: 48)
                Text(text)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Theme.evergreen, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(.white)
            }
        case .assistant(_, let text):
            HStack {
                Text(text)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                Spacer(minLength: 48)
            }
        case .proposal(let proposal):
            ProposalCard(proposal: proposal, engine: engine)
        }
    }

    private func composer(_ engine: ChatEngine) -> some View {
        HStack(spacing: 10) {
            TextField("Log something, ask a question, or build a plan…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .onSubmit(sendDraft)
            Button(action: sendDraft) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        draft.trimmed.isEmpty || engine.isThinking ? Color.secondary : Theme.evergreen
                    )
            }
            .disabled(draft.trimmed.isEmpty || engine.isThinking)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func sendDraft() {
        guard let engine else { return }
        let text = draft
        draft = ""
        engine.send(text)
    }
}

// MARK: - Empty state

private struct ChatEmptyState: View {
    let hasKey: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.evergreen)
            Text("Tell me what you need")
                .font(.title3.weight(.semibold))
            Text("Try one of these:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                suggestion("“I had two eggs and toast”")
                suggestion("“Did push day — bench 3×8 at 60 kg”")
                suggestion("“Build me a 35-minute workout for Home”")
                suggestion("“How has my week been?”")
            }
            if !hasKey {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Add your API key in Settings to connect the assistant",
                          systemImage: "key")
                        .font(.footnote)
                        .foregroundStyle(Theme.clay)
                }
            }
        }
        .card()
        .padding(.top, 12)
    }

    private func suggestion(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(Theme.moss)
    }
}

// MARK: - Proposal cards

private struct ProposalCard: View {
    let proposal: ChatProposal
    let engine: ChatEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch proposal.kind {
            case .meal(let meal):
                MealCardContent(meal: meal)
            case .workout(let workout):
                WorkoutCardContent(workout: workout)
            case .workoutPlan(let plan):
                WorkoutPlanCardContent(plan: plan)
            }
            footer
        }
        .card()
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    private var borderColor: Color {
        switch proposal.status {
        case .pending: return Theme.evergreen.opacity(0.35)
        case .saved: return Theme.moss.opacity(0.6)
        case .discarded: return Color.secondary.opacity(0.2)
        }
    }

    private var saveLabel: String {
        if case .workoutPlan = proposal.kind { return "Save plan" }
        return "Save"
    }

    @ViewBuilder
    private var footer: some View {
        switch proposal.status {
        case .pending:
            HStack(spacing: 12) {
                Button {
                    engine.confirm(proposal)
                } label: {
                    Text(saveLabel)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.evergreen)

                Button {
                    engine.discard(proposal)
                } label: {
                    Text("Discard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        case .saved:
            Label(saveLabel == "Save plan" ? "Plan saved" : "Saved", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.moss)
        case .discarded:
            Label("Discarded", systemImage: "xmark.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MealCardContent: View {
    let meal: MealProposal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Meal", systemImage: "fork.knife")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.moss)
            Text(meal.description)
                .font(.headline)

            if let items = meal.items, !items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        itemRow(item)
                    }
                }
                Divider()
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(totalLine)
                    .font(.subheadline.weight(.medium))
                if let confidence = meal.confidence {
                    Text("· confidence \(confidence)")
                        .font(.caption)
                        .foregroundStyle(Theme.honey)
                }
            }
        }
    }

    private func itemRow(_ item: MealItemBreakdown) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(itemTitle(item))
                    .font(.callout)
                if let macros = itemMacros(item) {
                    Text(macros)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let calories = item.calories {
                Text("~\(calories) kcal")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func itemTitle(_ item: MealItemBreakdown) -> String {
        var parts = [item.food]
        if let quantity = item.quantity { parts.append(quantity) }
        if let grams = item.grams { parts.append("~\(Int(grams)) g") }
        return parts.joined(separator: " · ")
    }

    private func itemMacros(_ item: MealItemBreakdown) -> String? {
        guard item.proteinGrams != nil || item.carbsGrams != nil || item.fatGrams != nil else {
            return nil
        }
        let protein = Int(item.proteinGrams ?? 0)
        let carbs = Int(item.carbsGrams ?? 0)
        let fat = Int(item.fatGrams ?? 0)
        return "P \(protein) · C \(carbs) · F \(fat)"
    }

    private var totalLine: String {
        var parts: [String] = []
        if let calories = meal.calories { parts.append("Total ~\(calories) kcal") }
        var macros: [String] = []
        if let protein = meal.proteinGrams { macros.append("P \(Int(protein))") }
        if let carbs = meal.carbsGrams { macros.append("C \(Int(carbs))") }
        if let fat = meal.fatGrams { macros.append("F \(Int(fat))") }
        if !macros.isEmpty { parts.append(macros.joined(separator: " · ")) }
        return parts.isEmpty ? "No estimate provided" : parts.joined(separator: " — ")
    }
}

private struct WorkoutCardContent: View {
    let workout: WorkoutProposal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Completed workout", systemImage: "figure.strengthtraining.traditional")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.moss)
            Text(workout.type)
                .font(.headline)

            if let detail = detailLine {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let sets = workout.sets, !sets.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(sets.enumerated()), id: \.offset) { _, set in
                        Text(setLine(set))
                            .font(.callout)
                    }
                }
            }
        }
    }

    private var detailLine: String? {
        var parts: [String] = []
        if let effort = workout.perceivedEffort { parts.append("effort \(effort)/10") }
        if let minutes = workout.durationMinutes { parts.append("\(minutes) min") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func setLine(_ set: WorkoutSetProposal) -> String {
        if let weight = set.weightKilograms {
            return "\(set.exercise) — \(set.reps) reps @ \(String(format: "%g", weight)) kg"
        }
        return "\(set.exercise) — \(set.reps) reps"
    }
}

private struct WorkoutPlanCardContent: View {
    let plan: WorkoutPlanProposal

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Future workout plan", systemImage: "list.clipboard")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.moss)

            Text(plan.title)
                .font(.headline)

            if let detailLine {
                Text(detailLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let goal = plan.goal, !goal.isEmpty {
                Text(goal)
                    .font(.subheadline)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(plan.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 18, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.callout.weight(.medium))
                            Text(stepDetail(step))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let notes = plan.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private var detailLine: String? {
        var parts: [String] = []
        if let minutes = plan.estimatedDurationMinutes { parts.append("\(minutes) min") }
        if let effort = plan.targetEffort { parts.append("effort \(effort)/10") }
        if let location = plan.location { parts.append(location) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func stepDetail(_ step: WorkoutPlanStepProposal) -> String {
        var parts = [stepTypeLabel(step.type)]
        if let sets = step.sets, let reps = step.reps { parts.append("\(sets) × \(reps)") }
        else if let sets = step.sets { parts.append("\(sets) set(s)") }
        else if let reps = step.reps { parts.append("\(reps) reps") }
        if let seconds = step.durationSeconds { parts.append(planDurationLabel(seconds)) }
        if let meters = step.distanceMeters { parts.append(planDistanceLabel(meters)) }
        if let weight = step.targetWeightKilograms { parts.append(String(format: "%g kg", weight)) }
        if let equipment = step.equipment { parts.append(equipment) }
        if let rest = step.restSeconds, rest > 0 { parts.append("rest \(planDurationLabel(rest))") }
        return parts.joined(separator: " · ")
    }

    private func stepTypeLabel(_ raw: String) -> String {
        WorkoutStepType(rawValue: raw)?.displayName ?? "Step"
    }
}

private func planDurationLabel(_ seconds: Int) -> String {
    if seconds < 60 { return "\(seconds) sec" }
    let minutes = seconds / 60
    let remainder = seconds % 60
    return remainder == 0 ? "\(minutes) min" : "\(minutes)m \(remainder)s"
}

private func planDistanceLabel(_ meters: Double) -> String {
    meters >= 1_000
        ? String(format: "%.1f km", meters / 1_000)
        : String(format: "%g m", meters)
}

#Preview {
    NavigationStack { ChatView() }
        .modelContainer(PersistenceController.preview.container)
}
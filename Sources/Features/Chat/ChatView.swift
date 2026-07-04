import SwiftData
import SwiftUI

/// The app's front door: a chat with the assistant. Freeform logging ("I had two
/// eggs and toast") renders inline confirmation cards that show the model's
/// per-food assumptions; questions are answered from recent rollup data.
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
                    // Anchor for scroll-to-bottom.
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
            TextField("Log a meal, a workout, or ask anything…", text: $draft, axis: .vertical)
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
            Text("Tell me about your day")
                .font(.title3.weight(.semibold))
            Text("Try one of these:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                suggestion("“I had two eggs and toast”")
                suggestion("“Did push day — bench 3×8 at 60 kg”")
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

    @ViewBuilder
    private var footer: some View {
        switch proposal.status {
        case .pending:
            HStack(spacing: 12) {
                Button {
                    engine.confirm(proposal)
                } label: {
                    Text("Save")
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
            Label("Saved", systemImage: "checkmark.circle.fill")
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
            Label("Workout", systemImage: "figure.strengthtraining.traditional")
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

#Preview {
    NavigationStack { ChatView() }
        .modelContainer(PersistenceController.preview.container)
}

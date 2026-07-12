import SwiftData
import SwiftUI

struct NellWorkoutPlansView: View {
    @Query(sort: \WorkoutPlan.updatedAt, order: .reverse) private var plans: [WorkoutPlan]

    var body: some View {
        NellScreen {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Workout Plans")
                    .font(Theme.FontToken.largeScreenTitle)
                    .foregroundStyle(NellPalette.textPrimary)
                Text("Choose a plan, review its movements, then start when ready.")
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)
            }

            if activePlans.isEmpty {
                NellEmptyState(
                    title: "No workout plans",
                    message: "Create a plan manually or ask the Coach to prepare an editable draft.",
                    systemImage: "list.clipboard"
                )
            } else {
                ForEach(activePlans, id: \.id) { plan in
                    NavigationLink { NellWorkoutPlanDetailView(plan: plan) } label: {
                        planCard(plan)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !archivedPlans.isEmpty {
                NellSectionHeader(title: "Archived")
                ForEach(archivedPlans.prefix(5), id: \.id) { plan in
                    NavigationLink { WorkoutPlanEditorView(plan: plan) } label: {
                        NellCard {
                            HStack {
                                Image(systemName: "archivebox")
                                    .foregroundStyle(NellPalette.textTertiary)
                                Text(plan.title)
                                    .font(Theme.FontToken.body)
                                    .foregroundStyle(NellPalette.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(NellPalette.textTertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Manage") { WorkoutPlansView() }
            }
        }
    }

    private var activePlans: [WorkoutPlan] { plans.filter { !$0.isArchived } }
    private var archivedPlans: [WorkoutPlan] { plans.filter(\.isArchived) }

    private func planCard(_ plan: WorkoutPlan) -> some View {
        NellFeaturedCard(tint: NellPalette.training) {
            HStack(spacing: Theme.Spacing.md) {
                WorkoutMotionView(
                    title: plan.orderedSteps.first?.title ?? plan.title,
                    type: plan.orderedSteps.first?.type,
                    presentation: .compact
                )
                .frame(width: 68)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(plan.title)
                            .font(Theme.FontToken.cardTitle)
                            .foregroundStyle(NellPalette.textPrimary)
                            .lineLimit(2)
                        if plan.source == .assistant {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(NellPalette.amber)
                        }
                    }
                    Text(planSummary(plan))
                        .font(Theme.FontToken.caption)
                        .foregroundStyle(NellPalette.textSecondary)
                    if let goal = plan.goalText, !goal.isEmpty {
                        Text(goal)
                            .font(Theme.FontToken.caption)
                            .foregroundStyle(NellPalette.textTertiary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: Theme.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NellPalette.textTertiary)
            }
        }
    }

    private func planSummary(_ plan: WorkoutPlan) -> String {
        var parts = ["\(plan.orderedSteps.count) movements"]
        if let minutes = plan.estimatedDurationMinutes { parts.append("\(minutes) min") }
        if let location = plan.locationNameSnapshot { parts.append(location) }
        return parts.joined(separator: " · ")
    }
}

struct NellWorkoutPlanDetailView: View {
    @Bindable var plan: WorkoutPlan

    var body: some View {
        NellScreen {
            planHeader

            if let firstStep = plan.orderedSteps.first {
                WorkoutMotionView(
                    title: firstStep.title,
                    type: firstStep.type,
                    presentation: .hero,
                    showsLabels: true
                )
            }

            if plan.orderedSteps.isEmpty {
                NellEmptyState(
                    title: "No movements yet",
                    message: "Open Edit to add warm-up, exercise, mobility, rest or cooldown steps.",
                    systemImage: "figure.strengthtraining.traditional"
                )
            } else {
                NellSectionHeader(
                    title: "Exercises",
                    subtitle: "Tap a movement to view its start and finish guide."
                )

                NellCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(plan.orderedSteps.enumerated()), id: \.offset) { index, step in
                            NavigationLink { NellExerciseDetailView(step: step) } label: {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Text("\(index + 1)")
                                        .font(Theme.FontToken.caption.monospacedDigit())
                                        .foregroundStyle(Color.white)
                                        .frame(width: 24, height: 24)
                                        .background(NellPalette.primary, in: Circle())
                                    WorkoutMotionRow(
                                        title: step.title,
                                        type: step.type,
                                        detail: stepSummary(step)
                                    )
                                }
                                .padding(Theme.Spacing.md)
                            }
                            .buttonStyle(.plain)

                            if index < plan.orderedSteps.count - 1 {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                }
            }

            if !plan.orderedSteps.isEmpty, !plan.isArchived {
                NavigationLink { NellActiveWorkoutLauncherView(plan: plan) } label: {
                    Label("Start Workout", systemImage: "play.fill")
                }
                .buttonStyle(.nellPrimary)
            }
        }
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Edit") { WorkoutPlanEditorView(plan: plan) }
            }
        }
    }

    private var planHeader: some View {
        NellFeaturedCard(tint: NellPalette.primary) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(plan.title)
                            .font(Theme.FontToken.navigationTitle)
                            .foregroundStyle(NellPalette.textPrimary)
                        if let goal = plan.goalText, !goal.isEmpty {
                            Text(goal)
                                .font(Theme.FontToken.secondaryBody)
                                .foregroundStyle(NellPalette.textSecondary)
                        }
                    }
                    Spacer()
                    NellStatusChip(
                        title: plan.source.displayName,
                        tone: plan.source == .assistant ? .informational : .neutral
                    )
                }

                HStack(spacing: Theme.Spacing.md) {
                    if let minutes = plan.estimatedDurationMinutes {
                        Label("\(minutes) min", systemImage: "clock")
                    }
                    if let effort = plan.targetEffort {
                        Label("Effort \(effort)/10", systemImage: "gauge.with.dots.needle.50percent")
                    }
                    if let location = plan.locationNameSnapshot {
                        Label(location, systemImage: "mappin")
                    }
                }
                .font(Theme.FontToken.caption)
                .foregroundStyle(NellPalette.textSecondary)
            }
        }
    }

    private func stepSummary(_ step: WorkoutStep) -> String {
        var parts: [String] = []
        if let sets = step.sets, let reps = step.reps { parts.append("\(sets) × \(reps)") }
        else if let sets = step.sets { parts.append("\(sets) sets") }
        else if let reps = step.reps { parts.append("\(reps) reps") }
        if let duration = step.durationSeconds { parts.append(durationLabel(duration)) }
        if let weight = step.targetWeightKilograms { parts.append("\(String(format: "%g", weight)) kg") }
        if let equipment = step.equipmentNameSnapshot { parts.append(equipment) }
        return parts.isEmpty ? step.type.displayName : parts.joined(separator: " · ")
    }

    private func durationLabel(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) sec" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return remainder == 0 ? "\(minutes) min" : "\(minutes)m \(remainder)s"
    }
}

struct NellExerciseDetailView: View {
    let step: WorkoutStep

    var body: some View {
        NellScreen {
            WorkoutMotionView(
                title: step.title,
                type: step.type,
                presentation: .hero,
                showsLabels: true
            )

            NellCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(step.title)
                        .font(Theme.FontToken.navigationTitle)
                        .foregroundStyle(NellPalette.textPrimary)
                    Text(step.type.displayName)
                        .font(Theme.FontToken.caption)
                        .foregroundStyle(NellPalette.primary)
                    Text(step.instruction?.isEmpty == false
                        ? step.instruction!
                        : "Follow the motion guide and use the plan's targets. Stop or adjust when the movement does not feel appropriate for you.")
                        .font(Theme.FontToken.secondaryBody)
                        .foregroundStyle(NellPalette.textSecondary)
                }
            }

            NellSectionHeader(title: "Planned target")
            NellCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) { detailRows }
            }

            NellCoachSuggestionCard(
                title: "Movement note",
                message: "This illustration is a general movement guide, not a diagnosis or a guarantee that the exercise is suitable for a specific injury."
            )
        }
        .navigationTitle(step.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var detailRows: some View {
        if let sets = step.sets { Label("\(sets) sets", systemImage: "repeat") }
        if let reps = step.reps { Label("\(reps) reps", systemImage: "number") }
        if let duration = step.durationSeconds { Label(durationLabel(duration), systemImage: "timer") }
        if let weight = step.targetWeightKilograms {
            Label("\(String(format: "%g", weight)) kg", systemImage: "scalemass")
        }
        if let rest = step.restSeconds { Label("Rest \(durationLabel(rest))", systemImage: "pause") }
        if step.side != .none { Label(step.side.displayName, systemImage: "arrow.left.and.right") }
        if let equipment = step.equipmentNameSnapshot { Label(equipment, systemImage: "dumbbell") }
    }

    private func durationLabel(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) sec" : "\(seconds / 60) min"
    }
}

#Preview {
    NavigationStack { NellWorkoutPlansView() }
        .modelContainer(PersistenceController.preview.container)
}

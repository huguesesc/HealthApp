import SwiftData
import SwiftUI

struct NellTrainHomeView: View {
    @Query(sort: \WorkoutPlan.updatedAt, order: .reverse) private var plans: [WorkoutPlan]
    @Query(sort: \ActiveWorkoutSession.updatedAt, order: .reverse) private var activeSessions: [ActiveWorkoutSession]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutHistory: [WorkoutSession]
    @Query(sort: \MovementFeedbackEntry.createdAt, order: .reverse) private var feedback: [MovementFeedbackEntry]

    var body: some View {
        NellScreen {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Train")
                    .font(Theme.FontToken.largeScreenTitle)
                    .foregroundStyle(NellPalette.textPrimary)

                Text("Plans, active workouts and movement feedback in one place.")
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)
            }

            if let session = resumableSession {
                activeSessionCard(session)
            } else if let plan = activePlans.first {
                nextPlanCard(plan)
            } else {
                NellEmptyState(
                    title: "No active workout plan",
                    message: "Create one manually or ask the Coach to draft a plan for review.",
                    systemImage: "list.clipboard"
                )
            }

            planSection
            trainingTools
            recentProgress
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: {
                    Image(systemName: "person.crop.circle")
                }
                .accessibilityLabel("Profile and settings")
            }
        }
    }

    private func activeSessionCard(_ session: ActiveWorkoutSession) -> some View {
        NavigationLink {
            NellActiveWorkoutContainerView(session: session)
        } label: {
            NellFeaturedCard(tint: NellPalette.training) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack {
                        NellStatusChip(
                            title: session.status.displayName,
                            tone: session.status == .paused ? .attention : .positive
                        )
                        Spacer()
                        Text("\(Int(session.progressFraction * 100))%")
                            .font(Theme.FontToken.metric)
                            .foregroundStyle(NellPalette.textPrimary)
                    }

                    HStack(spacing: Theme.Spacing.md) {
                        WorkoutMotionView(
                            title: session.currentStep?.title ?? session.titleSnapshot,
                            type: session.currentStep?.type,
                            presentation: .compact
                        )
                        .frame(width: 76)

                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(session.titleSnapshot)
                                .font(Theme.FontToken.navigationTitle)
                                .foregroundStyle(NellPalette.textPrimary)
                            Text(session.currentStep?.title ?? "Ready to finish")
                                .font(Theme.FontToken.secondaryBody)
                                .foregroundStyle(NellPalette.textSecondary)
                            Text("Saved progress · \(elapsedLabel(session.elapsedSeconds()))")
                                .font(Theme.FontToken.caption)
                                .foregroundStyle(NellPalette.textTertiary)
                        }
                        Spacer(minLength: 0)
                    }

                    Label("Continue Workout", systemImage: "play.fill")
                        .font(Theme.FontToken.button)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: NellLayout.primaryButtonHeight)
                        .background(
                            NellPalette.primary,
                            in: RoundedRectangle(cornerRadius: NellLayout.buttonRadius, style: .continuous)
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func nextPlanCard(_ plan: WorkoutPlan) -> some View {
        NellFeaturedCard(tint: NellPalette.primary) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Next Workout")
                            .font(Theme.FontToken.caption)
                            .foregroundStyle(NellPalette.primary)
                        Text(plan.title)
                            .font(Theme.FontToken.navigationTitle)
                            .foregroundStyle(NellPalette.textPrimary)
                    }
                    Spacer()
                    WorkoutMotionView(
                        title: plan.orderedSteps.first?.title ?? plan.title,
                        type: plan.orderedSteps.first?.type,
                        presentation: .compact
                    )
                    .frame(width: 72)
                }

                Text(planSummary(plan))
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)

                NavigationLink {
                    NellActiveWorkoutLauncherView(plan: plan)
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                }
                .buttonStyle(.nellPrimary)
            }
        }
    }

    @ViewBuilder
    private var planSection: some View {
        NellSectionHeader(title: "Your Plans")

        if activePlans.isEmpty {
            NavigationLink { NellWorkoutPlansView() } label: {
                NellCard {
                    HStack {
                        Label("Create or review plans", systemImage: "plus.circle")
                            .font(Theme.FontToken.cardTitle)
                            .foregroundStyle(NellPalette.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(NellPalette.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            NellCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(activePlans.prefix(3).enumerated()), id: \.offset) { index, plan in
                        NavigationLink { NellWorkoutPlanDetailView(plan: plan) } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                WorkoutMotionView(
                                    title: plan.orderedSteps.first?.title ?? plan.title,
                                    type: plan.orderedSteps.first?.type,
                                    presentation: .compact
                                )
                                .frame(width: 58)

                                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                    Text(plan.title)
                                        .font(Theme.FontToken.cardTitle)
                                        .foregroundStyle(NellPalette.textPrimary)
                                    Text(planSummary(plan))
                                        .font(Theme.FontToken.caption)
                                        .foregroundStyle(NellPalette.textSecondary)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(NellPalette.textTertiary)
                            }
                            .padding(Theme.Spacing.md)
                        }
                        .buttonStyle(.plain)

                        if index < min(activePlans.count, 3) - 1 {
                            Divider().padding(.leading, 74)
                        }
                    }

                    Divider()

                    NavigationLink { NellWorkoutPlansView() } label: {
                        HStack {
                            Text("See all plans")
                                .font(Theme.FontToken.button)
                                .foregroundStyle(NellPalette.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(NellPalette.primary)
                        }
                        .padding(Theme.Spacing.md)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var trainingTools: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(title: "Training Tools")
            NellCard(padding: 0) {
                VStack(spacing: 0) {
                    toolLink(
                        "Start or continue workout",
                        detail: "Choose a plan or resume a saved session.",
                        symbol: "figure.run.circle.fill",
                        tint: NellPalette.training
                    ) { NellWorkoutStartView() }
                    Divider().padding(.leading, 56)
                    toolLink(
                        "Workout history",
                        detail: "Completed manual and active sessions.",
                        symbol: "clock.arrow.circlepath",
                        tint: NellPalette.primary
                    ) { WorkoutLogView() }
                    Divider().padding(.leading, 56)
                    toolLink(
                        "Movement feedback",
                        detail: feedback.isEmpty
                            ? "No adjustments recorded yet."
                            : "\(feedback.count) user-reported adjustment(s).",
                        symbol: "slider.horizontal.3",
                        tint: NellPalette.amber
                    ) { MovementFeedbackHistoryView() }
                    Divider().padding(.leading, 56)
                    toolLink(
                        "Progress",
                        detail: "Review factual workout totals and recent activity.",
                        symbol: "chart.line.uptrend.xyaxis",
                        tint: NellPalette.nutrition
                    ) { NellProgressView() }
                }
            }
        }
    }

    private var recentProgress: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(title: "Recent Progress")
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Theme.Spacing.sm
            ) {
                NellMetricTile(
                    title: "Workouts",
                    value: "\(workoutsThisWeek)",
                    detail: "Completed this week",
                    systemImage: "checkmark.circle",
                    tint: NellPalette.primary
                )
                NellMetricTile(
                    title: "Duration",
                    value: durationThisWeekLabel,
                    detail: "Logged this week",
                    systemImage: "clock",
                    tint: NellPalette.nutrition
                )
            }

            NavigationLink { NellProgressView() } label: {
                NellCard {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(NellPalette.primary)
                        Text("View full progress")
                            .font(Theme.FontToken.button)
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

    private func toolLink<Destination: View>(
        _ title: String,
        detail: String,
        symbol: String,
        tint: Color,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink { destination() } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(title)
                        .font(Theme.FontToken.body)
                        .foregroundStyle(NellPalette.textPrimary)
                    Text(detail)
                        .font(Theme.FontToken.caption)
                        .foregroundStyle(NellPalette.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NellPalette.textTertiary)
            }
            .padding(Theme.Spacing.md)
        }
        .buttonStyle(.plain)
    }

    private var activePlans: [WorkoutPlan] {
        plans.filter { !$0.isArchived }
    }

    private var resumableSession: ActiveWorkoutSession? {
        activeSessions.first { $0.status == .inProgress || $0.status == .paused }
    }

    private var workoutsThisWeek: Int {
        workoutHistory.filter {
            Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .weekOfYear)
        }.count
    }

    private var durationThisWeekLabel: String {
        let total = workoutHistory
            .filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .weekOfYear) }
            .compactMap(\.durationMinutes)
            .reduce(0, +)
        return total == 0 ? "—" : "\(total) min"
    }

    private func planSummary(_ plan: WorkoutPlan) -> String {
        var parts = ["\(plan.orderedSteps.count) movements"]
        if let minutes = plan.estimatedDurationMinutes { parts.append("\(minutes) min") }
        if let target = plan.targetEffort { parts.append("effort \(target)/10") }
        return parts.joined(separator: " · ")
    }

    private func elapsedLabel(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }
}

#Preview {
    NavigationStack { NellTrainHomeView() }
        .modelContainer(PersistenceController.preview.container)
}

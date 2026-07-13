import SwiftData
import SwiftUI

struct NellWorkoutStartView: View {
    @Query(sort: \ActiveWorkoutSession.updatedAt, order: .reverse)
    private var sessions: [ActiveWorkoutSession]

    @Query(sort: \WorkoutPlan.updatedAt, order: .reverse)
    private var plans: [WorkoutPlan]

    var body: some View {
        NellScreen {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Start a Workout")
                    .font(Theme.FontToken.largeScreenTitle)
                    .foregroundStyle(NellPalette.textPrimary)

                Text("Resume saved progress or choose an editable workout plan.")
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)
            }

            if !resumable.isEmpty {
                NellSectionHeader(title: "Continue")
                ForEach(resumable, id: \.id) { session in
                    NavigationLink {
                        NellActiveWorkoutContainerView(session: session)
                    } label: {
                        NellFeaturedCard(tint: NellPalette.training) {
                            HStack(spacing: Theme.Spacing.md) {
                                WorkoutMotionView(
                                    title: session.currentStep?.title ?? session.titleSnapshot,
                                    type: session.currentStep?.type,
                                    presentation: .compact
                                )
                                .frame(width: 64)

                                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                    NellStatusChip(
                                        title: session.status.displayName,
                                        tone: session.status == .paused ? .attention : .positive
                                    )
                                    Text(session.titleSnapshot)
                                        .font(Theme.FontToken.cardTitle)
                                        .foregroundStyle(NellPalette.textPrimary)
                                    Text("\(Int(session.progressFraction * 100))% complete")
                                        .font(Theme.FontToken.caption)
                                        .foregroundStyle(NellPalette.textSecondary)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(NellPalette.textTertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            NellSectionHeader(title: "Plans")

            if activePlans.isEmpty {
                NellEmptyState(
                    title: "No workout plans",
                    message: "Create a plan manually or ask the Coach to prepare an editable draft.",
                    systemImage: "list.clipboard"
                )
            } else {
                NellCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(activePlans.enumerated()), id: \.offset) { index, plan in
                            NavigationLink {
                                NellActiveWorkoutLauncherView(plan: plan)
                            } label: {
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
                                    Image(systemName: "play.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(NellPalette.primary)
                                }
                                .padding(Theme.Spacing.md)
                            }
                            .buttonStyle(.plain)

                            if index < activePlans.count - 1 {
                                Divider().padding(.leading, 74)
                            }
                        }
                    }
                }
            }

            NellSectionHeader(
                title: "Execution History",
                subtitle: "Review saved progress, interruptions and completed workout executions."
            )

            NavigationLink {
                NellWorkoutExecutionHistoryView()
            } label: {
                NellCard {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundStyle(NellPalette.primary)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text("View execution history")
                                .font(Theme.FontToken.cardTitle)
                                .foregroundStyle(NellPalette.textPrimary)
                            Text(historyDetail)
                                .font(Theme.FontToken.caption)
                                .foregroundStyle(NellPalette.textSecondary)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(NellPalette.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var resumable: [ActiveWorkoutSession] {
        sessions.filter { $0.status == .inProgress || $0.status == .paused }
    }

    private var activePlans: [WorkoutPlan] {
        plans.filter { !$0.isArchived && !$0.orderedSteps.isEmpty }
    }

    private var historyDetail: String {
        let finishedCount = sessions.filter {
            $0.status == .completed || $0.status == .abandoned
        }.count
        return sessions.isEmpty
            ? "No saved executions yet."
            : "\(resumable.count) resumable · \(finishedCount) finished"
    }

    private func planSummary(_ plan: WorkoutPlan) -> String {
        var parts = ["\(plan.orderedSteps.count) movements"]
        if let minutes = plan.estimatedDurationMinutes { parts.append("\(minutes) min") }
        if let location = plan.locationNameSnapshot { parts.append(location) }
        return parts.joined(separator: " · ")
    }
}

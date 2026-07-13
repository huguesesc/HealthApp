import SwiftData
import SwiftUI

struct NellWorkoutExecutionHistoryView: View {
    @Query(sort: \ActiveWorkoutSession.updatedAt, order: .reverse)
    private var sessions: [ActiveWorkoutSession]

    var body: some View {
        NellScreen {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Execution History")
                    .font(Theme.FontToken.largeScreenTitle)
                    .foregroundStyle(NellPalette.textPrimary)

                Text("Saved active-workout sessions, including interruptions and completed executions.")
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)
            }

            if sessions.isEmpty {
                NellEmptyState(
                    title: "No workout executions yet",
                    message: "Start a saved workout plan to create durable progress and interruption history.",
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                if !resumable.isEmpty {
                    NellSectionHeader(
                        title: "Continue",
                        subtitle: "Progress and timers are restored from saved timestamps."
                    )

                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(resumable, id: \.id) { session in
                            NavigationLink {
                                NellActiveWorkoutContainerView(session: session)
                            } label: {
                                executionRow(session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !finished.isEmpty {
                    NellSectionHeader(
                        title: "Recent",
                        subtitle: "Completed and ended-early workout executions."
                    )

                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(finished.prefix(30), id: \.id) { session in
                            NavigationLink {
                                NellWorkoutExecutionSummaryView(session: session)
                            } label: {
                                executionRow(session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Execution History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var resumable: [ActiveWorkoutSession] {
        sessions.filter { $0.status == .inProgress || $0.status == .paused }
    }

    private var finished: [ActiveWorkoutSession] {
        sessions.filter { $0.status == .completed || $0.status == .abandoned }
    }

    private func executionRow(_ session: ActiveWorkoutSession) -> some View {
        NellCard {
            HStack(spacing: Theme.Spacing.md) {
                WorkoutMotionView(
                    title: session.currentStep?.title ?? session.titleSnapshot,
                    type: session.currentStep?.type,
                    presentation: .compact
                )
                .frame(width: 62)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    NellStatusChip(
                        title: session.status.displayName,
                        tone: statusTone(session.status)
                    )

                    Text(session.titleSnapshot)
                        .font(Theme.FontToken.cardTitle)
                        .foregroundStyle(NellPalette.textPrimary)
                        .lineLimit(2)

                    Text(rowDetail(session))
                        .font(Theme.FontToken.caption)
                        .foregroundStyle(NellPalette.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NellPalette.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func rowDetail(_ session: ActiveWorkoutSession) -> String {
        var parts = [elapsedLabel(session.elapsedSeconds(at: session.completedAt ?? .now))]
        parts.append("\(Int(session.progressFraction * 100))% resolved")
        if let location = session.locationNameSnapshot { parts.append(location) }
        return parts.joined(separator: " · ")
    }

    private func statusTone(_ status: ActiveWorkoutStatus) -> NellStatusTone {
        switch status {
        case .inProgress: return .informational
        case .paused: return .attention
        case .completed: return .positive
        case .abandoned: return .neutral
        }
    }
}

struct NellWorkoutExecutionSummaryView: View {
    let session: ActiveWorkoutSession

    var body: some View {
        NellScreen {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                NellStatusChip(
                    title: session.status.displayName,
                    tone: session.status == .completed ? .positive : .neutral
                )

                Text(session.titleSnapshot)
                    .font(Theme.FontToken.largeScreenTitle)
                    .foregroundStyle(NellPalette.textPrimary)

                Text(session.startedAt, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Theme.Spacing.sm
            ) {
                NellMetricTile(
                    title: "Duration",
                    value: elapsedLabel(session.elapsedSeconds(at: session.completedAt ?? .now)),
                    detail: "Recorded active time",
                    systemImage: "clock",
                    tint: NellPalette.primary
                )

                NellMetricTile(
                    title: "Completed",
                    value: "\(completedCount)",
                    detail: "Workout steps",
                    systemImage: "checkmark.circle",
                    tint: NellPalette.nutrition
                )

                NellMetricTile(
                    title: "Skipped",
                    value: "\(skippedCount)",
                    detail: "Workout steps",
                    systemImage: "forward.end.circle",
                    tint: NellPalette.warning
                )

                NellMetricTile(
                    title: "Effort",
                    value: session.actualEffort.map { "\($0)/10" } ?? "—",
                    detail: session.actualEffort == nil ? "Not recorded" : "Self-reported",
                    systemImage: "gauge.with.dots.needle.50percent",
                    tint: NellPalette.training
                )
            }

            if let location = session.locationNameSnapshot {
                NellCard {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(Theme.FontToken.body)
                        .foregroundStyle(NellPalette.textPrimary)
                }
            }

            if let notes = session.notes, !notes.trimmed.isEmpty {
                NellSectionHeader(title: "Notes")
                NellCard {
                    Text(notes)
                        .font(Theme.FontToken.body)
                        .foregroundStyle(NellPalette.textPrimary)
                }
            }

            NellCoachSuggestionCard(
                title: "Stored record",
                message: session.status == .completed
                    ? "This execution was converted into the workout record used by Today and Progress."
                    : "This execution ended early and remains available for factual history without creating a completed workout record."
            )
        }
        .navigationTitle("Workout Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var completedCount: Int {
        session.steps.filter { $0.status == .completed }.count
    }

    private var skippedCount: Int {
        session.steps.filter { $0.status == .skipped }.count
    }
}

private func elapsedLabel(_ seconds: Int) -> String {
    let safe = max(seconds, 0)
    let hours = safe / 3_600
    let minutes = (safe % 3_600) / 60
    let remainingSeconds = safe % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
    }
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}

#Preview {
    NavigationStack { NellWorkoutExecutionHistoryView() }
        .modelContainer(PersistenceController.preview.container)
}

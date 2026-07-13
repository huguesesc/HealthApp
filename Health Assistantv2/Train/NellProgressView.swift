import SwiftData
import SwiftUI

/// Progress derived only from completed workout records already stored on device.
struct NellProgressView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse)
    private var sessions: [WorkoutSession]

    private var currentWeek: [WorkoutSession] {
        sessions.filter { currentWeekInterval?.contains($0.date) == true }
    }

    private var previousWeek: [WorkoutSession] {
        sessions.filter { previousWeekInterval?.contains($0.date) == true }
    }

    private var currentWeekInterval: DateInterval? {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now)
    }

    private var previousWeekInterval: DateInterval? {
        guard let currentWeekInterval,
              let start = Calendar.current.date(byAdding: .day, value: -7, to: currentWeekInterval.start) else {
            return nil
        }
        return DateInterval(start: start, end: currentWeekInterval.start)
    }

    var body: some View {
        NellScreen {
            ProgressHeader()

            if sessions.isEmpty {
                NellEmptyState(
                    title: "No workout progress yet",
                    message: "Completed and manually logged workouts will appear here.",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
            } else {
                WeeklySummarySection(
                    workoutCount: currentWeek.count,
                    durationMinutes: currentWeekDuration,
                    setCount: currentWeekSetCount,
                    volumeKilograms: currentWeekVolume,
                    comparisonText: comparisonText
                )

                ActivityTrendSection(values: recentDailyCounts)

                RecentWorkoutSection(sessions: Array(sessions.prefix(8)))

                NellCoachSuggestionCard(
                    title: "What this progress means",
                    message: "These figures summarize saved workouts only. Nell does not infer readiness, recovery, or health status from missing data."
                )
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentWeekDuration: Int {
        currentWeek.compactMap(\.durationMinutes).reduce(0, +)
    }

    private var currentWeekSetCount: Int {
        currentWeek.reduce(0) { $0 + $1.sets.count }
    }

    private var currentWeekVolume: Double? {
        let weightedSets = currentWeek
            .flatMap(\.sets)
            .compactMap { set -> Double? in
                guard let weight = set.weightKilograms else { return nil }
                return weight * Double(set.reps)
            }

        guard !weightedSets.isEmpty else { return nil }
        return weightedSets.reduce(0, +)
    }

    private var comparisonText: String {
        let difference = currentWeek.count - previousWeek.count
        switch difference {
        case 1...:
            return "+\(difference) workout\(difference == 1 ? "" : "s") versus last week"
        case ..<0:
            let magnitude = abs(difference)
            return "\(magnitude) fewer workout\(magnitude == 1 ? "" : "s") than last week"
        default:
            return "Same number of workouts as last week"
        }
    }

    private var recentDailyCounts: [Double] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)

        return (0..<7).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else {
                return 0
            }
            return Double(sessions.filter { calendar.isDate($0.date, inSameDayAs: day) }.count)
        }
    }
}

private struct ProgressHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Progress")
                .font(Theme.FontToken.largeScreenTitle)
                .foregroundStyle(NellPalette.textPrimary)

            Text("A factual view of the workouts recorded on this device.")
                .font(Theme.FontToken.secondaryBody)
                .foregroundStyle(NellPalette.textSecondary)
        }
    }
}

private struct WeeklySummarySection: View {
    let workoutCount: Int
    let durationMinutes: Int
    let setCount: Int
    let volumeKilograms: Double?
    let comparisonText: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(title: "This Week", subtitle: comparisonText)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Theme.Spacing.sm
            ) {
                NellMetricTile(
                    title: "Workouts",
                    value: "\(workoutCount)",
                    detail: "Completed or manually logged",
                    systemImage: "checkmark.circle",
                    tint: NellPalette.primary
                )

                NellMetricTile(
                    title: "Duration",
                    value: durationMinutes > 0 ? "\(durationMinutes) min" : "—",
                    detail: durationMinutes > 0 ? "Recorded duration" : "No duration recorded",
                    systemImage: "clock",
                    tint: NellPalette.nutrition
                )

                NellMetricTile(
                    title: "Sets",
                    value: "\(setCount)",
                    detail: "Exercise sets recorded",
                    systemImage: "list.number",
                    tint: NellPalette.training
                )

                NellMetricTile(
                    title: "Volume",
                    value: volumeText,
                    detail: volumeKilograms == nil ? "No weighted sets recorded" : "Reps × recorded load",
                    systemImage: "scalemass",
                    tint: NellPalette.amber
                )
            }
        }
    }

    private var volumeText: String {
        guard let volumeKilograms else { return "—" }
        return volumeKilograms.formatted(.number.precision(.fractionLength(0))) + " kg"
    }
}

private struct ActivityTrendSection: View {
    let values: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(
                title: "Last 7 Days",
                subtitle: "Number of recorded workouts per day"
            )

            NellCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    NellMiniBarChart(values: values, tint: NellPalette.primary)

                    HStack {
                        Text("7 days ago")
                        Spacer()
                        Text("Today")
                    }
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textTertiary)
                }
            }
        }
    }
}

private struct RecentWorkoutSection: View {
    let sessions: [WorkoutSession]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(title: "Recent Workouts")

            NellCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                        RecentWorkoutRow(session: session)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)

                        if index < sessions.count - 1 {
                            Divider().padding(.leading, Theme.Spacing.md)
                        }
                    }
                }
            }
        }
    }
}

private struct RecentWorkoutRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "figure.strengthtraining.traditional")
                .foregroundStyle(NellPalette.training)
                .frame(width: 36, height: 36)
                .background(NellPalette.training.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(session.type)
                    .font(Theme.FontToken.cardTitle)
                    .foregroundStyle(NellPalette.textPrimary)

                Text(detailText)
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textSecondary)
            }

            Spacer(minLength: Theme.Spacing.xs)

            Text(session.date, format: .dateTime.month(.abbreviated).day())
                .font(Theme.FontToken.caption)
                .foregroundStyle(NellPalette.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }

    private var detailText: String {
        var parts = ["\(session.sets.count) set\(session.sets.count == 1 ? "" : "s")"]
        if let duration = session.durationMinutes {
            parts.append("\(duration) min")
        }
        if let effort = session.perceivedEffort {
            parts.append("effort \(effort)/10")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack { NellProgressView() }
        .modelContainer(PersistenceController.preview.container)
}

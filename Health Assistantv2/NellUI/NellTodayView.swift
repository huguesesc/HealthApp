import SwiftData
import SwiftUI

struct NellTodayView: View {
    @Query(sort: \DailyRollup.date, order: .reverse)
    private var rollups: [DailyRollup]

    private var today: DailyRollup? {
        rollups.first(where: { Calendar.current.isDateInToday($0.date) })
    }

    var body: some View {
        NellScreen {
            header
            welcomeCard
            overview
            checkInCard
            coachObservation
            recentActivity
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "person.crop.circle")
                        .accessibilityLabel("Profile and settings")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text("Today")
                .font(Theme.FontToken.largeScreenTitle)
                .foregroundStyle(NellPalette.textPrimary)
            Text(Date.now.formatted(date: .complete, time: .omitted))
                .font(Theme.FontToken.secondaryBody)
                .foregroundStyle(NellPalette.textSecondary)
        }
    }

    private var welcomeCard: some View {
        NellFeaturedCard(tint: NellPalette.primary) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(greeting)
                        .font(Theme.FontToken.sectionTitle)
                        .foregroundStyle(NellPalette.textPrimary)
                    Text(welcomeMessage)
                        .font(Theme.FontToken.secondaryBody)
                        .foregroundStyle(NellPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Theme.Spacing.sm)

                NellMascotView(pose: .wave)
                    .frame(width: 86, height: 86)
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(
                title: "Daily overview",
                subtitle: today == nil ? "Nothing has been logged yet today." : nil
            )

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Theme.Spacing.sm
            ) {
                NellMetricTile(
                    title: "Steps",
                    value: stepCount.formatted(),
                    detail: stepCount > 0 ? "From Apple Health" : "No data yet",
                    systemImage: "figure.walk",
                    tint: NellPalette.primary
                )

                NellMetricTile(
                    title: "Sleep",
                    value: sleepText,
                    detail: sleepHours == nil ? "No sleep data" : "Last recorded night",
                    systemImage: "moon.fill",
                    tint: NellPalette.sleep
                )

                NellMetricTile(
                    title: "Meals",
                    value: "\(today?.mealsLogged ?? 0)",
                    detail: calorieDetail,
                    systemImage: "fork.knife",
                    tint: NellPalette.nutrition
                )

                NellMetricTile(
                    title: "Training",
                    value: today?.workoutCompleted == true ? "Done" : "Not yet",
                    detail: today?.workoutType,
                    systemImage: "dumbbell.fill",
                    tint: NellPalette.training
                )
            }
        }
    }

    private var checkInCard: some View {
        NavigationLink {
            CheckInView()
        } label: {
            NellCard {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(NellPalette.primary)
                        .frame(width: 48, height: 48)
                        .background(NellPalette.primary.opacity(0.10), in: Circle())

                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Quick check-in")
                            .font(Theme.FontToken.cardTitle)
                            .foregroundStyle(NellPalette.textPrimary)
                        Text("Record how you feel, your energy and your day so far.")
                            .font(Theme.FontToken.secondaryBody)
                            .foregroundStyle(NellPalette.textSecondary)
                    }

                    Spacer(minLength: Theme.Spacing.xs)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(NellPalette.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var coachObservation: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(title: "Coach observation")
            NellCoachSuggestionCard(
                title: observationTitle,
                message: observationMessage
            )
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(title: "Recent activity")

            if recentDays.isEmpty {
                NellEmptyState(
                    title: "No recent activity",
                    message: "Your meals, workouts, sleep and check-ins will appear here.",
                    systemImage: "calendar"
                )
            } else {
                NellCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(recentDays.enumerated()), id: \.element.date) { index, rollup in
                            HStack(spacing: Theme.Spacing.sm) {
                                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                    Text(rollup.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(Theme.FontToken.body.weight(.semibold))
                                        .foregroundStyle(NellPalette.textPrimary)
                                    Text(activitySummary(for: rollup))
                                        .font(Theme.FontToken.caption)
                                        .foregroundStyle(NellPalette.textSecondary)
                                }
                                Spacer()
                                if rollup.workoutCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(NellPalette.training)
                                        .accessibilityLabel("Workout completed")
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)

                            if index < recentDays.count - 1 {
                                Divider().padding(.leading, Theme.Spacing.md)
                            }
                        }
                    }
                }
            }
        }
    }

    private var recentDays: [DailyRollup] {
        Array(rollups.filter { !Calendar.current.isDateInToday($0.date) }.prefix(4))
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date.now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var welcomeMessage: String {
        if today?.workoutCompleted == true {
            return "Your workout is logged. Keep the rest of the day steady."
        }
        if (today?.mealsLogged ?? 0) == 0 {
            return "Start with one useful log or a quick check-in."
        }
        return "Your day is taking shape. Small, consistent actions are enough."
    }

    private var stepCount: Int {
        today?.healthStepCount ?? 0
    }

    private var sleepHours: Double? {
        today?.sleepHours ?? today?.healthSleepHours
    }

    private var sleepText: String {
        guard let sleepHours else { return "—" }
        return sleepHours.formatted(.number.precision(.fractionLength(1))) + " h"
    }

    private var calorieDetail: String {
        let calories = today?.totalCalories ?? 0
        return calories > 0 ? "\(calories.formatted()) kcal logged" : "No calories logged"
    }

    private var observationTitle: String {
        if today?.workoutCompleted == true { return "Training complete" }
        if stepCount > 0 { return "Movement is underway" }
        return "Choose one small next step"
    }

    private var observationMessage: String {
        if today?.workoutCompleted == true {
            return "Consider recording how the session felt while it is still fresh."
        }
        if stepCount > 0 {
            return "Your activity is already contributing to today's movement."
        }
        return "A short walk, a meal log, or a check-in is enough to begin."
    }

    private func activitySummary(for rollup: DailyRollup) -> String {
        var parts: [String] = []
        if rollup.mealsLogged > 0 {
            parts.append("\(rollup.mealsLogged) meal\(rollup.mealsLogged == 1 ? "" : "s")")
        }
        if rollup.workoutCompleted {
            parts.append(rollup.workoutType ?? "workout")
        }
        if let sleep = rollup.sleepHours ?? rollup.healthSleepHours {
            parts.append("\(sleep.formatted(.number.precision(.fractionLength(1)))) h sleep")
        }
        return parts.isEmpty ? "No detailed entries" : parts.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack {
        NellTodayView()
    }
    .modelContainer(PersistenceController.preview.container)
}

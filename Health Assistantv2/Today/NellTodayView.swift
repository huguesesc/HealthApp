import SwiftData
import SwiftUI

struct NellTodayView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Meal.timestamp, order: .reverse) private var meals: [Meal]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workouts: [WorkoutSession]
    @Query(sort: \SleepEntry.date, order: .reverse) private var sleeps: [SleepEntry]
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query(sort: \DailyRollup.date, order: .reverse) private var rollups: [DailyRollup]
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var events: [ActivityEvent]
    @Query(sort: \ActiveWorkoutSession.updatedAt, order: .reverse) private var activeSessions: [ActiveWorkoutSession]

    private let rewards = RewardsEngine()
    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    var body: some View {
        NellScreen {
            greetingHeader

            if let session = resumableSession {
                resumeCard(session)
            }

            dailyOverview
            quickCheckIn

            NellCoachSuggestionCard(
                title: "Nell's observation",
                message: observationText
            )

            insightCard
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: {
                    Image(systemName: "person.crop.circle")
                }
                .accessibilityLabel("Profile and settings")
            }
        }
        .onAppear { _ = repo.refreshTodayRollup() }
    }

    private var greetingHeader: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("\(greeting), Hugues")
                    .font(Theme.FontToken.largeScreenTitle)
                    .foregroundStyle(NellPalette.textPrimary)

                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)

                Text(todayHeadline)
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.primary)
            }

            Spacer(minLength: Theme.Spacing.xs)

            NellMascotView(pose: .wave)
                .frame(width: 92, height: 92)
        }
        .accessibilityElement(children: .combine)
    }

    private var dailyOverview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(
                title: "Daily Overview",
                subtitle: "Only values available from your logs and Apple Health are shown."
            )

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Theme.Spacing.sm
            ) {
                NellMetricTile(
                    title: "Energy",
                    value: energyValue,
                    detail: checkInToday == nil ? "Not checked in" : "Self-reported today",
                    systemImage: "bolt.heart",
                    tint: NellPalette.primary
                )
                NellMetricTile(
                    title: "Sleep",
                    value: sleepValue,
                    detail: sleepDetail,
                    systemImage: "moon.fill",
                    tint: NellPalette.sleep
                )
                NellMetricTile(
                    title: "Steps",
                    value: stepsValue,
                    detail: todayRollup?.healthStepCount == nil ? "Apple Health not synced" : "Today",
                    systemImage: "figure.walk",
                    tint: NellPalette.nutrition
                )
                NellMetricTile(
                    title: "Meals",
                    value: "\(mealsToday.count)",
                    detail: caloriesToday.map { "\($0) kcal logged" } ?? "No calorie total",
                    systemImage: "fork.knife",
                    tint: NellPalette.amber
                )
            }
        }
    }

    private var quickCheckIn: some View {
        NavigationLink { CheckInView() } label: {
            NellCard {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: checkInToday == nil ? "face.smiling" : "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(checkInToday == nil ? NellPalette.primary : NellPalette.nutrition)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(checkInToday == nil ? "Quick check-in" : "Today's check-in")
                            .font(Theme.FontToken.cardTitle)
                            .foregroundStyle(NellPalette.textPrimary)
                        Text(checkInSummary)
                            .font(Theme.FontToken.secondaryBody)
                            .foregroundStyle(NellPalette.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NellPalette.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var insightCard: some View {
        let streak = rewards.headlineStreak(in: events)
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(title: "Insights")

            NellCard {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    Image(systemName: streak > 0 ? "flame.fill" : "leaf.fill")
                        .font(.title2)
                        .foregroundStyle(streak > 0 ? NellPalette.amber : NellPalette.primary)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(streakTitle(streak))
                            .font(Theme.FontToken.cardTitle)
                            .foregroundStyle(NellPalette.textPrimary)
                        Text(todayRollup?.summaryText ?? fallbackInsight)
                            .font(Theme.FontToken.secondaryBody)
                            .foregroundStyle(NellPalette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func resumeCard(_ session: ActiveWorkoutSession) -> some View {
        NavigationLink { NellActiveWorkoutContainerView(session: session) } label: {
            NellFeaturedCard(tint: NellPalette.training) {
                HStack(spacing: Theme.Spacing.md) {
                    WorkoutMotionView(
                        title: session.currentStep?.title ?? session.titleSnapshot,
                        type: session.currentStep?.type,
                        presentation: .compact
                    )
                    .frame(width: 66)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        NellStatusChip(
                            title: session.status.displayName,
                            tone: session.status == .paused ? .attention : .positive
                        )
                        Text(session.titleSnapshot)
                            .font(Theme.FontToken.cardTitle)
                            .foregroundStyle(NellPalette.textPrimary)
                        Text("\(Int(session.progressFraction * 100))% complete · \(elapsedLabel(session.elapsedSeconds()))")
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

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var todayHeadline: String {
        if resumableSession != nil { return "Your workout is ready to continue." }
        if checkInToday == nil { return "A short check-in can help Nell understand today." }
        return "Small, consistent actions are enough."
    }

    private var mealsToday: [Meal] {
        meals.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var workoutsToday: [WorkoutSession] {
        workouts.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var checkInToday: DailyCheckIn? {
        checkIns.first { Calendar.current.isDateInToday($0.date) }
    }

    private var todayRollup: DailyRollup? {
        rollups.first { Calendar.current.isDateInToday($0.date) }
    }

    private var resumableSession: ActiveWorkoutSession? {
        activeSessions.first { $0.status == .inProgress || $0.status == .paused }
    }

    private var caloriesToday: Int? {
        let values = mealsToday.compactMap(\.calories)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    private var energyValue: String {
        guard let energy = checkInToday?.energy else { return "—" }
        return "\(energy)/5"
    }

    private var sleepValue: String {
        if let healthSleep = todayRollup?.healthSleepHours {
            return String(format: "%.1f h", healthSleep)
        }
        guard let sleep = sleeps.first else { return "—" }
        if let bedtime = sleep.bedtime, let wake = sleep.wakeTime {
            let hours = wake.timeIntervalSince(bedtime) / 3600
            if hours > 0 { return String(format: "%.1f h", hours) }
        }
        if let quality = sleep.perceivedQuality { return "\(quality)/5" }
        return "Logged"
    }

    private var sleepDetail: String {
        if todayRollup?.healthSleepHours != nil { return "Apple Health summary" }
        return sleeps.isEmpty ? "No recent entry" : "Most recent log"
    }

    private var stepsValue: String {
        guard let steps = todayRollup?.healthStepCount else { return "—" }
        return steps.formatted(.number.grouping(.automatic))
    }

    private var checkInSummary: String {
        guard let checkInToday else {
            return "Record energy, mood, soreness, focus and stress."
        }
        var parts: [String] = []
        if let energy = checkInToday.energy { parts.append("Energy \(energy)/5") }
        if let mood = checkInToday.mood { parts.append("Mood \(mood)/5") }
        if let stress = checkInToday.stress { parts.append("Stress \(stress)/5") }
        return parts.isEmpty ? "Saved for today." : parts.joined(separator: " · ")
    }

    private var observationText: String {
        if let session = resumableSession {
            return "You have \(session.titleSnapshot) in progress. Continue from the saved step when you are ready."
        }
        if checkInToday == nil {
            return "There is no check-in for today yet. A quick self-report gives the Coach better context without making a diagnosis."
        }
        if workoutsToday.isEmpty, (todayRollup?.healthExerciseMinutes ?? 0) == 0 {
            return "No workout or Apple Health exercise minutes are recorded today. Rest may be appropriate, or you can choose a short session in Train."
        }
        if mealsToday.isEmpty {
            return "No meals are logged today. Logging is optional, but it helps the nutrition overview reflect what actually happened."
        }
        return "Today already contains useful context from your logs. Ask the Coach to review it or help plan the next small step."
    }

    private var fallbackInsight: String {
        if let workout = workoutsToday.first {
            return "\(workout.type) is recorded for today. Your history and streak have been updated locally."
        }
        if let note = checkInToday?.note, !note.isEmpty { return note }
        return "Complete a check-in, meal log, sleep entry or workout to create a more useful daily picture."
    }

    private func streakTitle(_ streak: Int) -> String {
        switch streak {
        case 0: return "No current logging streak"
        case 1: return "1 day streak"
        default: return "\(streak) day streak"
        }
    }

    private func elapsedLabel(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }
}

#Preview {
    NavigationStack { NellTodayView() }
        .modelContainer(PersistenceController.preview.container)
}

import SwiftData
import SwiftUI

/// Home screen. Shows today's status across modules, the current streak, the latest
/// daily rollup summary, and entry points into every module. Reads are live via
/// `@Query`; the rollup is refreshed through the repository on appear.
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Meal.timestamp, order: .reverse) private var meals: [Meal]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workouts: [WorkoutSession]
    @Query(sort: \SleepEntry.date, order: .reverse) private var sleeps: [SleepEntry]
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var events: [ActivityEvent]
    @Query(sort: \DailyRollup.date, order: .reverse) private var rollups: [DailyRollup]

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }
    private let rewards = RewardsEngine()

    var body: some View {
        List {
            Section("Today") {
                labeledRow("Meals logged", "\(mealsToday.count)")
                labeledRow("Workout", workoutsToday.first?.type ?? "Not yet")
                labeledRow("Last sleep", lastSleepText)
            }

            Section("Streak") {
                Label("\(rewards.headlineStreak(in: events)) day streak", systemImage: "flame")
                Text("Rewards & streak protection arrive later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Daily summary") {
                Text(rollups.first?.summaryText ?? "No summary yet — AI summary comes in M2.")
                    .foregroundStyle(rollups.first?.summaryText == nil ? .secondary : .primary)
            }

            Section("Log & explore") {
                NavigationLink("Nutrition") { MealEntryView() }
                NavigationLink("Workout") { WorkoutLogView() }
                NavigationLink("Sleep") { SleepEntryView() }
                NavigationLink("Daily check-in") { CheckInView() }
                NavigationLink("Screen Time / habits") { ScreenTimeView() }
            }
        }
        .navigationTitle("Today")
        .onAppear { repo.refreshTodayRollup() }
    }

    // MARK: - Derived

    private var mealsToday: [Meal] {
        meals.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var workoutsToday: [WorkoutSession] {
        workouts.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var lastSleepText: String {
        guard let sleep = sleeps.first else { return "None" }
        if let bedtime = sleep.bedtime, let wake = sleep.wakeTime {
            let hours = wake.timeIntervalSince(bedtime) / 3600
            if hours > 0 { return String(format: "%.1f h", hours) }
        }
        if let quality = sleep.perceivedQuality { return "quality \(quality)/5" }
        return "logged"
    }

    private func labeledRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { DashboardView() }
        .modelContainer(PersistenceController.preview.container)
}

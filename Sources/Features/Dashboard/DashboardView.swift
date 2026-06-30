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

    @State private var isGenerating = false
    @State private var errorMessage: String?

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
                Text(rollups.first?.summaryText ?? "No summary yet — tap Generate to create one.")
                    .foregroundStyle(rollups.first?.summaryText == nil ? .secondary : .primary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    generateSummary()
                } label: {
                    if isGenerating {
                        HStack {
                            ProgressView()
                            Text("Generating…")
                        }
                    } else {
                        Label("Generate summary", systemImage: "sparkles")
                    }
                }
                .disabled(isGenerating)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
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

    // MARK: - AI summary

    private func generateSummary() {
        errorMessage = nil
        guard let key = APIKeyStore.read(), !key.isEmpty else {
            errorMessage = "Add your Claude API key in Settings first."
            return
        }
        isGenerating = true
        Task { @MainActor in
            do {
                let context = repo.todayContext()
                let result = try await AIClientFactory.makeDefault().summarizeDay(context)
                repo.saveTodaySummary(result)
            } catch {
                errorMessage = Self.describe(error)
            }
            isGenerating = false
        }
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case AIClientError.missingAPIKey:
            return "No API key found. Add one in Settings."
        case let AIClientError.badResponse(statusCode, _):
            return statusCode == 401
                ? "API key was rejected (401). Re-check it in Settings."
                : "The AI service returned an error (\(statusCode))."
        default:
            return "Couldn't generate a summary. Check your connection and try again."
        }
    }
}

#Preview {
    NavigationStack { DashboardView() }
        .modelContainer(PersistenceController.preview.container)
}

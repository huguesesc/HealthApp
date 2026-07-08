import SwiftData
import SwiftUI

/// Home screen. The assistant is the front door; below it, today's status across
/// modules, the streak, the AI daily summary, and entry points into every module.
/// Reads are live via `@Query`; the rollup is refreshed through the repository on
/// appear.
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

    private var hasKey: Bool { APIKeyStore.read()?.isEmpty == false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                assistantCard

                if !hasKey {
                    setupCard
                }

                todayRow

                healthCard

                streakCard

                summaryCard

                modulesCard
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
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

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greeting)
                .font(.title2.weight(.semibold))
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var assistantCard: some View {
        NavigationLink {
            ChatView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white.opacity(0.9))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Assistant")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Log a meal or workout in plain words, or ask about your week.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.evergreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var setupCard: some View {
        NavigationLink {
            SettingsView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .foregroundStyle(Theme.honey)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect the assistant")
                        .font(.subheadline.weight(.semibold))
                    Text("Add your Claude API key once in Settings — everything else works offline.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var todayRow: some View {
        HStack(spacing: 10) {
            statTile(
                value: "\(mealsToday.count)",
                label: "meals",
                detail: caloriesToday.map { "~\($0) kcal" },
                icon: "fork.knife",
                color: Theme.moss
            )
            statTile(
                value: workoutsToday.isEmpty ? "—" : workoutsToday.first!.type,
                label: "workout",
                detail: nil,
                icon: "figure.run",
                color: Theme.evergreen
            )
            statTile(
                value: lastSleepValue,
                label: "sleep",
                detail: nil,
                icon: "moon.zzz",
                color: Theme.clay
            )
        }
    }

    @ViewBuilder
    private var healthCard: some View {
        if !healthParts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Apple Health", systemImage: "heart.text.square")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.moss)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                    ForEach(healthParts, id: \.self) { part in
                        Text(part)
                            .font(.footnote.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(
                                Color(.tertiarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                }
            }
            .card()
        }
    }

    private func statTile(value: String, label: String, detail: String?,
                          icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(color)
            Text(value)
                .font(Theme.statFont(size: 20))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail ?? label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private var streakCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title3)
                .foregroundStyle(Theme.clay)
            VStack(alignment: .leading, spacing: 2) {
                Text(streakText)
                    .font(.subheadline.weight(.semibold))
                Text("Log anything today to keep it going.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .card()
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Daily summary", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.moss)

            Text(rollups.first?.summaryText
                 ?? "No summary yet — generate one from today's meals, workout, sleep and check-in.")
                .font(.subheadline)
                .foregroundStyle(rollups.first?.summaryText == nil ? .secondary : .primary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.clay)
            }

            Button {
                generateSummary()
            } label: {
                if isGenerating {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Generating…")
                    }
                } else {
                    Label(rollups.first?.summaryText == nil ? "Generate summary" : "Regenerate",
                          systemImage: "sparkles")
                }
            }
            .buttonStyle(.bordered)
            .tint(Theme.evergreen)
            .disabled(isGenerating)
        }
        .card()
    }

    private var modulesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            moduleLink("Nutrition", icon: "fork.knife", color: Theme.moss) { MealEntryView() }
            Divider().padding(.leading, 40)
            moduleLink("Workout", icon: "figure.run", color: Theme.evergreen) { WorkoutLogView() }
            Divider().padding(.leading, 40)
            moduleLink("Sleep", icon: "moon.zzz", color: Theme.clay) { SleepEntryView() }
            Divider().padding(.leading, 40)
            moduleLink("Daily check-in", icon: "checkmark.circle", color: Theme.honey) { CheckInView() }
            Divider().padding(.leading, 40)
            moduleLink("Habits & screen time", icon: "hourglass", color: .secondary) { ScreenTimeView() }
        }
        .padding(.vertical, 4)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private func moduleLink<Destination: View>(
        _ title: String,
        icon: String,
        color: Color,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
                    .frame(width: 28)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var mealsToday: [Meal] {
        meals.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var caloriesToday: Int? {
        let calories = mealsToday.compactMap(\.calories)
        return calories.isEmpty ? nil : calories.reduce(0, +)
    }

    private var workoutsToday: [WorkoutSession] {
        workouts.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todayRollup: DailyRollup? {
        rollups.first { Calendar.current.isDateInToday($0.date) }
    }

    private var healthParts: [String] {
        guard let rollup = todayRollup else { return [] }
        var parts: [String] = []
        if let steps = rollup.healthStepCount { parts.append("\(steps) steps") }
        if let energy = rollup.healthActiveEnergyKcal { parts.append("\(energy) active kcal") }
        if let exercise = rollup.healthExerciseMinutes { parts.append("\(exercise) exercise min") }
        if let workouts = rollup.healthWorkoutCount, workouts > 0 {
            parts.append(rollup.healthWorkoutSummary ?? "\(workouts) workout(s)")
        }
        if let sleep = rollup.healthSleepHours {
            parts.append(String(format: "%.1f h sleep", sleep))
        }
        if let resting = rollup.healthRestingHeartRate { parts.append("\(resting) bpm resting") }
        return parts
    }

    private var lastSleepValue: String {
        guard let sleep = sleeps.first else { return "—" }
        if let bedtime = sleep.bedtime, let wake = sleep.wakeTime {
            let hours = wake.timeIntervalSince(bedtime) / 3600
            if hours > 0 { return String(format: "%.1f h", hours) }
        }
        if let quality = sleep.perceivedQuality { return "\(quality)/5" }
        return "logged"
    }

    private var streakText: String {
        let streak = rewards.headlineStreak(in: events)
        switch streak {
        case 0: return "No streak yet"
        case 1: return "1 day streak"
        default: return "\(streak) day streak"
        }
    }

    // MARK: - AI summary

    private func generateSummary() {
        errorMessage = nil
        guard hasKey else {
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

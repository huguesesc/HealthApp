import SwiftData
import SwiftUI

// MARK: - Today

struct NellTodayView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Meal.timestamp, order: .reverse) private var meals: [Meal]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workouts: [WorkoutSession]
    @Query(sort: \SleepEntry.date, order: .reverse) private var sleeps: [SleepEntry]
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var events: [ActivityEvent]
    @Query(sort: \DailyRollup.date, order: .reverse) private var rollups: [DailyRollup]

    @State private var isGeneratingSummary = false
    @State private var summaryError: String?

    private var repo: HealthDataRepository {
        HealthDataRepository(context: modelContext)
    }

    private let rewards = RewardsEngine()

    var body: some View {
        NellScreen {
            header

            NellMascotHero(
                pose: .thoughtful,
                title: greeting,
                message: todayMessage
            )

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Theme.Spacing.sm
            ) {
                NellMetricTile(
                    title: "Meals",
                    value: "\(mealsToday.count)",
                    detail: caloriesToday.map { "~\($0) kcal" },
                    systemImage: "fork.knife",
                    tint: NellPalette.nutrition
                )

                NellMetricTile(
                    title: "Workout",
                    value: workoutValue,
                    detail: workoutsToday.first?.durationMinutes.map { "\($0) min" },
                    systemImage: "dumbbell.fill",
                    tint: NellPalette.training
                )

                NellMetricTile(
                    title: "Sleep",
                    value: lastSleepValue,
                    detail: "latest entry",
                    systemImage: "moon.zzz.fill",
                    tint: NellPalette.sleep
                )

                NellMetricTile(
                    title: "Streak",
                    value: "\(streakDays)",
                    detail: streakDays == 1 ? "day" : "days",
                    systemImage: "flame.fill",
                    tint: NellPalette.amber
                )
            }

            if !healthParts.isEmpty {
                NellSectionHeader(
                    title: "Apple Health",
                    subtitle: "Latest compact daily summary"
                )

                NellCard {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 130), spacing: Theme.Spacing.sm)],
                        spacing: Theme.Spacing.sm
                    ) {
                        ForEach(healthParts, id: \.self) { part in
                            Text(part)
                                .font(Theme.FontToken.caption.weight(.medium))
                                .foregroundStyle(NellPalette.textPrimary)
                                .padding(Theme.Spacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    NellPalette.elevatedSurface,
                                    in: RoundedRectangle(
                                        cornerRadius: Theme.Radius.small,
                                        style: .continuous
                                    )
                                )
                        }
                    }
                }
            }

            NellSectionHeader(
                title: "From your Coach",
                subtitle: "A concise view of what you have logged"
            )

            NellCoachSuggestionCard(
                title: rollups.first?.summaryText == nil ? "No daily summary yet" : "Today's summary",
                message: rollups.first?.summaryText
                    ?? "Generate a summary from today's meals, workout, sleep and check-in.",
                actionTitle: isGeneratingSummary
                    ? nil
                    : (rollups.first?.summaryText == nil ? "Generate summary" : "Refresh summary"),
                action: isGeneratingSummary ? nil : generateSummary
            )

            if isGeneratingSummary {
                NellThinkingIndicator(label: "Preparing your daily summary…")
            }

            if let summaryError {
                NellErrorState(
                    title: "Summary unavailable",
                    message: summaryError,
                    retryTitle: "Try again",
                    retry: generateSummary
                )
            }

            HStack(spacing: Theme.Spacing.sm) {
                NavigationLink {
                    CheckInView()
                } label: {
                    Label("Daily check-in", systemImage: "checkmark.circle")
                }
                .buttonStyle(.nellSecondary)

                NavigationLink {
                    ChatView()
                } label: {
                    Label("Ask Coach", systemImage: "bubble.left.and.bubble.right")
                }
                .buttonStyle(.nellPrimary)
            }
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "person.crop.circle")
                }
                .accessibilityLabel("Profile and settings")
            }
        }
        .onAppear {
            _ = repo.refreshTodayRollup()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            NellBrandLockup(compact: true, showsDescriptor: false)
            Spacer()
            Text(Date.now, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                .font(Theme.FontToken.caption)
                .foregroundStyle(NellPalette.textSecondary)
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var todayMessage: String {
        if let summary = rollups.first?.summaryText, !summary.isEmpty {
            return summary
        }
        if mealsToday.isEmpty && workoutsToday.isEmpty {
            return "Start with one small log. Nell will organise the rest around your day."
        }
        return "Your day is taking shape. Review the overview below or check in with your Coach."
    }

    private var mealsToday: [Meal] {
        meals.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var workoutsToday: [WorkoutSession] {
        workouts.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var caloriesToday: Int? {
        let values = mealsToday.compactMap(\.calories)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    private var workoutValue: String {
        workoutsToday.first?.type ?? "—"
    }

    private var streakDays: Int {
        rewards.headlineStreak(in: events)
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
        if let sleep = rollup.healthSleepHours {
            parts.append(String(format: "%.1f h sleep", sleep))
        }
        if let resting = rollup.healthRestingHeartRate {
            parts.append("\(resting) bpm resting")
        }
        return parts
    }

    private var lastSleepValue: String {
        guard let sleep = sleeps.first else { return "—" }
        if let bedtime = sleep.bedtime, let wake = sleep.wakeTime {
            let hours = wake.timeIntervalSince(bedtime) / 3600
            if hours > 0 { return String(format: "%.1f h", hours) }
        }
        if let quality = sleep.perceivedQuality { return "\(quality)/5" }
        return "Logged"
    }

    private func generateSummary() {
        summaryError = nil
        guard APIKeyStore.read()?.isEmpty == false else {
            summaryError = "Add your Claude API key in Settings before generating a Coach summary."
            return
        }

        isGeneratingSummary = true
        Task { @MainActor in
            do {
                let result = try await AIClientFactory.makeDefault().summarizeDay(repo.todayContext())
                repo.saveTodaySummary(result)
            } catch {
                summaryError = AIErrorMessage.describe(error, operation: "daily summary")
            }
            isGeneratingSummary = false
        }
    }
}

// MARK: - Coach shell

struct NellCoachRootView: View {
    var body: some View {
        ChatView()
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Profile and settings")
                }
            }
            .background(NellPalette.background)
    }
}

// MARK: - Nutrition

struct NellNutritionHomeView: View {
    @Query(sort: \Meal.timestamp, order: .reverse) private var meals: [Meal]

    var body: some View {
        NellScreen {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Nutrition")
                        .font(Theme.FontToken.largeScreenTitle)
                        .foregroundStyle(NellPalette.textPrimary)
                    Text("A simple view of what you have logged today.")
                        .font(Theme.FontToken.secondaryBody)
                        .foregroundStyle(NellPalette.textSecondary)
                }
                Spacer()
            }

            NellMascotHero(
                pose: .nutrition,
                title: mealsToday.isEmpty ? "Nothing logged yet" : "Today's meals",
                message: mealsToday.isEmpty
                    ? "Log food in plain language and review every estimate before saving."
                    : "You have logged \(mealsToday.count) meal\(mealsToday.count == 1 ? "" : "s") today."
            )

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Theme.Spacing.sm
            ) {
                NellMetricTile(
                    title: "Calories",
                    value: calorieText,
                    detail: "logged today",
                    systemImage: "flame.fill",
                    tint: NellPalette.amber
                )
                NellMetricTile(
                    title: "Protein",
                    value: macroText(\.proteinGrams),
                    detail: "grams",
                    systemImage: "circle.grid.cross.fill",
                    tint: NellPalette.nutrition
                )
                NellMetricTile(
                    title: "Carbs",
                    value: macroText(\.carbsGrams),
                    detail: "grams",
                    systemImage: "leaf.fill",
                    tint: NellPalette.moss
                )
                NellMetricTile(
                    title: "Fat",
                    value: macroText(\.fatGrams),
                    detail: "grams",
                    systemImage: "drop.fill",
                    tint: NellPalette.warning
                )
            }

            NavigationLink {
                MealEntryView()
            } label: {
                Label("Log a meal", systemImage: "plus")
            }
            .buttonStyle(.nellPrimary)

            NellSectionHeader(
                title: "Recent meals",
                subtitle: meals.isEmpty ? "Your meal history will appear here." : nil
            )

            if meals.isEmpty {
                NellEmptyState(
                    title: "No meals yet",
                    message: "Your saved meals will stay on this device and appear here.",
                    systemImage: "fork.knife"
                )
            } else {
                NellCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(meals.prefix(8).enumerated()), id: \.element.id) { index, meal in
                            mealRow(meal)
                            if index < min(meals.count, 8) - 1 {
                                Divider().padding(.leading, Theme.Spacing.md)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "person.crop.circle")
                }
                .accessibilityLabel("Profile and settings")
            }
        }
    }

    private var mealsToday: [Meal] {
        meals.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var calorieText: String {
        let values = mealsToday.compactMap(\.calories)
        guard !values.isEmpty else { return "—" }
        return "\(values.reduce(0, +))"
    }

    private func macroText(_ keyPath: KeyPath<Meal, Double?>) -> String {
        let values = mealsToday.compactMap { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return "—" }
        return String(format: "%.0f", values.reduce(0, +))
    }

    private func mealRow(_ meal: Meal) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Circle()
                .fill(NellPalette.nutrition)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(meal.rawText)
                    .font(Theme.FontToken.body)
                    .foregroundStyle(NellPalette.textPrimary)
                    .lineLimit(2)
                Text(meal.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textTertiary)
            }

            Spacer(minLength: Theme.Spacing.xs)

            if let calories = meal.calories {
                Text("\(calories) kcal")
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textSecondary)
            }
        }
        .padding(Theme.Spacing.md)
    }
}

// MARK: - Train

struct NellTrainHomeView: View {
    @Query(sort: \WorkoutPlan.updatedAt, order: .reverse) private var plans: [WorkoutPlan]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workouts: [WorkoutSession]

    var body: some View {
        NellScreen {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Train")
                    .font(Theme.FontToken.largeScreenTitle)
                    .foregroundStyle(NellPalette.textPrimary)
                Text("Plans, active sessions and movement feedback in one place.")
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)
            }

            NellMascotHero(
                pose: .training,
                title: "Ready when you are",
                message: "Resume a session, choose a saved plan, or log a completed workout."
            )

            NavigationLink {
                WorkoutStartView()
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 36))
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Start or continue workout")
                            .font(Theme.FontToken.cardTitle)
                        Text("Resume an active session or choose a plan.")
                            .font(Theme.FontToken.secondaryBody)
                            .opacity(0.84)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding(Theme.Spacing.screen)
                .foregroundStyle(Color.white)
                .background(
                    NellPalette.forest,
                    in: RoundedRectangle(cornerRadius: NellLayout.featuredRadius, style: .continuous)
                )
            }
            .buttonStyle(.plain)

            if let plan = activePlans.first {
                NellSectionHeader(title: "Next saved plan")

                NavigationLink {
                    WorkoutPlansView()
                } label: {
                    NellFeaturedCard(tint: NellPalette.training) {
                        HStack(spacing: Theme.Spacing.md) {
                            if let firstStep = plan.orderedSteps.first {
                                WorkoutMotionView(
                                    title: firstStep.title,
                                    type: firstStep.type,
                                    presentation: .compact
                                )
                                .frame(width: 62)
                            }

                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(plan.title)
                                    .font(Theme.FontToken.cardTitle)
                                    .foregroundStyle(NellPalette.textPrimary)
                                Text(planDetail(plan))
                                    .font(Theme.FontToken.caption)
                                    .foregroundStyle(NellPalette.textSecondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(NellPalette.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            NellSectionHeader(
                title: "Training tools",
                subtitle: workouts.isEmpty ? "No completed workouts yet." : "\(workouts.count) completed workout\(workouts.count == 1 ? "" : "s")"
            )

            NellCard(padding: 0) {
                VStack(spacing: 0) {
                    trainLink("Structured workout plans", icon: "list.clipboard") {
                        WorkoutPlansView()
                    }
                    Divider().padding(.leading, 56)
                    trainLink("Workout log", icon: "dumbbell") {
                        WorkoutLogView()
                    }
                    Divider().padding(.leading, 56)
                    trainLink("Execution history", icon: "clock.arrow.circlepath") {
                        ActiveWorkoutsView()
                    }
                    Divider().padding(.leading, 56)
                    trainLink("Movement feedback", icon: "slider.horizontal.3") {
                        MovementFeedbackHistoryView()
                    }
                }
            }
        }
        .navigationTitle("Train")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "person.crop.circle")
                }
                .accessibilityLabel("Profile and settings")
            }
        }
    }

    private var activePlans: [WorkoutPlan] {
        plans.filter { !$0.isArchived }
    }

    private func planDetail(_ plan: WorkoutPlan) -> String {
        var parts = ["\(plan.orderedSteps.count) steps"]
        if let minutes = plan.estimatedDurationMinutes { parts.append("\(minutes) min") }
        if let location = plan.locationNameSnapshot, !location.isEmpty { parts.append(location) }
        return parts.joined(separator: " · ")
    }

    private func trainLink<Destination: View>(
        _ title: String,
        icon: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(NellPalette.training)
                    .frame(width: 32)
                Text(title)
                    .font(Theme.FontToken.body)
                    .foregroundStyle(NellPalette.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NellPalette.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Nell Today") {
    NavigationStack { NellTodayView() }
        .modelContainer(PersistenceController.preview.container)
}

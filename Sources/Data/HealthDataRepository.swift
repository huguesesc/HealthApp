import Foundation
import SwiftData

/// The main read/write seam across modules. Views write through this (so an
/// `ActivityEvent` is recorded alongside the data, feeding rewards), and the
/// dashboard / future assistant read cross-module snapshots and trends through it.
///
/// It is a thin value wrapper around a `ModelContext`; construct it per view from
/// `@Environment(\.modelContext)`. Per-module history lists may still use SwiftData's
/// `@Query` for live updates — the repository is the *write* seam and the
/// *cross-module / trend read* seam, not a replacement for simple live queries.
///
/// Queries deliberately fetch-then-filter in Swift rather than using `#Predicate`.
/// Data volumes are tiny (one person) and this avoids the brittle predicate
/// compilation that is a common source of cryptic SwiftData errors.
@MainActor
struct HealthDataRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Writes (each also records an ActivityEvent)

    func addMeal(_ meal: Meal) {
        context.insert(meal)
        insertEvent(.mealLogged, detail: meal.rawText)
        persist()
    }

    func addWorkout(_ session: WorkoutSession) {
        context.insert(session)
        insertEvent(.workoutCompleted, detail: session.type)
        persist()
    }

    func addSleep(_ entry: SleepEntry) {
        context.insert(entry)
        insertEvent(.sleepLogged)
        persist()
    }

    func addCheckIn(_ checkIn: DailyCheckIn) {
        context.insert(checkIn)
        insertEvent(.checkInCompleted)
        persist()
    }

    /// Record an event that isn't tied to one of the add* helpers (e.g. a
    /// screen-time override).
    func logEvent(_ type: ActivityEventType, detail: String? = nil) {
        insertEvent(type, detail: detail)
        persist()
    }

    // MARK: - Reads

    func allMeals() -> [Meal] { fetch(sortedBy: \Meal.timestamp) }
    func mealsToday() -> [Meal] { allMeals().filter { isToday($0.timestamp) } }

    func allWorkouts() -> [WorkoutSession] { fetch(sortedBy: \WorkoutSession.date) }
    func workoutsToday() -> [WorkoutSession] { allWorkouts().filter { isToday($0.date) } }

    func latestSleep() -> SleepEntry? { fetch(sortedBy: \SleepEntry.date).first }

    func checkInToday() -> DailyCheckIn? {
        fetch(sortedBy: \DailyCheckIn.date).first { isToday($0.date) }
    }

    func recentEvents(limit: Int = 365) -> [ActivityEvent] {
        Array(fetch(sortedBy: \ActivityEvent.timestamp).prefix(limit))
    }

    func recentRollups(days: Int = 14) -> [DailyRollup] {
        Array(fetch(sortedBy: \DailyRollup.date).prefix(days))
    }

    // MARK: - Daily rollup (cheap history layer)

    /// Recompute today's rollup from raw data and upsert it. Cheap; safe to call on
    /// dashboard appearance.
    @discardableResult
    func refreshTodayRollup() -> DailyRollup {
        let today = Calendar.current.startOfDay(for: .now)
        let existing = fetch(sortedBy: \DailyRollup.date)
            .first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let rollup = existing ?? DailyRollup(date: today)

        let meals = mealsToday()
        rollup.mealsLogged = meals.count
        let calories = meals.compactMap(\.calories)
        rollup.totalCalories = calories.isEmpty ? nil : calories.reduce(0, +)

        let workouts = workoutsToday()
        rollup.workoutCompleted = !workouts.isEmpty
        rollup.workoutType = workouts.first?.type

        if let sleep = latestSleep() {
            rollup.sleepQuality = sleep.perceivedQuality
            rollup.sleepHours = sleepHours(sleep)
        }

        if let checkIn = checkInToday() {
            rollup.energy = checkIn.energy
            rollup.mood = checkIn.mood
        }

        if existing == nil { context.insert(rollup) }
        persist()
        return rollup
    }

    /// Compact, Codable snapshots for the AI assistant's context window.
    func recentRollupSnapshots(days: Int = 14) -> [RollupSnapshot] {
        recentRollups(days: days).map { rollup in
            RollupSnapshot(
                date: rollup.date,
                mealsLogged: rollup.mealsLogged,
                totalCalories: rollup.totalCalories,
                workoutType: rollup.workoutCompleted ? rollup.workoutType : nil,
                sleepQuality: rollup.sleepQuality,
                energy: rollup.energy,
                mood: rollup.mood,
                screenTimeExceeded: rollup.screenTimeExceeded
            )
        }
    }

    /// Assemble today's cross-module context for `summarizeDay`. Substantive on
    /// purpose: macros, workout detail, sleep quality, the check-in note and the
    /// streak all go in so the summary has something real to comment on.
    func todayContext() -> DailyContext {
        var checkInValues: [String: Int] = [:]
        var checkInNote: String?
        if let checkIn = checkInToday() {
            if let value = checkIn.energy { checkInValues["energy"] = value }
            if let value = checkIn.mood { checkInValues["mood"] = value }
            if let value = checkIn.hunger { checkInValues["hunger"] = value }
            if let value = checkIn.soreness { checkInValues["soreness"] = value }
            if let value = checkIn.focus { checkInValues["focus"] = value }
            if let value = checkIn.stress { checkInValues["stress"] = value }
            checkInNote = checkIn.note
        }

        let meals = mealsToday()
        let calories = meals.compactMap(\.calories)
        let protein = meals.compactMap(\.proteinGrams)
        let carbs = meals.compactMap(\.carbsGrams)
        let fat = meals.compactMap(\.fatGrams)

        let streak = RewardsEngine().headlineStreak(in: recentEvents())

        return DailyContext(
            date: Calendar.current.startOfDay(for: .now),
            meals: meals.map(mealDescription),
            totalCalories: calories.isEmpty ? nil : calories.reduce(0, +),
            proteinGrams: protein.isEmpty ? nil : protein.reduce(0, +),
            carbsGrams: carbs.isEmpty ? nil : carbs.reduce(0, +),
            fatGrams: fat.isEmpty ? nil : fat.reduce(0, +),
            workoutSummary: workoutsToday().first.map(workoutDescription),
            sleepSummary: latestSleep().map(sleepDescription),
            checkIn: checkInValues,
            checkInNote: checkInNote,
            streakDays: streak > 0 ? streak : nil,
            screenTimeExceededLimit: nil
        )
    }

    private func mealDescription(_ meal: Meal) -> String {
        var parts: [String] = []
        if let calories = meal.calories { parts.append("~\(calories) kcal") }
        var macros: [String] = []
        if let protein = meal.proteinGrams { macros.append("P \(Int(protein))") }
        if let carbs = meal.carbsGrams { macros.append("C \(Int(carbs))") }
        if let fat = meal.fatGrams { macros.append("F \(Int(fat))") }
        if !macros.isEmpty { parts.append(macros.joined(separator: "/")) }
        return parts.isEmpty ? meal.rawText : "\(meal.rawText) (\(parts.joined(separator: ", ")))"
    }

    private func workoutDescription(_ session: WorkoutSession) -> String {
        var parts = [session.type]
        if !session.sets.isEmpty { parts.append("\(session.sets.count) set(s)") }
        if let effort = session.perceivedEffort { parts.append("effort \(effort)/10") }
        if let minutes = session.durationMinutes { parts.append("\(minutes) min") }
        return parts.joined(separator: ", ")
    }

    private func sleepDescription(_ entry: SleepEntry) -> String {
        var parts: [String] = []
        if let hours = sleepHours(entry) { parts.append(String(format: "%.1f h", hours)) }
        if let quality = entry.perceivedQuality { parts.append("quality \(quality)/5") }
        if let tiredness = entry.tiredness { parts.append("woke tired \(tiredness)/5") }
        return parts.isEmpty ? "logged" : parts.joined(separator: ", ")
    }

    /// Attach an AI-generated summary to today's rollup (upserting it first), and
    /// record which model produced it. Called after `summarizeDay` succeeds.
    func saveTodaySummary(_ result: DailySummaryResult) {
        let rollup = refreshTodayRollup()
        rollup.summaryText = result.text
        rollup.modelUsed = result.modelUsed
        persist()
    }

    // MARK: - Helpers

    private func insertEvent(_ type: ActivityEventType, detail: String? = nil) {
        context.insert(ActivityEvent(type: type, detail: detail))
    }

    private func persist() {
        try? context.save()
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    private func sleepHours(_ entry: SleepEntry) -> Double? {
        guard let bedtime = entry.bedtime, let wake = entry.wakeTime else { return nil }
        let seconds = wake.timeIntervalSince(bedtime)
        return seconds > 0 ? seconds / 3600 : nil
    }

    private func fetch<T: PersistentModel>(
        sortedBy keyPath: KeyPath<T, Date>,
        order: SortOrder = .reverse
    ) -> [T] {
        let descriptor = FetchDescriptor<T>(sortBy: [SortDescriptor(keyPath, order: order)])
        return (try? context.fetch(descriptor)) ?? []
    }
}

/// Plain Codable mirror of a `DailyRollup`, used to hand cheap history to the AI
/// layer without leaking SwiftData models into it.
struct RollupSnapshot: Codable, Equatable {
    var date: Date
    var mealsLogged: Int
    var totalCalories: Int?
    var workoutType: String?
    var sleepQuality: Int?
    var energy: Int?
    var mood: Int?
    var screenTimeExceeded: Bool?
}

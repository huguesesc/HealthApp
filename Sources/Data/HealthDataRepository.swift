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

    /// Assemble today's cross-module context for `summarizeDay`.
    func todayContext() -> DailyContext {
        var checkInValues: [String: Int] = [:]
        if let checkIn = checkInToday() {
            if let value = checkIn.energy { checkInValues["energy"] = value }
            if let value = checkIn.mood { checkInValues["mood"] = value }
            if let value = checkIn.soreness { checkInValues["soreness"] = value }
            if let value = checkIn.focus { checkInValues["focus"] = value }
            if let value = checkIn.stress { checkInValues["stress"] = value }
        }
        let workout = workoutsToday().first
        let sleep = latestSleep()
        return DailyContext(
            date: Calendar.current.startOfDay(for: .now),
            meals: mealsToday().map(\.rawText),
            workoutSummary: workout.map { "\($0.type), \($0.sets.count) set(s)" },
            sleepSummary: sleep.flatMap(sleepHours).map { String(format: "%.1f h", $0) },
            checkIn: checkInValues,
            screenTimeExceededLimit: nil
        )
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

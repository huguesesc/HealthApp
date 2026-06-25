import Foundation

/// Minimal rewards/streaks logic. Pure functions over the `ActivityEvent` stream —
/// no SwiftData dependency, so it's trivially testable and can grow without
/// touching the data layer. This is intentionally a stub: streak counting today,
/// points / badges / screen-time currency later.
struct RewardsEngine {
    /// Number of consecutive days ending today on which at least one event of
    /// `type` occurred. Today not yet logged → streak 0.
    func streak(
        of type: ActivityEventType,
        in events: [ActivityEvent],
        asOf now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let activeDays = Set(
            events
                .filter { $0.type == type }
                .map { calendar.startOfDay(for: $0.timestamp) }
        )
        var streak = 0
        var day = calendar.startOfDay(for: now)
        while activeDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    /// The "best" streak to surface on the dashboard: the longest current streak
    /// across the logging event types.
    func headlineStreak(in events: [ActivityEvent], asOf now: Date = .now) -> Int {
        let loggingTypes: [ActivityEventType] = [
            .mealLogged, .workoutCompleted, .sleepLogged, .checkInCompleted,
        ]
        return loggingTypes
            .map { streak(of: $0, in: events, asOf: now) }
            .max() ?? 0
    }
}

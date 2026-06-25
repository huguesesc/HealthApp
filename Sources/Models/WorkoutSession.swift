import Foundation
import SwiftData

/// A single workout, made up of one or more exercise sets.
@Model
final class WorkoutSession {
    var date: Date
    var type: String           // e.g. "Push", "Run", "Mobility"
    var durationMinutes: Int?
    /// Rate of perceived exertion, 1–10.
    var perceivedEffort: Int?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.session)
    var sets: [ExerciseSet]

    init(date: Date = .now, type: String, durationMinutes: Int? = nil,
         perceivedEffort: Int? = nil, sets: [ExerciseSet] = []) {
        self.date = date
        self.type = type
        self.durationMinutes = durationMinutes
        self.perceivedEffort = perceivedEffort
        self.sets = sets
    }
}

@Model
final class ExerciseSet {
    var exerciseName: String
    var reps: Int
    var weightKilograms: Double?
    var order: Int

    var session: WorkoutSession?

    init(exerciseName: String, reps: Int, weightKilograms: Double? = nil, order: Int = 0) {
        self.exerciseName = exerciseName
        self.reps = reps
        self.weightKilograms = weightKilograms
        self.order = order
    }
}

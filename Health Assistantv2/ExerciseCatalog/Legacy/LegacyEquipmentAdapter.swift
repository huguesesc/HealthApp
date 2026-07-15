enum LegacyEquipmentAdapter {
    static func avatarEquipment(for exercise: ExerciseDefinition) -> WorkoutAvatarEquipment {
        let clauses = exercise.equipment.required + exercise.equipment.alternatives.flatMap { $0 }
        let quantities = Dictionary(grouping: clauses, by: { $0.id.rawValue }).mapValues {
            $0.map(\.quantity).max() ?? 0
        }

        if exercise.id.rawValue == "dumbbell.goblet_squat",
           (
               quantities["dumbbell", default: 0] > 0
                || quantities["kettlebell", default: 0] > 0
                || quantities["weight_plate", default: 0] > 0
           ) {
            return .gobletWeight
        }
        if quantities["dumbbell", default: 0] > 0 {
            return .dumbbells
        }
        return .none
    }
}

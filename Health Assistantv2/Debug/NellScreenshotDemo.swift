#if DEBUG
import Foundation
import SwiftData

/// Deterministic demo content for simulator screenshot capture.
///
/// Activated ONLY by the `-nell-screenshot-demo` launch argument, which CI
/// passes when running the screenshot UI tests. The app then runs against a
/// fresh in-memory store so real user data can never be touched, and the
/// Nell conversation is pre-populated without contacting any AI service.
enum NellScreenshotDemo {
    static let launchArgument = "-nell-screenshot-demo"

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    @MainActor
    static func makeContainer() -> ModelContainer {
        let controller = PersistenceController(inMemory: true)
        seed(using: controller.container)
        return controller.container
    }

    @MainActor
    private static func seed(using container: ModelContainer) {
        let context = ModelContext(container)
        let calendar = Calendar.current
        let now = Date.now

        let profile = HealthProfile(
            unitSystem: .metric,
            primaryGoal: .generalHealth,
            experienceLevel: .beginner
        )
        profile.generalPreferences = "Prefers short morning sessions."
        context.insert(profile)

        let home = WorkoutLocation(name: "Home", category: .home)
        home.spaceLimitations = "Small living-room corner."
        context.insert(home)
        context.insert(
            EquipmentItem(
                name: "Pair of dumbbells",
                category: .dumbbells,
                quantity: 1,
                minWeightKilograms: 5,
                maxWeightKilograms: 20,
                location: home
            )
        )
        context.insert(
            EquipmentItem(name: "Yoga mat", category: .yogaMat, location: home)
        )

        // Today's meals.
        context.insert(
            Meal(
                timestamp: calendar.date(byAdding: .hour, value: -3, to: now) ?? now,
                rawText: "Overnight oats with blueberries"
            )
        )
        context.insert(
            Meal(
                timestamp: calendar.date(byAdding: .hour, value: -1, to: now) ?? now,
                rawText: "Two eggs and toast"
            )
        )

        // Last night's sleep.
        context.insert(
            SleepEntry(
                date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                bedtime: calendar.date(byAdding: .hour, value: -9, to: now),
                wakeTime: calendar.date(byAdding: .hour, value: -1, to: now),
                perceivedQuality: 4,
                napMinutes: nil,
                tiredness: 2
            )
        )

        // Today's check-in.
        context.insert(
            DailyCheckIn(date: now, energy: 4, mood: 4, hunger: 2, soreness: 2, focus: 4, stress: 2)
        )

        // Yesterday's completed workout with sets.
        let yesterdayWorkout = WorkoutSession(
            date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
            type: "Full body",
            durationMinutes: 32,
            perceivedEffort: 6
        )
        context.insert(yesterdayWorkout)
        let squatSet = ExerciseSet(
            exerciseName: "Goblet squat",
            exerciseIDSnapshot: "dumbbell.goblet_squat",
            reps: 10,
            weightKilograms: 12,
            order: 0
        )
        squatSet.session = yesterdayWorkout
        context.insert(squatSet)
        let pushUpSet = ExerciseSet(
            exerciseName: "Push-up",
            exerciseIDSnapshot: "bodyweight.push_up",
            reps: 12,
            order: 1
        )
        pushUpSet.session = yesterdayWorkout
        context.insert(pushUpSet)

        // A saved plan ready to review.
        let plan = WorkoutPlan(
            title: "Full-body reset",
            goalText: "Build strength",
            notes: "Keep rests short.",
            estimatedDurationMinutes: 35,
            targetEffort: 6,
            source: .assistant
        )
        context.insert(plan)
        context.insert(
            WorkoutStep(
                order: 0,
                type: .warmUp,
                title: "Joint circles",
                instruction: "Loosen shoulders, hips and ankles.",
                durationSeconds: 120,
                plan: plan
            )
        )
        context.insert(
            WorkoutStep(
                order: 1,
                type: .exercise,
                exerciseIDSnapshot: "bodyweight.squat",
                title: "Bodyweight squat",
                instruction: "Lower with control and keep the heels grounded.",
                sets: 3,
                reps: 10,
                restSeconds: 60,
                plan: plan
            )
        )
        context.insert(
            WorkoutStep(
                order: 2,
                type: .exercise,
                exerciseIDSnapshot: "dumbbell.bent_over_row",
                title: "Bent-over row",
                instruction: "Pull toward the ribs without shrugging.",
                sets: 3,
                reps: 10,
                restSeconds: 60,
                equipmentNameSnapshot: "Pair of dumbbells",
                plan: plan
            )
        )

        // A resumable active workout mid-execution.
        let session = ActiveWorkoutSession(
            startedAt: calendar.date(byAdding: .minute, value: -14, to: now) ?? now,
            status: .inProgress,
            titleSnapshot: "Full-body reset",
            goalSnapshot: "Build strength",
            locationNameSnapshot: "Home",
            targetEffortSnapshot: 6,
            currentStepIndex: 1
        )
        context.insert(session)
        context.insert(
            ActiveWorkoutStep(
                order: 0,
                type: .warmUp,
                title: "Joint circles",
                instruction: "Loosen shoulders, hips and ankles.",
                plannedDurationSeconds: 120,
                status: .completed,
                session: session
            )
        )
        context.insert(
            ActiveWorkoutStep(
                order: 1,
                type: .exercise,
                exerciseIDSnapshot: "bodyweight.squat",
                title: "Bodyweight squat",
                instruction: "Lower with control and keep the heels grounded.",
                plannedSets: 3,
                plannedReps: 10,
                plannedRestSeconds: 60,
                status: .active,
                completedSets: 1,
                session: session
            )
        )
        context.insert(
            ActiveWorkoutStep(
                order: 2,
                type: .exercise,
                exerciseIDSnapshot: "dumbbell.bent_over_row",
                title: "Bent-over row",
                instruction: "Pull toward the ribs without shrugging.",
                plannedSets: 3,
                plannedReps: 10,
                plannedRestSeconds: 60,
                session: session
            )
        )

        try? context.save()
    }

    /// Pre-populated transcript for the conversation screenshots. Never sends
    /// anything to a model service.
    @MainActor
    static func demoChatItems() -> [ChatItem] {
        let meal = MealProposal(
            description: "Two eggs and toast",
            items: [
                MealItemBreakdown(
                    food: "Eggs",
                    quantity: "2 large",
                    grams: 100,
                    calories: 143,
                    proteinGrams: 12.6,
                    carbsGrams: 0.7,
                    fatGrams: 9.5
                ),
                MealItemBreakdown(
                    food: "Toast",
                    quantity: "2 slices",
                    grams: 56,
                    calories: 154,
                    proteinGrams: 5,
                    carbsGrams: 27,
                    fatGrams: 2
                ),
            ],
            calories: 297,
            proteinGrams: 17.6,
            carbsGrams: 27.7,
            fatGrams: 11.5,
            confidence: "medium"
        )
        let mealProposal = ChatProposal(kind: .meal(meal))
        mealProposal.status = .saved

        return [
            .user(UUID(), "I had two eggs and toast"),
            .assistant(
                UUID(),
                "Logged that as **two eggs and toast** — about 297 kcal with 18 g of protein. It is saved to today's nutrition overview."
            ),
            .proposal(mealProposal),
            .assistant(
                UUID(),
                "Your check-in showed solid energy today. If you want a small next step, I can draft a short session for your home dumbbells."
            ),
        ]
    }
}
#endif

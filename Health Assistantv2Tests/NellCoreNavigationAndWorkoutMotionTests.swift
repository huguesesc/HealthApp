import Testing
@testable import Health_Assistantv2

struct NellCoreNavigationAndWorkoutMotionTests {
    @Test func logCategoriesRemainExplicitAndComplete() {
        #expect(NellLogCategory.allCases.map(\.rawValue) == [
            "Meal",
            "Workout",
            "Sleep",
            "Check-in"
        ])
    }

    @Test func defaultWorkoutMotionAssetsHaveUniqueStableIdentifiers() {
        let assets = WorkoutMotionRegistry.defaultAssets
        #expect(assets.count == 8)
        #expect(Set(assets.map(\.id)).count == assets.count)
        #expect(Set(assets.map(\.movementID)).count == assets.count)
    }

    @Test func workoutAliasesResolveToStableMovementIDs() {
        #expect(WorkoutMotionRegistry.movementID(for: "Goblet squat") == "goblet_squat")
        #expect(WorkoutMotionRegistry.movementID(for: "Dumbbell bent-over row") == "bent_over_row")
        #expect(WorkoutMotionRegistry.movementID(for: "Romanian deadlift") == "hip_hinge")
        #expect(WorkoutMotionRegistry.movementID(for: "Tree pose") == "yoga_balance")
    }

    @Test func unknownMovementsUseTheSafeFallbackPath() {
        #expect(WorkoutMotionRegistry.asset(for: "Custom cable movement") == nil)
    }

    @Test func productionAssetNamesAreStyleScoped() {
        let asset = WorkoutMotionRegistry.asset(movementID: "goblet_squat")
        #expect(asset?.characterStyleID == WorkoutAvatarStyle.nellNeutral.id)
        #expect(asset?.startAssetName.contains("NellNeutral01") == true)
        #expect(asset?.endAssetName?.hasSuffix("_End") == true)
    }
}

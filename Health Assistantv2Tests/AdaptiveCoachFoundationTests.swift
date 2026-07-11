import Foundation
import Testing
@testable import Health_Assistantv2

@MainActor
struct AdaptiveCoachFoundationTests {
    @Test func currentProfileIsSingletonByConvention() throws {
        let controller = PersistenceController(inMemory: true)
        let repo = HealthDataRepository(context: controller.container.mainContext)

        let first = repo.currentProfile()
        first.primaryGoalRaw = CoachGoal.buildStrength.rawValue
        repo.profileDidChange(first)

        let second = repo.currentProfile()

        #expect(first.id == second.id)
        #expect(second.primaryGoal == .buildStrength)
    }

    @Test func profileSnapshotContainsOnlyConfirmedNonArchivedConsiderations() throws {
        let controller = PersistenceController(inMemory: true)
        let repo = HealthDataRepository(context: controller.container.mainContext)

        let profile = repo.currentProfile()
        profile.primaryGoalRaw = CoachGoal.returnToSport.rawValue
        profile.experienceLevelRaw = CoachExperienceLevel.intermediate.rawValue
        profile.preferredActivitiesText = "Tennis, Cycling"
        repo.profileDidChange(profile)

        let active = HealthConsideration(
            title: "Left knee",
            bodyArea: .knee,
            side: .left,
            category: .previousSurgery,
            userDescription: "Previous surgery and sometimes feels less stable under fatigue."
        )
        repo.addConsideration(active)

        let archived = HealthConsideration(
            title: "Old ankle note",
            bodyArea: .ankle,
            side: .right,
            category: .previousInjury,
            userDescription: "No longer relevant.",
            status: .archived
        )
        repo.addConsideration(archived)

        let snapshot = try #require(repo.healthProfileSnapshot())

        #expect(snapshot.goal == CoachGoal.returnToSport.displayName)
        #expect(snapshot.preferredActivities == ["Tennis", "Cycling"])
        #expect(snapshot.considerations.count == 1)
        #expect(snapshot.considerations.first?.title == "Left knee")
        #expect(snapshot.considerations.first?.userReported == true)
    }

    @Test func workoutLocationSnapshotExcludesUnavailableEquipment() throws {
        let controller = PersistenceController(inMemory: true)
        let repo = HealthDataRepository(context: controller.container.mainContext)

        let home = WorkoutLocation(
            name: "Home",
            category: .home,
            spaceLimitations: "Limited floor space"
        )
        repo.addLocation(home)
        repo.addEquipment(
            EquipmentItem(name: "Foam balance pad", category: .foamBalancePad),
            to: home
        )
        repo.addEquipment(
            EquipmentItem(
                name: "Heavy resistance band",
                category: .longResistanceBands,
                isAvailable: false
            ),
            to: home
        )

        let snapshots = repo.workoutLocationSnapshots()
        let snapshot = try #require(snapshots.first)

        #expect(snapshots.count == 1)
        #expect(snapshot.name == "Home")
        #expect(snapshot.spaceLimitations == "Limited floor space")
        #expect(snapshot.equipment.count == 1)
        #expect(snapshot.equipment.first?.name == "Foam balance pad")
        #expect(snapshot.equipment.first?.capability == EquipmentCapability.balance.rawValue)
    }

    @Test func archivedLocationsAreExcludedFromAssistantSnapshot() throws {
        let controller = PersistenceController(inMemory: true)
        let repo = HealthDataRepository(context: controller.container.mainContext)

        let home = WorkoutLocation(name: "Home", category: .home)
        let formerGym = WorkoutLocation(name: "Former gym", category: .gym)
        repo.addLocation(home)
        repo.addLocation(formerGym)
        repo.archiveLocation(formerGym)

        let snapshots = repo.workoutLocationSnapshots()

        #expect(snapshots.map(\.name) == ["Home"])
    }

    @Test func bodyMetricTrendUsesLatestEntryAndThirtyDayComparison() throws {
        let controller = PersistenceController(inMemory: true)
        let repo = HealthDataRepository(context: controller.container.mainContext)
        let calendar = Calendar(identifier: .gregorian)
        let latestDate = Date(timeIntervalSince1970: 1_788_739_200)
        let earlierDate = try #require(calendar.date(byAdding: .day, value: -35, to: latestDate))

        repo.addBodyMetric(
            BodyMetricEntry(
                timestamp: earlierDate,
                weightKilograms: 80,
                heightCentimeters: 180
            )
        )
        repo.addBodyMetric(
            BodyMetricEntry(
                timestamp: latestDate,
                weightKilograms: 78.5,
                heightCentimeters: 180
            )
        )

        let trend = try #require(repo.bodyMetricTrendSnapshot())

        #expect(trend.latestDate == latestDate)
        #expect(trend.latestWeightKilograms == 78.5)
        #expect(trend.weightChangeKilograms30Days == -1.5)
    }
}

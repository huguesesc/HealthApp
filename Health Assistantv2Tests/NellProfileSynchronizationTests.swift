import Foundation
import Testing
@testable import Health_Assistantv2

@MainActor
struct NellProfileSynchronizationTests {
    @Test func onboardingPreferencesPopulateAuthoritativeSwiftDataProfile() throws {
        let controller = PersistenceController(inMemory: true)
        let repository = HealthDataRepository(context: controller.container.mainContext)
        let suiteName = "NellProfileSynchronizationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("strength,nutrition", forKey: "nell.profile.goals")
        defaults.set("gym", forKey: "nell.profile.trainingContext")
        defaults.set("Avoid deep knee flexion for now.", forKey: "nell.profile.movementNotes")

        NellOnboardingProfileSynchronizer.synchronize(
            context: controller.container.mainContext,
            defaults: defaults,
            force: true
        )

        let profile = try #require(repository.existingProfile())
        #expect(profile.primaryGoal == .buildStrength)
        #expect(profile.goalDetail?.contains("Build strength") == true)
        #expect(profile.goalDetail?.contains("Understand nutrition") == true)
        #expect(profile.generalPreferences?.contains("Mostly at a gym") == true)

        let consideration = try #require(
            repository.allConsiderations().first {
                $0.title == "Onboarding movement considerations"
            }
        )
        #expect(consideration.userDescription == "Avoid deep knee flexion for now.")
        #expect(consideration.confirmedByUser)
        #expect(consideration.status == .active)
    }

    @Test func migrationDoesNotRepeatedlyOverwriteLaterProfileEdits() throws {
        let controller = PersistenceController(inMemory: true)
        let repository = HealthDataRepository(context: controller.container.mainContext)
        let suiteName = "NellProfileMigrationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("strength", forKey: "nell.profile.goals")
        NellOnboardingProfileSynchronizer.synchronize(
            context: controller.container.mainContext,
            defaults: defaults,
            force: true
        )

        let profile = try #require(repository.existingProfile())
        profile.primaryGoalRaw = CoachGoal.returnToSport.rawValue
        repository.profileDidChange(profile)

        defaults.set("fitness", forKey: "nell.profile.goals")
        NellOnboardingProfileSynchronizer.synchronize(
            context: controller.container.mainContext,
            defaults: defaults,
            force: false
        )

        #expect(profile.primaryGoal == .returnToSport)

        NellOnboardingProfileSynchronizer.synchronize(
            context: controller.container.mainContext,
            defaults: defaults,
            force: true
        )

        #expect(profile.primaryGoal == .improveEndurance)
    }
}

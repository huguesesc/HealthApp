import Foundation
import SwiftData

/// Bridges the lightweight onboarding draft into the SwiftData records used by
/// Coach context. AppStorage remains only a draft cache for onboarding replay;
/// HealthProfile and HealthConsideration are the authoritative persisted data.
@MainActor
enum NellOnboardingProfileSynchronizer {
    private static let goalsKey = "nell.profile.goals"
    private static let trainingContextKey = "nell.profile.trainingContext"
    private static let movementNotesKey = "nell.profile.movementNotes"
    private static let migrationVersionKey = "nell.profile.swiftDataMigrationVersion"
    private static let currentMigrationVersion = 1

    private static let trainingContextPrefix = "Nell onboarding training context:"
    private static let movementConsiderationTitle = "Onboarding movement considerations"

    static func synchronize(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        force: Bool = false
    ) {
        let migratedVersion = defaults.integer(forKey: migrationVersionKey)
        guard force || migratedVersion < currentMigrationVersion else { return }

        let repository = HealthDataRepository(context: context)
        let profile = repository.currentProfile()

        if let rawGoals = defaults.string(forKey: goalsKey), !rawGoals.trimmed.isEmpty {
            let goals = parsedGoals(rawGoals)
            if !goals.isEmpty {
                profile.primaryGoalRaw = primaryGoal(for: goals).rawValue
                profile.goalDetail = "Onboarding goals: "
                    + goals.map(\.displayName).joined(separator: ", ")
            }
        }

        if let rawContext = defaults.string(forKey: trainingContextKey),
           let trainingContext = OnboardingTrainingContext(rawValue: rawContext) {
            profile.generalPreferences = replacingTaggedLine(
                in: profile.generalPreferences,
                prefix: trainingContextPrefix,
                value: trainingContext.displayName
            )
        }

        repository.profileDidChange(profile)
        synchronizeMovementConsideration(repository: repository, defaults: defaults)
        defaults.set(currentMigrationVersion, forKey: migrationVersionKey)
    }

    private static func synchronizeMovementConsideration(
        repository: HealthDataRepository,
        defaults: UserDefaults
    ) {
        guard defaults.object(forKey: movementNotesKey) != nil else { return }

        let notes = (defaults.string(forKey: movementNotesKey) ?? "").trimmed
        let existing = repository.allConsiderations().first {
            $0.title == movementConsiderationTitle
        }

        guard !notes.isEmpty else {
            if let existing, existing.status != .archived {
                repository.archiveConsideration(existing)
            }
            return
        }

        if let existing {
            existing.bodyAreaRaw = HealthBodyArea.other.rawValue
            existing.sideRaw = BodySide.unspecified.rawValue
            existing.categoryRaw = HealthConsiderationCategory.custom.rawValue
            existing.userDescription = notes
            existing.statusRaw = HealthConsiderationStatus.active.rawValue
            existing.confirmedByUser = true
            repository.considerationDidChange(existing)
        } else {
            repository.addConsideration(
                HealthConsideration(
                    title: movementConsiderationTitle,
                    bodyArea: .other,
                    side: .unspecified,
                    category: .custom,
                    userDescription: notes,
                    status: .active
                )
            )
        }
    }

    private static func parsedGoals(_ rawValue: String) -> [OnboardingGoal] {
        let selected = Set(
            rawValue
                .split(separator: ",")
                .compactMap { OnboardingGoal(rawValue: String($0)) }
        )
        return OnboardingGoal.allCases.filter(selected.contains)
    }

    private static func primaryGoal(for goals: [OnboardingGoal]) -> CoachGoal {
        if goals.contains(.strength) { return .buildStrength }
        if goals.contains(.fitness) { return .improveEndurance }
        return .generalHealth
    }

    private static func replacingTaggedLine(
        in existingValue: String?,
        prefix: String,
        value: String
    ) -> String {
        var lines = (existingValue ?? "")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { !$0.hasPrefix(prefix) }

        lines.append("\(prefix) \(value)")
        return lines.joined(separator: "\n")
    }
}

private enum OnboardingGoal: String, CaseIterable {
    case everydayHealth
    case strength
    case fitness
    case nutrition
    case consistency

    var displayName: String {
        switch self {
        case .everydayHealth: return "Everyday health"
        case .strength: return "Build strength"
        case .fitness: return "Improve fitness"
        case .nutrition: return "Understand nutrition"
        case .consistency: return "Build consistency"
        }
    }
}

private enum OnboardingTrainingContext: String {
    case home
    case gym
    case outdoors
    case mixed

    var displayName: String {
        switch self {
        case .home: return "Mostly at home"
        case .gym: return "Mostly at a gym"
        case .outdoors: return "Mostly outdoors"
        case .mixed: return "A mix of settings"
        }
    }
}

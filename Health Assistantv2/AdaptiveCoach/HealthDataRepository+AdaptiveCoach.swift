import Foundation
import SwiftData

// MARK: - Plain assistant snapshots

struct HealthConsiderationSnapshot: Codable, Equatable {
    var title: String
    var bodyArea: String
    var side: String
    var category: String
    var description: String
    var approximateWhen: String?
    var userGuidance: String?
    var userReported: Bool
}

struct BodyMetricTrendSnapshot: Codable, Equatable {
    var latestDate: Date
    var latestWeightKilograms: Double?
    var latestHeightCentimeters: Double?
    var weightChangeKilograms30Days: Double?
}

struct HealthProfileSnapshot: Codable, Equatable {
    var goal: String
    var goalDetail: String?
    var experienceLevel: String
    var preferredActivities: [String]
    var weeklyTrainingDays: Int?
    var preferredSessionMinutes: Int?
    var generalPreferences: String?
    var considerations: [HealthConsiderationSnapshot]
    var bodyMetricTrend: BodyMetricTrendSnapshot?
}

struct EquipmentSnapshot: Codable, Equatable {
    var name: String
    var category: String
    var capability: String
    var quantity: Int
    var minimumWeightKilograms: Double?
    var maximumWeightKilograms: Double?
    var resistanceDescription: String?
    var notes: String?
}

struct WorkoutLocationSnapshot: Codable, Equatable {
    var name: String
    var category: String
    var notes: String?
    var spaceLimitations: String?
    var equipment: [EquipmentSnapshot]
}

// MARK: - Adaptive coach repository

extension HealthDataRepository {
    // MARK: Profile

    /// Fetches the existing profile or creates the one local profile used by the app.
    /// Read-only assistant tools deliberately use `existingProfile()` instead.
    @discardableResult
    func currentProfile() -> HealthProfile {
        if let existing = existingProfile() { return existing }
        let profile = HealthProfile()
        context.insert(profile)
        persistCoachChanges()
        return profile
    }

    func existingProfile() -> HealthProfile? {
        fetchCoachModels(
            FetchDescriptor<HealthProfile>(
                sortBy: [SortDescriptor(\HealthProfile.createdAt, order: .forward)]
            )
        ).first
    }

    func profileDidChange(_ profile: HealthProfile) {
        profile.updatedAt = .now
        persistCoachChanges()
    }

    // MARK: User-reported considerations

    func addConsideration(_ consideration: HealthConsideration) {
        consideration.updatedAt = .now
        consideration.confirmedByUser = true
        consideration.sourceRaw = HealthConsiderationSource.userEntered.rawValue
        context.insert(consideration)
        persistCoachChanges()
    }

    func considerationDidChange(_ consideration: HealthConsideration) {
        consideration.updatedAt = .now
        consideration.confirmedByUser = true
        persistCoachChanges()
    }

    func archiveConsideration(_ consideration: HealthConsideration) {
        consideration.statusRaw = HealthConsiderationStatus.archived.rawValue
        consideration.updatedAt = .now
        persistCoachChanges()
    }

    func activeConsiderations() -> [HealthConsideration] {
        allConsiderations().filter {
            $0.status != .archived && $0.confirmedByUser
        }
    }

    func allConsiderations() -> [HealthConsideration] {
        fetchCoachModels(
            FetchDescriptor<HealthConsideration>(
                sortBy: [SortDescriptor(\HealthConsideration.updatedAt, order: .reverse)]
            )
        )
    }

    // MARK: Body metrics

    func addBodyMetric(_ entry: BodyMetricEntry) {
        context.insert(entry)
        persistCoachChanges()
    }

    func recentBodyMetrics(limit: Int = 90) -> [BodyMetricEntry] {
        Array(
            fetchCoachModels(
                FetchDescriptor<BodyMetricEntry>(
                    sortBy: [SortDescriptor(\BodyMetricEntry.timestamp, order: .reverse)]
                )
            ).prefix(max(limit, 0))
        )
    }

    func latestBodyMetric() -> BodyMetricEntry? {
        recentBodyMetrics(limit: 1).first
    }

    // MARK: Workout locations and equipment

    func addLocation(_ location: WorkoutLocation) {
        location.updatedAt = .now
        context.insert(location)
        persistCoachChanges()
    }

    func locationDidChange(_ location: WorkoutLocation) {
        location.updatedAt = .now
        persistCoachChanges()
    }

    func archiveLocation(_ location: WorkoutLocation) {
        location.isActive = false
        location.updatedAt = .now
        persistCoachChanges()
    }

    func restoreLocation(_ location: WorkoutLocation) {
        location.isActive = true
        location.updatedAt = .now
        persistCoachChanges()
    }

    func activeLocations() -> [WorkoutLocation] {
        allLocations().filter(\.isActive)
    }

    func allLocations() -> [WorkoutLocation] {
        fetchCoachModels(
            FetchDescriptor<WorkoutLocation>(
                sortBy: [SortDescriptor(\WorkoutLocation.updatedAt, order: .reverse)]
            )
        )
    }

    func addEquipment(_ item: EquipmentItem, to location: WorkoutLocation) {
        item.location = location
        item.updatedAt = .now
        context.insert(item)
        location.updatedAt = .now
        persistCoachChanges()
    }

    func equipmentDidChange(_ item: EquipmentItem) {
        item.updatedAt = .now
        item.location?.updatedAt = .now
        persistCoachChanges()
    }

    func removeEquipment(_ item: EquipmentItem) {
        let location = item.location
        context.delete(item)
        location?.updatedAt = .now
        persistCoachChanges()
    }

    // MARK: Compact AI context

    /// A read-only snapshot. It never creates a profile or mutates the store.
    func healthProfileSnapshot() -> HealthProfileSnapshot? {
        guard let profile = existingProfile() else { return nil }

        let considerationSnapshots = activeConsiderations().map {
            HealthConsiderationSnapshot(
                title: $0.title,
                bodyArea: $0.bodyArea.displayName,
                side: $0.side.displayName,
                category: $0.category.displayName,
                description: $0.userDescription,
                approximateWhen: $0.approximateWhen,
                userGuidance: $0.userGuidance,
                userReported: true
            )
        }

        return HealthProfileSnapshot(
            goal: profile.primaryGoal.displayName,
            goalDetail: profile.goalDetail,
            experienceLevel: profile.experienceLevel.displayName,
            preferredActivities: profile.preferredActivities,
            weeklyTrainingDays: profile.weeklyTrainingDays,
            preferredSessionMinutes: profile.preferredSessionMinutes,
            generalPreferences: profile.generalPreferences,
            considerations: considerationSnapshots,
            bodyMetricTrend: bodyMetricTrendSnapshot()
        )
    }

    func workoutLocationSnapshots() -> [WorkoutLocationSnapshot] {
        activeLocations().map { location in
            WorkoutLocationSnapshot(
                name: location.name,
                category: location.category.displayName,
                notes: location.notes,
                spaceLimitations: location.spaceLimitations,
                equipment: location.equipment
                    .filter(\.isAvailable)
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    .map {
                        EquipmentSnapshot(
                            name: $0.name,
                            category: $0.category.displayName,
                            capability: $0.capability.rawValue,
                            quantity: $0.quantity,
                            minimumWeightKilograms: $0.minWeightKilograms,
                            maximumWeightKilograms: $0.maxWeightKilograms,
                            resistanceDescription: $0.resistanceDescription,
                            notes: $0.notes
                        )
                    }
            )
        }
    }

    func bodyMetricTrendSnapshot() -> BodyMetricTrendSnapshot? {
        let entries = recentBodyMetrics(limit: 365)
        guard let latest = entries.first else { return nil }

        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: latest.timestamp)
        let comparison = cutoff.flatMap { date in
            entries
                .filter { $0.timestamp <= date && $0.weightKilograms != nil }
                .max { $0.timestamp < $1.timestamp }
        }

        let change: Double?
        if let latestWeight = latest.weightKilograms,
           let earlierWeight = comparison?.weightKilograms {
            change = latestWeight - earlierWeight
        } else {
            change = nil
        }

        return BodyMetricTrendSnapshot(
            latestDate: latest.timestamp,
            latestWeightKilograms: latest.weightKilograms,
            latestHeightCentimeters: latest.heightCentimeters,
            weightChangeKilograms30Days: change
        )
    }

    // MARK: Helpers

    private func fetchCoachModels<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        (try? context.fetch(descriptor)) ?? []
    }

    private func persistCoachChanges() {
        try? context.save()
    }
}

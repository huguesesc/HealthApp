import Foundation
import SwiftData

struct WorkoutPlanStepSnapshot: Codable, Equatable {
    var order: Int
    var type: String
    var title: String
    var instruction: String?
    var sets: Int?
    var reps: Int?
    var durationSeconds: Int?
    var distanceMeters: Double?
    var targetWeightKilograms: Double?
    var restSeconds: Int?
    var side: String?
    var equipment: String?
    var notes: String?
}

struct WorkoutPlanSnapshot: Codable, Equatable {
    var title: String
    var goal: String?
    var estimatedDurationMinutes: Int?
    var targetEffort: Int?
    var location: String?
    var equipmentSummary: String?
    var source: String
    var steps: [WorkoutPlanStepSnapshot]
}

extension HealthDataRepository {
    // MARK: Plans

    func addWorkoutPlan(_ plan: WorkoutPlan) {
        plan.updatedAt = .now
        context.insert(plan)
        normalizeStepOrder(in: plan)
        persistWorkoutPlanChanges()
    }

    func workoutPlanDidChange(_ plan: WorkoutPlan) {
        plan.title = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.updatedAt = .now
        normalizeStepOrder(in: plan)
        persistWorkoutPlanChanges()
    }

    func archiveWorkoutPlan(_ plan: WorkoutPlan) {
        plan.isArchived = true
        plan.updatedAt = .now
        persistWorkoutPlanChanges()
    }

    func restoreWorkoutPlan(_ plan: WorkoutPlan) {
        plan.isArchived = false
        plan.updatedAt = .now
        persistWorkoutPlanChanges()
    }

    func activeWorkoutPlans() -> [WorkoutPlan] {
        allWorkoutPlans().filter { !$0.isArchived }
    }

    func allWorkoutPlans() -> [WorkoutPlan] {
        fetchWorkoutPlanModels(
            FetchDescriptor<WorkoutPlan>(
                sortBy: [SortDescriptor(\WorkoutPlan.updatedAt, order: .reverse)]
            )
        )
    }

    // MARK: Steps

    func addWorkoutStep(_ step: WorkoutStep, to plan: WorkoutPlan) {
        step.order = plan.steps.count
        step.plan = plan
        step.updatedAt = .now
        context.insert(step)
        plan.updatedAt = .now
        normalizeStepOrder(in: plan)
        persistWorkoutPlanChanges()
    }

    func workoutStepDidChange(_ step: WorkoutStep) {
        step.updatedAt = .now
        step.plan?.updatedAt = .now
        persistWorkoutPlanChanges()
    }

    func removeWorkoutStep(_ step: WorkoutStep) {
        let plan = step.plan
        context.delete(step)
        if let plan {
            plan.updatedAt = .now
            normalizeStepOrder(in: plan, excluding: step.id)
        }
        persistWorkoutPlanChanges()
    }

    func moveWorkoutSteps(in plan: WorkoutPlan, from source: IndexSet, to destination: Int) {
        var ordered = plan.orderedSteps
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, step) in ordered.enumerated() {
            step.order = index
            step.updatedAt = .now
        }
        plan.updatedAt = .now
        persistWorkoutPlanChanges()
    }

    func replaceWorkoutSteps(in plan: WorkoutPlan, with steps: [WorkoutStep]) {
        for oldStep in plan.steps {
            context.delete(oldStep)
        }
        plan.steps.removeAll()

        for (index, step) in steps.enumerated() {
            step.order = index
            step.plan = plan
            context.insert(step)
        }
        plan.updatedAt = .now
        persistWorkoutPlanChanges()
    }

    // MARK: Location snapshots

    func applyWorkoutLocationSnapshot(_ location: WorkoutLocation?, to plan: WorkoutPlan) {
        guard let location else {
            plan.locationIDSnapshot = nil
            plan.locationNameSnapshot = nil
            plan.locationCategoryRawSnapshot = nil
            plan.equipmentSummarySnapshot = nil
            plan.updatedAt = .now
            persistWorkoutPlanChanges()
            return
        }

        plan.locationIDSnapshot = location.id
        plan.locationNameSnapshot = location.name
        plan.locationCategoryRawSnapshot = location.categoryRaw
        plan.equipmentSummarySnapshot = availableEquipmentNames(in: location)
            .joined(separator: ", ")
        plan.updatedAt = .now
        persistWorkoutPlanChanges()
    }

    func matchingActiveLocation(named name: String?) -> WorkoutLocation? {
        guard let cleaned = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !cleaned.isEmpty else { return nil }
        return activeLocations().first {
            $0.name.caseInsensitiveCompare(cleaned) == .orderedSame
        }
    }

    func availableEquipmentNames(in location: WorkoutLocation) -> [String] {
        location.equipment
            .filter(\.isAvailable)
            .map(\.name)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func isEquipmentNameAvailable(_ name: String?, at location: WorkoutLocation?) -> Bool {
        guard let location,
              let cleaned = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !cleaned.isEmpty else { return false }
        return location.equipment.contains {
            $0.isAvailable && (
                $0.name.caseInsensitiveCompare(cleaned) == .orderedSame
                    || $0.category.displayName.caseInsensitiveCompare(cleaned) == .orderedSame
            )
        }
    }

    // MARK: Compact snapshots

    func workoutPlanSnapshots(limit: Int = 20) -> [WorkoutPlanSnapshot] {
        Array(activeWorkoutPlans().prefix(max(limit, 0))).map { plan in
            WorkoutPlanSnapshot(
                title: plan.title,
                goal: plan.goalText,
                estimatedDurationMinutes: plan.estimatedDurationMinutes,
                targetEffort: plan.targetEffort,
                location: plan.locationNameSnapshot,
                equipmentSummary: plan.equipmentSummarySnapshot,
                source: plan.source.displayName,
                steps: plan.orderedSteps.map {
                    WorkoutPlanStepSnapshot(
                        order: $0.order,
                        type: $0.type.displayName,
                        title: $0.title,
                        instruction: $0.instruction,
                        sets: $0.sets,
                        reps: $0.reps,
                        durationSeconds: $0.durationSeconds,
                        distanceMeters: $0.distanceMeters,
                        targetWeightKilograms: $0.targetWeightKilograms,
                        restSeconds: $0.restSeconds,
                        side: $0.side == .none ? nil : $0.side.displayName,
                        equipment: $0.equipmentNameSnapshot,
                        notes: $0.notes
                    )
                }
            )
        }
    }

    // MARK: Helpers

    private func normalizeStepOrder(in plan: WorkoutPlan, excluding excludedID: UUID? = nil) {
        let ordered = plan.steps
            .filter { $0.id != excludedID }
            .sorted {
                if $0.order == $1.order { return $0.createdAt < $1.createdAt }
                return $0.order < $1.order
            }
        for (index, step) in ordered.enumerated() {
            step.order = index
        }
    }

    private func fetchWorkoutPlanModels<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        (try? context.fetch(descriptor)) ?? []
    }

    private func persistWorkoutPlanChanges() {
        try? context.save()
    }
}
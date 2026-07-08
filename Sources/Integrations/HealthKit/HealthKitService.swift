import Foundation
import HealthKit

enum HealthKitServiceError: LocalizedError {
    case unavailable
    case authorizationDenied
    case missingType(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Health is not available on this device."
        case .authorizationDenied:
            return "Apple Health permission was not granted."
        case .missingType(let name):
            return "Apple Health does not expose \(name) on this device."
        }
    }
}

final class HealthKitService {
    private let store: HKHealthStore
    private let calendar: Calendar

    init(store: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitServiceError.unavailable }

        let readTypes = try healthTypesToRead()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: Set<HKSampleType>(), read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitServiceError.authorizationDenied)
                }
            }
        }
    }

    func fetchDailyImports(days: Int = 30) async throws -> [HealthKitDailyImport] {
        guard isAvailable else { throw HealthKitServiceError.unavailable }
        let boundedDays = min(max(days, 1), 60)
        let end = Date()
        let startOfToday = calendar.startOfDay(for: end)
        let start = calendar.date(byAdding: .day, value: -(boundedDays - 1), to: startOfToday)
            ?? startOfToday

        var imports = seedImports(from: start, through: startOfToday)

        let steps = try await fetchDailyCumulative(
            .stepCount,
            unit: .count(),
            start: start,
            end: end
        )
        merge(steps, into: &imports) { $0.stepCount = Int($1.rounded()) }

        let activeEnergy = try await fetchDailyCumulative(
            .activeEnergyBurned,
            unit: .kilocalorie(),
            start: start,
            end: end
        )
        merge(activeEnergy, into: &imports) { $0.activeEnergyKcal = Int($1.rounded()) }

        let exercise = try await fetchDailyCumulative(
            .appleExerciseTime,
            unit: .minute(),
            start: start,
            end: end
        )
        merge(exercise, into: &imports) { $0.exerciseMinutes = Int($1.rounded()) }

        let restingHeartRate = try await fetchDailyAverage(
            .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: HKUnit.minute()),
            start: start,
            end: end
        )
        merge(restingHeartRate, into: &imports) { $0.restingHeartRate = Int($1.rounded()) }

        try await mergeWorkouts(start: start, end: end, into: &imports)
        try await mergeSleep(start: start, end: end, into: &imports)

        return imports.values
            .filter { !$0.isEmpty }
            .sorted { $0.date < $1.date }
    }

    private func healthTypesToRead() throws -> Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        for identifier in [
            HKQuantityTypeIdentifier.stepCount,
            .activeEnergyBurned,
            .appleExerciseTime,
            .restingHeartRate,
        ] {
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
                throw HealthKitServiceError.missingType(identifier.rawValue)
            }
            types.insert(type)
        }
        guard let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitServiceError.missingType("sleepAnalysis")
        }
        types.insert(sleep)
        return types
    }

    private func seedImports(from start: Date, through endOfDay: Date) -> [Date: HealthKitDailyImport] {
        var result: [Date: HealthKitDailyImport] = [:]
        var day = calendar.startOfDay(for: start)
        while day <= endOfDay {
            result[day] = HealthKitDailyImport(date: day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    private func merge(
        _ values: [Date: Double],
        into imports: inout [Date: HealthKitDailyImport],
        assign: (inout HealthKitDailyImport, Double) -> Void
    ) {
        for (date, value) in values {
            let day = calendar.startOfDay(for: date)
            var daily = imports[day] ?? HealthKitDailyImport(date: day)
            assign(&daily, value)
            imports[day] = daily
        }
    }

    private func fetchDailyCumulative(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> [Date: Double] {
        try await fetchDailyStatistics(
            identifier,
            unit: unit,
            options: .cumulativeSum,
            start: start,
            end: end
        )
    }

    private func fetchDailyAverage(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> [Date: Double] {
        try await fetchDailyStatistics(
            identifier,
            unit: unit,
            options: .discreteAverage,
            start: start,
            end: end
        )
    }

    private func fetchDailyStatistics(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        options: HKStatisticsOptions,
        start: Date,
        end: Date
    ) async throws -> [Date: Double] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitServiceError.missingType(identifier.rawValue)
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: [.strictStartDate]
        )

        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[Date: Double], Error>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: calendar.startOfDay(for: start),
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var result: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let quantity: HKQuantity?
                    if options.contains(.cumulativeSum) {
                        quantity = statistics.sumQuantity()
                    } else {
                        quantity = statistics.averageQuantity()
                    }
                    if let quantity {
                        result[calendar.startOfDay(for: statistics.startDate)] = quantity.doubleValue(for: unit)
                    }
                }
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }

    private func mergeWorkouts(
        start: Date,
        end: Date,
        into imports: inout [Date: HealthKitDailyImport]
    ) async throws {
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: [.strictStartDate]
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }

        var summariesByDay: [Date: [String]] = [:]
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startDate)
            var daily = imports[day] ?? HealthKitDailyImport(date: day)
            daily.workoutCount = (daily.workoutCount ?? 0) + 1
            imports[day] = daily

            let minutes = Int((workout.duration / 60).rounded())
            summariesByDay[day, default: []].append("\(workoutName(workout.workoutActivityType)), \(minutes) min")
        }

        for (day, summaries) in summariesByDay {
            var daily = imports[day] ?? HealthKitDailyImport(date: day)
            daily.workoutSummary = summaries.prefix(3).joined(separator: "; ")
            imports[day] = daily
        }
    }

    private func mergeSleep(
        start: Date,
        end: Date,
        into imports: inout [Date: HealthKitDailyImport]
    ) async throws {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitServiceError.missingType("sleepAnalysis")
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: []
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[HKCategorySample], Error>) in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }

        var secondsByDay: [Date: TimeInterval] = [:]
        for sample in samples where isAsleep(sample) {
            let day = calendar.startOfDay(for: sample.endDate)
            secondsByDay[day, default: 0] += sample.endDate.timeIntervalSince(sample.startDate)
        }

        for (day, seconds) in secondsByDay {
            var daily = imports[day] ?? HealthKitDailyImport(date: day)
            daily.sleepHours = seconds / 3600
            imports[day] = daily
        }
    }

    private func isAsleep(_ sample: HKCategorySample) -> Bool {
        guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else {
            return false
        }
        switch value {
        case .asleep, .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified:
            return true
        default:
            return false
        }
    }

    private func workoutName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Ride"
        case .traditionalStrengthTraining: return "Strength"
        case .functionalStrengthTraining: return "Functional strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .swimming: return "Swim"
        case .coreTraining: return "Core"
        case .flexibility: return "Mobility"
        default: return "Workout"
        }
    }
}

private extension HealthKitDailyImport {
    var isEmpty: Bool {
        stepCount == nil
            && activeEnergyKcal == nil
            && exerciseMinutes == nil
            && workoutCount == nil
            && workoutSummary == nil
            && sleepHours == nil
            && restingHeartRate == nil
    }
}

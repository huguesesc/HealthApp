import Foundation
import Testing
@testable import Health_Assistantv2

struct ExerciseCatalogLoadingTests {
    @Test func resolvesStableLegacyAndNormalizedReferencesFromInjectedManifest() async throws {
        let pushUp = exercise(
            id: "bodyweight.push_up",
            displayName: "Push-Up",
            aliases: ["Press up"],
            legacyIDs: ["bodyweight.press_up"]
        )
        let repository = ExerciseCatalogRepository(
            dataProvider: StaticCatalogDataProvider(data: try manifestData(exercises: [pushUp]))
        )

        let stable = await repository.resolve(reference: "bodyweight.push_up")
        let legacy = await repository.resolve(reference: "bodyweight.press_up")
        let displayName = await repository.resolve(reference: "  push up ")
        let alias = await repository.resolve(reference: "PRESS-UP")

        #expect(stable?.id.rawValue == "bodyweight.push_up")
        #expect(legacy?.id.rawValue == "bodyweight.push_up")
        #expect(displayName?.id.rawValue == "bodyweight.push_up")
        #expect(alias?.id.rawValue == "bodyweight.push_up")
    }

    @Test func corruptJSONProducesAnUnavailableDiagnostic() async {
        let repository = ExerciseCatalogRepository(
            dataProvider: StaticCatalogDataProvider(data: Data("not json".utf8))
        )

        switch await repository.loadState() {
        case .unavailable(.decodingFailed(let description)):
            #expect(description == "Unable to decode exercise catalogue manifest.")
        default:
            #expect(Bool(false))
        }
    }

    @Test func unsupportedNewerManifestVersionProducesAnUnavailableDiagnostic() async throws {
        let repository = ExerciseCatalogRepository(
            dataProvider: StaticCatalogDataProvider(
                data: try manifestData(schemaVersion: 2, exercises: [])
            )
        )

        switch await repository.loadState() {
        case .unavailable(.unsupportedSchemaVersion(let version)):
            #expect(version == 2)
        default:
            #expect(Bool(false))
        }
    }

    @Test func duplicateStableIDProducesDeterministicValidationFailure() async throws {
        let first = exercise(id: "bodyweight.squat", displayName: "Squat")
        let duplicate = exercise(id: "bodyweight.squat", displayName: "Other squat")
        let repository = ExerciseCatalogRepository(
            dataProvider: StaticCatalogDataProvider(
                data: try manifestData(exercises: [first, duplicate])
            )
        )

        switch await repository.loadState() {
        case .unavailable(.validationFailed(let messages)):
            #expect(messages == ["Duplicate stable ID: bodyweight.squat."])
        default:
            #expect(Bool(false))
        }
    }

    @Test func duplicateLegacyIDProducesDeterministicValidationFailure() async throws {
        let first = exercise(
            id: "bodyweight.squat",
            displayName: "Squat",
            legacyIDs: ["bodyweight.air_squat"]
        )
        let second = exercise(
            id: "bodyweight.lunge",
            displayName: "Lunge",
            legacyIDs: ["bodyweight.air_squat"]
        )
        let repository = ExerciseCatalogRepository(
            dataProvider: StaticCatalogDataProvider(
                data: try manifestData(exercises: [first, second])
            )
        )

        switch await repository.loadState() {
        case .unavailable(.validationFailed(let messages)):
            #expect(messages == ["Duplicate legacy ID: bodyweight.air_squat."])
        default:
            #expect(Bool(false))
        }
    }

    @Test func collidingNormalizedDisplayNamesAndAliasesMakeTheCatalogueUnavailable() async throws {
        let first = exercise(
            id: "bodyweight.squat",
            displayName: "Bodyweight squat",
            aliases: ["Air squat"]
        )
        let second = exercise(
            id: "bodyweight.lunge",
            displayName: "Air-Squat"
        )
        let repository = ExerciseCatalogRepository(
            dataProvider: StaticCatalogDataProvider(
                data: try manifestData(exercises: [first, second])
            )
        )

        switch await repository.loadState() {
        case .unavailable(.validationFailed(let messages)):
            #expect(messages == ["Ambiguous normalized reference: airsquat."])
        default:
            #expect(Bool(false))
        }
    }

    @Test func missingDataProviderResourceProducesAnUnavailableDiagnostic() async {
        let repository = ExerciseCatalogRepository(
            dataProvider: StaticCatalogDataProvider(data: nil)
        )

        switch await repository.loadState() {
        case .unavailable(.resourceNotFound(let name)):
            #expect(name == "catalog.json")
        default:
            #expect(Bool(false))
        }
    }

    @Test func resolverNeverUsesSubstringMatching() async throws {
        let exercise = exercise(
            id: "dumbbell.biceps_curl",
            displayName: "Dumbbell biceps curl",
            aliases: ["Arm curl"]
        )
        let repository = ExerciseCatalogRepository(
            dataProvider: StaticCatalogDataProvider(data: try manifestData(exercises: [exercise]))
        )

        let resolved = await repository.resolve(reference: "curl")

        #expect(resolved == nil)
    }

    @Test func repositoryLoadsItsProviderOnlyOnce() async throws {
        let dataProvider = CountingCatalogDataProvider(
            data: try manifestData(exercises: [
                exercise(id: "bodyweight.squat", displayName: "Squat")
            ])
        )
        let repository = ExerciseCatalogRepository(dataProvider: dataProvider)

        _ = await repository.loadState()
        _ = await repository.resolve(reference: "bodyweight.squat")
        _ = await repository.loadState()

        let loadCount = await dataProvider.loadCount()

        #expect(loadCount == 1)
    }

    @Test func repositorySharesAnInFlightLoadAcrossConcurrentCallers() async throws {
        let dataProvider = BlockingCatalogDataProvider(
            data: try manifestData(exercises: [
                exercise(id: "bodyweight.squat", displayName: "Squat")
            ])
        )
        let repository = ExerciseCatalogRepository(dataProvider: dataProvider)

        let firstCaller = Task { await repository.loadState() }
        await dataProvider.waitUntilFirstLoadIsBlocked()

        let concurrentCallers = (0..<20).map { _ in
            Task { await repository.loadState() }
        }
        for _ in concurrentCallers {
            await Task.yield()
        }

        let loadCountWhileBlocked = await dataProvider.loadCount()
        #expect(loadCountWhileBlocked == 1)

        await dataProvider.releaseFirstLoad()
        _ = await firstCaller.value
        for caller in concurrentCallers {
            _ = await caller.value
        }

        let finalLoadCount = await dataProvider.loadCount()
        #expect(finalLoadCount == 1)
    }

    @Test func fakeRepositoryCanSatisfyTheInjectedRepositoryProtocol() async {
        let definition = exercise(id: "bodyweight.squat", displayName: "Squat")
        let fake: any ExerciseCatalogRepositoryProviding = FakeCatalogRepository(
            state: .available(
                ExerciseCatalogManifest(catalogSchemaVersion: 1, exercises: [definition])
            ),
            resolvedDefinition: definition
        )

        let state = await fake.loadState()
        let resolved = await fake.resolve(reference: "anything")

        #expect(state == .available(
            ExerciseCatalogManifest(catalogSchemaVersion: 1, exercises: [definition])
        ))
        #expect(resolved == definition)
    }

    private func manifestData(
        schemaVersion: Int = 1,
        exercises: [ExerciseDefinition]
    ) throws -> Data {
        try JSONEncoder().encode(
            ExerciseCatalogManifest(catalogSchemaVersion: schemaVersion, exercises: exercises)
        )
    }

    private func exercise(
        id: String,
        displayName: String,
        aliases: [String]? = nil,
        legacyIDs: [String]? = nil
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: ExerciseID(rawValue: id)!,
            schemaVersion: 1,
            displayName: displayName,
            category: ExerciseCategory(rawValue: "test"),
            movementPattern: ExerciseMovementPattern(rawValue: "test"),
            exerciseType: ExerciseType(rawValue: "test"),
            equipment: ExerciseEquipmentRequirements(required: [
                ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "none"), quantity: 1)
            ]),
            trackingMode: ExerciseTrackingMode(rawValue: "test"),
            instructions: [],
            lifecycle: ExerciseLifecycle(status: .active, replacementExerciseID: nil),
            media: nil,
            aliases: aliases,
            legacyIDs: legacyIDs?.compactMap(ExerciseID.init(rawValue:)),
            guidance: nil,
            environmentRequirements: nil
        )
    }
}

private struct StaticCatalogDataProvider: ExerciseCatalogDataProvider {
    let data: Data?

    func loadCatalogData() async throws -> Data? {
        data
    }
}

private actor CountingCatalogDataProvider: ExerciseCatalogDataProvider {
    private let data: Data?
    private var numberOfLoads = 0

    init(data: Data?) {
        self.data = data
    }

    func loadCatalogData() async throws -> Data? {
        numberOfLoads += 1
        return data
    }

    func loadCount() async -> Int {
        numberOfLoads
    }
}

private actor BlockingCatalogDataProvider: ExerciseCatalogDataProvider {
    private let data: Data?
    private var numberOfLoads = 0
    private var firstLoadRelease: CheckedContinuation<Void, Never>?
    private var firstLoadStarted: CheckedContinuation<Void, Never>?

    init(data: Data?) {
        self.data = data
    }

    func loadCatalogData() async throws -> Data? {
        numberOfLoads += 1
        if numberOfLoads == 1 {
            await withCheckedContinuation { continuation in
                firstLoadRelease = continuation
                firstLoadStarted?.resume()
                firstLoadStarted = nil
            }
        }
        return data
    }

    func waitUntilFirstLoadIsBlocked() async {
        guard firstLoadRelease == nil else {
            return
        }
        await withCheckedContinuation { continuation in
            firstLoadStarted = continuation
        }
    }

    func releaseFirstLoad() {
        firstLoadRelease?.resume()
        firstLoadRelease = nil
    }

    func loadCount() -> Int {
        numberOfLoads
    }
}

private struct FakeCatalogRepository: ExerciseCatalogRepositoryProviding {
    let state: ExerciseCatalogLoadState
    let resolvedDefinition: ExerciseDefinition?

    func loadState() async -> ExerciseCatalogLoadState {
        state
    }

    func resolve(reference: String) async -> ExerciseDefinition? {
        resolvedDefinition
    }
}

import Foundation

struct BundledExerciseCatalogDataProvider: ExerciseCatalogDataProvider {
    private let resourceName: String
    private let resourceExtension: String

    init(resourceName: String = "catalog", resourceExtension: String = "json") {
        self.resourceName = resourceName
        self.resourceExtension = resourceExtension
    }

    func loadCatalogData() async throws -> Data? {
        guard let resourceURL = Bundle.main.url(
            forResource: resourceName,
            withExtension: resourceExtension
        ) else {
            return nil
        }
        return try Data(contentsOf: resourceURL)
    }
}

actor BundledExerciseCatalogRepository: ExerciseCatalogRepositoryProviding {
    private let repository: ExerciseCatalogRepository

    init(resourceName: String = "catalog", resourceExtension: String = "json") {
        repository = ExerciseCatalogRepository(
            dataProvider: BundledExerciseCatalogDataProvider(
                resourceName: resourceName,
                resourceExtension: resourceExtension
            )
        )
    }

    func loadState() async -> ExerciseCatalogLoadState {
        await repository.loadState()
    }

    func resolve(reference: String) async -> ExerciseDefinition? {
        await repository.resolve(reference: reference)
    }
}

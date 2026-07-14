import Foundation

enum ExerciseCatalogLoadState: Hashable, Sendable {
    case available(ExerciseCatalogManifest)
    case unavailable(ExerciseCatalogError)
}

protocol ExerciseCatalogRepositoryProviding: Sendable {
    func loadState() async -> ExerciseCatalogLoadState
    func resolve(reference: String) async -> ExerciseDefinition?
}

actor ExerciseCatalogRepository: ExerciseCatalogRepositoryProviding {
    private let loader: ExerciseCatalogLoader
    private var cachedLoadResult: Result<ExerciseCatalogIndex, ExerciseCatalogError>?

    init(dataProvider: any ExerciseCatalogDataProvider) {
        loader = ExerciseCatalogLoader(dataProvider: dataProvider)
    }

    func loadState() async -> ExerciseCatalogLoadState {
        switch await loadResult() {
        case .success(let catalog):
            return .available(catalog.manifest)
        case .failure(let error):
            return .unavailable(error)
        }
    }

    func resolve(reference: String) async -> ExerciseDefinition? {
        switch await loadResult() {
        case .success(let catalog):
            return catalog.resolve(reference: reference)
        case .failure:
            return nil
        }
    }

    private func loadResult() async -> Result<ExerciseCatalogIndex, ExerciseCatalogError> {
        if let cachedLoadResult {
            return cachedLoadResult
        }

        let loadResult = await loader.load()
        cachedLoadResult = loadResult
        return loadResult
    }
}

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
    private var inFlightLoadTask: Task<Result<ExerciseCatalogIndex, ExerciseCatalogError>, Never>?

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

        if let inFlightLoadTask {
            return await inFlightLoadTask.value
        }

        let loader = loader
        let loadTask = Task.detached {
            await loader.load()
        }
        inFlightLoadTask = loadTask

        let loadResult = await loadTask.value
        cachedLoadResult = loadResult
        inFlightLoadTask = nil
        return loadResult
    }
}

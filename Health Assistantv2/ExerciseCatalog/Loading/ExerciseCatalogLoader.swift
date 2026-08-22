import Foundation

struct ExerciseCatalogManifest: Codable, Hashable, Sendable {
    let catalogSchemaVersion: Int
    let exercises: [ExerciseDefinition]
}

private struct ExerciseCatalogVersionHeader: Decodable {
    let catalogSchemaVersion: Int
}

protocol ExerciseCatalogDataProvider: Sendable {
    func loadCatalogData() async throws -> Data?
}

struct ExerciseCatalogLoader: Sendable {
    private let dataProvider: any ExerciseCatalogDataProvider

    init(dataProvider: any ExerciseCatalogDataProvider) {
        self.dataProvider = dataProvider
    }

    func load() async -> Result<ExerciseCatalogIndex, ExerciseCatalogError> {
        do {
            guard let data = try await dataProvider.loadCatalogData() else {
                return .failure(.resourceNotFound(name: "catalog.json"))
            }

            let decoder = JSONDecoder()
            let versionHeader = try decoder.decode(ExerciseCatalogVersionHeader.self, from: data)
            guard versionHeader.catalogSchemaVersion == 1 else {
                return .failure(.unsupportedSchemaVersion(versionHeader.catalogSchemaVersion))
            }
            let manifest = try decoder.decode(ExerciseCatalogManifest.self, from: data)
            return .success(try ExerciseCatalogIndex(manifest: manifest))
        } catch let error as ExerciseCatalogError {
            return .failure(error)
        } catch {
            return .failure(
                .decodingFailed(description: "Unable to decode exercise catalogue manifest.")
            )
        }
    }
}

struct ExerciseCatalogIndex: Sendable {
    let manifest: ExerciseCatalogManifest

    private let exercisesByStableID: [ExerciseID: ExerciseDefinition]
    private let exercisesByLegacyID: [ExerciseID: ExerciseDefinition]
    private let exercisesByNormalizedReference: [String: ExerciseDefinition]

    init(manifest: ExerciseCatalogManifest) throws {
        self.manifest = manifest

        let stableIDClaims = Dictionary(grouping: manifest.exercises, by: \.id)
        let duplicateStableIDs = stableIDClaims
            .filter { $0.value.count > 1 }
            .map(\.key)
            .sorted { $0.rawValue < $1.rawValue }

        var legacyIDIndex: [ExerciseID: ExerciseDefinition] = [:]
        var duplicateLegacyIDs: Set<ExerciseID> = []
        var legacyIDsCollidingWithStableIDs: Set<ExerciseID> = []
        for exercise in manifest.exercises {
            for legacyID in exercise.legacyIDs ?? [] {
                if stableIDClaims[legacyID] != nil {
                    legacyIDsCollidingWithStableIDs.insert(legacyID)
                }
                if legacyIDIndex[legacyID] == nil {
                    legacyIDIndex[legacyID] = exercise
                } else {
                    duplicateLegacyIDs.insert(legacyID)
                }
            }
        }

        var normalizedReferenceIndex: [String: ExerciseDefinition] = [:]
        var ambiguousNormalizedReferences: Set<String> = []
        for exercise in manifest.exercises {
            let normalizedReferences = Set(
                ExerciseReferenceNormalization.references(for: exercise)
                    .compactMap(ExerciseReferenceNormalization.normalized)
            )
            for normalizedReference in normalizedReferences {
                guard let existing = normalizedReferenceIndex[normalizedReference] else {
                    normalizedReferenceIndex[normalizedReference] = exercise
                    continue
                }
                if existing.id != exercise.id {
                    ambiguousNormalizedReferences.insert(normalizedReference)
                }
            }
        }

        let validationMessages = duplicateStableIDs.map {
            "Duplicate stable ID: \($0.rawValue)."
        } + duplicateLegacyIDs.sorted { $0.rawValue < $1.rawValue }.map {
            "Duplicate legacy ID: \($0.rawValue)."
        } + legacyIDsCollidingWithStableIDs.sorted { $0.rawValue < $1.rawValue }.map {
            "Legacy ID collides with stable ID: \($0.rawValue)."
        } + ambiguousNormalizedReferences.sorted().map {
            "Ambiguous normalized reference: \($0)."
        }
        guard validationMessages.isEmpty else {
            throw ExerciseCatalogError.validationFailed(messages: validationMessages)
        }

        exercisesByStableID = Dictionary(
            manifest.exercises.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        exercisesByLegacyID = legacyIDIndex
        exercisesByNormalizedReference = normalizedReferenceIndex
    }

    func resolve(reference: String) -> ExerciseDefinition? {
        if let stableID = ExerciseID(rawValue: reference),
           let exercise = exercisesByStableID[stableID] {
            return exercise
        }
        if let legacyID = ExerciseID(rawValue: reference),
           let exercise = exercisesByLegacyID[legacyID] {
            return exercise
        }
        guard let normalizedReference = ExerciseReferenceNormalization.normalized(reference) else {
            return nil
        }
        return exercisesByNormalizedReference[normalizedReference]
    }
}

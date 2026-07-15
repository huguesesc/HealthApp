import Foundation

protocol ExerciseMediaResolving: Sendable {
    func assetName(for key: String) -> String?
}

enum ExerciseMediaResolverError: Error, Equatable, Sendable {
    case resourceNotFound(String)
    case unsupportedSchemaVersion(Int)
    case duplicateKey(String)
}

struct DictionaryExerciseMediaResolver: ExerciseMediaResolving {
    let assetNamesByKey: [String: String]

    func assetName(for key: String) -> String? {
        assetNamesByKey[key]
    }
}

struct BundledExerciseMediaResolver: ExerciseMediaResolving {
    private static let supportedSchemaVersion = 1

    private let assetNamesByKey: [String: String]

    init(
        bundle: Bundle = .main,
        resourceName: String = "media-index"
    ) throws {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw ExerciseMediaResolverError.resourceNotFound("\(resourceName).json")
        }
        try self.init(data: Data(contentsOf: url))
    }

    init(data: Data) throws {
        let index = try JSONDecoder().decode(ExerciseMediaIndex.self, from: data)
        guard index.schemaVersion == Self.supportedSchemaVersion else {
            throw ExerciseMediaResolverError.unsupportedSchemaVersion(index.schemaVersion)
        }

        var resolved: [String: String] = [:]
        for item in index.media {
            guard resolved[item.key] == nil else {
                throw ExerciseMediaResolverError.duplicateKey(item.key)
            }
            resolved[item.key] = item.assetName
        }
        assetNamesByKey = resolved
    }

    func assetName(for key: String) -> String? {
        assetNamesByKey[key]
    }
}

private struct ExerciseMediaIndex: Decodable {
    let schemaVersion: Int
    let media: [ExerciseMediaIndexEntry]
}

private struct ExerciseMediaIndexEntry: Decodable {
    let key: String
    let assetName: String
}

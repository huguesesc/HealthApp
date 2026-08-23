import Foundation

enum ExerciseCatalogError: Error, Hashable, Sendable {
    case resourceNotFound(name: String)
    case decodingFailed(description: String)
    case unsupportedSchemaVersion(Int)
    case validationFailed(messages: [String])
}

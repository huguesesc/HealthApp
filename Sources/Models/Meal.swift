import Foundation
import SwiftData

/// A meal logged in natural language, with an optional AI-produced estimate.
@Model
final class Meal {
    var timestamp: Date
    var rawText: String

    // Optional estimate — populated only after an AI call. All optional so a meal
    // can be logged and stored with no network access.
    var calories: Int?
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
    /// 0.0–1.0 rough confidence reported by the model.
    var confidence: Double?
    /// Free-text caveat, e.g. portion-size uncertainty.
    var uncertaintyNote: String?

    init(timestamp: Date = .now, rawText: String) {
        self.timestamp = timestamp
        self.rawText = rawText
    }
}

import Foundation

/// The single seam between the app and any AI provider. Nothing outside the `AI`
/// folder should know which model or provider is used. When a paid/premium tier or
/// a backend proxy is introduced, it is just another `AIClient` implementation
/// pointing at your server — no other code changes.
protocol AIClient {
    /// Text → nutrition estimate.
    func parseMeal(text: String) async throws -> MealEstimate

    /// Natural-language workout description → structured sets.
    func parseWorkout(text: String) async throws -> ParsedWorkout

    /// A short, hedged end-of-day summary from the day's data.
    func summarizeDay(_ context: DailyContext) async throws -> DailySummaryResult

    /// The central assistant: answer a question using compact recent history.
    func ask(_ question: String, recent: [RollupSnapshot]) async throws -> String

    /// One round of the agentic chat loop: send the conversation plus tool
    /// definitions, get back the assistant's text and any tool calls. The caller
    /// (ChatEngine) executes the tools and loops until there are none.
    func chat(_ turns: [ChatTurn], tools: [ChatToolDef], system: String) async throws -> ChatReply

    /// FUTURE (premium): estimate nutrition from a food photo. Not implemented yet
    /// — implementations should throw `AIClientError.notImplemented`.
    func estimateMeal(image: Data) async throws -> MealEstimate
}

// MARK: - Intent-level DTOs (provider-agnostic)

struct MealEstimate: Codable, Equatable {
    var calories: Int
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    /// 0.0–1.0
    var confidence: Double
    var uncertaintyNote: String?
}

struct ParsedWorkout: Codable, Equatable {
    var type: String
    var perceivedEffort: Int?
    var sets: [ParsedSet]
}

struct ParsedSet: Codable, Equatable {
    var exerciseName: String
    var reps: Int
    var weightKilograms: Double?
}

/// Everything the day-summary prompt is allowed to see. Assembled from SwiftData by
/// `HealthDataRepository.todayContext()`. Screen-time is a coarse signal only.
struct DailyContext: Codable, Equatable {
    var date: Date
    /// Each meal as logged, with any macro estimate inlined for the model.
    var meals: [String]
    var totalCalories: Int?
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
    var workoutSummary: String?
    var sleepSummary: String?
    /// Compact Apple Health import summary, if the user authorized HealthKit.
    var healthSummary: String?
    var checkIn: [String: Int]
    var checkInNote: String?
    /// Current logging streak in days, for encouragement.
    var streakDays: Int?
    var screenTimeExceededLimit: Bool?
}

struct DailySummaryResult: Codable, Equatable {
    var text: String
    var modelUsed: String
}

enum AIClientError: Error {
    case missingAPIKey
    case badResponse(statusCode: Int, body: String)
    case decodingFailed(String)
    case notImplemented
}

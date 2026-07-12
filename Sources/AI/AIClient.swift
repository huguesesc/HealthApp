import Foundation

/// The single seam between the app and any AI provider. Nothing outside the `AI`
/// folder should know which model or provider is used. When a paid/premium tier or
/// a backend proxy is introduced, it is just another `AIClient` implementation
/// pointing at your server — no other code changes.
protocol AIClient {
    func parseMeal(text: String) async throws -> MealEstimate
    func parseWorkout(text: String) async throws -> ParsedWorkout
    func summarizeDay(_ context: DailyContext) async throws -> DailySummaryResult
    func ask(_ question: String, recent: [RollupSnapshot]) async throws -> String
    func chat(_ turns: [ChatTurn], tools: [ChatToolDef], system: String) async throws -> ChatReply
    func estimateMeal(image: Data) async throws -> MealEstimate
}

// MARK: - Intent-level DTOs (provider-agnostic)

struct MealEstimate: Codable, Equatable {
    var calories: Int
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var confidence: Double
    var uncertaintyNote: String?

    init(
        calories: Int,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        confidence: Double,
        uncertaintyNote: String?
    ) {
        self.calories = max(calories, 0)
        self.proteinGrams = max(proteinGrams, 0)
        self.carbsGrams = max(carbsGrams, 0)
        self.fatGrams = max(fatGrams, 0)
        self.confidence = min(max(confidence, 0), 1)
        self.uncertaintyNote = uncertaintyNote
    }

    private enum CodingKeys: String, CodingKey {
        case calories, proteinGrams, carbsGrams, fatGrams, confidence, uncertaintyNote
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            calories: values.flexibleInt(forKey: .calories) ?? 0,
            proteinGrams: values.flexibleDouble(forKey: .proteinGrams) ?? 0,
            carbsGrams: values.flexibleDouble(forKey: .carbsGrams) ?? 0,
            fatGrams: values.flexibleDouble(forKey: .fatGrams) ?? 0,
            confidence: values.flexibleDouble(forKey: .confidence) ?? 0.5,
            uncertaintyNote: try values.decodeIfPresent(String.self, forKey: .uncertaintyNote)
        )
    }
}

struct ParsedWorkout: Codable, Equatable {
    var type: String
    var perceivedEffort: Int?
    var sets: [ParsedSet]

    init(type: String, perceivedEffort: Int?, sets: [ParsedSet]) {
        self.type = type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Workout" : type
        self.perceivedEffort = perceivedEffort.map { min(max($0, 1), 10) }
        self.sets = sets
    }

    private enum CodingKeys: String, CodingKey {
        case type, perceivedEffort, sets
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            type: (try? values.decode(String.self, forKey: .type)) ?? "Workout",
            perceivedEffort: values.flexibleInt(forKey: .perceivedEffort),
            sets: (try? values.decode([ParsedSet].self, forKey: .sets)) ?? []
        )
    }
}

struct ParsedSet: Codable, Equatable {
    var exerciseName: String
    var reps: Int
    var weightKilograms: Double?

    init(exerciseName: String, reps: Int, weightKilograms: Double?) {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.exerciseName = trimmed.isEmpty ? "Exercise" : trimmed
        self.reps = max(reps, 1)
        self.weightKilograms = weightKilograms.map { max($0, 0) }
    }

    private enum CodingKeys: String, CodingKey {
        case exerciseName, reps, weightKilograms
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            exerciseName: (try? values.decode(String.self, forKey: .exerciseName)) ?? "Exercise",
            reps: values.flexibleInt(forKey: .reps) ?? 1,
            weightKilograms: values.flexibleDouble(forKey: .weightKilograms)
        )
    }
}

/// Everything the day-summary prompt is allowed to see. Assembled from SwiftData by
/// `HealthDataRepository.todayContext()`. Screen-time is a coarse signal only.
struct DailyContext: Codable, Equatable {
    var date: Date
    var meals: [String]
    var totalCalories: Int?
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
    var workoutSummary: String?
    var sleepSummary: String?
    var healthSummary: String?
    var checkIn: [String: Int]
    var checkInNote: String?
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

extension AIClientError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No Claude API key is saved."
        case let .badResponse(statusCode, _):
            switch statusCode {
            case 401: return "The saved Claude API key was rejected."
            case 403: return "This API key is not allowed to use the requested model."
            case 404: return "The requested AI model is unavailable for this account."
            case 429: return "The Claude account has reached a rate or usage limit."
            case 500...599: return "Claude is temporarily unavailable."
            default: return "Claude returned an error (\(statusCode))."
            }
        case .decodingFailed:
            return "The AI response could not be interpreted safely."
        case .notImplemented:
            return "This AI feature is not available yet."
        }
    }
}

/// Converts provider and transport errors into useful, non-technical recovery copy.
/// The response body and API key are deliberately never shown to the user.
enum AIErrorPresenter {
    static func message(for error: Error) -> String {
        if let clientError = error as? AIClientError {
            switch clientError {
            case .missingAPIKey:
                return "Add your Claude API key in Settings, then try again."
            case let .badResponse(statusCode, _):
                switch statusCode {
                case 401:
                    return "The saved Claude API key was rejected. Review it in Settings."
                case 403:
                    return "This key does not have access to the selected Claude model."
                case 404:
                    return "The selected Claude model is not available for this account."
                case 429:
                    return "Your Claude account has reached a rate or usage limit. Try again later or review billing."
                case 500...599:
                    return "Claude is temporarily unavailable. Try again in a moment."
                default:
                    return "Claude returned an error (\(statusCode)). Try again or enter the details manually."
                }
            case .decodingFailed:
                return "The response could not be interpreted safely. Try again or enter the details manually."
            case .notImplemented:
                return "This AI feature is not available yet."
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "This device is offline. Connect to the internet or enter the details manually."
            case .timedOut:
                return "The request timed out. Try again or enter the details manually."
            default:
                return "The network request failed. Try again or enter the details manually."
            }
        }

        return "Something went wrong. Try again or enter the details manually."
    }
}

private extension KeyedDecodingContainer {
    func flexibleInt(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return Int(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value) ?? Double(value).map(Int.init)
        }
        return nil
    }

    func flexibleDouble(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }
}

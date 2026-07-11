import Foundation
import Observation
import SwiftData

// MARK: - Proposals (pending writes awaiting user confirmation)

/// One per-food row of the model's portion assumptions, shown on the meal card so
/// the user can catch bad gram guesses before saving. Display-only: the stored
/// `Meal` keeps totals + raw text.
struct MealItemBreakdown: Codable, Equatable {
    var food: String
    var quantity: String?
    var grams: Double?
    var calories: Int?
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?

    enum CodingKeys: String, CodingKey {
        case food
        case quantity
        case grams
        case calories
        case proteinGrams = "protein_g"
        case carbsGrams = "carbs_g"
        case fatGrams = "fat_g"
    }
}

struct MealProposal: Codable, Equatable {
    var description: String
    var items: [MealItemBreakdown]?
    var calories: Int?
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
    var confidence: String?

    enum CodingKeys: String, CodingKey {
        case description
        case items
        case calories
        case proteinGrams = "protein_g"
        case carbsGrams = "carbs_g"
        case fatGrams = "fat_g"
        case confidence
    }
}

struct WorkoutSetProposal: Codable, Equatable {
    var exercise: String
    var reps: Int
    var weightKilograms: Double?

    enum CodingKeys: String, CodingKey {
        case exercise
        case reps
        case weightKilograms = "weight_kg"
    }
}

struct WorkoutProposal: Codable, Equatable {
    var type: String
    var perceivedEffort: Int?
    var durationMinutes: Int?
    var sets: [WorkoutSetProposal]?

    enum CodingKeys: String, CodingKey {
        case type
        case perceivedEffort = "perceived_effort"
        case durationMinutes = "duration_minutes"
        case sets
    }
}

/// A pending write drafted by the assistant, rendered as an inline confirmation
/// card. Nothing touches the store until the user taps Save.
@MainActor
@Observable
final class ChatProposal: Identifiable {
    enum Kind {
        case meal(MealProposal)
        case workout(WorkoutProposal)
    }

    enum Status {
        case pending
        case saved
        case discarded
    }

    let id = UUID()
    let kind: Kind
    var status: Status = .pending

    init(kind: Kind) {
        self.kind = kind
    }
}

/// What the chat transcript renders: user/assistant bubbles and proposal cards.
enum ChatItem: Identifiable {
    case user(UUID, String)
    case assistant(UUID, String)
    case proposal(ChatProposal)

    var id: UUID {
        switch self {
        case .user(let id, _): return id
        case .assistant(let id, _): return id
        case .proposal(let proposal): return proposal.id
        }
    }
}

// MARK: - Engine

/// The send → tool-loop → confirm cycle behind ChatView. Holds the API history
/// (`[ChatTurn]`) and the display list; executes tools against
/// `HealthDataRepository`; writes happen only when the user confirms a card.
@MainActor
@Observable
final class ChatEngine {
    private(set) var items: [ChatItem] = []
    private(set) var isThinking = false
    var errorMessage: String?

    private var history: [ChatTurn] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    private var repo: HealthDataRepository {
        HealthDataRepository(context: modelContext)
    }

    var hasKey: Bool {
        APIKeyStore.read()?.isEmpty == false
    }

    // MARK: Sending

    func send(_ text: String) {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty, !isThinking else { return }
        errorMessage = nil
        items.append(.user(UUID(), trimmed))
        history.append(ChatTurn(role: .user, content: [.text(trimmed)]))
        isThinking = true
        Task { await runLoop() }
    }

    private func runLoop() async {
        let client = AIClientFactory.makeDefault()
        do {
            // Bounded so a confused model can't loop forever on our token budget.
            for _ in 0..<6 {
                let reply = try await client.chat(history, tools: Self.tools, system: Self.systemPrompt)

                var assistantContent: [ChatContent] = []
                if !reply.text.isEmpty {
                    assistantContent.append(.text(reply.text))
                    items.append(.assistant(UUID(), reply.text))
                }
                for call in reply.toolCalls {
                    assistantContent.append(.toolUse(call))
                }
                if !assistantContent.isEmpty {
                    history.append(ChatTurn(role: .assistant, content: assistantContent))
                }

                guard !reply.toolCalls.isEmpty else { break }

                var results: [ChatContent] = []
                for call in reply.toolCalls {
                    let result = execute(call)
                    results.append(.toolResult(toolUseID: call.id, text: result))
                }
                history.append(ChatTurn(role: .user, content: results))
            }
        } catch {
            errorMessage = Self.describe(error)
        }
        isThinking = false
    }

    // MARK: Tool execution

    private func execute(_ call: ChatToolCall) -> String {
        let data = Data(call.inputJSON.utf8)
        switch call.name {
        case "propose_meal":
            guard let proposal = try? JSONDecoder().decode(MealProposal.self, from: data) else {
                return "Error: could not parse the meal proposal input."
            }
            items.append(.proposal(ChatProposal(kind: .meal(proposal))))
            return "Drafted a meal card and showed it to the user for confirmation. "
                + "It is NOT saved yet — the user must tap Save."

        case "propose_workout":
            guard let proposal = try? JSONDecoder().decode(WorkoutProposal.self, from: data) else {
                return "Error: could not parse the workout proposal input."
            }
            items.append(.proposal(ChatProposal(kind: .workout(proposal))))
            return "Drafted a workout card and showed it to the user for confirmation. "
                + "It is NOT saved yet — the user must tap Save."

        case "get_recent_summaries":
            struct DaysInput: Codable { var days: Int? }
            let days = (try? JSONDecoder().decode(DaysInput.self, from: data))?.days ?? 14
            let snapshots = repo.recentRollupSnapshots(days: min(max(days, 1), 60))
            return snapshots.isEmpty
                ? "No history yet — the user hasn't logged anything on previous days."
                : encodeJSON(snapshots, failure: "recent summaries")

        case "get_health_profile":
            guard let snapshot = repo.healthProfileSnapshot() else {
                return "The user has not set up their health and training profile yet."
            }
            return encodeJSON(snapshot, failure: "health profile")

        case "get_workout_locations":
            let snapshots = repo.workoutLocationSnapshots()
            return snapshots.isEmpty
                ? "The user has not added any active workout locations or equipment yet."
                : encodeJSON(snapshots, failure: "workout locations")

        default:
            return "Error: unknown tool \(call.name)."
        }
    }

    private func encodeJSON<T: Encodable>(_ value: T, failure label: String) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let encoded = try? encoder.encode(value),
              let json = String(data: encoded, encoding: .utf8) else {
            return "Error: could not encode the \(label)."
        }
        return json
    }

    // MARK: Confirmation

    func confirm(_ proposal: ChatProposal) {
        guard proposal.status == .pending else { return }
        switch proposal.kind {
        case .meal(let meal):
            let record = Meal(rawText: meal.description)
            record.calories = meal.calories
            record.proteinGrams = meal.proteinGrams
            record.carbsGrams = meal.carbsGrams
            record.fatGrams = meal.fatGrams
            record.confidence = Self.confidenceValue(meal.confidence)
            record.uncertaintyNote = "Estimated by the assistant from: \"\(meal.description)\""
            repo.addMeal(record)
        case .workout(let workout):
            let session = WorkoutSession(
                type: workout.type,
                durationMinutes: workout.durationMinutes,
                perceivedEffort: workout.perceivedEffort
            )
            session.sets = (workout.sets ?? []).enumerated().map { index, set in
                ExerciseSet(
                    exerciseName: set.exercise,
                    reps: set.reps,
                    weightKilograms: set.weightKilograms,
                    order: index
                )
            }
            repo.addWorkout(session)
        }
        proposal.status = .saved
        repo.refreshTodayRollup()
    }

    func discard(_ proposal: ChatProposal) {
        guard proposal.status == .pending else { return }
        proposal.status = .discarded
    }

    private static func confidenceValue(_ label: String?) -> Double? {
        switch label {
        case "low": return 0.25
        case "medium": return 0.55
        case "high": return 0.85
        default: return nil
        }
    }

    // MARK: Errors

    private static func describe(_ error: Error) -> String {
        switch error {
        case AIClientError.missingAPIKey:
            return "No API key found. Add one in Settings."
        case let AIClientError.badResponse(statusCode, _):
            return statusCode == 401
                ? "API key was rejected (401). Re-check it in Settings."
                : "The AI service returned an error (\(statusCode)). Try again."
        default:
            return "Couldn't reach the assistant. Check your connection and try again."
        }
    }

    // MARK: Prompt & tools

    static let systemPrompt = """
    You are the user's personal health and lifestyle assistant inside their private \
    tracking app. You are NOT a doctor and never diagnose; use hedged language \
    ("rough estimate", "consider") and avoid extreme diet or unsafe workout advice.

    When the user describes food they ate, call propose_meal. Always fill the `items` \
    array with your per-food portion assumptions (grams and per-item macros) so the \
    user can verify your guesses, plus estimated totals and a confidence level. When \
    they describe a workout, call propose_workout with structured sets. Both tools \
    only DRAFT a card that the user must confirm — never claim something is already \
    saved or logged; say it's ready for them to review.

    To answer questions about how they've been doing, call get_recent_summaries and \
    ground your answer in that data; if it's empty, say there's no history yet. Use \
    get_health_profile when goals, preferences, measurements, previous surgery, old \
    injuries, asymmetries, or movement considerations are relevant. The returned \
    considerations are the user's own reports, not diagnoses. Account for them \
    conservatively and never infer a condition, prescribe treatment, or override \
    clinician guidance. Use get_workout_locations before recommending equipment-\
    dependent exercises or when the user names a location.

    Keep replies short and conversational — a sentence or two around a card is enough.
    """

    static let tools: [ChatToolDef] = [
        ChatToolDef(
            name: "propose_meal",
            description: "Draft a meal log entry for the user to confirm. Include a "
                + "per-food breakdown of your portion assumptions in `items` so the "
                + "user can verify them, plus estimated totals. This only shows a "
                + "card — the user must tap Save.",
            inputSchemaJSON: """
            {
              "type": "object",
              "properties": {
                "description": {"type": "string", "description": "The meal in the user's words, e.g. '2 eggs and toast'"},
                "items": {
                  "type": "array",
                  "description": "Per-food portion assumptions and per-item estimates",
                  "items": {
                    "type": "object",
                    "properties": {
                      "food": {"type": "string"},
                      "quantity": {"type": "string", "description": "e.g. 'x2', '1 slice', '1 cup'"},
                      "grams": {"type": "number", "description": "Assumed portion weight in grams"},
                      "calories": {"type": "integer"},
                      "protein_g": {"type": "number"},
                      "carbs_g": {"type": "number"},
                      "fat_g": {"type": "number"}
                    },
                    "required": ["food"]
                  }
                },
                "calories": {"type": "integer", "description": "Estimated total calories"},
                "protein_g": {"type": "number"},
                "carbs_g": {"type": "number"},
                "fat_g": {"type": "number"},
                "confidence": {"type": "string", "enum": ["low", "medium", "high"]}
              },
              "required": ["description"]
            }
            """
        ),
        ChatToolDef(
            name: "propose_workout",
            description: "Draft a workout log entry for the user to confirm. This only "
                + "shows a card — the user must tap Save.",
            inputSchemaJSON: """
            {
              "type": "object",
              "properties": {
                "type": {"type": "string", "description": "e.g. 'Push', 'Run', 'Mobility'"},
                "perceived_effort": {"type": "integer", "description": "RPE 1-10"},
                "duration_minutes": {"type": "integer"},
                "sets": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "exercise": {"type": "string"},
                      "reps": {"type": "integer"},
                      "weight_kg": {"type": "number"}
                    },
                    "required": ["exercise", "reps"]
                  }
                }
              },
              "required": ["type"]
            }
            """
        ),
        ChatToolDef(
            name: "get_recent_summaries",
            description: "Fetch the user's compact daily summaries (meals, calories, "
                + "workouts, sleep, energy, mood, and Apple Health activity aggregates) "
                + "for recent days, as JSON. Use this to answer any question about "
                + "their data or trends.",
            inputSchemaJSON: """
            {
              "type": "object",
              "properties": {
                "days": {"type": "integer", "description": "How many recent days to fetch (default 14, max 60)"}
              }
            }
            """
        ),
        ChatToolDef(
            name: "get_health_profile",
            description: "Read the user's compact, user-confirmed health and training profile: goals, experience, preferences, availability, user-reported movement considerations, and a compact body-metric trend. Read-only; never changes profile data.",
            inputSchemaJSON: """
            {"type": "object", "properties": {}}
            """
        ),
        ChatToolDef(
            name: "get_workout_locations",
            description: "Read active workout locations with available equipment, space limitations, and notes. Use before suggesting equipment-dependent exercises. Read-only.",
            inputSchemaJSON: """
            {"type": "object", "properties": {}}
            """
        ),
    ]
}

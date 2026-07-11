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

struct WorkoutPlanStepProposal: Codable, Equatable {
    var type: String
    var title: String
    var instruction: String?
    var sets: Int?
    var reps: Int?
    var durationSeconds: Int?
    var distanceMeters: Double?
    var targetWeightKilograms: Double?
    var restSeconds: Int?
    var side: String?
    var equipment: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case type
        case title
        case instruction
        case sets
        case reps
        case durationSeconds = "duration_seconds"
        case distanceMeters = "distance_meters"
        case targetWeightKilograms = "target_weight_kg"
        case restSeconds = "rest_seconds"
        case side
        case equipment
        case notes
    }
}

struct WorkoutPlanProposal: Codable, Equatable {
    var title: String
    var goal: String?
    var estimatedDurationMinutes: Int?
    var targetEffort: Int?
    var location: String?
    var notes: String?
    var steps: [WorkoutPlanStepProposal]

    enum CodingKeys: String, CodingKey {
        case title
        case goal
        case estimatedDurationMinutes = "estimated_duration_minutes"
        case targetEffort = "target_effort"
        case location
        case notes
        case steps
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
        case workoutPlan(WorkoutPlanProposal)
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
            // Bounded so a confused model cannot loop forever on the token budget.
            for _ in 0..<8 {
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
            return "Drafted a completed-workout card and showed it to the user for confirmation. "
                + "It is NOT saved yet — the user must tap Save."

        case "propose_workout_plan":
            guard let proposal = try? JSONDecoder().decode(WorkoutPlanProposal.self, from: data),
                  !proposal.title.trimmed.isEmpty,
                  !proposal.steps.isEmpty else {
                return "Error: could not parse a complete workout-plan proposal."
            }
            items.append(.proposal(ChatProposal(kind: .workoutPlan(proposal))))
            return "Drafted a structured workout plan and showed it to the user for confirmation. "
                + "It is NOT saved yet — the user must tap Save plan."

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

        case "get_workout_plans":
            let snapshots = repo.workoutPlanSnapshots(limit: 20)
            return snapshots.isEmpty
                ? "The user has no active saved workout plans yet."
                : encodeJSON(snapshots, failure: "workout plans")

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
        var refreshesDailyRollup = false

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
            refreshesDailyRollup = true

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
            refreshesDailyRollup = true

        case .workoutPlan(let draft):
            saveWorkoutPlan(draft)
        }

        proposal.status = .saved
        if refreshesDailyRollup {
            repo.refreshTodayRollup()
        }
    }

    private func saveWorkoutPlan(_ draft: WorkoutPlanProposal) {
        let resolvedLocation = repo.matchingActiveLocation(named: draft.location)
        let plan = WorkoutPlan(
            title: draft.title.trimmed,
            goalText: draft.goal?.trimmed.nilIfEmpty,
            notes: draft.notes?.trimmed.nilIfEmpty,
            estimatedDurationMinutes: draft.estimatedDurationMinutes.map { min(max($0, 5), 240) },
            targetEffort: draft.targetEffort.map { min(max($0, 1), 10) },
            source: .assistant
        )
        repo.addWorkoutPlan(plan)
        repo.applyWorkoutLocationSnapshot(resolvedLocation, to: plan)

        let steps = draft.steps.enumerated().compactMap { index, proposed -> WorkoutStep? in
            let cleanedTitle = proposed.title.trimmed
            guard !cleanedTitle.isEmpty else { return nil }
            let type = WorkoutStepType(rawValue: proposed.type) ?? .freeform
            let side = WorkoutStepSide(rawValue: proposed.side ?? "") ?? .none
            let equipment = repo.isEquipmentNameAvailable(proposed.equipment, at: resolvedLocation)
                ? proposed.equipment?.trimmed.nilIfEmpty
                : nil

            return WorkoutStep(
                order: index,
                type: type,
                title: cleanedTitle,
                instruction: proposed.instruction?.trimmed.nilIfEmpty,
                sets: positive(proposed.sets),
                reps: positive(proposed.reps),
                durationSeconds: positive(proposed.durationSeconds),
                distanceMeters: positive(proposed.distanceMeters),
                targetWeightKilograms: nonnegative(proposed.targetWeightKilograms),
                restSeconds: nonnegative(proposed.restSeconds),
                side: side,
                equipmentNameSnapshot: equipment,
                notes: proposed.notes?.trimmed.nilIfEmpty
            )
        }
        repo.replaceWorkoutSteps(in: plan, with: steps)
    }

    func discard(_ proposal: ChatProposal) {
        guard proposal.status == .pending else { return }
        proposal.status = .discarded
    }

    private func positive(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private func positive(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private func nonnegative(_ value: Int?) -> Int? {
        guard let value, value >= 0 else { return nil }
        return value
    }

    private func nonnegative(_ value: Double?) -> Double? {
        guard let value, value >= 0 else { return nil }
        return value
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
    they describe a workout they already completed, call propose_workout with structured \
    sets. These tools only DRAFT cards that the user must confirm — never claim something \
    is already saved or logged.

    When the user asks you to CREATE, DESIGN, or SUGGEST a future workout plan, first \
    call get_health_profile and get_workout_locations. Then call propose_workout_plan. \
    Use only equipment marked available at the selected active location. Include ordered \
    warm-up, exercise, mobility/cardio/rest as appropriate, and cooldown steps. Make the \
    plan realistic for the user's stated duration, experience, goal, and preferences. \
    The plan is a draft requiring Save plan; do not describe it as saved before confirmation.

    Health considerations returned by get_health_profile are the user's own reports, not \
    diagnoses. Account for them conservatively. Do not infer a medical condition, prescribe \
    treatment or rehabilitation, claim an exercise is medically safe, or override clinician \
    guidance. Prefer neutral adjustments such as reduced load, stable support, shorter range, \
    lower volume, or an alternative movement when appropriate.

    To answer questions about how the user has been doing, call get_recent_summaries. Use \
    get_workout_plans when they ask about an existing saved plan. Keep replies concise; a \
    sentence or two around a proposal card is enough.
    """

    static let tools: [ChatToolDef] = [
        ChatToolDef(
            name: "propose_meal",
            description: "Draft a meal log entry for the user to confirm. Include a "
                + "per-food breakdown of portion assumptions and totals. This only shows "
                + "a card — the user must tap Save.",
            inputSchemaJSON: """
            {
              "type": "object",
              "properties": {
                "description": {"type": "string"},
                "items": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "food": {"type": "string"},
                      "quantity": {"type": "string"},
                      "grams": {"type": "number"},
                      "calories": {"type": "integer"},
                      "protein_g": {"type": "number"},
                      "carbs_g": {"type": "number"},
                      "fat_g": {"type": "number"}
                    },
                    "required": ["food"]
                  }
                },
                "calories": {"type": "integer"},
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
            description: "Draft a log entry for a workout the user already completed. "
                + "This only shows a card — the user must tap Save.",
            inputSchemaJSON: """
            {
              "type": "object",
              "properties": {
                "type": {"type": "string"},
                "perceived_effort": {"type": "integer"},
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
            name: "propose_workout_plan",
            description: "Draft an ordered future workout plan for user confirmation. "
                + "Call get_health_profile and get_workout_locations first. Use only "
                + "available equipment at the named location. This does not start or "
                + "complete a workout; the user must tap Save plan.",
            inputSchemaJSON: """
            {
              "type": "object",
              "properties": {
                "title": {"type": "string"},
                "goal": {"type": "string"},
                "estimated_duration_minutes": {"type": "integer", "minimum": 5, "maximum": 240},
                "target_effort": {"type": "integer", "minimum": 1, "maximum": 10},
                "location": {"type": "string", "description": "Exact active location name from get_workout_locations"},
                "notes": {"type": "string"},
                "steps": {
                  "type": "array",
                  "minItems": 1,
                  "items": {
                    "type": "object",
                    "properties": {
                      "type": {"type": "string", "enum": ["warm_up", "exercise", "mobility", "hold", "cardio", "interval", "distance", "rest", "cooldown", "freeform"]},
                      "title": {"type": "string"},
                      "instruction": {"type": "string"},
                      "sets": {"type": "integer", "minimum": 1},
                      "reps": {"type": "integer", "minimum": 1},
                      "duration_seconds": {"type": "integer", "minimum": 1},
                      "distance_meters": {"type": "number", "minimum": 0},
                      "target_weight_kg": {"type": "number", "minimum": 0},
                      "rest_seconds": {"type": "integer", "minimum": 0},
                      "side": {"type": "string", "enum": ["none", "left", "right", "both", "alternating"]},
                      "equipment": {"type": "string", "description": "Exact available equipment name from the selected location"},
                      "notes": {"type": "string"}
                    },
                    "required": ["type", "title"]
                  }
                }
              },
              "required": ["title", "steps"]
            }
            """
        ),
        ChatToolDef(
            name: "get_recent_summaries",
            description: "Fetch compact daily summaries for recent days as JSON.",
            inputSchemaJSON: """
            {
              "type": "object",
              "properties": {
                "days": {"type": "integer", "description": "Default 14, maximum 60"}
              }
            }
            """
        ),
        ChatToolDef(
            name: "get_health_profile",
            description: "Read the compact, user-confirmed health and training profile. "
                + "Includes goals, experience, availability, preferences, user-reported "
                + "considerations, and a compact body-metric trend. Read-only.",
            inputSchemaJSON: """
            {"type": "object", "properties": {}}
            """
        ),
        ChatToolDef(
            name: "get_workout_locations",
            description: "Read active workout locations with available equipment and "
                + "space limitations. Read-only.",
            inputSchemaJSON: """
            {"type": "object", "properties": {}}
            """
        ),
        ChatToolDef(
            name: "get_workout_plans",
            description: "Read compact snapshots of active saved workout plans and their "
                + "ordered steps. Read-only.",
            inputSchemaJSON: """
            {"type": "object", "properties": {}}
            """
        ),
    ]
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
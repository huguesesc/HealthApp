import Foundation

/// Deterministic, offline implementation. The default everywhere until the AI is
/// deliberately switched on (M2). Runs with no API key and no network so the app is
/// fully usable offline.
struct StubAIClient: AIClient {
    func parseMeal(text: String) async throws -> MealEstimate {
        MealEstimate(
            calories: 450,
            proteinGrams: 20,
            carbsGrams: 45,
            fatGrams: 18,
            confidence: 0.3,
            uncertaintyNote: "Rough placeholder estimate — AI not yet connected."
        )
    }

    func parseWorkout(text: String) async throws -> ParsedWorkout {
        ParsedWorkout(
            type: "General",
            perceivedEffort: nil,
            sets: [ParsedSet(exerciseName: "Exercise", reps: 8, weightKilograms: nil)]
        )
    }

    func summarizeDay(_ context: DailyContext) async throws -> DailySummaryResult {
        DailySummaryResult(
            text: "Placeholder summary for \(context.meals.count) meal(s) logged today. "
                + "Connect the AI client to generate a real daily summary.",
            modelUsed: "stub"
        )
    }

    func ask(_ question: String, recent: [RollupSnapshot]) async throws -> String {
        "Assistant is not connected yet. You asked: \"\(question)\". "
            + "When the AI client is enabled, I'll answer using your recent data "
            + "(\(recent.count) day(s) of history available)."
    }

    func estimateMeal(image: Data) async throws -> MealEstimate {
        throw AIClientError.notImplemented
    }

    func chat(_ turns: [ChatTurn], tools: [ChatToolDef], system: String) async throws -> ChatReply {
        ChatReply(
            text: "The assistant isn't connected yet — add your Claude API key in "
                + "Settings and I'll be able to log meals and workouts from chat "
                + "and answer questions about your data.",
            toolCalls: []
        )
    }
}

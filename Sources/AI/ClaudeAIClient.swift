import Foundation

/// Talks to the Claude Messages API over raw HTTPS (there is no official Swift SDK).
/// Not the default — `AIClientFactory` returns the stub until this is deliberately
/// enabled in M2. The key is read from the Keychain; never hardcoded.
///
/// Default model is the cheapest current model, which is plenty for one daily
/// summary or a short answer. Change `model` to upgrade quality — nothing else in
/// the app changes.
///
/// BACKEND NOTE: for premium/metered features (e.g. photo estimation), point this
/// at your own proxy instead of api.anthropic.com so the key and usage limits live
/// server-side. The protocol seam means callers are unaffected.
struct ClaudeAIClient: AIClient {
    /// Swap this single constant to change models (e.g. "claude-sonnet-4-6").
    var model = "claude-haiku-4-5"
    var maxTokens = 1024

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - AIClient

    func parseMeal(text: String) async throws -> MealEstimate {
        let system = """
        You estimate nutrition from a short meal description. Always treat numbers as \
        rough estimates. If portions are uncertain, say so. Respond ONLY with a JSON \
        object: {"calories":int,"proteinGrams":number,"carbsGrams":number,\
        "fatGrams":number,"confidence":number(0..1),"uncertaintyNote":string}.
        """
        let json = try await sendForJSON(system: system, userText: text)
        return try decode(MealEstimate.self, from: json)
    }

    func parseWorkout(text: String) async throws -> ParsedWorkout {
        let system = """
        You convert a natural-language workout description into structured data. \
        Respond ONLY with a JSON object: {"type":string,"perceivedEffort":int|null,\
        "sets":[{"exerciseName":string,"reps":int,"weightKilograms":number|null}]}. \
        Infer reasonable values; use null when genuinely unknown.
        """
        let json = try await sendForJSON(system: system, userText: text)
        return try decode(ParsedWorkout.self, from: json)
    }

    func summarizeDay(_ context: DailyContext) async throws -> DailySummaryResult {
        let system = """
        You are a supportive personal wellness assistant. You are NOT a doctor and do \
        not diagnose. Give a short (2–4 sentence) summary connecting the day's sleep, \
        food, workout, and habits. Use hedged language ("rough", "consider", "general \
        wellness suggestion"). Avoid "you must", medical claims, extreme diet or \
        unsafe workout advice.
        """
        let userText = "Here is today's data as JSON:\n" + encodeToString(context)
        let text = try await sendForText(system: system, userText: userText)
        return DailySummaryResult(text: text, modelUsed: model)
    }

    func ask(_ question: String, recent: [RollupSnapshot]) async throws -> String {
        let system = """
        You are a supportive personal wellness assistant with access to the user's \
        recent daily summaries. You are NOT a doctor and do not diagnose. Connect \
        information across sleep, food, workouts and habits. Use hedged language and \
        avoid medical claims, extreme diet advice, or unsafe workout advice. Keep \
        answers concise.
        """
        let history = encodeToString(recent)
        let userText = "Recent daily history as JSON:\n\(history)\n\nQuestion: \(question)"
        return try await sendForText(system: system, userText: userText)
    }

    func estimateMeal(image: Data) async throws -> MealEstimate {
        // Vision / photo estimation is deliberately deferred (premium feature).
        throw AIClientError.notImplemented
    }

    // MARK: - Transport

    private func makeRequest(system: String, userText: String) throws -> URLRequest {
        guard let key = APIKeyStore.read(), !key.isEmpty else {
            throw AIClientError.missingAPIKey
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": userText]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func sendForText(system: String, userText: String) async throws -> String {
        let request = try makeRequest(system: system, userText: userText)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIClientError.badResponse(
                statusCode: code,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }
        return try extractText(from: data)
    }

    private func sendForJSON(system: String, userText: String) async throws -> Data {
        let text = try await sendForText(system: system, userText: userText)
        guard let data = text.data(using: .utf8) else {
            throw AIClientError.decodingFailed("response text was not UTF-8")
        }
        return data
    }

    private func extractText(from data: Data) throws -> String {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = root["content"] as? [[String: Any]]
        else {
            throw AIClientError.decodingFailed("unexpected response shape")
        }
        return content
            .compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
            .joined()
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AIClientError.decodingFailed(String(describing: error))
        }
    }

    private func encodeToString<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

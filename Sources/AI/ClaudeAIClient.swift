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

    /// The agentic chat assistant runs on a stronger model: reliable tool-calling
    /// matters when it is drafting real data. One-shot calls stay on the cheap model.
    var chatModel = "claude-sonnet-4-6"
    var chatMaxTokens = 2048

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
        not diagnose. Write a 3–5 sentence summary of the user's day that connects \
        the data: comment on the food actually eaten (calorie/macro balance when the \
        numbers are there), the workout and how it fits with sleep and energy, and \
        acknowledge the streak if present. End with one small, concrete, gentle \
        suggestion for tomorrow. Use hedged language ("rough", "consider", "general \
        wellness suggestion"). Avoid "you must", medical claims, extreme diet or \
        unsafe workout advice. If a section has no data, skip it rather than \
        commenting on its absence more than once.
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

    // MARK: - Tool-use chat (the agentic assistant)

    func chat(_ turns: [ChatTurn], tools: [ChatToolDef], system: String) async throws -> ChatReply {
        guard let key = APIKeyStore.read(), !key.isEmpty else {
            throw AIClientError.missingAPIKey
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": chatModel,
            "max_tokens": chatMaxTokens,
            "system": system,
            "tools": tools.map { tool in
                [
                    "name": tool.name,
                    "description": tool.description,
                    "input_schema": jsonObject(from: tool.inputSchemaJSON),
                ] as [String: Any]
            },
            "messages": turns.map(encodeTurn),
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIClientError.badResponse(
                statusCode: code,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }
        return try parseChatReply(from: data)
    }

    private func encodeTurn(_ turn: ChatTurn) -> [String: Any] {
        let blocks: [[String: Any]] = turn.content.map { content -> [String: Any] in
            switch content {
            case .text(let text):
                return ["type": "text", "text": text]
            case .toolUse(let call):
                return [
                    "type": "tool_use",
                    "id": call.id,
                    "name": call.name,
                    "input": jsonObject(from: call.inputJSON),
                ]
            case .toolResult(let toolUseID, let text):
                return [
                    "type": "tool_result",
                    "tool_use_id": toolUseID,
                    "content": text,
                ]
            }
        }
        return ["role": turn.role.rawValue, "content": blocks]
    }

    private func parseChatReply(from data: Data) throws -> ChatReply {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = root["content"] as? [[String: Any]]
        else {
            throw AIClientError.decodingFailed("unexpected chat response shape")
        }
        var text = ""
        var toolCalls: [ChatToolCall] = []
        for block in content {
            switch block["type"] as? String {
            case "text":
                text += (block["text"] as? String) ?? ""
            case "tool_use":
                guard let id = block["id"] as? String,
                      let name = block["name"] as? String else { continue }
                let input = block["input"] ?? [String: Any]()
                let inputData = (try? JSONSerialization.data(withJSONObject: input)) ?? Data("{}".utf8)
                let inputJSON = String(data: inputData, encoding: .utf8) ?? "{}"
                toolCalls.append(ChatToolCall(id: id, name: name, inputJSON: inputJSON))
            default:
                continue
            }
        }
        return ChatReply(text: text, toolCalls: toolCalls)
    }

    /// Parse a raw JSON object string; malformed input degrades to an empty object
    /// rather than failing the whole request.
    private func jsonObject(from json: String) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]) ?? [:]
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

import Foundation

// Value types for the tool-use chat loop. Everything is Sendable and string-based:
// tool inputs/schemas stay raw JSON strings so the JSONSerialization-based client
// owns all wire-format concerns and these types stay provider-agnostic.

enum ChatRole: String, Sendable {
    case user
    case assistant
}

/// One tool invocation requested by the model.
struct ChatToolCall: Sendable, Equatable {
    let id: String
    let name: String
    /// The tool input as a raw JSON object string.
    let inputJSON: String
}

/// One content block within a turn.
enum ChatContent: Sendable, Equatable {
    case text(String)
    case toolUse(ChatToolCall)
    case toolResult(toolUseID: String, text: String)
}

/// One message in the conversation history sent to the API.
struct ChatTurn: Sendable, Equatable {
    let role: ChatRole
    let content: [ChatContent]
}

/// A tool the model may call. `inputSchemaJSON` is a raw JSON Schema object string.
struct ChatToolDef: Sendable, Equatable {
    let name: String
    let description: String
    let inputSchemaJSON: String
}

/// One assistant turn as parsed from the API: concatenated text plus any tool calls.
struct ChatReply: Sendable, Equatable {
    let text: String
    let toolCalls: [ChatToolCall]
}

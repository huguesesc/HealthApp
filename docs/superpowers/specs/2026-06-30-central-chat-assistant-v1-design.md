# Central chat assistant — v1 (agentic, tool-use)

Date: 2026-06-30
Status: design approved; spec pending user review, then build (Windows-authored,
verified on Mac). This is the largest piece so far — build in stages.

## Context

The app should be **centered on a conversational assistant**: you talk to it, it logs
your meals/workouts from freeform chat, and it answers questions about your data. This
is the original "central cross-module AI assistant" vision and the user's chosen
direction (chatbot before the freeform forms; full v3 "log + answer" agent).

Unlike every slice so far, this needs **new engine code, not just wiring**: the current
`ClaudeAIClient` is single-shot. An agent that logs and queries needs **tool use /
function calling** — Claude decides to call tools, the app executes them, results go
back, loop until it replies.

**Writes are user-confirmed** (user preference: safer for real data, done with good UI).
A log request renders an inline **confirmation card** in the chat; the repo write happens
only when the user taps **Save**.

Model for the agent: **`claude-sonnet-4-6`** — reliable tool-calling matters when it's
logging real data. The cheap one-shot daily summary stays on Haiku.

## Architecture

### 1. AI layer — tool-use chat
New value types (`Sources/AI/ChatTypes.swift`), all Sendable (strings only; tool inputs
kept as raw JSON strings to match the existing `JSONSerialization`-based client):

- `enum ChatRole { case user, assistant }`
- `struct ChatToolCall { let id, name, inputJSON: String }`
- `enum ChatContent { case text(String); case toolUse(ChatToolCall); case toolResult(toolUseID: String, text: String) }`
- `struct ChatTurn { let role: ChatRole; let content: [ChatContent] }`
- `struct ChatToolDef { let name, description, inputSchemaJSON: String }`
- `struct ChatReply { let text: String; let toolCalls: [ChatToolCall] }`  // one assistant turn

`AIClient` gains: `func chat(_ turns: [ChatTurn], tools: [ChatToolDef], system: String) async throws -> ChatReply`

- **`ClaudeAIClient.chat`**: translate `turns` → Anthropic `messages` wire format
  (`text` / `tool_use` / `tool_result` blocks), send with the `tools` array against the
  same `/v1/messages` endpoint, parse the response content blocks into `ChatReply`
  (text concatenated, `tool_use` blocks → `toolCalls`). Add `var chatModel = "claude-sonnet-4-6"`.
- **`StubAIClient.chat`**: canned reply ("Assistant isn't connected — add your API key
  in Settings."), no tool calls, so the UI works offline.

### 2. ChatEngine (`Sources/Features/Chat/ChatEngine.swift`, `@MainActor @Observable`)
- Holds the API history `[ChatTurn]` and a UI list of display items (user bubble,
  assistant bubble, proposal card).
- `send(_ userText:)`: guard a key exists (else hint); append user turn; loop:
  1. `reply = try await client.chat(history, tools, system)`
  2. append assistant turn; show `reply.text` as a bubble if non-empty
  3. for each tool call:
     - `get_recent_summaries` → run `repo.recentRollupSnapshots(days:)` → JSON `toolResult`
     - `propose_meal` / `propose_workout` → create a **pending proposal**, render a card,
       `toolResult` = "Drafted and shown to the user for confirmation."
  4. append a user turn carrying the `toolResult`s; repeat until no tool calls.
- **Confirm:** card **Save** → `repo.addMeal(...)` / `repo.addWorkout(...)` (existing
  write seam) → mark card saved. **Discard** → dismiss. (Inline edit = later.)
- Network awaited off-main inside the client; repo writes on main.

### 3. UI (`Sources/Features/Chat/ChatView.swift`)
- Scrolling message list: user/assistant bubbles + proposal cards (fields + Save/Discard).
- Text field + send button; a "thinking…" indicator during the loop.
- Reached via a **prominent "Assistant" entry at the top of the dashboard** (promote to
  the home screen once proven — nav rebuild deferred).

### 4. Tools (v1)
- `propose_meal(description, calories?, protein_g?, carbs_g?, fat_g?)`
- `propose_workout(type, perceived_effort?, duration_minutes?, sets?[{exercise, reps, weight_kg?}])`
- `get_recent_summaries(days?)` → recent `RollupSnapshot`s as JSON
- System prompt: supportive personal health assistant; to log food/workouts call the
  `propose_*` tools (draft for confirmation — never claim it's already saved); to answer
  questions call `get_recent_summaries`; concise; not medical.

## Files
- New: `Sources/AI/ChatTypes.swift`, `Sources/Features/Chat/ChatEngine.swift`,
  `Sources/Features/Chat/ChatView.swift`
- Edit: `Sources/AI/AIClient.swift` (protocol), `Sources/AI/ClaudeAIClient.swift`,
  `Sources/AI/StubAIClient.swift`, `Sources/Features/Dashboard/DashboardView.swift` (entry)

## Verification (next Mac session)
1. Add new files to the Xcode target (group references — see project note in memory).
2. Open **Assistant** → "I had two eggs and toast" → a **meal card** appears with
   estimated kcal/macros → **Save** → dashboard "Meals logged" ticks up.
3. "Did push day, bench 3×8 at 60kg" → **workout card** → Save → workout logged.
4. "How's my week been?" → it calls `get_recent_summaries` and answers from your data.
5. No key → hint; offline → stub reply, UI still works.

## Deferred (next iterations)
Streaming replies; sleep/check-in logging tools; granular per-entry queries; inline
editing of a proposal card; conversation persistence; promoting chat to the home screen.

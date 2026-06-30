# 0004 — Central chat assistant: build handoff

Date: 2026-06-30
Status: **designed, not built.** Full design in
`docs/superpowers/specs/2026-06-30-central-chat-assistant-v1-design.md`. Read that spec
first; this note adds the confirmation-UX refinement, the build order, and resume state.

## What we're building

The app's **centerpiece**: a chat assistant that (a) logs meals/workouts from freeform
chat and (b) answers questions about the user's data. First feature needing **new engine
code** — tool use / function calling (current `ClaudeAIClient` is single-shot). Agent
runs on **`claude-sonnet-4-6`** (reliable tool-calling); the one-shot daily summary stays
on Haiku. Writes are **user-confirmed via inline cards** (Save only on tap).

## Confirmation card must SHOW ITS WORK (refinement, 2026-06-30)

When the user says "I ate 2 eggs and toast," the meal card should display the model's
**per-food portion assumptions + the estimate built from them**, not just a total — so
the user can spot when the gram guesses are off and correct quickly. Example:

```
Meal: 2 eggs and toast
  • Eggs ×2        ~100 g   ~140 kcal   (P 12 / C 1 / F 10)
  • Toast ×1 slice ~30 g    ~80 kcal    (P 3 / C 14 / F 1)
  Total: ~220 kcal · P 15 · C 15 · F 11      confidence: medium
  [ Save ]  [ Discard ]
```

→ **Tool change:** `propose_meal` gains an optional structured `items` breakdown, e.g.
`items: [{ food, quantity, grams?, calories?, protein_g?, carbs_g?, fat_g? }]`, plus the
totals already in the spec. The card renders `items` as rows + a totals line. (The stored
`Meal` model only keeps the totals/rawText for now; the breakdown is display-only unless
we later extend the model.) System prompt should tell the agent to fill `items` with its
portion assumptions so the user can verify them.

## Build order (UI/placement LAST — confirmed with user)

Do the logic first; leave the chat UI rough and the dashboard entry until the end.

1. **Stage 1 — engine + types** (`Sources/AI/`):
   - `ChatTypes.swift` (ChatRole, ChatToolCall, ChatContent, ChatTurn, ChatToolDef, ChatReply)
   - `AIClient.chat(_:tools:system:)` on the protocol
   - `ClaudeAIClient.chat` (tool-use wire format: text/tool_use/tool_result blocks + `tools`
     array on `/v1/messages`; add `var chatModel = "claude-sonnet-4-6"`)
   - `StubAIClient.chat` (canned offline reply)
   - Commit.
2. **Stage 2 — ChatEngine** (`Sources/Features/Chat/ChatEngine.swift`, `@MainActor`):
   the send→tool-loop→tool_result loop; tool execution (`propose_meal`, `propose_workout`,
   `get_recent_summaries`); pending-proposal + Save→`repo.addMeal`/`addWorkout`. Commit.
3. **Stage 3 — UI (rough, polish later)**: `ChatView.swift` (bubbles + proposal cards +
   input), then a prominent dashboard entry. Placement/visual polish + promoting chat to
   the home screen are deliberately **last**. Commit + push.

## Reuse / seams (already exist)
- Writes: `HealthDataRepository.addMeal` / `addWorkout` (so chat-logged data feeds the
  dashboard + daily summary automatically).
- Queries: `repo.recentRollupSnapshots(days:)`.
- Key handling: `APIKeyStore` + the no-key guard pattern from `DashboardView.generateSummary`.
- Existing `parseMeal`/`parseWorkout`/`summarizeDay` are unaffected; `chat` is additive.

## Xcode gotcha (don't forget on the Mac)
The committed `Health Assistantv2.xcodeproj` references files as **groups**, so NEW files
(`ChatTypes.swift`, `ChatEngine.swift`, `ChatView.swift`) won't auto-appear — drag each
into the project navigator with the **Health Assistantv2** target checked, or re-clone +
recreate the project.

## Resume state (where things stand as of this note)
- ✅ M1 builds & runs on device; repo opens-and-runs on any Mac (committed `.xcodeproj`).
- ✅ M2 slice 1 (API key Settings + one-tap daily summary) — **verified working on device**.
  Summary is shallow on meals (known: brief prompt + `todayContext` lacks macros).
- ⏸️ **Freeform AI forms** feature was designed (meal/workout "Estimate with AI" buttons +
  enrich `todayContext` with macros) — **deprioritized**, since the chat now does logging.
  Design lives in this conversation; re-derive from the parse functions if revived.
- ⏸️ Minor lever: bump summary to Sonnet / reword prompt — on the shelf.
- 🔜 **Next: build the chat assistant** per the spec + this note, stages 1→3.

Funding: personal Anthropic key, ~€5 credit, BYOK for dev (proxy for real users later).

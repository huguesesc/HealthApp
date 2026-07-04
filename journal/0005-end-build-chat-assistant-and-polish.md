# 0005 — v1 "end build": chat assistant + cohesion pass

Date: 2026-07-04
Status: **authored on Windows, NOT compiled.** This session ran on the Windows
laptop (no Xcode, no Swift toolchain — `xcodebuild`/`swiftc` do not exist here),
so the brief's "build is your verification" loop was impossible. Everything below
was verified by careful reading against the existing code, **not** by a compiler.
The next Mac session (Opus debugging pass) must build first, fix what falls out,
then run the on-device checklist. Treat every "works" below as "should work".

## What was built (in commit order)

1. **Chat engine types + wire format** (`7b2f80a`)
   - `Sources/AI/ChatTypes.swift` — ChatRole/ChatToolCall/ChatContent/ChatTurn/
     ChatToolDef/ChatReply, all Sendable, tool inputs as raw JSON strings.
   - `AIClient.chat(_:tools:system:)` added to the protocol.
   - `ClaudeAIClient.chat` — Anthropic tool-use wire format on `/v1/messages`
     (`tools` array with `input_schema`; `text`/`tool_use`/`tool_result` blocks;
     `tool_result` goes back in a **user** turn). `chatModel = "claude-sonnet-4-6"`
     (verified against current model list — no date suffix), `chatMaxTokens = 2048`.
     One-shot calls stay on `claude-haiku-4-5`.
   - `StubAIClient.chat` — canned offline reply, no tool calls.

2. **ChatEngine** (`16df5a4`) — `Sources/Features/Chat/ChatEngine.swift`
   - `@MainActor @Observable`; holds `[ChatTurn]` API history + `[ChatItem]`
     display list (user/assistant bubbles + proposal cards).
   - `send()` → loop (bounded at 6 iterations): chat → append assistant turn →
     execute tools → append tool_results as a user turn → repeat until no calls.
   - Tools: `propose_meal` (with per-food `items` breakdown per journal/0004's
     show-your-work refinement), `propose_workout`, `get_recent_summaries`
     (ISO8601-encoded `RollupSnapshot` JSON, days clamped 1–60).
   - Proposals are `@Observable ChatProposal` (pending/saved/discarded). **Save**
     writes through `repo.addMeal`/`addWorkout` and refreshes the rollup;
     Discard just flips status. Tool results explicitly tell the model nothing
     is saved until the user confirms.
   - Guard: empty-content assistant turns are never appended to history (the API
     rejects empty content arrays).

3. **ChatView + Theme + dashboard front door** (`2c45e72`)
   - `ChatView` — scrolling transcript, evergreen user bubbles, meal cards render
     item rows (`food · qty · ~grams`, per-item kcal + P/C/F) + totals line +
     confidence, workout cards render sets; Save/Discard; thinking indicator;
     empty state with example prompts; no-key hint links to Settings; composer
     pinned via `safeAreaInset`.
   - `Sources/Shared/Theme.swift` — evergreen/moss/clay/honey palette, `.card()`
     container, rounded stat font. Accents over system grouped backgrounds so
     dark mode survives.
   - Dashboard rebuilt (ScrollView, not List): greeting → **Assistant hero card**
     → "Connect the assistant" key card (only when no key) → 3 stat tiles →
     streak card → daily-summary card → module list. All prior @Query/summary
     logic preserved. Global `.tint(Theme.evergreen)` on RootView.

4. **Summary enrichment + AI on manual forms** (`c16b479`)
   - `DailyContext` gains totalCalories/protein/carbs/fat, hunger, check-in note,
     `streakDays`; `todayContext()` inlines per-meal macros and richer workout/
     sleep descriptions. `summarizeDay` prompt rewritten (3–5 sentences, comments
     on macro balance + streak, ends with one gentle suggestion, still hedged).
   - MealEntryView: **Estimate with AI** fills the macro fields via `parseMeal`
     (editable before save; uncertainty note shown and persisted).
   - WorkoutEntryForm: freeform "Describe it" + **Fill in with AI** via
     `parseWorkout` into type/effort/sets.

5. **Xcode target registration** (`56a735d`) — the four new files
   (ChatTypes, ChatEngine, ChatView, Theme) hand-registered in `project.pbxproj`:
   PBXFileReference + PBXBuildFile + Sources build phase + new `Chat` group under
   Features (IDs prefixed `18C7B1…`, verified unique). **If the Mac build shows
   them missing/duplicated in the navigator, prefer re-adding via Xcode and
   discarding my pbxproj hunks — the .swift files are the real work.**

6. Docs: architecture.md (AI layer + navigation/identity), README (status +
   building — removed the stale XcodeGen instructions), this note.

## Deliberate decisions / deviations

- **No subagents.** The brief suggested delegating chunks, but with zero compile
  feedback on this machine, single-author cross-file consistency was the only
  defense against symbol mismatches. Everything was written after reading every
  existing source file.
- Conversation persistence, streaming replies, sleep/check-in chat tools, inline
  card editing: deferred, per the spec's own deferred list.
- Screen Time / HealthKit untouched; simulator path stays App-Group-free; no
  entitlement changes; no new dependencies; key stays in Keychain only.

## Known risks for the Mac/Opus session (ranked)

1. **It has never compiled.** Expect a handful of Swift errors. Likely spots:
   - `ChatEngine.swift` / `ChatView.swift`: `@Observable` usage (needs
     `import Observation` — present), enum `ChatItem` non-isolated `var id`
     touching a `@MainActor` class's `let id` (fine under Swift 5 minimal
     concurrency, which this target uses — `SWIFT_VERSION 5.0`, no strict flag).
   - `ClaudeAIClient.chat`: `[String: Any]` literal inference in the `tools.map`
     and `encodeTurn` closures (explicit return types added, but this is classic
     inference-failure territory).
   - `DashboardView`: `.onChange(of:)` zero-parameter closure and
     `Date.now, format:` FormatStyle usage — both iOS 17-fine, but check.
2. **Tool-use wire format** was written from current API docs, not exercised.
   If chat 400s, print the response body from `AIClientError.badResponse` —
   most likely a schema nit in the `tools` array.
3. **`DailyContext` changed shape** (new memberwise params). Only constructor is
   `todayContext()` (updated); Stub/Claude clients only read `meals`. Codable
   changes don't matter (it's encoded, never decoded).
4. **pbxproj hand edits** (see item 5 above for the recovery path).
5. Minor: chat scroll anchoring behavior, card layout on small screens — polish
   in the sim if off.

## On-device test checklist (needs a real key, ~€0.10 of Sonnet)

1. Build **Health Assistantv2** scheme → iPhone simulator → launches clean, no
   crash, dashboard shows greeting/hero/stats/streak/summary/modules.
2. Settings (gear) → paste API key → Save → "A key is saved on this device."
   Dashboard's "Connect the assistant" card disappears (after re-entering the
   screen — `hasKey` is computed per render).
3. Assistant → "I had two eggs and toast" → meal card appears with per-food rows
   (grams + kcal + macros), totals, confidence → **Save** → card shows "Saved",
   dashboard meals count ticks up, Nutrition history has the entry.
4. "Did push day, bench 3×8 at 60kg" → workout card with sets → Save → Workout
   log shows it.
5. "How has my week been?" → it calls get_recent_summaries and answers from your
   data (with fresh data it should mention today's entries).
6. Discard path: propose another meal → Discard → nothing written.
7. No key (clear it in Settings): chat still works via stub (canned reply);
   dashboard shows the connect card; Estimate-with-AI buttons show the
   "add your key" message instead of calling out.
8. Nutrition → describe a meal → **Estimate with AI** → fields fill, tweak,
   Add meal. Workout → + → describe → **Fill in with AI** → form fills → Save.
9. Dashboard → Generate summary → 3–5 sentence summary referencing actual meals/
   workout/streak lands in the card and persists (it's on today's rollup).
10. Kill + relaunch: data persists; chat transcript does NOT (by design, v1).

## Resume state

- ✅ Chat assistant stages 1–3 authored per spec + journal/0004, incl. the
  show-your-work card refinement.
- ✅ Summary enrichment, AI-assist on manual forms, design pass, first-run key path.
- ⏸️ Verified-on-device M2 behavior (key + summary) should be re-tested after the
  dashboard rewrite — logic untouched, UI moved from List to cards.
- 🔜 Next: **compile on the Mac**, fix, run the checklist above, then consider the
  deferred list (persistence of conversations, streaming, promoting chat to
  literal home screen).

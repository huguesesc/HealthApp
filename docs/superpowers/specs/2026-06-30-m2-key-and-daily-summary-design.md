# M2 slice 1 — API key + one-tap daily summary

Date: 2026-06-30
Status: approved (design), authored on Windows, pending first Mac build to verify.

## Context

M1 runs offline: the app logs meals/workouts/sleep/check-ins and shows a dashboard,
but the "Daily summary" card just reads "No summary yet — AI summary comes in M2."
The whole AI engine already exists — `ClaudeAIClient` implements `summarizeDay`,
`HealthDataRepository.todayContext()` assembles the day's data, `DailyRollup` has
`summaryText`/`modelUsed` fields, and `APIKeyStore` wraps the Keychain. M2 slice 1 is
**wiring + UI**, not engine-building: let the user enter a key, switch the factory to
the real client when a key exists, and turn the placeholder into a real one-tap summary.

This is the smallest path that exercises the entire AI pipeline end-to-end
(key → factory → real API call → save → display). Meal estimate and the assistant
question box (later slices) reuse the exact same plumbing.

API model: **BYOK (bring-your-own-key)** — the user pastes their own Anthropic API key
(`console.anthropic.com`, pay-per-use; NOT a Claude.ai subscription). Correct for dev
and technical early users; a backend proxy replaces it for real users later, swapped in
behind `AIClientFactory`/`AIClient` with no other code change.

## Changes

1. **`Sources/AI/AIClientFactory.swift`** — enable the opt-in already written in the
   file's comment: return `ClaudeAIClient()` when `APIKeyStore.read()` is non-empty,
   else `StubAIClient()`.

2. **`Sources/Features/Settings/SettingsView.swift`** (new) — a `Form` with a
   `SecureField` for the key, **Save** and **Clear** buttons (→ `APIKeyStore`), a
   "key is / isn't saved" status line, and a footer pointing to console.anthropic.com.
   Reached via a gear icon in the dashboard toolbar.

3. **`Sources/Data/HealthDataRepository.swift`** — add `saveTodaySummary(_:)`: upsert
   today's rollup via `refreshTodayRollup()`, set `summaryText` + `modelUsed`, persist.
   Keeps writes on the existing write-seam.

4. **`Sources/Features/Dashboard/DashboardView.swift`** — toolbar gear →
   `SettingsView`; a **Generate summary** button in the Daily summary section with a
   spinner and inline error. Tap → `repo.todayContext()` →
   `AIClientFactory.makeDefault().summarizeDay(_:)` → `repo.saveTodaySummary(_:)`; the
   `@Query` re-renders the text. No key set → a gentle "Add your API key in Settings"
   hint instead of silently running the stub.

Model stays `claude-haiku-4-5` (cheapest tier; ~¼ cent per summary).

## Verification (next Mac session)

1. Build & run in the iOS simulator (Cmd+R), land on Today.
2. Settings (gear) → paste a real `sk-ant-…` key → Save → status flips to "saved".
3. Log a meal → back on Today, tap **Generate summary** → spinner → a real 2–4 sentence
   summary replaces the placeholder.
4. Relaunch the app → the summary persisted (it's on `DailyRollup`).
5. Edge cases: no key → hint shown, no crash; deliberately wrong key → friendly 401
   error, no crash.

Pre-flight (Windows, optional): `Invoke-RestMethod` POST to `/v1/messages` with the key
confirms the key/model/billing work before spending Mac time.

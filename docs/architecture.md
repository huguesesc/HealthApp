# Architecture

## Shape

```
SwiftUI views
      │
      ▼
HealthDataRepository  ── read/write seam across all modules
      │
      ├──► SwiftData (local store for M1 simulator, on-device)
      ├──► ActivityEvent stream ──► RewardsEngine (streaks/rewards)
      └──► DailyRollup (compact daily history)
                                   │
AIClient (protocol) ──► StubAIClient (default)  ──► ClaudeAIClient (M2, raw HTTPS)
                                   ▲
                          reads compact RollupSnapshots, not raw rows

HealthKit (later) + Screen Time (App Group bridge, coarse signal only)
```

- **Native iOS / SwiftUI / SwiftData.** Single app target plus one app-extension
  target for Screen Time monitoring.
- **Local-first.** All user data on-device. Network is touched only for AI.

## Core layers

### Persistence

`PersistenceController` currently uses the default local SwiftData store. This is
the correct M1 simulator setup: it avoids requiring App Group entitlements and
keeps the app runnable on a plain Xcode simulator.

When Screen Time moves to real-device testing, the App Group bridge belongs in the
Screen Time milestone, with entitlements configured for both the app and the
DeviceActivity extension. Do not reintroduce App Group-backed app persistence until
that entitlement path is actually available.

### HealthDataRepository — the read/write seam

`Sources/Data/HealthDataRepository.swift` is the main interface across modules.
Views **write** through it (so an `ActivityEvent` is recorded alongside the data,
feeding rewards), and the dashboard / future assistant **read** cross-module
snapshots and trends through it. It's a thin `@MainActor` value wrapper around a
`ModelContext`, built per-view from `@Environment(\.modelContext)`.

Per-module history lists may still use SwiftData `@Query` for live updates — the
repository is the *write* seam and the *cross-module / trend read* seam, not a
replacement for simple live queries.

Queries deliberately **fetch-then-filter in Swift** rather than using `#Predicate`.
Data volumes are tiny (one person), and this avoids brittle predicate compilation.

### DailyRollup — cheap history

`DailyRollup` is one compact record per day (meals logged, calories, workout
done, sleep quality/hours, energy/mood, screen-time signal, optional AI summary).
The assistant reads these small records over weeks instead of thousands of raw
rows — the key cost-control move. `RollupSnapshot` is its plain Codable mirror,
handed to the AI layer so SwiftData models never leak into it.

### ActivityEvent + RewardsEngine

Every meaningful action emits an `ActivityEvent` (logged meal, completed workout,
etc.). `RewardsEngine` is a pure-function stub over that stream (streak counting
today; points/badges/screen-time currency later). Keeping rewards as one shared
event log — not logic embedded per feature — is what keeps it from tangling.

## Data model (SwiftData)

| Entity | Holds |
|--------|-------|
| `Meal` | timestamp, raw text, optional kcal/protein/carbs/fat, confidence |
| `WorkoutSession` + `ExerciseSet` | type, duration, effort, sets (name/reps/weight) |
| `SleepEntry` | bedtime, wake, perceived quality, naps, tiredness |
| `DailyCheckIn` | energy, mood, hunger, soreness, focus, stress, note |
| `DailyRollup` | compact per-day summary + optional AI text |
| `ActivityEvent` | timestamped action for rewards/reminders |
| `ScreenTimeSnapshot` | coarse daily screen-time signal |

## AI layer

`AIClient` exposes intent-level methods, not raw prompts:

- `parseMeal(text:)` — text → nutrition estimate ("Estimate with AI" on the meal form)
- `parseWorkout(text:)` — text → structured sets ("Fill in with AI" on the workout form)
- `summarizeDay(_:)` — hedged daily summary from an enriched `DailyContext`
  (per-meal macros, workout detail, sleep quality, check-in note, streak)
- `ask(_:recent:)` — one-shot Q&A over compact `RollupSnapshot` history
- `chat(_:tools:system:)` — **the centerpiece**: one round of the agentic tool-use
  loop. `ChatEngine` (`Sources/Features/Chat/`) drives it: `propose_meal` /
  `propose_workout` draft inline confirmation cards (per-food portion assumptions
  shown so the user can catch bad guesses; writes happen only on Save, through
  `HealthDataRepository`), `get_recent_summaries` feeds rollup JSON back for data
  questions. Chat runs on `claude-sonnet-4-6`; one-shot calls stay on Haiku.
- `estimateMeal(image:)` — **future/premium**, throws `notImplemented`

Implementations:
- `StubAIClient` — deterministic, offline. The **default** via `AIClientFactory`.
- `ClaudeAIClient` — raw HTTPS to `/v1/messages` (no official Swift SDK). Default
  model `claude-haiku-4-5`, swappable via one constant. Enabled in M2.

Voice transcription is a separate seam (`VoiceTranscriber`), planned to use Apple's
on-device `Speech` framework (free, private) → text → `parseWorkout`/`parseMeal`.

### Key handling & the backend boundary

No key in source. `APIKeyStore` reads/writes the Claude key in the Keychain; the
user enters it once. For a single-user personal app this is the pragmatic,
serverless choice.

**Where a backend/proxy fits:** premium/metered features (notably photo/vision
estimation) can't protect a key or meter usage client-side. When that arrives,
return a client that targets your own proxy from `AIClientFactory` /
`ClaudeAIClient`'s endpoint — everything upstream is provider-agnostic, so nothing
else changes. Not built now; not precluded.

## Screen Time

See `docs/screen-time.md` for the full capability/limit breakdown. Summary: the app
can pick apps, set thresholds, and receive a threshold callback in an extension; raw
per-app durations stay sandboxed, so only a **coarse "exceeded limit" signal**
crosses (via App Group) into the rollup and the AI. Needs the Family Controls
entitlement + a real device. The rest of the app does not depend on it.

## Safety

Summary/estimate/assistant prompts use hedged language ("rough estimate",
"consider", "general wellness suggestion") and avoid diagnosis, extreme dieting, or
unsafe workout advice. Prompt text lives next to `ClaudeAIClient` for review.

### Known compliance risk (flagged, not yet relevant)

Once HealthKit data is in play, sending it to a third-party LLM is restricted by
App Store guideline 5.1.3. The assistant will need explicit, per-data-type consent
and a privacy policy. Designed for, not built yet.

## Navigation & identity

`RootView` is a single `NavigationStack` with `DashboardView` as home. The
**Assistant (ChatView) is the front door** — the hero card at the top of the
dashboard; every module remains reachable from the module list below. No tab bar.

Visual identity lives in `Sources/Shared/Theme.swift` (evergreen / moss / clay /
honey over system grouped backgrounds, shared `.card()` container, rounded stat
numerals). New UI should use `Theme` colors, not ad-hoc ones.

## Decisions log

Material decisions and open questions live in `journal/`.

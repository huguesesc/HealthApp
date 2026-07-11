# Adaptive Health & Workout Coach — Design

Date: 2026-07-11
Status: approved direction; Phase 1 implementation has not started (handoff preserves this specification)
Base: `test/fix-settings-section-initializers` @ `9c9f4a8`
(checkpoint tag `checkpoint/pre-adaptive-coach-2026-07-11`)

This document is the durable record of the whole adaptive-coach product direction.
No roadmap phase is implemented by this handoff; everything here is direction,
not code. Do not delete phases from this file when they ship — mark them done.

## Product vision

Turn the app into a **local-first adaptive health and workout coach** that combines:

- user goals and limitations;
- Apple Health activity and recovery summaries;
- meal and protein tracking;
- body-measurement trends;
- workout locations and available equipment;
- structured workout plans;
- active workout execution;
- movement feedback;
- user-confirmed long-term memory;
- a central assistant that bridges all modules.

The loop is:

> Understand the user → create a realistic plan → guide the workout → record what
> happened → identify useful patterns → improve the next plan.

## Product principles

1. **Useful without AI.** Every screen works offline with no key.
2. **Local-first structured data.** SwiftData on device is the source of truth.
3. **Raw HealthKit samples stay local.** Only compact aggregates reach the AI layer.
4. **Compact AI context only.** Snapshots, never raw database dumps.
5. **Confirmation before AI writes.** The assistant drafts; the user saves.
6. **No diagnosis.** Ever. The app records what the user reports.
7. Mechanical reasoning may inform **conservative** adjustments.
8. Medical-sounding language must not be the default UI. Prefer **"Adjust"** and
   **"How did that feel?"** over a prominent Pain button.
9. **User-reported health facts must remain distinguishable from model inference.**
   (`HealthConsideration.source` exists for exactly this.)
10. **Long-term profile changes require user confirmation.** The model never
    rewrites user memory automatically.

## Long-term roadmap

- **Phase 1 (this branch):** health/profile foundation; body metrics; workout
  locations; equipment inventory; assistant read access.
- **Phase 2:** structured workout plans; ordered workout steps;
  location/equipment-aware AI plan drafts.
- **Phase 3:** Active Workout Mode; rep screen; countdown, stopwatch, intervals and
  rest timers; planned-versus-actual execution; crash/interruption recovery.
- **Phase 4:** neutral movement-feedback flow; body area and side; stable / tight /
  weak / unsteady / uncomfortable; action taken; exact exercise/set context;
  similar-history matching.
- **Phase 5:** questions during active workouts; current-exercise context; Apple
  Health recovery context; conservative mechanical reasoning; deterministic
  stop-and-review conditions.
- **Phase 6:** protein and calorie targets; body-measurement trends;
  nutrition/training/recovery synthesis.
- **Phase 7:** monthly compact review; stronger-model analysis; proposed
  memory/profile changes with **Accept / Edit / Discard**.
- **Phase 8:** production backend; StoreKit subscription; managed AI; credit
  ledger; cost telemetry.
- **Phase 9:** release polish; accessibility; TestFlight; privacy policy;
  App Review preparation.

## Pricing direction — DOCUMENT ONLY, not implemented

**Free:** free download; manual logging; Apple Health sync; body metrics; basic
workout timer and execution; dashboard/history; ~10 introductory AI credits.

**Coach Pro:** €1.99 monthly / €11.99 yearly; 25 monthly AI credits; advanced
coaching and workout features.

**Additional AI:** €0.99 for 40 credits; €2.99 for 160 credits.

Purchased credits and monthly credits must eventually be **separate balances**.
No StoreKit, no backend, no credit enforcement on this branch (Phase 8).

## Model routing direction — DOCUMENT ONLY

- Low-cost model (Haiku-class) for extraction, classification, routine summaries.
- Sonnet-class model for workout generation and normal coaching.
- Opus/Fable-class model only for occasional longitudinal review (Phase 7).
- No raw database dumps in prompts; snapshots only.
- No unrestricted model-written memory; profile changes go through user
  confirmation (Accept / Edit / Discard).

Today the app already routes one-shot calls to `claude-haiku-4-5` and chat to
`claude-sonnet-4-6` (`ClaudeAIClient`); this direction extends that split.

---

# Phase 1 — Foundation (specified; not implemented in this handoff)

Phase 1 establishes structured knowledge about the user and their workout
environment, plus read-only assistant access to it. **No** plans, timers, active
execution, movement feedback, payments or monthly review.

## Data model (new SwiftData entities)

All entities are **new** — no existing entity changes — so SwiftData lightweight
migration only has to add tables. All enums are stored as raw `String`
(`ActivityEvent.typeRaw` pattern) for forward compatibility.

### HealthProfile (singleton by convention)

One current profile for the local user. `HealthDataRepository.currentProfile()`
fetch-or-creates it; the oldest `createdAt` wins if duplicates ever appear.

- `id: UUID`, `createdAt`, `updatedAt`
- `unitSystemRaw` — metric | imperial (display conversion only; storage is SI)
- `primaryGoalRaw` — build strength | build muscle | lose fat | improve endurance |
  improve mobility | general health | custom, plus `goalDetail: String?`
- `experienceLevelRaw` — beginner | intermediate | advanced | returning after a break
- `preferredActivitiesText` — free text, comma-separated; computed `[String]`
- `weeklyTrainingDays: Int?` (0–7), `preferredSessionMinutes: Int?`
- `generalPreferences: String?`, `notes: String?`

Large unstructured AI memory does **not** belong here.

### HealthConsideration

Normalized, user-reported considerations — **reports, not diagnoses**. Example:
"Left knee — previous surgery ~2 years ago — goal: confidence & proprioception —
sometimes feels less stable under fatigue."

- `id: UUID`, `createdAt`, `updatedAt`
- `title` (e.g. "Left knee")
- `bodyAreaRaw` — neck/shoulder/elbow/wrist/hand/upper back/lower back/hip/knee/
  ankle/foot/core/other
- `sideRaw` — left | right | both | central | unspecified
- `categoryRaw` — previous surgery | previous injury | weakness | instability |
  uncomfortable movement | clinician guidance | custom
- `userDescription` — the user's own words
- `statusRaw` — active | monitoring | archived
- `sourceRaw` — user entered (the mechanism keeping user facts distinguishable
  from any future model inference)
- `approximateWhen: String?` (free text; approximate dates are normal)
- `userGuidance: String?` (e.g. what a clinician actually told them)
- `confirmedByUser: Bool`

### BodyMetricEntry

- `id: UUID`, `timestamp`
- `weightKilograms: Double?`, `heightCentimeters: Double?` (height is a snapshot)
- `sourceRaw` — manual | healthKit (HealthKit weight import is future work)
- `note: String?`

Storage is always SI; the UI converts for imperial users. **BMI is not persisted**
— it is derivable at display time if ever wanted.

### WorkoutLocation

- `id: UUID`, `name`, `categoryRaw` — home | gym | outdoors | travel |
  sport venue | custom
- `notes: String?`, `spaceLimitations: String?`
- `isActive: Bool` (archive = flip to false; never delete history)
- `createdAt`, `updatedAt`
- `equipment: [EquipmentItem]` (cascade delete, inverse `EquipmentItem.location`)

### EquipmentItem

- `id: UUID`, `name`, `categoryRaw` (see catalog below), `quantity: Int`
- `minWeightKilograms` / `maxWeightKilograms: Double?`
- `resistanceDescription: String?` (bands etc.)
- `isAvailable: Bool`, `notes: String?`, `location: WorkoutLocation?`

Category catalog (each with a coarse computed capability —
strength / cardio / balance / mobility / support):
bodyweight, yoga mat, stability ball, mini resistance bands, long resistance
bands, foam balance pad, wobble board, balance disc, BOSU-style trainer, slant
board, dumbbells, kettlebells, barbell, squat rack, cable station, leg press,
hamstring curl, stationary bike, treadmill, rowing machine, custom.

No subclassing; simple entities and raw-string enums that serialize reliably.
`WorkoutSession` / `ExerciseSet` are untouched — workout location snapshots on
sessions belong to Phase 2.

## Migration & persistence

- All five entities added to `PersistenceController`'s explicit `Schema`.
- **Lightweight migration is sufficient**: the change set is "new entities only";
  existing `Meal`, `WorkoutSession`, `ExerciseSet`, `SleepEntry`, `DailyCheckIn`,
  `DailyRollup`, `ActivityEvent`, `ScreenTimeSnapshot` rows are untouched.
- No store resets, no destructive fallbacks, no schema-version machinery (would be
  speculative today; add `VersionedSchema` only when an existing entity changes).
- Previews/tests share the same schema through `PersistenceController(inMemory:)`.

## Repository layer

`HealthDataRepository` is extended (in `HealthDataRepository+AdaptiveCoach.swift`)
— screens do not invent their own persistence:

- `currentProfile()` fetch-or-create; `profileDidChange(_:)` bumps `updatedAt`.
- `addConsideration`, `considerationDidChange`, `archiveConsideration`,
  `activeConsiderations()` (archived excluded by default), `allConsiderations()`.
- `addBodyMetric`, `recentBodyMetrics(limit:)`, `latestBodyMetric()`.
- `addLocation`, `locationDidChange`, `archiveLocation`, `activeLocations()`,
  `allLocations()`.
- `addEquipment(_:to:)`, `equipmentDidChange`, `removeEquipment`.
- Snapshots for the AI layer (plain Codable, never SwiftData models):
  `HealthProfileSnapshot`, `HealthConsiderationSnapshot`,
  `WorkoutLocationSnapshot`, `EquipmentSnapshot`, `BodyMetricTrendSnapshot`.
  Snapshot reads never create records (tools stay read-only).

Coach entities do **not** emit `ActivityEvent`s in Phase 1 — streak semantics are
about daily logging, and changing them here would be a silent behavior change.

## Phase 1 UI

Navigation: Settings gains a "Profile & coaching" section (Profile, Workout
locations); the dashboard module list gains a "Profile & coach" row. Existing
Theme (evergreen/moss/clay/honey, `.card()`) everywhere; Dynamic Type; labels on
all controls; no color-only state; VoiceOver-friendly forms.

- **ProfileView** — goal, experience, weekly availability, session length,
  preferred activities, preferences/notes; links to considerations, body metrics
  and workout locations.
- **HealthConsiderationsView** — active list + archived section; add/edit/archive
  via an editor sheet; neutral, non-alarmist copy; explicit footer that entries
  are the user's own reports, not medical assessments.
- **BodyMetricsView** — latest weight/height, add form, simple 30-day trend line
  of text (no chart dependency in Phase 1), history; metric/imperial input.
- **WorkoutLocationsView** — active locations with equipment counts; archived
  section; clear empty state.
- **WorkoutLocationEditorView** — name, category, notes, space limitations,
  equipment inventory management, one-tap **suggestions** (Home: yoga mat,
  stability ball, mini bands, long bands, foam balance pad, wobble board,
  dumbbells; Gym: squat rack, cable station, leg press, hamstring curl,
  stationary bike, treadmill). Suggestions are added only when tapped — nothing
  auto-saves.
- **EquipmentEditorView** — predefined category picker, custom name, quantity,
  weight/resistance range, availability, notes.

The fast path stays fast: create "Home", tap two suggestion chips, done.

## Assistant read tools (Phase 1)

Two new **read-only** tools in the chat loop (`CoachAssistantTools`, wired into
`ChatEngine`):

- `get_health_profile` → goals, experience, preferences, availability,
  active+monitoring user-reported considerations (flagged `userReported: true`),
  compact body-metric trend. Returns a friendly "not set up yet" string when the
  profile doesn't exist — it never creates one.
- `get_workout_locations` → active locations, their **available** equipment,
  notes and space limitations.

Rules enforced in Phase 1: no AI profile writes; no automatic memory
modification; no workout-plan generation; no diagnosis; no raw SwiftData model
encoding; compact trend instead of full measurement history; existing
`propose_meal` / `propose_workout` / `get_recent_summaries` and the
confirmation-based logging flow are unchanged. The stub client still answers
offline, so the app keeps working with no key.

## Safety boundary

The system prompt tells the model the considerations are the user's own reports,
to account for them conservatively, and to never diagnose or prescribe
treatment/rehabilitation. UI copy uses "consideration", "your report", "Adjust" —
not medical framing. This boundary is a hard requirement for every later phase.

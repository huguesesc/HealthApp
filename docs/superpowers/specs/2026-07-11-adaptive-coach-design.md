# Adaptive Health & Workout Coach — Design

Date: 2026-07-11
Status: approved direction; Phase 1 implemented on `feature/adaptive-coach-foundation`, awaiting Mac/Xcode verification
Base: `test/fix-settings-section-initializers` @ `9c9f4a8`

This is the durable product and architecture record for the adaptive coach. Shipped
phases remain documented here and are marked with their implementation status.

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

The product loop is:

> Understand the user → create a realistic plan → guide the workout → record what
> happened → identify useful patterns → improve the next plan.

## Product principles

1. **Useful without AI.** Local screens and tracking work without an API key.
2. **Local-first structured data.** SwiftData on device is the source of truth.
3. **Raw HealthKit samples stay local.** Only compact aggregates reach the AI layer.
4. **Compact AI context only.** Snapshots, never raw database dumps.
5. **Confirmation before AI writes.** The assistant drafts; the user saves.
6. **No diagnosis.** The app records what the user reports.
7. Mechanical reasoning may inform conservative adjustments in later phases.
8. Medical-sounding language is not the default UI. Prefer **Adjust** and
   **How did that feel?** over a prominent Pain button.
9. User-reported health facts remain distinguishable from model inference.
10. Long-term profile changes require explicit user confirmation.

## Roadmap

- **Phase 1 — implemented, awaiting Xcode verification:** health/profile foundation,
  body metrics, workout locations, equipment inventory, assistant read access.
- **Phase 2:** structured workout plans, ordered workout steps, editable
  location/equipment-aware AI plan drafts.
- **Phase 3:** Active Workout Mode, rep screen, countdown/stopwatch/interval/rest
  timers, planned-versus-actual execution, interruption recovery.
- **Phase 4:** neutral movement feedback, body area and side, sensations such as
  stable/tight/weak/unsteady/uncomfortable, action taken, exercise/set context,
  similar-history matching.
- **Phase 5:** questions during active workouts, current-exercise context, Apple
  Health recovery context, conservative mechanical reasoning, deterministic
  stop-and-review conditions.
- **Phase 6:** protein and calorie targets, body-measurement trends,
  nutrition/training/recovery synthesis.
- **Phase 7:** compact monthly review, stronger-model analysis, proposed memory or
  profile changes with Accept/Edit/Discard.
- **Phase 8:** production backend, StoreKit subscription, managed AI, credit ledger,
  cost telemetry.
- **Phase 9:** accessibility and release polish, TestFlight, privacy policy, App
  Review preparation.

## Pricing direction — not implemented

**Free:** free download, manual logging, Apple Health sync, body metrics, basic
workout timer and execution, dashboard/history, approximately 10 introductory AI
credits.

**Coach Pro:** €1.99 monthly or €11.99 yearly, 25 monthly AI credits, advanced
coaching and workout features.

**Additional AI:** €0.99 for 40 credits; €2.99 for 160 credits.

Purchased and monthly credits eventually use separate balances. No StoreKit,
backend, or credit enforcement belongs in Phase 1.

## Model routing direction — not implemented beyond the current app split

- Haiku-class model for extraction, classification, and routine summaries.
- Sonnet-class model for workout generation and normal coaching.
- Opus-class model only for occasional longitudinal review.
- No full database or raw HealthKit dump in prompts.
- No unrestricted model-written memory.

The current app already routes one-shot calls to `claude-haiku-4-5` and chat to
`claude-sonnet-4-6`. Later phases extend that routing rather than replace it.

---

# Phase 1 — Foundation

## Implementation status

Implemented on `feature/adaptive-coach-foundation`:

- five new SwiftData entities and persisted raw-string enums;
- schema registration without modifying existing entities;
- repository operations and compact assistant snapshots;
- profile, consideration, body-metric, location, and equipment screens;
- Settings entry points;
- read-only `get_health_profile` and `get_workout_locations` assistant tools;
- Swift Testing coverage for persistence, filtering, trends, tools, and safety copy.

The implementation has not yet been built or tested with Xcode. SwiftData migration,
file-system-synchronized target inclusion, SwiftUI layout, and device persistence
remain explicit Mac verification requirements.

## Source layout

The new app-target source files are placed under the Xcode 16
file-system-synchronized app group:

- `Health Assistantv2/AdaptiveCoach/AdaptiveCoachModels.swift`
- `Health Assistantv2/AdaptiveCoach/HealthDataRepository+AdaptiveCoach.swift`
- `Health Assistantv2/AdaptiveCoach/ProfileViews.swift`
- `Health Assistantv2/AdaptiveCoach/WorkoutEnvironmentViews.swift`

This avoids duplicating them in the classic `Sources` PBX group and avoids a broad,
risky `project.pbxproj` rewrite.

## Data model

All persisted enums use raw `String` values for forward compatibility. New records
store SI values where applicable.

### HealthProfile

One current local profile, singleton by repository convention:

- `id`, `createdAt`, `updatedAt`;
- unit system;
- primary goal and optional detail;
- experience level;
- preferred activities;
- weekly training days;
- preferred session duration;
- general preferences and notes.

Large unstructured AI memory does not belong in this entity.

### HealthConsideration

A normalized user report, not a diagnosis:

- title;
- body area and side;
- category such as previous surgery, previous injury, weakness, instability,
  uncomfortable movement, clinician guidance, or custom;
- the user's own description;
- active, monitoring, or archived status;
- source fixed to user-entered in Phase 1;
- approximate date and optional user-entered guidance;
- explicit user-confirmation flag.

### BodyMetricEntry

- timestamp;
- optional weight in kilograms;
- optional height snapshot in centimetres;
- manual or future HealthKit source;
- optional note.

BMI is not persisted. It can be derived for display later.

### WorkoutLocation

- name and category;
- notes and space/setup limitations;
- active/archive state;
- timestamps;
- cascade relationship to equipment.

### EquipmentItem

- name and equipment category;
- quantity;
- optional minimum/maximum kilograms;
- resistance description;
- available/unavailable state;
- notes;
- location relationship.

The equipment catalog includes bodyweight, yoga mat, stability ball, mini/long
bands, foam balance pad, wobble board, balance disc, BOSU-style trainer, slant
board, dumbbells, kettlebells, barbell, squat rack, cable station, leg press,
hamstring curl, stationary bike, treadmill, rowing machine, and custom items.

`WorkoutSession` and `ExerciseSet` remain unchanged. Historical location/equipment
snapshots belong to Phase 2.

## Migration and persistence

- The five entities are added to `PersistenceController`'s explicit schema.
- Existing meal, workout, sleep, check-in, rollup, activity, HealthKit, and screen
  time entities are unchanged.
- No destructive fallback or store reset is added.
- The expected path is SwiftData lightweight migration because this phase adds only
  new entities, but this is not considered verified until an existing device store
  opens successfully in Xcode/on device.
- Phase 1 profile/environment changes do not create `ActivityEvent` rows.

## Repository layer

`HealthDataRepository+AdaptiveCoach.swift` owns the new persistence behavior:

- fetch-or-create current profile and read existing profile without creation;
- add/edit/archive considerations;
- add and fetch body metrics;
- add/edit/archive/restore locations;
- add/edit/remove equipment;
- build compact Codable snapshots.

Assistant snapshots are plain values and never encode SwiftData models directly.
Read-only snapshot calls do not create a profile or mutate the store.

## Phase 1 UI

Settings includes **Profile & coaching** entry points.

- **ProfileView:** goal, experience, availability, preferred session length,
  activities, preferences, notes.
- **HealthConsiderationsView:** active and archived user reports with neutral copy.
- **BodyMetricsView:** latest measurement, history, simple text trend, metric and
  imperial input/display conversion.
- **WorkoutLocationsView:** active and archived locations and equipment counts.
- **WorkoutLocationEditorView:** location context, inventory management, archive or
  restore, and one-tap suggestions.
- **EquipmentEditorView:** predefined/custom equipment, quantity, weight range,
  resistance, availability, and notes.

Home suggestions include yoga mat, stability ball, mini bands, long bands, foam
balance pad, wobble board, and dumbbells. Gym suggestions include squat rack, cable
station, leg press, hamstring curl, stationary bike, and treadmill. Nothing is
added until the user taps a suggestion.

## Assistant read tools

Two new read-only tools are wired directly into `ChatEngine`:

- `get_health_profile` returns goal, experience, preferences, availability,
  confirmed non-archived user reports, and a compact body-metric trend;
- `get_workout_locations` returns active locations, available equipment, notes,
  and space limitations.

The tools never write profile data, generate workout plans, or rewrite memory.
Existing `propose_meal`, `propose_workout`, and `get_recent_summaries` behavior is
preserved.

## Safety boundary

The system prompt and UI state that considerations are the user's own reports. The
assistant may account for them conservatively, but it must not diagnose, infer a
condition, prescribe treatment or rehabilitation, or override clinician guidance.

## Phase 1 acceptance gate

Phase 1 is complete only after a Mac verifies:

1. clean simulator build;
2. unit tests;
3. launch without immediate crash;
4. existing local store opens without data loss;
5. profile, considerations, metrics, locations, and equipment persist;
6. assistant tools return compact context and do not mutate data;
7. existing meal/workout confirmation and Apple Health flows still open;
8. physical-device HealthKit behavior remains intact.

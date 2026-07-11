# Structured Workout Plans — Phase 2 Design

Date: 2026-07-11
Status: implemented on `feature/structured-workout-plans`; Mac verification required
Base: `feature/adaptive-coach-foundation`

## Objective

Add editable future workout plans that work without AI and can also be drafted by the assistant from compact, user-confirmed context.

This phase creates plans. It does not execute them. Timers, live set completion, planned-versus-actual tracking, interruption recovery, movement feedback, and in-workout coaching remain Phase 3 and later.

## Product behavior

A user can:

- create a plan manually;
- choose an active workout location;
- store a snapshot of currently available equipment;
- add, edit, delete, and reorder structured steps;
- archive and restore plans;
- ask the assistant to draft a plan;
- review the complete ordered draft before saving;
- edit an assistant-authored plan after saving.

The assistant can read the profile, active locations, available equipment, recent summaries, and saved-plan snapshots. It cannot save a plan without the user pressing **Save plan**.

## Data model

### WorkoutPlan

- identity and timestamps;
- title, goal, notes;
- estimated duration and target effort;
- selected location ID/name/category snapshots;
- available-equipment summary snapshot;
- source: manual or assistant;
- archived state;
- cascade-owned ordered steps.

### WorkoutStep

- stable identity, timestamps, and explicit order;
- type: warm-up, exercise, mobility, hold, cardio, interval, distance, rest, cooldown, or free-form;
- title and instruction;
- optional sets, reps, duration, distance, load, rest-after, side, equipment snapshot, and notes.

All categories use raw strings. Existing persisted models remain unchanged. This is another additive schema change and must be tested against an existing device store.

## Location and equipment rules

Plans snapshot their environment instead of depending on a live relationship. This preserves what the plan was designed around even if the location inventory later changes.

Assistant-authored steps keep an equipment name only when it matches equipment currently marked available at the resolved active location. Unknown or unavailable equipment is omitted during confirmation rather than being silently represented as available.

Manual plans remain editable. Users may type equipment notes directly because a plan can describe future access or a non-catalog item.

## Assistant workflow

For a future-plan request, the system prompt requires this sequence:

1. `get_health_profile`
2. `get_workout_locations`
3. `propose_workout_plan`

The proposal includes ordered steps and appears as a confirmation card. `get_workout_plans` supports questions about existing plans.

The assistant must:

- use only available equipment at the named active location;
- fit the requested duration and stated experience;
- treat health considerations as user reports, not diagnoses;
- use conservative adjustments;
- avoid treatment, rehabilitation, medical-safety claims, and overriding clinician guidance.

## UI

Settings → Profile & coaching gains **Structured workout plans**.

The plan list separates active and archived plans. The editor supports location snapshots, ordered steps, drag-to-reorder, and type-specific fields. The chat proposal card shows the complete ordered workout before confirmation.

## Out of scope

- starting or completing a plan;
- countdown, stopwatch, interval, or rest timers;
- live workout persistence;
- planned-versus-actual performance;
- movement feedback;
- injury or pain classification;
- automatic plan adaptation;
- StoreKit, backend, or credits;
- watchOS.

## Verification requirements

Before merge, run a clean simulator build and tests on macOS, then manually verify:

- migration with existing Phase 1 data;
- manual plan creation and persistence;
- step add/edit/delete/reorder;
- archive/restore;
- location and equipment snapshots;
- assistant draft, discard, and confirmation;
- invalid/unavailable assistant equipment is not stored;
- existing meal/workout confirmation and HealthKit behavior remain intact.
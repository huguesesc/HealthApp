# Nell stabilization — workout completion, profile source and execution history

## Scope

This pass addresses four source-level issues identified during repository orientation:

1. Active Workout finish/save boundary.
2. Onboarding-to-profile persistence.
3. Nell-native access to durable workout execution history.
4. Duplicate and competing profile data paths.

## Changes

### Active Workout completion

The Nell completion overlay now appears only after the durable session has status `completed` and its legacy `WorkoutSession` conversion has been created.

Resolving the final workout step no longer hides the inherited finish form. The user can still review effort and notes and press **Save workout** before the interface claims that the workout is stored.

### Profile source of truth

`HealthProfile` and `HealthConsideration` in SwiftData are now the authoritative Coach-relevant profile records.

Onboarding remains a lightweight UI and uses its existing AppStorage values as a draft/replay cache. On completion, a synchronizer maps confirmed onboarding values into SwiftData:

- strength → `buildStrength`
- fitness → `improveEndurance`
- other onboarding goals → `generalHealth` with the complete selected-goal list retained in `goalDetail`
- training setting → one tagged line inside `generalPreferences`
- movement notes → one identifiable, user-reported `HealthConsideration`

The migration is versioned so normal app launches do not repeatedly overwrite later edits made in the detailed profile. Explicit onboarding completion forces a deliberate re-sync.

Preferred display name remains in AppStorage because it is a presentation preference rather than Coach health context.

### Profile navigation cleanup

The former AppStorage-backed goals, training-context and movement-notes editor has been removed from `NellProfilePreferencesView`.

Settings now exposes one **Personalisation and profile** route. That screen edits the display name and routes into the authoritative SwiftData coaching profile and movement considerations.

### Execution history

A Nell-native execution-history screen now presents:

- resumable in-progress and paused sessions
- completed executions
- ended-early executions
- saved duration, progress, completed/skipped steps, effort, location and notes

The route is available from **Train → Start or continue workout → Execution History**.

## Preserved behaviour

- Existing Active Workout timers, pause/resume and rest logic.
- Exactly-once conversion into `WorkoutSession`.
- Existing detailed SwiftData profile editor.
- Existing movement-consideration and body-metric models.
- Existing completed-workout Progress calculations.

## Added tests

- `NellActiveWorkoutBoundaryTests`
- `NellProfileSynchronizationTests`

These cover the final-step/save boundary, profile mapping, movement-note persistence and migration non-overwrite behaviour.

## Verification status

Source changes and tests are committed to `feature/nell-full-brand-and-ui-system`.

Not verified in this environment:

- Xcode compilation
- Swift Testing execution
- simulator launch
- physical-device migration
- visual review in light/dark mode

Required manual flow:

1. Resolve the final step of a workout.
2. Confirm the finish form remains visible.
3. Enter effort/notes and save.
4. Confirm the completion overlay appears only after saving.
5. Confirm one workout appears in Today/Progress.
6. Complete onboarding and verify the detailed profile and movement considerations.
7. Open Execution History from the Train flow and review resumable, completed and ended-early sessions.

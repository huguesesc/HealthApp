# 0008 - Structured workout plans

Date: 2026-07-11

## Git provenance

- Base branch: `feature/adaptive-coach-foundation`
- Implementation branch: `feature/structured-workout-plans`
- Phase 1 remains separate and unmodified.
- Main was not modified or merged.

## Scope delivered

Phase 2 adds editable future workout plans. It does not add active workout execution.

New app-target files:

- `Health Assistantv2/WorkoutPlans/WorkoutPlanModels.swift`
- `Health Assistantv2/WorkoutPlans/HealthDataRepository+WorkoutPlans.swift`
- `Health Assistantv2/WorkoutPlans/WorkoutPlanViews.swift`

Modified app files:

- `Sources/Persistence/PersistenceController.swift`
- `Sources/Features/Settings/SettingsView.swift`
- `Sources/Features/Chat/ChatEngine.swift`
- `Sources/Features/Chat/ChatView.swift`

New tests:

- `Health Assistantv2Tests/StructuredWorkoutPlanTests.swift`

Documentation:

- `docs/superpowers/specs/2026-07-11-structured-workout-plans-design.md`
- `docs/superpowers/plans/2026-07-11-structured-workout-plans.md`
- this journal entry.

## Data model

`WorkoutPlan` stores title, goal, notes, estimated duration, target effort, source, archive status, and selected environment snapshots. It cascade-owns ordered `WorkoutStep` rows.

`WorkoutStep` supports warm-up, exercise, mobility, hold, cardio, interval, distance, rest, cooldown, and free-form types. Optional fields cover sets, reps, duration, distance, target load, rest-after, side, equipment, instruction, and notes.

The schema change is additive. Existing Phase 1 and earlier models were not modified. Migration against an existing device store is still required before merge.

## Manual and assistant workflows

Manual plans work without an API key. Users can create, edit, reorder, archive, and restore plans from Settings → Structured workout plans.

Assistant plan requests use:

1. `get_health_profile`
2. `get_workout_locations`
3. `propose_workout_plan`

The full ordered proposal appears in chat. No plan is stored until **Save plan** is pressed. `get_workout_plans` provides compact read-only access to saved active plans.

During assistant confirmation, a named location must resolve to an active location. Step equipment is stored only when it matches equipment currently marked available at that location. Unknown or unavailable equipment is omitted from the saved step.

## Safety boundary

User-reported considerations remain distinct from diagnosis. The assistant is instructed to use conservative modifications and must not diagnose, prescribe treatment or rehabilitation, claim medical safety, or override clinician guidance.

## Verification status

The implementation was written through GitHub without access to Xcode. No build, test, simulator, migration, Dynamic Type, VoiceOver, or physical HealthKit result is claimed.

Required Mac commands:

```bash
xcrun simctl list devices available
SIMULATOR="<AVAILABLE IPHONE NAME>"

rm -rf build/StructuredPlansDerivedData

xcodebuild \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -destination "platform=iOS Simulator,name=${SIMULATOR},OS=latest" \
  -derivedDataPath "$PWD/build/StructuredPlansDerivedData" \
  clean build

xcodebuild \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -destination "platform=iOS Simulator,name=${SIMULATOR},OS=latest" \
  -derivedDataPath "$PWD/build/StructuredPlansDerivedData" \
  test
```

## Manual verification checklist

1. Launch without deleting the Phase 1 store.
2. Confirm meals, completed workouts, profile, considerations, metrics, locations, and equipment remain.
3. Create a manual plan and add multiple step types.
4. Reorder, edit, archive, restore, relaunch, and confirm persistence.
5. Request a Home plan from the assistant.
6. Discard a draft and confirm no save.
7. Save a draft and edit it in the plan screen.
8. Verify unavailable equipment is not attached to assistant-authored steps.
9. Confirm meal and completed-workout logging still work.
10. Test Apple Health separately on a physical device.

## Known risks

- The two new SwiftData entities have not been migration-tested.
- The new files rely on the Xcode 16 file-system-synchronized app and test groups for automatic target membership.
- SwiftUI form behavior and step reordering require simulator/device review.
- Assistant behavior depends on the provider respecting the required read-tool sequence; deterministic equipment filtering still runs at save time.
- Manual equipment text is intentionally not restricted to the current location inventory.

## Next phase

After this branch builds and tests successfully, create a new branch for Active Workout Mode. That phase should add persistent execution sessions, current-step state, set completion, countdown/stopwatch/interval/rest timers, pause/resume, skip/modify, planned-versus-actual values, and interruption recovery. Movement feedback remains a later phase.
# 0009 - Active Workout Mode

Date: 2026-07-11

## Git provenance

- Base branch: `feature/structured-workout-plans`
- Base commit: `8fb7d071bd364daa3f2e843462dcc12c2c2bdb51`
- Implementation branch: `feature/active-workout-mode`
- Earlier branches and `main` were not merged or rewritten by this work.

## Product boundary

This slice implements Phase 3 execution:

- start a saved structured workout plan;
- copy plan details into durable execution history;
- complete sets and steps;
- record actual reps, load, distance, and elapsed time;
- run step and rest timers;
- pause and resume;
- skip, reopen, back, and next;
- finish with perceived effort and notes;
- create one existing workout log for dashboard and streak integration.

It deliberately excludes movement-feedback classification, in-workout AI coaching, diagnosis, rehabilitation advice, plan adaptation, local notifications, HealthKit workout writing, watchOS, StoreKit, and backend work.

## New files

- `Health Assistantv2/ActiveWorkout/ActiveWorkoutModels.swift`
- `Health Assistantv2/ActiveWorkout/HealthDataRepository+ActiveWorkout.swift`
- `Health Assistantv2/ActiveWorkout/ActiveWorkoutViews.swift`
- `Health Assistantv2/ActiveWorkout/WorkoutStartView.swift`
- `Health Assistantv2Tests/ActiveWorkoutModeTests.swift`
- `docs/superpowers/specs/2026-07-11-active-workout-mode-design.md`
- `docs/superpowers/plans/2026-07-11-active-workout-mode.md`
- this journal entry

## Modified files

- `Sources/Persistence/PersistenceController.swift`
- `Sources/Features/Settings/SettingsView.swift`

## Persistence decisions

`ActiveWorkoutSession` and `ActiveWorkoutStep` are new SwiftData entities. The plan is copied when execution begins, so changes to a saved plan do not rewrite an in-progress or completed workout.

Whole-workout time, step time, and rest time use persisted timestamps and accumulated seconds. The UI can be suspended without relying on an in-memory timer loop. This is an additive migration, but it still requires verification against the user's existing Phase 2 store.

## Existing-module integration

Finishing converts completed rep-based execution steps into the existing `WorkoutSession` and `ExerciseSet` types. It calls the existing repository write path so the normal `ActivityEvent`, dashboard, streak, and daily-rollup behavior remains centralized.

A `workoutLogCreated` guard prevents a completed execution from creating duplicate workout logs. Ending early preserves execution history but intentionally does not call `addWorkout`.

## UI entry points

Settings now contains:

- Start or continue workout
- Workout execution history

The start hub lists resumable executions and runnable active plans. The active screen displays elapsed time, progress, current planned values, actual controls, timers, rest, navigation, and completion.

## Tests added

- plan-to-execution snapshot and ordering;
- set progression and rest timer;
- date-derived step timer and pause;
- whole-workout pause/resume time;
- exactly one legacy workout log on completion;
- no completed log when ending early.

## Verification status

The implementation was written through GitHub without access to Xcode or an iOS simulator. No build, migration, runtime, timer-background, or test success is claimed yet.

Required before merge:

```bash
xcrun simctl list devices available
SIMULATOR="<AVAILABLE IPHONE NAME>"

rm -rf build/ActiveWorkoutDerivedData

xcodebuild \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -destination "platform=iOS Simulator,name=${SIMULATOR},OS=latest" \
  -derivedDataPath "$PWD/build/ActiveWorkoutDerivedData" \
  clean build

xcodebuild \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -destination "platform=iOS Simulator,name=${SIMULATOR},OS=latest" \
  -derivedDataPath "$PWD/build/ActiveWorkoutDerivedData" \
  test
```

## Next phase

After concrete Mac compile/runtime fixes, Phase 4 should add neutral movement feedback tied to the exact execution step and set. The default action remains **Adjust**, not a prominent pain or diagnosis flow.

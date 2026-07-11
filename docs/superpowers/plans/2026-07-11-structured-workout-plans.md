# Structured Workout Plans — Implementation Plan

Date: 2026-07-11
Branch: `feature/structured-workout-plans`
Base: `feature/adaptive-coach-foundation`

## Delivered

1. Additive SwiftData entities: `WorkoutPlan` and `WorkoutStep`.
2. Explicit schema registration without changing existing entities.
3. Repository operations for plans, steps, ordering, archive/restore, environment snapshots, and compact reads.
4. Manual plan list, creation, editing, step editing, and reordering UI.
5. Settings navigation.
6. Assistant proposal and read tools:
   - `propose_workout_plan`
   - `get_workout_plans`
7. Full plan proposal card with user confirmation.
8. Equipment validation against the selected active location during assistant-plan confirmation.
9. Swift Testing coverage for ordering, persistence, snapshots, proposal confirmation, equipment filtering, tools, and safety instructions.
10. Phase 2 design and handoff documentation.

## Verification pass on Mac

From the repository root:

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

## Manual checks

1. Retain existing app data and launch the new schema.
2. Open Settings → Structured workout plans.
3. Create a manual Home plan.
4. Add warm-up, exercise, hold/rest, and cooldown steps.
5. Reorder steps, relaunch, and verify order.
6. Edit load, reps, duration, distance, and rest values.
7. Archive and restore the plan.
8. Ask the assistant: “Build me a 35-minute workout for Home.”
9. Confirm it reads profile and location context before proposing.
10. Discard one draft and verify no plan is stored.
11. Save one draft and verify it appears in the plan list.
12. Mark one location item unavailable, request another plan, and verify the unavailable item is not saved on a step.
13. Confirm existing meal and completed-workout proposal cards still require confirmation.

## Deferred

Phase 3 must start on a new branch after this branch is compiled and migration-tested. It should add active workout execution, persistent session state, timers, set completion, planned-versus-actual values, pause/resume, skip/modify, and interruption recovery.
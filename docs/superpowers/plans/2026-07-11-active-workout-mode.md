# Active Workout Mode — Implementation Plan

Date: 2026-07-11
Branch: `feature/active-workout-mode`
Base: `feature/structured-workout-plans` @ `8fb7d07`

## Delivered slices

1. **Additive persistence**
   - `ActiveWorkoutSession`
   - `ActiveWorkoutStep`
   - explicit schema registration
   - plan and step snapshots

2. **Repository lifecycle**
   - start from a saved plan
   - query resumable/recent executions
   - pause, resume, finish, and end early
   - current-step navigation
   - complete set/step, skip, and reopen
   - step and rest timers
   - one-time conversion to existing `WorkoutSession`

3. **Execution UI**
   - start/resume hub
   - active-workout header and progress
   - planned-versus-actual step controls
   - repetition/load and distance controls
   - countdown/count-up timer controls
   - rest timer
   - back, next, skip, reopen, pause, resume, and finish
   - execution history

4. **Regression integration**
   - Settings navigation
   - existing workout event and rollup path reused
   - tests for snapshots, set progression, timers, pause/resume, completion idempotency, and ending early

5. **Documentation**
   - design spec
   - implementation plan
   - journal entry

## Mac verification

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

## Manual verification

1. Preserve the existing store; do not delete the app.
2. Open Settings → Start or continue workout.
3. Start a plan containing rep, timed, distance, and rest-after fields.
4. Complete one set and confirm the rest countdown appears.
5. Background the app during a timer, return, and verify the timestamp-derived time.
6. Pause the workout and verify total elapsed time stops.
7. Resume and verify elapsed time continues.
8. Skip and reopen a step.
9. Navigate back and forward without losing actual values.
10. Finish with effort and notes.
11. Confirm the dashboard and workout history contain one completed workout.
12. Reopen the execution and confirm a duplicate log is not created.
13. End a separate workout early and confirm no completed workout is added.

## Deferred

- movement-feedback capture;
- deterministic safety escalation;
- in-workout assistant context;
- local notifications and Live Activities;
- watchOS;
- HealthKit workout-session writing;
- automatic plan adaptation;
- payments and backend work.

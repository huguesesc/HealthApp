# Adaptive Coach Foundation — Implementation Plan

Date: 2026-07-11
Branch: `feature/adaptive-coach-foundation`
Base: `test/fix-settings-section-initializers` @ `9c9f4a8bdc5fc59a221e9f0fb1cadfec129d76c9`

## Scope

This phase establishes structured, local-first knowledge about the user and the
places/equipment available for workouts. It deliberately stops before structured
workout plans, active workout execution, timers, movement feedback, payments,
watchOS, or autonomous memory changes.

## Implemented slices

### 1. SwiftData foundation

- `HealthProfile`
- `HealthConsideration`
- `BodyMetricEntry`
- `WorkoutLocation`
- `EquipmentItem`
- raw-string enums for forward-compatible persisted categories
- SI storage for weight and height
- explicit schema registration in `PersistenceController`

The new source files are placed under the Xcode 16 file-system-synchronized
`Health Assistantv2/AdaptiveCoach` group. This keeps them in the app target
without hand-editing `project.pbxproj`; the existing classic `Sources` group is
left unchanged.

### 2. Repository and snapshots

`HealthDataRepository+AdaptiveCoach.swift` adds:

- singleton-by-convention profile creation and reads;
- consideration add/edit/archive operations;
- body-metric history and 30-day trend calculation;
- location and equipment add/edit/archive operations;
- compact Codable profile, consideration, metric, location, and equipment
  snapshots for assistant context;
- read-only snapshot functions that never create or mutate profile data.

No Phase 1 write creates an `ActivityEvent`.

### 3. User interface

- Profile and training preferences
- User-reported movement considerations
- Body measurements with metric/imperial display conversion
- Workout locations
- Equipment inventory
- Home/gym quick-add equipment suggestions
- Archive/restore for locations and considerations
- Entry points from Settings

### 4. Assistant context

`ChatEngine` now exposes two read-only tools:

- `get_health_profile`
- `get_workout_locations`

The system prompt explicitly treats considerations as user reports, not diagnoses,
and prohibits diagnosis, treatment prescription, and overriding clinician guidance.
Existing proposal confirmation for meals and workouts remains unchanged.

### 5. Tests

Swift Testing coverage includes:

- profile singleton behavior;
- confirmed/non-archived consideration filtering;
- location snapshot filtering;
- unavailable-equipment filtering;
- body-metric trend calculation;
- assistant tool registration and schemas;
- safety wording in the assistant system prompt.

## Required Mac verification

This implementation was authored through GitHub and has not yet been compiled in
Xcode. On a Mac with an available iPhone simulator:

```bash
xcrun simctl list devices available

xcodebuild \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -destination "platform=iOS Simulator,name=<AVAILABLE_DEVICE>,OS=latest" \
  -derivedDataPath "$PWD/build/AdaptiveCoachDerivedData" \
  clean build

xcodebuild \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -destination "platform=iOS Simulator,name=<AVAILABLE_DEVICE>,OS=latest" \
  -derivedDataPath "$PWD/build/AdaptiveCoachDerivedData" \
  test
```

Then manually verify:

1. Existing meals, workouts, sleep, HealthKit sync, and chat still open.
2. Settings → Health and training profile opens.
3. A profile survives relaunch.
4. A user-reported left-knee consideration survives relaunch.
5. Metric and imperial body entries display correctly.
6. Home and Gym locations can be created.
7. Equipment suggestions add only after tapping.
8. Unavailable equipment is retained in the UI but excluded from assistant context.
9. The assistant can answer what equipment exists at Home.
10. The assistant reports considerations neutrally and does not diagnose.

## Phase 2 starting point

After the Mac compile pass is green, Phase 2 should introduce `WorkoutPlan` and
`WorkoutStep` snapshots without changing completed `WorkoutSession` history. A
plan must remain an editable draft until the user confirms it.

# 0007 - Adaptive coach foundation handoff

Date: 2026-07-11

## Git provenance

- Original base branch: `test/fix-settings-section-initializers`
- Original base commit: `9c9f4a8bdc5fc59a221e9f0fb1cadfec129d76c9`
- Implementation branch: `feature/adaptive-coach-foundation`
- Main was not modified or merged.
- The initial WIP preservation commit was `ce710ee21280fd95f9487685ecf60ba02293cd42`.

## Product boundary

The durable direction is recorded in
`docs/superpowers/specs/2026-07-11-adaptive-coach-design.md`. This branch implements
Phase 1 only:

- local health/training profile;
- user-reported considerations;
- body metrics;
- workout locations;
- equipment inventory;
- compact read-only assistant context.

It does not implement structured workout plans, active workout execution, timers,
movement feedback, payments, backend work, watchOS, or model-written memory.

## Implemented files

New app-target files are under the existing Xcode 16 file-system-synchronized
`Health Assistantv2/AdaptiveCoach` group:

- `AdaptiveCoachModels.swift`
- `HealthDataRepository+AdaptiveCoach.swift`
- `ProfileViews.swift`
- `WorkoutEnvironmentViews.swift`

Other modified files:

- `Sources/Persistence/PersistenceController.swift`
- `Sources/Features/Settings/SettingsView.swift`
- `Sources/Features/Chat/ChatEngine.swift`

New tests:

- `Health Assistantv2Tests/AdaptiveCoachFoundationTests.swift`
- `Health Assistantv2Tests/AdaptiveCoachAssistantToolTests.swift`

Documentation:

- `docs/superpowers/specs/2026-07-11-adaptive-coach-design.md`
- `docs/superpowers/plans/2026-07-11-adaptive-coach-foundation.md`
- this journal entry.

## SwiftData and migration decisions

Five new entities were added to the explicit app schema:

- `HealthProfile`
- `HealthConsideration`
- `BodyMetricEntry`
- `WorkoutLocation`
- `EquipmentItem`

Existing entities were not changed. Persisted categories use raw strings and body
metrics use SI units. BMI is derived rather than stored. The intended migration is
SwiftData lightweight migration because the change adds new tables only; this must
still be verified against an existing on-device store during the Mac compile pass.
No destructive store fallback was added.

`WorkoutLocation` owns equipment through a cascade relationship. Locations and
considerations are archived instead of deleted by normal UI actions. Deleting one
equipment item affects only that inventory item.

## Repository and assistant decisions

`HealthDataRepository+AdaptiveCoach.swift` owns all Phase 1 persistence operations.
Assistant snapshots are plain Codable values; SwiftData models are never encoded
directly. Snapshot reads do not create a profile or mutate the store.

`ChatEngine` adds two read-only tools:

- `get_health_profile`
- `get_workout_locations`

The profile tool returns only user-confirmed, non-archived considerations and a
compact body-metric trend. The location tool returns only active locations and
available equipment. Existing meal/workout proposals still require user
confirmation.

The assistant prompt explicitly states that considerations are the user's own
reports and prohibits diagnosis, treatment prescription, and overriding clinician
guidance.

## UI delivered

Settings now links to:

- Health and training profile
- Workout locations & equipment

The profile flow supports goals, experience, weekly availability, preferred
session length, activities, preferences, user-reported considerations, and body
measurements. The location flow supports active/archived locations, equipment,
availability, weights/resistance notes, and one-tap suggestions that save only after
the user taps them.

## Verification status

Implementation and tests are committed, but this environment cannot run Xcode,
SwiftData, SwiftUI, HealthKit, or an iOS simulator. No build or test result is being
claimed.

Required Mac commands:

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

## Manual verification checklist

1. Launch with the existing local store and confirm prior meals/workouts remain.
2. Open Settings → Health and training profile.
3. Save a goal, experience level, availability, and preferences.
4. Add a user-reported left-knee consideration.
5. Add metric and imperial body measurements.
6. Create Home and add bands, stability ball, balance pad, and dumbbells.
7. Create Gym and add bike, treadmill, cable station, and leg press.
8. Mark one item unavailable and confirm it remains in the inventory.
9. Relaunch and verify persistence.
10. Ask the assistant what equipment is available at Home.
11. Ask what user-reported considerations should be accounted for.
12. Confirm the answer is neutral and does not diagnose.
13. Confirm existing meal and workout proposal cards still save only after review.
14. Confirm Apple Health connect/sync still opens and works on a physical device.

## Known risks

- The SwiftData migration has not been exercised against the user's existing store.
- The new files rely on the existing Xcode 16 file-system-synchronized app group for
  target inclusion; verify they appear in Compile Sources automatically in Xcode.
- SwiftUI layout and Dynamic Type require simulator/device review.
- HealthKit cannot be fully verified on the simulator.
- No dashboard shortcut was added in this slice; the complete feature is available
  from Settings. A dashboard entry can follow after the first compile pass.

## Recommended next step

Run the Mac compile/test pass and fix only concrete compiler or migration failures on
this branch. Once Phase 1 is green, begin Phase 2 on a new branch with structured,
editable `WorkoutPlan` and `WorkoutStep` models. Do not combine that work with the
first migration verification.

# 0007 - Adaptive coach foundation handoff

Date: 2026-07-11

## Git provenance

- Original base branch: `test/fix-settings-section-initializers`
- Original base commit: `9c9f4a8bdc5fc59a221e9f0fb1cadfec129d76c9`
- Handoff branch: `feature/adaptive-coach-foundation`
- Main was not modified or merged.

## What this handoff preserves

- `docs/superpowers/specs/2026-07-11-adaptive-coach-design.md` is the approved
  Phase 1 design and the longer-term product direction.
- The design document previously stated that Phase 1 was implemented. Repository
  inspection found no Phase 1 source files, SwiftData entities, repository
  extension, views, assistant tools, tests, or Xcode project registrations. Its
  status has been corrected to avoid a false implementation claim.
- A non-empty local recovery patch was created before this documentation work at
  `.local-handoff/adaptive-coach-recovery.patch`. It is intentionally ignored and
  is not committed.

## Files changed for this handoff

- Modified: `.gitignore` to exclude `.local-handoff/`.
- Modified: `docs/superpowers/specs/2026-07-11-adaptive-coach-design.md` to state
  that Phase 1 is specified, not implemented.
- Created: this journal entry.

## Phase 1 status

Completed:

- Durable adaptive-coach design specification, including the local-first,
  user-confirmed, read-only-assistant and no-diagnosis boundaries.
- Preservation patch and Git handoff documentation.

Not implemented:

- `HealthProfile`, `HealthConsideration`, `BodyMetricEntry`, `WorkoutLocation`,
  and `EquipmentItem` SwiftData entities.
- Explicit schema registration and migration verification.
- `HealthDataRepository+AdaptiveCoach.swift` persistence operations and compact
  Codable snapshots.
- Profile, consideration, body-metric, location, and equipment SwiftUI screens.
- Assistant read tools (`get_health_profile`, `get_workout_locations`) and system
  prompt constraints.
- Xcode target registration, Swift Testing coverage, simulator verification and
  manual accessibility testing.

## Architecture and migration notes

The specification intentionally requires new SwiftData entities only, raw-string
enum storage, SI storage for body metrics, compact Codable snapshots rather than
model encoding, assistant reads that never create a profile, and no Phase 1
`ActivityEvent` writes. The intended migration is lightweight only if those new
tables are added without changing existing entities. This remains an unverified
design decision because no schema change has been made.

## Verification

The Windows handoff environment has no Xcode command-line tools:

```text
xcrun : Le terme «xcrun» n'est pas reconnu comme nom d'applet de commande...
xcodebuild : Le terme «xcodebuild» n'est pas reconnu comme nom d'applet de commande...
```

No simulator could be discovered, so no build or test ran. On a Mac, select an
actual available iPhone simulator and run:

```bash
xcodebuild \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -destination "platform=iOS Simulator,name=<AVAILABLE_DEVICE>,OS=latest" \
  -derivedDataPath "$PWD/build/HandoffDerivedData" \
  build

xcodebuild \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -destination "platform=iOS Simulator,name=<AVAILABLE_DEVICE>,OS=latest" \
  -derivedDataPath "$PWD/build/HandoffDerivedData" \
  test
```

Known compiler errors: none observed; compilation was not possible here.
Manual testing was not performed.

## Recommended next step

Implement and test the five Phase 1 SwiftData models plus their explicit
`PersistenceController` schema registration as one small, independently
compilable commit. Do not start plans, timers, movement feedback, payments,
backend work, watchOS, or any later roadmap phase.

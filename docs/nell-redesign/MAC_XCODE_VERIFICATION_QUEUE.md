# Mac/Xcode verification queue

Created 2026-08-23 by the Windows implementation phase. Everything above this
line of history was either proven on macOS (T13–T18 evidence in
`TERRA_PROGRESS_AND_DEVIATIONS.md`) or is enumerated below as unverified.
Work through the queue top-to-bottom; do not skip a failing step.

Baseline expected at time of writing: branch
`feature/nell-exercise-catalog-location-context`, commit `d69e5bd`
(or later), clean tree.

## 0. Environment and preflight

```bash
git -C HealthApp status --short --branch          # expect clean, branch synced
xcodebuild -version                                # Xcode 16.2 known-good
xcrun simctl list devices available                # pick ONE iPhone by UDID
export SIM="platform=iOS Simulator,id=<UDID>"
python3 -B -m unittest scripts.tests.test_exercise_catalog   # 47 tests expected
python3 -B scripts/exercise_catalog.py validate --strict \
  --source-pack ../HealthAssistant_image_Pack      # exercises=20 errors=0 warnings=0
```

If the source pack is not present beside the repo, extract it read-only from
the ZIP first; validator exits 1 with `E_IMPORT_SOURCE_PACK_REQUIRED`
otherwise (intentional).

## 1. Compile gate (highest priority)

The following Windows-written Swift has NEVER compiled:

- `Health Assistantv2/ExerciseCatalog/Domain/ExerciseReferenceNormalization.swift` (new)
- `LegacyExerciseResolver.swift`, `ExerciseCatalogLoader.swift` (normalization extraction + legacyNames indexing)
- `GeneratedWorkoutValidator.swift` (demotion policy, `GeneratedWorkoutDemotion`)
- `ChatEngine.swift` (demotion audit message)
- `NellActiveWorkoutContainerView.swift` (catalogue media strip, explicit init)
- `ExerciseDefinition.swift` (`legacyNames` field; all 11 memberwise-init call sites updated to pass it)
- Test files: `LegacyNameCompatibilityTests.swift` (new),
  `EquipmentLocationCompatibilityTests.swift` (new),
  `GeneratedWorkoutValidatorTests.swift` (rewritten expectations),
  plus six fixtures updated with `legacyNames: nil`.

```bash
xcodebuild build -quiet -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" -configuration Debug -destination "$SIM" \
  CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO
```

Fix any compile errors before continuing; keep fixes minimal and re-commit.

## 2. Full unit test target

```bash
xcodebuild test -quiet -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" -configuration Debug -destination "$SIM" \
  -only-testing:"Health Assistantv2Tests" \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Expected green unless the pre-existing wording failure documented at T13
(`systemPromptKeepsUserReportsSeparateFromDiagnosis`) still exists — that one
is tracked separately, do not paper over it.

Specifically confirm these NEW/CHANGED suites pass:

| Suite | What changed |
|---|---|
| `GeneratedWorkoutValidatorTests` | unresolved/ambiguous/inactive now DEMOTE to custom instead of rejecting; ineligible/unauthorized still reject |
| `LegacyNameCompatibilityTests` | pins real-manifest aliases incl. RDL family, Air squat, Deadlift |
| `EquipmentLocationCompatibilityTests` | full compatibility matrix on real taxonomies |
| `ExerciseCatalogDomainTests` / `LoadingTests` / `MediaTests` / `ManifestFixtureTests` | legacyNames decoding/collisions; manifest aliases grew |
| `AdaptiveCoachAssistantToolTests`, `ExercisePersistenceMigrationTests`, `ExerciseCandidateFilterTests`, `EligibilityTests`, `ViewStateTests`, `LegacyExerciseResolverTests` | mechanical `legacyNames: nil` fixture parameter only |

## 3. Catalogue content changes shipped this phase

- `catalog.json`: aliases added to `bodyweight.squat` (Air squat),
  `dumbbell.bent_over_row` (Dumbbell row), `dumbbell.overhead_press`
  (Overhead press, Shoulder press), `barbell.deadlift` (Deadlift),
  `barbell.romanian_deadlift` (RDL, Romanian deadlift, Barbell RDL).
- Validator collision namespace now includes hidden `legacyNames`.
- Confirm the catalogue screen still loads 20 entries and search finds
  "RDL" and "Air squat".

## 4. Active Workout media integration (screen test)

Open Train → any plan with illustrated steps → Start Workout:

1. Illustrated step (e.g. bodyweight squat): Movement Guide shows the real
   composite image, caption reads "Catalogue illustration".
2. Custom/free-form step: vector pair illustration, caption unchanged.
3. Step transitions: verify no stale image flashes for the next step
   (implementation clears state before resolving).
4. Timer/skip/complete behavior unchanged; written instructions still precede
   media; complete exactly once into History.
5. Dark mode + light mode; Reduce Motion on; AX5 Dynamic Type layout intact;
   VoiceOver reads title then combined guide element.

## 5. Proposal demotion end-to-end (chat tool)

Using a stub or live client, propose a plan containing one authorized stable
ID, one unknown movement ("Fancy Pump Move") with instruction, and one
authorized-but-ineligible ID:

- unknown → plan previews with the step preserved as custom exercise;
- ineligible → proposal rejected before preview (regeneration error);
- saved plan stores nil ID + supplied title/instruction for the custom step;
- History shows the custom wording unchanged.

## 6. Python tooling on macOS

```bash
python3 -B scripts/exercise_catalog.py inventory \
  --source-pack ../HealthAssistant_image_Pack            # rows=65 mapped=50 imported=20 pending_entry=5 unreviewed=25 flagged=31
python3 -B scripts/exercise_catalog.py inventory \
  --source-pack ../HealthAssistant_image_Pack --json > /tmp/inv.json
python3 -c "import json;d=json.load(open('/tmp/inv.json'));print(d['totals'])"
python3 -B scripts/exercise_catalog.py import --dry-run \
  --source-pack ../HealthAssistant_image_Pack            # approved=20 rejected_pending=5 rejected_unreviewed=25
# Idempotence: second apply must produce zero git diff (only if apply is ever needed again)
```

AppleDouble tolerance: copying the pack through a Mac/exFAT round trip may
recreate `._` files; validator must emit `W_SOURCE_APPLEDOUBLE_SKIPPED`
warnings and still exit 0.

## 7. Release configuration

```bash
xcodebuild build -quiet -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" -configuration Release \
  -destination "$SIM" CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO
```

## 8. Still-open manual gates (unchanged from Sol plan)

- HR-06 blue-halo gallery/device review over all 20 imported composites.
- Accessibility sweep per T26 matrix (VoiceOver, Dynamic Type AX1/AX5,
  small+large devices, landscape where supported).
- T28 physical-device upgrade/resume/media QA (HR-07 access).
- Debug-gallery route absent from Release navigation (once T24 lands).

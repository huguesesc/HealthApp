# Mac/Xcode verification queue

Updated 2026-08-23 after CI came online. **Compilation and the full Swift
unit-test suite are already proven on every push** by GitHub Actions (see
`IOS_CI_STATUS.md`): as of commit `e2a47b0` the macos runner builds the app
with Xcode 26.x/16.x and runs all unit suites green. What remains below is
what CI cannot see: simulator interaction, runtime resource behavior beyond
the bundle tests, visuals, accessibility, devices.

## FIRST 15 MINUTES ON MAC

Run these top-to-bottom; each step lists its success condition.

```bash
# 1. Get the branch and prove provenance            (~1 min)
git -C HealthApp fetch origin
git -C HealthApp switch feature/nell-exercise-catalog-location-context
git -C HealthApp status --short --branch
#   SUCCESS: clean tree; branch in sync or only your own local commits ahead.
#   FAILURE surface: unexpected modified files -> STOP, investigate before editing.

# 2. Catalogue tooling                              (~1 min)
cd HealthApp
python3 -m pip install -r scripts/exercise_catalog_requirements.txt  # if needed
python3 -B scripts/exercise_catalog.py validate --strict \
  --source-pack ../HealthAssistant_image_Pack
#   SUCCESS: "exercises=20 ... errors=0 warnings=0"
#   If pack absent: plain `validate --strict` exits 1 with
#   E_IMPORT_SOURCE_PACK_REQUIRED — expected, not a defect.

python3 -B scripts/nell_integrity.py
#   SUCCESS: "errors=0" (3 known warnings about the superseded plan doc are fine)

python3 -B -m unittest discover -s scripts/tests -t .   # needs __init__ fallback:
python3 -B -m unittest scripts.tests.test_exercise_catalog scripts.tests.test_nell_integrity
#   SUCCESS: 53 + 5 tests OK (one skips without the sibling source pack).

# 3. Xcode/scheme discovery                         (~2 min)
xcodebuild -version
xcodebuild -project "Health Assistantv2.xcodeproj" -list
#   SUCCESS: scheme "Health Assistantv2" listed.
xcrun simctl list devices available | grep iPhone | head -3
export SIM="platform=iOS Simulator,id=<pick-a-UDID>"

# 4. Fast confidence build (CI already proves this; skip if pressed)
xcodebuild build -quiet -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" -configuration Debug -destination "$SIM" \
  CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO
```

5–10 are covered by the interactive checklist below.

## Interactive checklist

| # | Check | How | Expected | Failure surface | Files implicated | Blocks further work? |
|---|---|---|---|---|---|---|
| 1 | Unit suite locally | xcodebuild test … `-only-testing:"Health Assistantv2Tests"` (see IOS_CI_STATUS for exact flags) | same green as CI (151+ tests) | simulator runtime missing | — | yes |
| 2 | Bundle resources resolve | run `ExerciseCatalogBundleTests` | 3/3 pass | Assets.car / JSON not bundled | project.pbxproj exception set | yes |
| 3 | Catalogue screen | Train → Exercise catalogue | 20 rows; search "RDL"/"Air squat" hit; filters work; no-media/deprecated states render | loader path, SwiftUI layout | ExerciseCatalogView.swift | no |
| 4 | Detail screen | tap any row | instructions primary, composite renders aspect-fit, dark mode clean | media rendering | ExerciseCatalogDetailView.swift, ExerciseMediaView.swift | no |
| 5 | Active Workout media strip | start an illustrated plan | real image + caption "Catalogue illustration"; custom steps show vector pair; no stale-image flash between steps | task(id:) timing | NellActiveWorkoutContainerView.swift | no |
| 6 | Exactly-once completion | finish a workout | one history entry; resume works from background | untouched T21 semantics | ActiveWorkout stack | regression = stop |
| 7 | Demotion end-to-end | chat: propose plan w/ unknown movement + ineligible ID | unknown preserved as custom card text; ineligible rejected before preview | tool wiring | ChatEngine.swift, GeneratedWorkoutValidator.swift | no |
| 8 | Debug gallery | About Nell → debug card (DEBUG build only) | gallery lists 20 IDs; filters isolate missing media/inactive/hidden legacy names; Release build has NO card | #if DEBUG correctness | ExerciseCatalogDebugGallery.swift, NellSettingsSections.swift | no |
| 9 | HR-06 halo review | gallery hero preview over light/dark for all 20 composites + thruster outfit question | halos acceptable or quarantine list produced | aesthetics | assets | release gate |
| 10 | Accessibility sweep | VoiceOver + AX1/AX5 + Reduce Motion across catalogue/detail/active/history/gallery | reading order text-first; no clipped controls | layout | UI files above | release gate |
| 11 | Release build + gallery absence | xcodebuild Release + launch | builds; About Nell shows no debug card | conditional compilation | same as 8 | release gate |
| 12 | Device QA (HR-07) | install-over-existing with seeded store; offline workout; media scroll | upgrade keeps data; exactly-once holds on device | signing/provisioning needed | persistence stack | release gate |

## Known-good reference points

- CI-proven commits: `0156553`, then everything after (workflow reruns on push).
- Pre-existing unrelated failure to expect if running the FULL history of
  suites at old SHAs only: `systemPromptKeepsUserReportsSeparateFromDiagnosis`
  wording mismatch — fixed during T17/T18; do not reintroduce.
- Source pack lives beside the repo (`../HealthAssistant_image_Pack`);
  validator strict mode intentionally requires it there.

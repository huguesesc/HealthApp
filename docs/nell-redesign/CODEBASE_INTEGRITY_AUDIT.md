# Codebase integrity audit

Audit date: 2026-08-23 (Windows phase, static analysis only). Classification
legend: **SAFE-FIX** applied now; **MAC** requires build verification;
**PRODUCT** needs a product decision; **OBSOLETE?** probably removable but
left alone pending confirmation; **LEAVE** intentional.

## Duplicate declarations

| Finding | Verdict |
|---|---|
| No Swift type name is declared in more than one file. All cross-file collisions are legal extensions (`HealthDataRepository`, `String`, conditional `ButtonStyle` conformances). | LEAVE |
| `ExerciseCatalogDetailView` vs `NellExerciseDetailView` are distinct: the latter is a thin resolver wrapper delegating to the former (`NellWorkoutPlansView.swift:260`). | LEAVE |

## Repeated logic

| Finding | Disposition |
|---|---|
| Reference normalization existed in three copies. Two identical copies (loader index + legacy resolver) were centralized into `ExerciseReferenceNormalization` this phase. | SAFE-FIX done |
| Third copy `WorkoutMotionRegistry.normalise` keeps space-separated tokens for its own alias table and slug generation; semantics differ deliberately. Centralizing would change stored keys for zero behavioral gain. | MAC verify fallback tests still pass; otherwise LEAVE |

## Force unwraps in workout/catalogue paths

| Location | Context | Verdict |
|---|---|---|
| `ExerciseCatalogView.swift` preview fixture (2×) | `#if DEBUG` previews only | MAC (harmless if wrong) |
| `GeneratedWorkoutValidator.swift:103` `suppliedID!` | guarded by `hasSuppliedID` boolean on the previous line | LEAVE (guarded) |
| `NellWorkoutPlansView.swift:302` `step.instruction!` | guarded by emptiness check on line above | LEAVE (guarded); could become `?? default` in a later pass |
| No `try!` / `as!` anywhere in Train/ActiveWorkout/WorkoutPlans/WorkoutMotion/ExerciseCatalog | — | — |

## Unreferenced / superseded views

| Finding | Verdict |
|---|---|
| Legacy stack views unwired from Nell shell: `DashboardView`, legacy `WorkoutStartView`, `ActiveWorkoutsView`, `ChatView` internals, `SettingsView` (legacy) still compile into `Sources/` targets referenced only by each other or previews | OBSOLETE? — removal is a separate approved cleanup; do not delete now |
| Internal composition helpers used only inside their own files (onboarding pages, editor subviews, progress sections) are normal SwiftUI decomposition | LEAVE |
| `NellMascotHero`, `NellProgressRing` declared but never instantiated | OBSOLETE? candidate for the future component cleanup |

## Markers

No TODO/FIXME/XXX/HACK comments exist anywhere in `.swift` sources.

## Documentation contradictions

| Finding | Disposition |
|---|---|
| `docs/setup-mac.md:98` presents stale `project.yml`/XcodeGen as current tooling, contradicting four exercise-catalog docs that record it as unsafe/stale | SAFE-FIX: corrected in this commit to warn against regenerating from it |
| Sol docs reference pre-rename file names (e.g. `01_CURRENT_STATE_AUDIT.md` vs actual `01_CURRENT_STATE_AND_ASSET_AUDIT.md`) inside `CODEX_SOL_MAC_CONTINUATION_PROMPT.md` reading list | SAFE-FIX: corrected names in that list |
| `TERRA_PROGRESS_AND_DEVIATIONS.md` records old repository path (`C:\Users\...\Desktop\Nell.app`) | LEAVE: historical evidence log; current location recorded in implementation status instead |

## Asset references

All 20 `media-index.json` asset names resolve to existing `ExerciseMedia`
imagesets; all catalogue media keys resolve through the index. Seven brand
enum cases intentionally have no imageset yet (vector/SF-symbol fallbacks
render) — see the brand audit document.

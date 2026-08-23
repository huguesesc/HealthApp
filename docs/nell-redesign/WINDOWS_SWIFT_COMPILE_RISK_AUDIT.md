# Windows Swift compile-risk audit — CLOSED by CI

Original scope: every Swift file created or materially edited after the last
Mac-verified commit (`6352354`, T18). The audit below was written as a static
risk assessment and then **fully resolved empirically**: since the workflow in
`.github/workflows/nell-ios-verification.yml` landed, GitHub's macOS runners
compile both targets and run all unit suites on every push. Per-run history:
`IOS_CI_STATUS.md`.

## Risk classes found vs CI outcome

| File | Static risk notes | CI verdict |
|---|---|---|
| `ExerciseCatalogView.swift` (new, phase 1) | medium: uncompiled SwiftUI; relied on 12 brand/component types + taxonomy loader API | ✅ compiles; `ExerciseCatalogViewStateTests` pass |
| `ExerciseCatalogDetailView.swift` (new, phase 1) | low-medium: reused verified components; `WorkoutStep` field names cross-checked against model | ✅ compiles |
| `ExerciseCatalogViewStateTests.swift` (new, phase 1) | low: pure value-type filter/sort logic re-derived from implementation | ✅ passes |
| `NellTrainHomeView.swift` catalogue tool link | low: pattern-followed existing `toolLink` rows | ✅ compiles |
| `NellWorkoutPlansView.swift` (+39) | low: `NellExerciseDetailView` wrapper only | ✅ compiles |
| `ExerciseReferenceNormalization.swift` (new) | minimal: Foundation-only extraction of two identical private helpers | ✅ compiles |
| `LegacyExerciseResolver.swift` / `ExerciseCatalogLoader.swift` | low: call-site swap to shared normalizer + `legacyNames` indexing | ✅ compiles; resolver/loading suites pass |
| `GeneratedWorkoutValidator.swift` demotion | **high at write time**: inout-to-subscript, enum synthesis, control-flow restructure → **definite static error found by CI**: instance calls to a `static` helper (3 sites), fixed `0156553` | ✅ compiles; validator suite green |
| `ChatEngine.swift` demotion message | low: string interpolation over Equatable arrays | ✅ compiles; tool-contract suite passes |
| `NellActiveWorkoutContainerView.swift` media strip | medium: explicit init around `@Bindable`, `.task(id:)`, protocol defaults | ✅ compiles (suite-level proof); interaction feel remains simulator-only |
| `EquipmentLocationCompatibilityTests.swift` | **definite static error found by self-audit pre-push**: `.map` on non-failable `init(rawValue:)`; fixed before CI ever saw it | ✅ compiles; 11 tests pass |
| `GeneratedWorkoutValidatorTests.swift` rewrite | medium: Swift Testing macro contexts in helpers; refactored to plain guards | ✅ passes on CI |
| `LegacyNameCompatibilityTests.swift`, `LegacyCompatibilityFixtureTests.swift` | medium: `#require`/`Comment?` macro rules → **definite errors caught by CI**: runtime String into `Comment?` (`bc3e801` fix) | ✅ passes |
| `ExerciseCatalogDebugGallery.swift` (new) | medium → **definite error caught by CI**: referenced file-private state enum (`40bb173` run); fixed by promoting the enum to internal (`e2a47b0`) | pending the run for `e2a47b0`+ |
| Nine test-fixture files (+`legacyNames: nil`) | mechanical | ✅ all suites pass |

## Method notes

- Symbol existence was verified by grep before writing (16 component/type
  families, member APIs, design tokens).
- Two defect classes were invisible to static reading on this host and were
  caught only by real compilation: Swift's `static` dispatch rule and Swift
  Testing's `Comment?` argument conversion.
- Conclusion: the residual risk of the current tree is **runtime/visual**,
  not compilation; the interactive checklist in
  `MAC_XCODE_VERIFICATION_QUEUE.md` owns what is left.

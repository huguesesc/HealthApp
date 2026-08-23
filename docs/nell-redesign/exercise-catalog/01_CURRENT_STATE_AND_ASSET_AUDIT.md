# Current state and asset audit

Audit date: 2026-07-14. `archive` was not inspected or modified.

## Repository provenance

| Item | Confirmed value |
|---|---|
| Root | `C:\Users\Hugues Esclapez\Desktop\Nell.app\HealthApp` |
| Remote | `https://github.com/huguesesc/HealthApp.git` |
| Branch | `feature/nell-exercise-catalog-location-context` |
| HEAD | `61d3076ddddbc6a0f5765eec118363ddb6aaadd0` |
| Tracking | `origin/feature/nell-exercise-catalog-location-context` |
| Target/upstream divergence | 0 behind, 0 ahead at audit |
| Parent comparison | `origin/feature/nell-full-brand-and-ui-system...HEAD` = 0 behind, 8 ahead |
| Initial worktree | Clean |
| Clone caveat | The initial single-branch clone did not contain the parent ref; it was fetched explicitly before measuring divergence. |

The branch changes 19 files relative to the parent (455 insertions, 43 deletions), mainly Nell brand resources, navigation/Train presentation, workout-motion fallback, tests, and the earlier exercise-catalogue plan.

## Relevant code and resources

| Path | Current responsibility | Kind | Terra disposition |
|---|---|---|---|
| `Health Assistantv2.xcodeproj/project.pbxproj` | Actual targets, build settings, synchronized groups, resources | Project | Modify only if generated folders are not picked up; validate membership. |
| `project.yml` | Stale XcodeGen description for a differently named target and older deployment target | Tool config | Leave untouched initially; do not regenerate the project from it. Document or repair only in a separately approved cleanup. |
| `Sources/App/HealthAssistantApp.swift` | App entry and SwiftData container injection | Production | Inject catalogue dependency with minimal lifecycle change. |
| `Sources/App/RootView.swift` | Onboarding gate and Nell shell | Production | Leave behavior intact; pass dependencies if needed. |
| `Health Assistantv2/Navigation/NellAppShellView.swift` | Five-tab custom shell: Today, Log, Nell, Nutrition, Train | Production | Add no release gallery route; keep current shell. |
| `Health Assistantv2/Train/NellTrainHomeView.swift` | Train landing | Production | Add catalogue/search entry only after foundation is stable. |
| `Health Assistantv2/Train/NellWorkoutPlansView.swift` | Plan list/detail and `NellExerciseDetailView` | Production | Resolve stable IDs and adopt reusable media view. |
| `Health Assistantv2/Train/NellActiveWorkoutContainerView.swift` | Branded active-workout presentation | Production | Add restrained media without changing execution semantics. |
| `Health Assistantv2/Train/NellWorkoutExecutionHistoryView.swift` | Execution history and summary | Production | Prefer immutable snapshots, optionally resolve current definition. |
| `Health Assistantv2/WorkoutPlans/WorkoutPlanModels.swift` | SwiftData `WorkoutPlan` and title-based `WorkoutStep` | Production/persistence | Add optional ID snapshot only after migration gate. |
| `Health Assistantv2/ActiveWorkout/ActiveWorkoutModels.swift` | Durable active session and step snapshots | Production/persistence | Add optional ID snapshot; preserve resumability and exactly-once conversion. |
| `Sources/Models/WorkoutSession.swift` | Completed history and `ExerciseSet` keyed by exercise name | Production/persistence | Preserve `exerciseName`; later add optional canonical ID. |
| `Health Assistantv2/ActiveWorkout/HealthDataRepository+ActiveWorkout.swift` | Plan-to-active snapshot and exactly-once history conversion | Production | Propagate optional IDs; do not alter the conversion boundary. |
| `Health Assistantv2/WorkoutPlans/HealthDataRepository+WorkoutPlans.swift` | Plan snapshots and mutations | Production | Include optional IDs without losing old decoding. |
| `Sources/Persistence/PersistenceController.swift` | Single unversioned SwiftData schema; container creation currently `fatalError`s | Production/persistence | Introduce explicit migration/version plan before stored-model changes. Catalogue failure must not add another fatal path. |
| `Health Assistantv2/AdaptiveCoach/AdaptiveCoachModels.swift` | User locations/equipment; enum-based equipment and free-text space limits | Production/persistence | Retain raw legacy fields; add optional taxonomy IDs/capabilities behind migration gate. |
| `Health Assistantv2/AdaptiveCoach/HealthDataRepository+AdaptiveCoach.swift` | Profile/location/equipment reads and writes | Production | Add adapters to typed catalogue context. |
| `Health Assistantv2/AdaptiveCoach/WorkoutEnvironmentViews.swift` | Environment editing UI | Production | Add structured capability controls later; preserve custom text. |
| `Sources/Features/Chat/ChatEngine.swift` | AI proposals, tools, confirmation, plan persistence | Production | Candidate filtering and output validation belong here or in injected collaborators; keep confirmation boundary. |
| `Health Assistantv2/WorkoutMotion/WorkoutMotionRegistry.swift` | Eight static name/alias-to-vector definitions with partial-match fallback | Production | Replace as canonical exercise source; retain as legacy/fallback adapter until migration completes. |
| `Health Assistantv2/WorkoutMotion/WorkoutMotionView.swift` | Vector avatar presentations and rows | Production | Wrap or delegate to `ExerciseMediaView`; keep fallback. |
| `Health Assistantv2/WorkoutMotion/WorkoutAvatarStyle.swift` | Canvas/vector avatar and equipment/pose enums | Production | Keep as no-media fallback, not catalogue data. |
| `Health Assistantv2/Assets.xcassets` | Brand, app icon, and current Nell assets | Resource | Add generated `ExerciseMedia` namespace; do not disturb brand assets. |
| `Health Assistantv2Tests/StructuredWorkoutPlanTests.swift` | Plan save/reorder/location/equipment snapshot and confirmation tests | Test | Extend for stable IDs and backward compatibility. |
| `Health Assistantv2Tests/ActiveWorkoutModeTests.swift` | Timers, resume, skip, completion and conversion | Test | Add ID propagation and migration fixtures. |
| `Health Assistantv2Tests/NellNavigationAndWorkoutMotionTests.swift` | Shell/motion alias/fallback coverage | Test | Retain fallback tests; add media resolution. |
| `Health Assistantv2Tests/NellActiveWorkoutBoundaryTests.swift` | Active-workout UI boundary | Test | Assert written guidance remains primary and media optional. |
| `Health Assistantv2Tests/AdaptiveCoachAssistantToolTests.swift` | Assistant tool contracts | Test | Add compact candidate and output-validation contracts. |
| `Health Assistantv2Tests/AdaptiveCoachFoundationTests.swift` | Location/equipment foundation | Test | Add taxonomy adapters and capability rules. |
| `scripts/check_m1_simulator_safe.py` | Existing Python safety check | Tooling | Follow repository Python conventions; do not overload it. |
| `docs/nell-redesign/EXERCISE_CATALOG_LOCATION_CONTEXT_PLAN.md` | Earlier high-level plan | Documentation | Superseded by this package where conflicts exist. |
| `docs/nell-redesign/WORKOUT_MOTION_ASSET_MANIFEST.md` | Assumes separate start/end image files | Documentation | Superseded: supplied exercise PNGs are primarily two-pose composites. |
| `docs/nell-redesign/IMAGE_PACK_MAPPING.md` | Older image-name mapping | Documentation | Treat as stale reference, not truth. |

## Current behavior and risks

- Confirmed: plans, active steps, and completed sets identify exercises by mutable titles/names.
- Confirmed: active sessions snapshot text for durable resume and convert to history exactly once. That boundary is protected behavior.
- Confirmed: generation checks equipment names in prompt context but has no canonical candidate list, stable-ID contract, or returned-ID validator.
- Confirmed: unknown motion titles fall back to a generated vector figure. Partial name matching can mis-resolve unrelated titles.
- Confirmed: the app has no explicit SwiftData schema version or migration plan.
- Confirmed: `project.yml` does not describe the actual current project accurately; running XcodeGen from it is unsafe.
- Inference: filesystem-synchronized project groups may absorb new source/resource directories, but Terra must verify build-phase membership in Xcode rather than assume it.
- Windows limitation: `xcodebuild`, `xcrun`, and `xcodegen` are unavailable. Python 3.12 is available. No iOS build claim can be made from this audit host.

## Asset-pack facts

Source directory: `C:\Users\Hugues Esclapez\Desktop\Nell.app\HealthAssistant_image_Pack`
ZIP: `C:\Users\Hugues Esclapez\Desktop\Nell.app\HealthAssistant_image_Pack.zip`

| Finding | Result |
|---|---|
| PNG count | 65: 7 brand, 8 Nell poses, 50 workout illustrations |
| ZIP parity | Exact path set and SHA-256 parity for all 65 files |
| Exact duplicates | None; all SHA-256 values unique |
| Dimensions | 63 at 1254×1254; `header_intro1.png` 1536×1024; `nell_pensive.png` 1122×1402 |
| Color/alpha | `app_icon.png` is opaque RGB; the other 64 are RGBA and contain alpha values from 0 to 255 |
| Invalid/unreadable | None found |
| Duplicate periods | 11 filenames end in `..png`, including `brand_id/logo..png` |
| Spelling defect | `bench_dumbell_hip_thrust.png` uses `dumbell` |
| App-icon defect | Source is 1254×1254 rather than final 1024×1024; this is a brand pipeline issue, not exercise-catalogue media |
| Visual model | Exercise files are overwhelmingly one transparent 1254-square composite containing two poses/phases |

Alpha metadata alone is not proof of a clean transparent visual. Visual inspection found `nell_poses/nell_plan.png` rendered with a saturated blue field and it must not be automatically promoted. Thin blue edge halos are visible around many rendered workout figures and need device/background QA.

### Exact per-file byte inventory

All entries are PNG. Unless overridden in parentheses, dimensions are 1254×1254 and mode is RGBA with nontrivial alpha. Category and likely use follow the top-level directory; the exercise rows receive their exact semantic mapping in `03_ASSET_INVENTORY_AND_MIGRATION_MAP.md`.

```text
brand_id/app_icon.png                                             3,125,833 bytes (RGB opaque)
brand_id/header_intro1.png                                       2,118,585 bytes (1536×1024)
brand_id/logo..png                                                  960,384 bytes
brand_id/monochrome-dark.png                                        450,357 bytes
brand_id/monochrome-light.png                                       378,820 bytes
brand_id/sublogo-dark.png                                           707,015 bytes
brand_id/sublogo-light.png                                          804,977 bytes
nell_poses/nell_allfours.png                                        998,319 bytes
nell_poses/nell_balance.png                                         930,033 bytes
nell_poses/nell_exercise.png                                        899,250 bytes
nell_poses/nell_food.png                                            978,721 bytes
nell_poses/nell_hello.png                                           775,215 bytes
nell_poses/nell_pensive.png                                         841,154 bytes (1122×1402)
nell_poses/nell_plan.png                                          2,884,174 bytes
nell_poses/nell_zen.png                                           1,192,818 bytes
workout_avatar/barbell_biceps_curl.png                              594,589 bytes
workout_avatar/barbell_close_grip_bench_press.png                   532,556 bytes
workout_avatar/barbell_deadlift.png                                 560,102 bytes
workout_avatar/barbell_flat_bench_press.png                         527,339 bytes
workout_avatar/barbell_overhead_triceps_extension.png               493,004 bytes
workout_avatar/barbell_reverse_curl.png                             541,763 bytes
workout_avatar/barbell_romanian_deadlift.png                        588,940 bytes
workout_avatar/barbell_skullcrusher.png                             507,117 bytes
workout_avatar/bench_copenhagen_plank_isometric_hold_short_lever..png 350,172 bytes
workout_avatar/bench_dumbbell_flat_chest_press..png                 376,144 bytes
workout_avatar/bench_dumbbell_flat_chest_press_alt_01..png          579,733 bytes
workout_avatar/bench_dumbbell_incline_chest_press..png              691,503 bytes
workout_avatar/bench_dumbell_hip_thrust.png                         419,842 bytes
workout_avatar/bench_step_up..png                                   718,722 bytes
workout_avatar/bodyweight_bird_dog..png                             263,741 bytes
workout_avatar/bodyweight_calf_raise..png                           610,487 bytes
workout_avatar/bodyweight_cat_cow..png                              444,145 bytes
workout_avatar/bodyweight_dead_bug..png                             293,874 bytes
workout_avatar/bodyweight_forward_lunge..png                        592,117 bytes
workout_avatar/bodyweight_glute_bridge.png                          280,374 bytes
workout_avatar/bodyweight_jumping_jack.png                          522,576 bytes
workout_avatar/bodyweight_mountain_climber.png                      392,435 bytes
workout_avatar/bodyweight_push_up.png                               320,590 bytes
workout_avatar/bodyweight_side_plank.png                            377,790 bytes
workout_avatar/bodyweight_squat.png                                 595,986 bytes
workout_avatar/bodyweight_standing_side_bend.png                    556,191 bytes
workout_avatar/bodyweight_yoga_dancer_pose.png                      547,940 bytes
workout_avatar/cable_standing_hip_extension_kickback.png            586,036 bytes
workout_avatar/cable_triceps_pushdown.png                           833,329 bytes
workout_avatar/dumbbell_bent_over_row.png                           598,253 bytes
workout_avatar/dumbbell_biceps_curl.png                             666,281 bytes
workout_avatar/dumbbell_bulgarian_split_squat.png                   475,874 bytes
workout_avatar/dumbbell_forward_lunge.png                           624,087 bytes
workout_avatar/dumbbell_goblet_squat.png                            509,536 bytes
workout_avatar/dumbbell_hammer_curl.png                             558,882 bytes
workout_avatar/dumbbell_lateral_raise.png                           638,754 bytes
workout_avatar/dumbbell_overhead_press.png                          595,172 bytes
workout_avatar/dumbbell_romanian_deadlift_hip_hinge.png             594,549 bytes
workout_avatar/dumbbell_thruster.png                                530,669 bytes
workout_avatar/machine_lat_pulldown.png                             904,166 bytes
workout_avatar/machine_leg_extension.png                            722,450 bytes
workout_avatar/machine_leg_press.png                                629,733 bytes
workout_avatar/machine_prone_leg_curl.png                           850,188 bytes
workout_avatar/machine_seated_calf_raise.png                        679,062 bytes
workout_avatar/machine_seated_row.png                               709,181 bytes
workout_avatar/resistance_band_lateral_squat.png                    639,965 bytes
workout_avatar/resistance_band_standing_hip_extension.png           637,543 bytes
workout_avatar/resistance_band_terminal_knee_extension_tke.png      633,684 bytes
workout_avatar/stability_ball_glute_bridge.png                      311,791 bytes
workout_avatar/stability_ball_hamstring_curl.png                    331,519 bytes
```

## Visual interpretation

- High-confidence: 49 of 50 workout images plausibly correspond to their filename and can be proposed as `composite` media, subject to medical/fitness-content approval.
- Mismatch: `workout_avatar/bench_dumbbell_flat_chest_press..png` shows a floor dumbbell press without a bench. Safest default: quarantine it; likely remap to `dumbbell.floor_press` only after approval.
- Alternate: `bench_dumbbell_flat_chest_press_alt_01..png` does show a bench and is the high-confidence image for `dumbbell.flat_bench_press`.
- Limited phase: `bench_step_up..png` shows neutral standing and one foot on a step, not a completed step-up. Keep as a setup/composite reference only; do not claim a complete motion sequence.
- Static holds/poses such as Copenhagen plank and dancer pose use a neutral/setup panel plus the target position; that is acceptable as a composite, not a start/end animation.
- `nell_allfours.png` is neutral/all-fours, not a reliable “success” state.

## Epistemic labels

- Confirmed facts above come from Git commands, source reads, PNG decoding, SHA-256 comparison, and direct visual inspection.
- Likely exercise IDs and frame roles are evidence-based interpretations, not clinical approval.
- Human review is mandatory for the mismatch, `nell_plan`, brand finalization, and any fitness-safety claims. See `09_OPEN_QUESTIONS_AND_HUMAN_REVIEW_QUEUE.md`.

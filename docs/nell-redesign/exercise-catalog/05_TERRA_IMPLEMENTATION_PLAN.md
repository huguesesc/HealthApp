# Terra implementation plan

Execute sequentially unless a task explicitly names parallel work. Every task uses the same safety rule: inspect the listed confirmed files again, preserve unrelated dirty work, never touch `archive`, and log commands/results in `docs/nell-redesign/exercise-catalog/TERRA_PROGRESS_AND_DEVIATIONS.md` (new).

## T01 — Branch and repository preflight

- **Task ID / objective:** T01; prove the exact repository, branch, parent relationship, and safe starting state.
- **Why:** all later diffs and migration evidence depend on trustworthy provenance.
- **Dependencies:** none.
- **Confirmed files to inspect:** `Health Assistantv2.xcodeproj/project.pbxproj`, `project.yml`, this Sol package, `docs/nell-redesign/EXERCISE_CATALOG_LOCATION_CONTEXT_PLAN.md`.
- **Files to create:** `docs/nell-redesign/exercise-catalog/TERRA_PROGRESS_AND_DEVIATIONS.md`.
- **Files to modify:** none otherwise. **Must remain untouched:** `archive`, assets, production code.
- **Steps:** verify root/remote/branch/HEAD/tracking; fetch target and parent; record status and `parent...HEAD`; inventory dirty files; read all ten Sol documents; record stale `project.yml` warning.
- **Migration impact:** none.
- **Tests / validation command:** `git status --short --branch`; `git rev-list --left-right --count origin/feature/nell-full-brand-and-ui-system...HEAD`.
- **Manual verification:** compare values with `01_CURRENT_STATE_AND_ASSET_AUDIT.md`; stop if on the wrong branch or unknown user changes overlap.
- **Done / completion criteria:** provenance and baseline recorded; no write outside the progress log.
- **Rollback/safety:** delete only the new log if abandoning; do not reset user work.
- **Expected commit boundary:** no commit or `docs: start Terra execution log` only if the user wants logs committed.

## T02 — Schema foundation

- **Task ID / objective:** T02; add dependency-light catalogue domain types.
- **Why:** establishes one compile-time vocabulary before loader/UI work.
- **Dependencies:** T01.
- **Confirmed files:** `Health Assistantv2/WorkoutMotion/WorkoutMotionRegistry.swift`, `Health Assistantv2/WorkoutPlans/WorkoutPlanModels.swift`.
- **Create:** `Health Assistantv2/ExerciseCatalog/Domain/ExerciseDefinition.swift`, `ExerciseTaxonomies.swift`, `ExerciseCatalogError.swift`.
- **Modify:** `Health Assistantv2.xcodeproj/project.pbxproj` only if synchronized groups do not include files. **Untouched:** persistence models, generator, UI, assets.
- **Steps:** implement `Codable`, `Hashable`, `Sendable` value types and controlled raw-value wrappers; distinguish required/optional fields; reject empty instructions at validation, not in a crash-prone initializer.
- **Migration:** none.
- **Tests / command:** create domain decoding tests in T08; for now build the app target.
- **Manual:** review public surface against `02_EXERCISE_CATALOG_ARCHITECTURE.md`.
- **Done:** domain compiles without SwiftUI/SwiftData dependencies.
- **Rollback:** remove only new domain files/project references.
- **Commit:** `feat: add exercise catalogue domain schema`.

## T03 — Stable IDs

- **Task ID / objective:** T03; implement validated `ExerciseID` and lifecycle references.
- **Why:** mutable titles cannot remain identity.
- **Dependencies:** T02.
- **Confirmed files:** `WorkoutPlanModels.swift`, `ActiveWorkoutModels.swift`, `WorkoutSession.swift` (inspect only).
- **Create:** ID validation inside `ExerciseDefinition.swift` or a focused `ExerciseID.swift` in the same Domain directory; unit tests in `Health Assistantv2Tests/ExerciseCatalogDomainTests.swift`.
- **Modify:** domain files/tests only. **Untouched:** stored models.
- **Steps:** enforce regex; implement exact equality/coding; add `legacyIDs`, lifecycle status, replacement validation hooks; document unilateral and variant rules in test names.
- **Migration:** none yet.
- **Tests / command:** targeted `xcodebuild test ... -only-testing:Health_Assistantv2Tests/ExerciseCatalogDomainTests`.
- **Manual:** ensure display-name change does not alter IDs.
- **Done:** malformed IDs fail deterministically and valid examples round-trip.
- **Rollback:** revert focused domain/test commit.
- **Commit:** may fold into T02 if tested together; otherwise `feat: add stable exercise identifiers`.

## T04 — Equipment taxonomy

- **Task ID / objective:** T04; add data-driven equipment definitions and satisfaction rules.
- **Why:** existing `EquipmentCategory` is incomplete and not safely extensible.
- **Dependencies:** T02–T03.
- **Confirmed files:** `Health Assistantv2/AdaptiveCoach/AdaptiveCoachModels.swift`, `HealthDataRepository+AdaptiveCoach.swift`, `WorkoutEnvironmentViews.swift`.
- **Create:** `Health Assistantv2/ExerciseCatalog/Resources/Authoring/equipment.json`; equipment domain/filter tests.
- **Modify:** `ExerciseTaxonomies.swift`.
- **Untouched:** existing SwiftData enum/model in this task.
- **Steps:** add required prompt list; model quantity, AND requirements, OR alternatives, explicit equivalences; reject `none` mixed with other requirements and cycles/unknown parents.
- **Migration:** none; legacy adapter is T15.
- **Tests / command:** taxonomy decode and satisfaction tests, validator later repeats them.
- **Manual:** inspect machine specificity and pair-vs-single dumbbell cases.
- **Done:** controlled list loads and compatibility has no implicit machine inference.
- **Rollback:** remove resource/domain additions.
- **Commit:** `feat: add data-driven equipment taxonomy`.

## T05 — Location/environment taxonomy

- **Task ID / objective:** T05; implement presets, capabilities, and contradiction-free eligibility.
- **Why:** current location category plus free text cannot filter reliably.
- **Dependencies:** T04.
- **Confirmed files:** `AdaptiveCoachModels.swift`, `WorkoutEnvironmentViews.swift`.
- **Create:** `Health Assistantv2/ExerciseCatalog/Resources/Authoring/environments.json`; `Health Assistantv2/ExerciseCatalog/Filtering/ExerciseEligibility.swift`; tests.
- **Modify:** `ExerciseTaxonomies.swift`.
- **Untouched:** stored user locations until T16.
- **Steps:** define required presets/capabilities; expand presets; make explicit user values authoritative; implement required/prohibited checks and reason codes.
- **Migration:** none.
- **Tests / command:** table tests for home/gym/hotel, noise, jumping, floor, anchor, and machine contradictions.
- **Manual:** inspect reason text for user-facing/debug suitability.
- **Done:** identical context always produces the same eligible set/reasons.
- **Rollback:** revert taxonomy/filter commit.
- **Commit:** `feat: add exercise environment capabilities`.

## T06 — Media schema

- **Task ID / objective:** T06; define optional ordered media independent of filenames.
- **Why:** current vector registry cannot represent PNGs or future frames.
- **Dependencies:** T02–T03.
- **Confirmed files:** `WorkoutMotionRegistry.swift`, `WorkoutMotionView.swift`, `WorkoutAvatarStyle.swift`.
- **Create:** `Health Assistantv2/ExerciseCatalog/Domain/ExerciseMediaDefinition.swift`.
- **Modify:** `ExerciseDefinition.swift`, domain tests.
- **Untouched:** `Assets.xcassets` and existing motion code.
- **Steps:** roles including `composite`; key/sequence/variant/appearance/accessibility; structural validation for pairs/order/unique keys.
- **Migration:** none.
- **Tests / command:** decode no-media, one, pair, multi-frame, invalid-order fixtures.
- **Manual:** confirm supplied composites are not represented as fake pairs.
- **Done:** all required media configurations round-trip; no-media is valid.
- **Rollback:** focused revert.
- **Commit:** can join schema commit or `feat: add exercise media schema`.

## T07 — Authoring manifest

- **Task ID / objective:** T07; author the initial approved catalogue JSON.
- **Why:** runtime/tooling need real entries, not hard-coded examples.
- **Dependencies:** T03–T06 and human decisions for quarantined items.
- **Confirmed files:** `WorkoutMotionRegistry.swift`, asset migration map, `ChatEngine.swift`.
- **Create:** `Health Assistantv2/ExerciseCatalog/Resources/Authoring/catalog.json`.
- **Modify:** none.
- **Untouched:** source asset pack, quarantine entries, stored data.
- **Steps:** seed approved exercise records; include eight legacy motion aliases; add written instructions, equipment/capabilities, composite media keys; exclude the floor/bench mismatch unless approved.
- **Migration:** enables compatibility mapping but changes no store.
- **Tests / command:** strict validator once T09 exists; until then JSON parse and fixture decode.
- **Manual:** content owner reviews names/instructions/safety and all medium-confidence mappings.
- **Done:** every active entry has non-empty written guidance and resolvable taxonomy references.
- **Rollback:** remove/revert manifest only.
- **Commit:** `feat: add initial exercise catalogue manifest` after approval.

## T08 — Loader and repository layer

- **Task ID / objective:** T08; decode, index, cache, resolve, and inject catalogue data.
- **Why:** consumers require testable behavior and controlled failures.
- **Dependencies:** T02–T07.
- **Confirmed files:** `Sources/App/HealthAssistantApp.swift`, `RootView.swift`, `HealthDataRepository.swift`.
- **Create:** `Loading/ExerciseCatalogLoader.swift`, `ExerciseCatalogRepository.swift`, `BundledExerciseCatalogRepository.swift`, loader/repository tests.
- **Modify:** app composition only after tests prove initialization behavior.
- **Untouched:** `PersistenceController` failure policy; no global singleton.
- **Steps:** version checks; immutable O(1) indexes; exact ID/legacy/alias resolution; actor-safe one-time load; inject protocol; release-safe empty/fallback state and debug diagnostics.
- **Migration:** none.
- **Tests / command:** good/corrupt/newer-version/duplicate/alias-collision/missing-resource injection tests.
- **Manual:** launch with valid and deliberately missing bundle fixture.
- **Done:** consumers can receive a fake repository; app does not crash on catalogue failure in release policy.
- **Rollback:** remove composition injection and new layer.
- **Commit:** `feat: add catalogue loader and repository`.

## T09 — Validation engine

- **Task ID / objective:** T09; implement cross-platform structural/content/resource validation.
- **Why:** adding exercises must not depend on Xcode or manual inspection.
- **Dependencies:** T03–T07.
- **Confirmed files:** `scripts/check_m1_simulator_safe.py`, `project.yml` (do not regenerate).
- **Create:** `scripts/exercise_catalog.py`, `scripts/exercise_catalog_requirements.txt`, Python tests under `scripts/tests/test_exercise_catalog.py`.
- **Modify:** `.gitignore` for intake policy if needed.
- **Untouched:** generated assets until T12.
- **Steps:** implement `validate/report`; JSON pointers; all mandatory checks from Sol prompt; Pillow PNG checks; deterministic output/exit codes; no writes in validate.
- **Migration:** none.
- **Tests / command:** `python -m unittest scripts.tests.test_exercise_catalog`; `python scripts/exercise_catalog.py validate --strict`.
- **Manual:** inject each error class and inspect actionable output.
- **Done:** exact file/entry, expected rule, and likely fix for every error.
- **Rollback:** remove standalone tooling files.
- **Commit:** `tooling: add exercise catalogue validation`.

## T10 — Asset approval boundary

- **Task ID / objective:** T10; freeze approved/quarantined mapping before any asset write.
- **Why:** tooling cannot decide exercise semantics from pixels.
- **Dependencies:** T07, T09, human queue decisions.
- **Confirmed files:** `03_ASSET_INVENTORY_AND_MIGRATION_MAP.md`, `09_OPEN_QUESTIONS_AND_HUMAN_REVIEW_QUEUE.md`.
- **Create:** a machine-readable import mapping such as `Health Assistantv2/ExerciseCatalog/Resources/Authoring/media-import-map.json`.
- **Modify:** progress log and mapping docs with approved decisions.
- **Untouched:** source pack and `archive`.
- **Steps:** require explicit status per image; exclude quarantine; record checksum/source/canonical key; reject unreviewed rows in `--apply`.
- **Migration:** none.
- **Tests / command:** validator verifies every import row maps to one manifest key and checksum.
- **Manual:** human signs off the mismatch and terminology items.
- **Done:** no ambiguous file can enter generated resources silently.
- **Rollback:** mapping file removal only.
- **Commit:** `docs: record approved exercise media mapping` or with T11–T12.

## T11 — Asset normalization

- **Task ID / objective:** T11; define deterministic canonical copies without mutating sources.
- **Why:** source names contain duplicate periods and spelling errors.
- **Dependencies:** T09–T10.
- **Confirmed files:** approved import map and source pack outside repo.
- **Create/modify:** importer code/tests only at first; dry-run report in progress log.
- **Untouched:** original extracted pack, ZIP, brand/pose assets, quarantine.
- **Steps:** sanitize to canonical naming; verify checksum before copy; reject collisions/case-fold collisions; preserve provenance; never crop or infer frames.
- **Migration:** legacy filenames recorded only as provenance/compatibility metadata.
- **Tests / command:** `python scripts/exercise_catalog.py import --dry-run` on fixture and real approved map.
- **Manual:** compare all 50 proposed destinations with mapping table.
- **Done:** dry run is deterministic and contains no writes/unapproved items.
- **Rollback:** no data write before T12.
- **Commit:** combine with tooling import commit.

## T12 — Import tooling

- **Task ID / objective:** T12; generate imagesets and media index from approved inputs.
- **Why:** manual resource editing does not scale.
- **Dependencies:** T10–T11.
- **Confirmed files:** `Health Assistantv2/Assets.xcassets/Contents.json` and existing imageset `Contents.json` examples.
- **Create:** `Assets.xcassets/ExerciseMedia/*.imageset`, `Resources/Generated/media-index.json`.
- **Modify:** `scripts/exercise_catalog.py` and tests.
- **Untouched:** existing brand/app-icon imagesets.
- **Steps:** transactional staging; verify all inputs; write deterministic `Contents.json`; atomically replace only generated namespace; emit provenance/checksums; `--apply` required.
- **Migration:** none.
- **Tests / command:** dry-run then apply; rerun and assert clean Git diff; validator/report.
- **Manual:** inspect representative bodyweight, machine, transparent-edge and composite assets.
- **Done:** idempotent import; orphan/missing counts zero except documented quarantine.
- **Rollback:** delete only generated namespace/index and rerun prior version.
- **Commit:** `assets: import approved exercise media` separate from code.

## T13 — Xcode resource integration

- **Task ID / objective:** T13; prove generated JSON and images are in app/test bundles.
- **Why:** filesystem presence does not prove build membership.
- **Dependencies:** T08, T12; macOS/Xcode.
- **Confirmed files:** `project.pbxproj`, current `Assets.xcassets`.
- **Create:** bundle-resolution tests if not already present.
- **Modify:** `project.pbxproj` only as necessary.
- **Untouched:** `project.yml` unless separately reconciled.
- **Steps:** inspect synchronized group/resource phase; add explicit references only if required; ensure authoring-only files are not unnecessarily bundled and runtime/index are.
- **Migration:** none.
- **Tests / command:** targeted bundle tests plus Debug and Release simulator builds.
- **Manual:** inspect built product or resolve representative assets at runtime.
- **Done:** manifest and sample asset resolve in both configurations.
- **Rollback:** revert minimal project-file/resource changes.
- **Commit:** `build: bundle exercise catalogue resources`.

## T14 — Image loading and reusable media component

- **Task ID / objective:** T14; add resilient media resolution/rendering.
- **Why:** all UI surfaces need one fallback/accessibility policy.
- **Dependencies:** T08, T12–T13.
- **Confirmed files:** `WorkoutMotionView.swift`, `WorkoutAvatarStyle.swift`, `NellStates.swift`.
- **Create:** `UI/ExerciseMediaView.swift`; media resolver implementation/tests.
- **Modify:** `WorkoutMotionView.swift` only to delegate or preserve fallback compatibility.
- **Untouched:** plan/active/history surfaces until later tasks.
- **Steps:** aspect-fit transparent PNG; role ordering/paging; compact/hero policies; fallback vector; accessibility labels/reading order; no forced animations; injectable missing-key behavior.
- **Migration:** none.
- **Tests / command:** snapshot/layout/previews where available; resolver unit tests.
- **Manual:** light/dark, smallest/largest devices, AX sizes, VoiceOver, Reduce Motion.
- **Done:** missing media never crashes or hides written guidance.
- **Rollback:** consumers can retain existing motion view.
- **Commit:** `feat: add exercise media loading and fallback`.

## T15 — Legacy mapping

- **Task ID / objective:** T15; replace fuzzy title matching with exact compatibility resolution.
- **Why:** current partial matching can map the wrong movement.
- **Dependencies:** T07–T08.
- **Confirmed files:** `WorkoutMotionRegistry.swift`, current tests.
- **Create:** `Legacy/LegacyExerciseResolver.swift`, `Legacy/LegacyEquipmentAdapter.swift`.
- **Modify:** `WorkoutMotionRegistry.swift` to route exact resolved definitions then vector fallback; tests.
- **Untouched:** stored records.
- **Steps:** exact stable/legacy ID, normalized exact alias/name, unresolved/ambiguous outcomes; log diagnostics; keep eight vector definitions as fallback until all callers migrate.
- **Migration:** compatibility shim required before release.
- **Tests / command:** aliases, ambiguous names, unknown custom, no-substring-resolution tests.
- **Manual:** exercise current eight motion names and unknown titles.
- **Done:** no risky partial match remains on the canonical path.
- **Rollback:** retain old registry behind isolated adapter until fixed.
- **Commit:** `feat: add legacy exercise resolution`.

## T16 — Persistence migration/compatibility shim

- **Task ID / objective:** T16; add optional canonical references while preserving snapshots and stores.
- **Why:** new workouts need IDs; history must survive renames.
- **Dependencies:** T15 and explicit migration test fixtures.
- **Confirmed files:** `PersistenceController.swift`, `WorkoutPlanModels.swift`, `ActiveWorkoutModels.swift`, `WorkoutSession.swift`, both repository extensions.
- **Create:** explicit SwiftData schema/version types and migration tests/fixtures as required by actual APIs.
- **Modify:** add optional `exerciseIDSnapshot` fields; propagate plan→active→history; optionally add `equipmentTypeID`/`capabilitiesJSON` only if included in tested schema plan.
- **Untouched:** historical display names/instructions; exactly-once completion logic.
- **Steps:** back up test stores; test old-schema open; test in-progress resume; only exact unique backfill; preserve unknown/custom; document release rollback.
- **Migration:** required-before-release fields plus compatibility shim; broad backfill optional.
- **Tests / command:** old-store migration, reopen, resume, complete once, rename/deprecate, unknown/custom fixtures.
- **Manual:** upgrade an installed debug build with seeded data on simulator/device.
- **Done:** old data opens/readable; new records carry IDs; snapshots unchanged.
- **Rollback:** additive optional fields permit code rollback only if store-version compatibility is proven; otherwise restore backup/test build.
- **Commit:** `feat: add stable exercise references with legacy compatibility`.

## T17 — Generator candidate filtering

- **Task ID / objective:** T17; give the model only eligible compact candidates.
- **Why:** prompt-only equipment prose cannot enforce compatibility.
- **Dependencies:** T05, T08, T16.
- **Confirmed files:** `Sources/Features/Chat/ChatEngine.swift`, adaptive-coach repository/models.
- **Create:** `Filtering/ExerciseCandidateFilter.swift` and tests.
- **Modify:** `ChatEngine.swift` composition and prompt payload.
- **Untouched:** confirmation/persistence boundary and unrelated meal generation.
- **Steps:** construct context; apply hard constraints; rank by goal/duration/balance; serialize compact ID/name/tracking/equipment fields; keep custom path explicit.
- **Migration:** uses adapters for legacy location/equipment.
- **Tests / command:** deterministic context matrices; token-size guard test if practical.
- **Manual:** inspect model request for home/gym/no-equipment cases.
- **Done:** ineligible catalogue entries are absent before generation; media has no eligibility effect.
- **Rollback:** feature flag/fallback to existing generation only if safety policy explicitly allows and logs it.
- **Commit:** `feat: filter workout generation candidates`.

## T18 — Generated-output validation

- **Task ID / objective:** T18; validate or reject every generated exercise reference.
- **Why:** models can still return invalid IDs.
- **Dependencies:** T17.
- **Confirmed files:** `ChatEngine.swift`, proposal structs in the same file.
- **Create:** `Filtering/GeneratedWorkoutValidator.swift` and tests.
- **Modify:** proposal schema to carry ID/snapshot; `ChatEngine.swift` before preview/confirmation.
- **Untouched:** confirmed-plan transaction semantics.
- **Steps:** exact resolve; validate eligibility, tracking fields, nonempty instructions; permit logged repair only for exact legacy/unique alias; return actionable proposal error or request regeneration.
- **Migration:** new saved plans use IDs; legacy proposals remain decodable where needed.
- **Tests / command:** nonexistent/deprecated/disabled/ambiguous/ineligible/custom IDs and repair audit.
- **Manual:** stub client failure injection.
- **Done:** no nonexistent catalogue ID reaches persistence silently.
- **Rollback:** validator can be isolated without store rewrite.
- **Commit:** `feat: validate generated workout exercise IDs`.

## T19 — Catalogue and detail UI

- **Task ID / objective:** T19; add searchable catalogue and canonical detail.
- **Why:** users/devs need discoverable written definitions independent of workouts.
- **Dependencies:** T08, T14.
- **Confirmed files:** `NellTrainHomeView.swift`, `NellWorkoutPlansView.swift`, `NellControls.swift`, `NellSurfaces.swift`.
- **Create:** `UI/ExerciseCatalogView.swift`, `UI/ExerciseCatalogDetailView.swift`.
- **Modify:** Train entry and/or existing `NellExerciseDetailView` to delegate; avoid duplicate detail implementations.
- **Untouched:** navigation shell architecture.
- **Steps:** search aliases/display names; filter equipment/location/category; show text first, optional media, lifecycle; recoverable loading/empty/error states.
- **Migration:** legacy plan detail resolves optional ID then snapshots.
- **Tests / command:** UI/state tests and previews.
- **Manual:** long names, no media, deprecated, unknown, dark/AX/VoiceOver.
- **Done:** all states accessible without layout clipping or identity ambiguity.
- **Rollback:** remove Train entry while leaving domain intact.
- **Commit:** `feat: add exercise catalogue and detail UI`.

## T20 — Workout-preview integration

- **Task ID / objective:** T20; show canonical media/details in generated and saved plan preview.
- **Why:** users need to review what will be performed before confirmation/start.
- **Dependencies:** T18–T19.
- **Confirmed files:** `WorkoutPlanViews.swift`, `NellWorkoutPlansView.swift`, `ChatView.swift`.
- **Create:** no new file unless a reusable card is justified (`UI/ExerciseCatalogCard.swift`).
- **Modify:** preview/card surfaces to resolve ID and pass snapshots/fallback.
- **Untouched:** confirmation semantics and plan ordering.
- **Steps:** compact thumbnail/composite; stable-ID navigation; unresolved custom/legacy text state; do not require media.
- **Migration:** reads optional ID/snapshots.
- **Tests / command:** preview tests for canonical/no-media/unknown/custom.
- **Manual:** proposal confirmation remains explicit and tappable with large text.
- **Done:** preview never blocks confirmation due solely to image failure.
- **Rollback:** revert UI-only integration.
- **Commit:** `feat: integrate catalogue into workout previews`.

## T21 — Active Workout integration

- **Task ID / objective:** T21; add restrained optional instruction media to active execution.
- **Why:** supplement form guidance without displacing controls/text.
- **Dependencies:** T14, T16.
- **Confirmed files:** `NellActiveWorkoutContainerView.swift`, `ActiveWorkoutViews.swift`, `NellActiveWorkoutBoundaryTests.swift`.
- **Create:** none expected.
- **Modify:** active views and boundary tests.
- **Untouched:** timer, resume, skip, completion, and exactly-once conversion code.
- **Steps:** resolve by ID; compact composite/thumbnail; optional expanded frames; text/timer/control reading order first; fallback for unknown.
- **Migration:** optional ID with snapshot fallback.
- **Tests / command:** full active workout suite plus boundary tests.
- **Manual:** background/resume, rotation, AX5, VoiceOver, Reduce Motion.
- **Done:** all old active-workout tests pass and media failure is inert.
- **Rollback:** UI feature can be removed without data changes.
- **Commit:** `feat: add optional media to active workouts`.

## T22 — History integration

- **Task ID / objective:** T22; show historical snapshot truth with optional current details.
- **Why:** renames/deprecations must not rewrite history.
- **Dependencies:** T16, T19.
- **Confirmed files:** `NellWorkoutExecutionHistoryView.swift`, `WorkoutLogView.swift`, `WorkoutSession.swift`.
- **Create:** none expected.
- **Modify:** history/summary surfaces and tests.
- **Untouched:** stored `exerciseName` snapshots.
- **Steps:** display snapshot as primary; optional “current exercise details” resolution; distinguish unresolved/custom; never substitute replacement automatically in history.
- **Migration:** validates preservation policy.
- **Tests / command:** rename/deprecated/unknown/custom history fixtures.
- **Manual:** compare pre/post-upgrade completed workout wording.
- **Done:** historical wording identical after catalogue changes.
- **Rollback:** revert view resolution.
- **Commit:** `feat: resolve current exercise details from history`.

## T23 — Fallback states

- **Task ID / objective:** T23; unify catalogue/media/load/unknown failure UX.
- **Why:** resilience is a product requirement, not an edge case.
- **Dependencies:** T14, T19–T22.
- **Confirmed files:** `NellStates.swift`, all integrated surfaces.
- **Create:** focused state view only if existing `NellStates` cannot represent needs.
- **Modify:** state components/callers/tests.
- **Untouched:** unrelated network/error UI.
- **Steps:** empty/corrupt catalogue, missing asset, unresolved legacy/custom, unsupported schema; diagnostic detail in debug, plain recovery in release.
- **Migration:** none.
- **Tests / command:** injected failure-state tests.
- **Manual:** sever manifest/index/media one at a time in debug fixtures.
- **Done:** no crash/blank control surface and written snapshots remain usable.
- **Rollback:** component-level revert.
- **Commit:** may combine with media/UI integration.

## T24 — Debug gallery

- **Task ID / objective:** T24; create exhaustive DEBUG-only catalogue inspector.
- **Why:** visual and metadata QA must scale with catalogue size.
- **Dependencies:** T08, T14, T19, T23.
- **Confirmed files:** `NellSettingsSections.swift`, `NellAppShellView.swift`.
- **Create:** `UI/ExerciseCatalogDebugGallery.swift`.
- **Modify:** DEBUG-only Settings route or launch-argument composition.
- **Untouched:** release navigation.
- **Steps:** list all IDs/names/aliases/categories/equipment/capabilities/media; filters invalid/incomplete/deprecated/missing; variants for long names/dark/AX/accessibility.
- **Migration:** none.
- **Tests / command:** compile Debug and Release; source/build assertion that release route is absent.
- **Manual:** exercise every gallery filter and media role.
- **Done:** every entry inspectable; gallery unreachable in Release.
- **Rollback:** remove DEBUG route/file.
- **Commit:** `dev: add exercise catalogue debug gallery`.

## T25 — Unit, integration, migration, and UI tests

- **Task ID / objective:** T25; close coverage gaps across the full matrix.
- **Why:** individual task tests do not prove cross-boundary behavior.
- **Dependencies:** T02–T24.
- **Confirmed files:** all `Health Assistantv2Tests/*.swift` suites listed in audit.
- **Create/modify:** focused catalogue, generation, migration, UI test files; do not make one monolithic suite.
- **Untouched:** production behavior solely to placate weak tests.
- **Steps:** implement every automated row in `07_TEST_AND_QA_MATRIX.md`; preserve existing tests; use old-store fixtures and fake repositories/media resolvers.
- **Migration:** migration coverage is release-gating.
- **Tests / command:** targeted suites then full `xcodebuild test`.
- **Manual:** inspect skipped tests and justify any platform-only gap.
- **Done:** matrix automation statuses truthful and all gating tests pass.
- **Rollback:** tests should expose regression; do not delete failures without cause.
- **Commit:** `test: cover exercise catalogue generation and migration`.

## T26 — Accessibility and appearance

- **Task ID / objective:** T26; validate VoiceOver, Dynamic Type, dark mode, and Reduce Motion.
- **Why:** instructional UI can become unsafe or unusable when clipped/reordered.
- **Dependencies:** T19–T24.
- **Confirmed files:** new catalogue/media UI and integrated Train surfaces.
- **Create/modify:** previews/UI tests and accessibility labels; no unrelated redesign.
- **Untouched:** brand style unless contrast actually fails.
- **Steps:** text-first reading order; descriptive nonduplicative alt text; decorative images hidden; paging controls named; no information only in motion/color; AX5 layout.
- **Migration:** none.
- **Tests / command:** UI/previews plus Accessibility Inspector/manual matrix.
- **Manual:** VoiceOver on device/simulator, dark/light, Reduce Motion, small/large devices.
- **Done:** all matrix rows pass or blockers documented.
- **Rollback:** revert focused layout changes, not accessibility requirements.
- **Commit:** `fix: harden exercise media accessibility` if separate.

## T27 — Build and simulator validation

- **Task ID / objective:** T27; prove clean Debug/Release builds and simulator flows.
- **Why:** Windows Sol audit could not build iOS.
- **Dependencies:** T25–T26; macOS.
- **Confirmed files:** actual xcodeproj/scheme, not stale `project.yml`.
- **Create/modify:** only fixes required by build/test evidence.
- **Untouched:** unrelated warnings/features.
- **Steps:** clean derived data if needed; build Debug/Release; run full tests; install/launch; exercise catalogue→plan→active→complete→history and failure fixtures.
- **Migration:** run upgrade simulator before fresh install.
- **Tests / command:** recorded `xcodebuild build/test` commands with destinations.
- **Manual:** inspect logs and resource resolution.
- **Done:** zero build/test failures; exact warnings and simulator versions recorded.
- **Rollback:** revert only evidence-linked build fixes.
- **Commit:** fixes in logical owning commits, not a “misc fixes” dump.

## T28 — Physical-device QA

- **Task ID / objective:** T28; validate real-device rendering, memory, resume, and upgrade.
- **Why:** PNG scale, accessibility, lifecycle, and SwiftData migration need device evidence.
- **Dependencies:** T27 and signed device access.
- **Confirmed files:** no planned source file.
- **Create/modify:** QA log only unless a defect is reproduced.
- **Untouched:** production code without a tracked failure.
- **Steps:** install over prior build with saved plan/active/history; exercise media-heavy gallery; background/resume; offline run; VoiceOver; low-memory observation; complete once.
- **Migration:** mandatory installed-data check.
- **Tests / validation:** record device/OS/build and outcomes.
- **Manual:** entire task.
- **Done:** pass, or explicit blocker with reproducible evidence; never claim pass if no device was available.
- **Rollback:** retain prior test build/store backup.
- **Commit:** none unless evidence-driven fix.

## T29 — Contributor-guide finalization

- **Task ID / objective:** T29; make workflow docs match actual commands/layout.
- **Why:** stale documentation recreates scattered edits.
- **Dependencies:** T09–T28.
- **Confirmed files:** `04_GENERAL_PURPOSE_EXERCISE_AND_IMAGE_WORKFLOW.md`, `README.md`, `docs/nell-redesign/README.md`.
- **Create:** none expected.
- **Modify:** contributor guide and relevant doc indexes; mark stale manifests superseded without deleting history.
- **Untouched:** unrelated roadmap/product docs.
- **Steps:** copy/paste every command; verify paths/options; document dependency install, debug gallery, bundle verification, rollback.
- **Migration:** document actual shipped version.
- **Tests / command:** fresh-clone dry run of documented validator/import steps.
- **Manual:** a contributor follows the guide without hidden knowledge.
- **Done:** no command/path fiction and generated files clearly marked.
- **Rollback:** revert doc-only changes if implementation reverts.
- **Commit:** `docs: finalize exercise catalogue contributor workflow`.

## T30 — Cleanup and logical commits

- **Task ID / objective:** T30; remove temporary artifacts and organize intentional history.
- **Why:** a working feature with polluted scope is not PR-ready.
- **Dependencies:** T27–T29.
- **Confirmed files:** full `git status`, progress log, generated reports.
- **Create/modify:** only cleanup in owned files.
- **Untouched:** user/unrelated changes and `archive`.
- **Steps:** delete temp fixtures not meant for repo; rerun generator for idempotence; inspect every diff; split/fixup commits by architecture boundary; do not rewrite shared history without approval.
- **Migration:** ensure migration code/fixtures remain together.
- **Tests / command:** validator, full tests, Debug/Release build after final commit structure.
- **Manual:** `git diff parent...HEAD` scope review.
- **Done:** clean tree, logical commits, no generated drift.
- **Rollback:** use non-destructive revert/fixup; never `reset --hard` over user work.
- **Commit:** sequence defined in executive decisions and T02–T29.

## T31 — Draft PR preparation

- **Task ID / objective:** T31; prepare a truthful PR-ready handoff; open/push only with user authorization.
- **Why:** reviewers need scope, migration evidence, risks, and QA status.
- **Dependencies:** T30.
- **Confirmed files:** Git log/diff, test/build logs, human queue.
- **Create:** draft PR body in progress log or requested file.
- **Modify:** none.
- **Untouched:** remote state absent authorization.
- **Steps:** summarize architecture, asset approvals/quarantine, schema/migration, commands, simulator/device coverage, screenshots if requested, rollback, remaining blockers.
- **Migration:** explicitly called out.
- **Tests / validation:** recheck CI-equivalent commands and clean tree.
- **Manual:** reviewer can trace every claim to evidence.
- **Done:** draft is honest; no hidden skipped QA.
- **Rollback:** delete local draft only.
- **Commit:** none.

## T32 — Final acceptance review

- **Task ID / objective:** T32; verify every binary acceptance item and stop.
- **Why:** “mostly done” is not release evidence.
- **Dependencies:** T01–T31.
- **Confirmed files:** `08_ACCEPTANCE_CHECKLIST.md`, full Sol package, progress/deviation log.
- **Create/modify:** check off only evidence-backed items; update open questions with resolved decisions.
- **Untouched:** production code unless a failed item reopens its owning task.
- **Steps:** walk checklist; map failures back to task IDs; rerun validation/build/tests; record Git/commit/PR status; state device limitation if any.
- **Migration:** release gate cannot pass without old-store evidence.
- **Tests / command:** final command set from T30.
- **Manual:** catalogue/gallery/workout/history/accessibility/device review.
- **Done:** every required item yes or the handoff explicitly remains not ready; no ambiguous “N/A” for required device/migration items.
- **Rollback:** reopen the owning task rather than patching around evidence.
- **Commit:** `docs: record final exercise catalogue acceptance` only if acceptance artifacts are tracked.

## Parallelism map

- After T03: T04, T05, and T06 may proceed in parallel, but merge before T07.
- After T09 and T10: importer implementation tests and loader unit tests may proceed in parallel; real asset application waits for approval.
- After T16 and shared UI primitives: T19, T21, and T22 can be developed in parallel on separate files; T20 waits for generator output T18.
- Accessibility review can begin per component, but T26 final pass waits for all UI integration.
- T27–T32 are sequential release gates. Persistence model edits (T16), asset generation (T12), and project-file edits (T13) must each have a single owner at a time.

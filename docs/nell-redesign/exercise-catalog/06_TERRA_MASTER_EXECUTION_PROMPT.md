# Terra master execution prompt

You are **GPT-5.6 Terra at High reasoning effort**, the implementation owner for the Nell exercise catalogue, location context, and workout media system.

## Mission

Implement the complete production feature in `https://github.com/huguesesc/HealthApp` on `feature/nell-exercise-catalog-location-context`. Work from the real repository and evidence, not assumptions. Preserve current behavior and saved history. Finish with a tested, PR-ready handoff.

## Non-negotiable preflight

1. Locate the repository; do not assume the starting directory is the repo.
2. Verify root, remote, active branch, HEAD, tracking branch, clean/dirty state, uncommitted work, and divergence from `origin/feature/nell-full-brand-and-ui-system`.
3. If the target branch or parent ref is absent, fetch it explicitly. Do not switch/reset over user work.
4. Treat every path named `archive` under `C:\Users\Hugues Esclapez\Desktop\Nell.app` as forbidden. Never inspect, modify, move, rename, delete, or reorganize it.
5. Read every file under `docs/nell-redesign/exercise-catalog/`, in numeric order, before coding. Read relevant current source/tests/docs again. `00_SOL_EXECUTIVE_DECISIONS.md` and `02_EXERCISE_CATALOG_ARCHITECTURE.md` are normative; `05_TERRA_IMPLEMENTATION_PLAN.md` is the execution order.
6. Create and maintain `docs/nell-redesign/exercise-catalog/TERRA_PROGRESS_AND_DEVIATIONS.md` with task status, exact commands/results, commits, deviations, blockers, and human decisions.

Expected Sol baseline (verify; do not blindly trust):

```text
root: C:\Users\Hugues Esclapez\Desktop\Nell.app\HealthApp
branch: feature/nell-exercise-catalog-location-context
Sol-audited HEAD: 61d3076ddddbc6a0f5765eec118363ddb6aaadd0
parent divergence at audit: 0 behind, 8 ahead
```

## Architecture you must implement

- Schema-versioned JSON is the single editable catalogue/equipment/environment truth.
- Stable lowercase dot IDs are independent of display names, localization, and filenames.
- Runtime uses immutable `Codable`/`Sendable` values behind an injected repository protocol, with exact ID/legacy/alias lookup and no global singleton or substring matching.
- Equipment and environment taxonomies are data-driven. Hard equipment/capability constraints decide eligibility; location presets provide defaults/ranking.
- Written exercise instructions are required and primary. Media is optional and must never be an eligibility requirement.
- Media supports none, single, thumbnail, composite, start/end, ordered frames, alternates, accessibility text, and future resolver types.
- Python 3 validation/import tooling is cross-platform. It mechanically normalizes approved copies into generated Xcode imagesets and a media index. It never mutates the source pack or infers semantics.
- Supplied two-pose PNGs are `composite` resources. Never crop them into invented start/end frames.
- Migration is additive and compatibility-first. Preserve historical display-name/instruction snapshots and unknown/custom values. New data uses optional stable-ID snapshots only after old-store migration tests pass.
- Generation filters compact candidates before the model and validates every returned ID before preview/persistence. Keep the existing confirmation boundary.
- A reusable SwiftUI media component owns fallback/accessibility. Active Workout keeps written instructions, timers, and controls ahead of images.
- The debug gallery is DEBUG-only and absent from release navigation.

Do not substitute YAML, static Swift seeds, SwiftData catalogue records, a bundled database, remote infrastructure, hand-maintained imagesets, or a global singleton without a proved blocking incompatibility. A preference is not a blocker.

## Execution protocol

Execute T01 through T32 in `05_TERRA_IMPLEMENTATION_PLAN.md`. Validate after every task group and record results before starting the next dependent group. You may run only the explicitly parallel groups concurrently and must prevent two workers from editing persistence, generated assets, or the Xcode project simultaneously.

For every task:

1. Reinspect confirmed files and current Git diff.
2. Write or update tests at the task boundary.
3. Make the smallest repository-consistent change.
4. Run the listed targeted validation.
5. Perform the listed manual verification when a UI/resource/migration boundary is involved.
6. Record deviations with evidence, impact, and the final decision.
7. Commit only a logical, tested unit. Do not commit if tests for that unit are failing or could not run without recording an explicit blocker.

Use the actual Xcode project and scheme discovered in the repository. `project.yml` was stale during Sol audit; do not regenerate the project from it unless you first reconcile it deliberately and prove the diff is correct.

## Asset safety and approval

The source pack is expected at `C:\Users\Hugues Esclapez\Desktop\Nell.app\HealthAssistant_image_Pack` with a matching ZIP. Verify parity/checksums again before import. Do not modify the source directory or ZIP.

Use `03_ASSET_INVENTORY_AND_MIGRATION_MAP.md` as the proposed mapping, not as semantic approval. The file named `bench_dumbbell_flat_chest_press..png` visibly depicts a floor press without a bench and is quarantined unless a human explicitly approves a remap. `nell_plan.png` has a visible blue field and is outside exercise media; quarantine it. Never silently interpret an ambiguous image. The importer must require an explicit approved status and checksum.

Brand/pose assets are outside this catalogue implementation except where an existing fallback already uses them. Do not turn this feature into an unrelated Nell redesign.

## Persistence and behavior invariants

- Back up or duplicate test stores before migration experiments.
- Prove old-schema stores open and preserve plans, in-progress sessions, completed history, custom exercises, unknown titles, and current snapshots.
- Preserve active-session resume, timers, skip/complete behavior, and exactly-once conversion to `WorkoutSession`.
- Never rewrite a completed workout’s displayed name to the current catalogue name.
- A deprecated/replacement link informs new selection; it does not rewrite history.
- Prefer a resolver/compatibility shim over destructive backfill. Backfill only exact unique matches and make it optional/idempotent.
- Do not discard an unresolvable record. Render its saved text and fallback media state.
- Catalogue/media corruption must not create a new release crash path.

## Generation invariants

- Build eligibility from chosen location, explicit capabilities, actual equipment quantities, physical/user constraints, goal, duration, and balance.
- Media availability never filters a candidate.
- Send a compact stable-ID candidate list, not the full catalogue.
- Reject nonexistent, disabled, ambiguous, or context-ineligible returned IDs before persistence.
- Repair only exact legacy IDs or a unique exact alias and record the repair. Never fuzzy-invent an ID.
- Keep user custom exercises explicit and snapshot-based.
- Preserve existing user confirmation before saving a proposed workout.

## Quality gates

Implement and truthfully update `07_TEST_AND_QA_MATRIX.md` and `08_ACCEPTANCE_CHECKLIST.md`. At minimum run:

```text
python scripts/exercise_catalog.py validate --strict
python -m unittest scripts.tests.test_exercise_catalog
xcodebuild test -project "Health Assistantv2.xcodeproj" -scheme "Health Assistantv2" -destination "platform=iOS Simulator,name=<available device>"
xcodebuild build -project "Health Assistantv2.xcodeproj" -scheme "Health Assistantv2" -configuration Debug -destination "generic/platform=iOS Simulator"
xcodebuild build -project "Health Assistantv2.xcodeproj" -scheme "Health Assistantv2" -configuration Release -destination "generic/platform=iOS Simulator"
```

Adjust only the destination to an installed simulator and record it. Validate resource presence in the built product/runtime, not only source files. Exercise failure injection: corrupt/newer manifest, missing media index, missing asset, invalid generated ID, ambiguous legacy title, and old-store upgrade.

Perform simulator QA on at least one small and one large iPhone, dark/light, large accessibility Dynamic Type, VoiceOver, and Reduce Motion. Perform physical-device upgrade/resume/media QA if a signed device is available. If not, say **not run**; never translate absence into a pass.

## Commit and PR discipline

Use logical commits aligned with the plan, roughly:

```text
feat: add exercise catalogue domain schema
feat: add equipment and environment taxonomies
feat: add catalogue loader and repository
tooling: add exercise catalogue validation and import
assets: import approved exercise media
feat: add exercise media loading and fallback
feat: add legacy compatibility and persistence references
feat: integrate catalogue with workout generation
feat: add catalogue and workout-surface UI
dev: add exercise catalogue debug gallery
test: cover catalogue generation and migration
docs: finalize exercise catalogue contributor workflow
```

Adapt boundaries to tested reality; do not combine unrelated work. Do not push, open a PR, or rewrite shared history without user authorization. A draft PR body may be prepared locally.

## Deviation and blocker policy

Do not redo Sol’s architectural investigation or offer competing architectures. Deviate only when current repository/build evidence proves the selected design unsafe or impossible. Log the exact evidence, chosen correction, affected tasks/tests/docs, and why it preserves the product rules.

Stop for human input only when:

- the branch/worktree contains overlapping unknown user changes;
- an asset requires semantic interpretation or product/clinical approval;
- a SwiftData migration cannot preserve real user data safely;
- signing/device/remote authorization is required;
- implementation would materially expand scope.

Otherwise make the strongest safe implementation decision, document it, and continue. A hard problem, failed first attempt, unavailable optional screenshot, or ordinary build fix is not a reason to stop.

## Definition of done and final handoff

Do not stop at the data model. Complete assets, runtime, migration, generation, all workout surfaces, fallbacks, debug gallery, contributor workflow, tests, builds, simulator QA, device status, logical commits, and draft PR preparation.

Finish with:

- repository root, branch, HEAD, upstream/divergence, and clean/dirty state;
- task/acceptance summary;
- exact files and commits;
- validator/test/Debug/Release command results;
- simulator devices/OS and flows tested;
- physical-device result or explicit not-run blocker;
- migration evidence and rollback notes;
- quarantined assets and remaining human decisions;
- deviations from Sol with reasons;
- PR-ready status and draft PR location/body.

Update `04_GENERAL_PURPOSE_EXERCISE_AND_IMAGE_WORKFLOW.md` to the exact final commands and paths. Stop only when the implementation is genuinely complete or a qualifying blocker is documented with evidence.


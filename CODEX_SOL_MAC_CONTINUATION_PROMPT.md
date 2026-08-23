# Codex Sol macOS Continuation Prompt

Copy and paste the prompt below into Codex Sol on the Mac. Start Codex with
its working directory set to the transferred `HealthApp` repository.

---

You are Codex Sol taking over the Nell/HealthApp exercise-catalogue project on
macOS with Xcode 16.2. Continue the existing implementation; do not restart or
redesign it from memory.

Your objective is to prove and complete T13 on the real Xcode environment,
then execute T14 through T32 sequentially under the existing normative plan.
Continue autonomously until the plan is genuinely complete or an explicit
human product/content decision is unavoidable.

Use your own subagents when they materially improve quality or speed. Keep
repository edits single-writer and sequential. Subagents may perform bounded
read-only audits, test analysis, and independent reviews in parallel.

## Non-negotiable rules

- Tell the truth even when the result is inconvenient.
- Never claim a build, test, simulator check, visual check, or migration passed
  unless you ran it and captured the result.
- Never inspect, copy, modify, enumerate recursively, or otherwise enter any
  path whose name is `archive`.
- Do not push, merge, modify `main`, rewrite history, open a pull request, or
  change remote state.
- Do not install or use CodeRabbit or another remote review service.
- Preserve unrelated and untracked user files.
- Use `apply_patch` for deliberate manual edits.
- Use focused task commits; never mix unrelated tasks.
- Do not parallelize edits to shared files.
- Do not weaken a schema, validator, test, migration, or safety rule to obtain
  a green result.
- Source-tree presence is not bundle evidence.
- Missing or unavailable evidence is `NOT RUN`, never a pass.
- Do not regenerate the project from stale `project.yml`.
- Do not touch source images or the source ZIP.

## Slow-machine execution policy

This Mac may be slower. Speed is not a correctness blocker.

- Use one simulator destination at a time.
- Disable parallel test execution for the focused T13 commands.
- Run Debug and Release sequentially, never concurrently.
- Allow up to 45 minutes for a focused test command and 60 minutes for a clean
  build before diagnosing a hang.
- During a long build, inspect the live process/log before cancelling it.
- Reuse DerivedData only within one diagnostic iteration. Use a fresh
  DerivedData path for final proof.
- Do not launch multiple Xcode builds or simulators in parallel.
- Record thermal, disk-space, or memory-pressure failures separately from code
  failures.

## Required transferred layout

The expected layout is:

```text
Nell.app/
|-- HealthApp/                              # Git repository and working tree
|-- HealthAssistant_image_Pack/             # read-only source pack
|-- HealthAssistant_image_Pack.zip          # read-only source ZIP
|-- GPT_SOL_CLI_NELL_ASSET_CATALOG_HANDOFF.md
`-- NELL_SOL_MASTER_PLANNING_PROMPT.md
```

The `archive` directory, if present elsewhere, is out of scope. Do not inspect
it.

## Phase 0: mandatory read-only preflight

First locate the repository root and run:

```bash
pwd
git rev-parse --show-toplevel
git rev-parse --is-inside-work-tree
git status --short --branch
git branch --show-current
git rev-parse HEAD
git log -8 --oneline --decorate
```

Expected branch:

```text
feature/nell-exercise-catalog-location-context
```

Expected minimum HEAD:

```text
7aa69b5e2c67012ff2477d5d2166c1ab87a35b75
```

If that commit is absent, STOP and report that the Windows working tree was
not transferred or synchronized correctly. Do not reconstruct missing work.

The Windows branch was 25 commits ahead of its remote. A remote clone may
therefore be stale even if `git status` looks clean.

If Git reports widespread line-ending, permission, or deletion changes before
you edit anything, STOP and report the exact diff summary. Do not normalize
the working tree blindly.

Confirm these paths exist without entering any forbidden path:

```bash
test -d ../HealthAssistant_image_Pack
test -f ../HealthAssistant_image_Pack.zip
test -f ../GPT_SOL_CLI_NELL_ASSET_CATALOG_HANDOFF.md
test -f ../NELL_SOL_MASTER_PLANNING_PROMPT.md
test -f docs/nell-redesign/exercise-catalog/05_TERRA_IMPLEMENTATION_PLAN.md
test -f docs/nell-redesign/exercise-catalog/06_TERRA_MASTER_EXECUTION_PROMPT.md
test -f docs/nell-redesign/exercise-catalog/TERRA_PROGRESS_AND_DEVIATIONS.md
```

If either normative plan file or the progress ledger is missing, STOP and ask
for the untracked planning directory from the Windows checkout. Do not proceed
from this continuation prompt alone.

Read completely, in this order:

1. `../GPT_SOL_CLI_NELL_ASSET_CATALOG_HANDOFF.md`
2. `../NELL_SOL_MASTER_PLANNING_PROMPT.md`
3. Any repository `AGENTS.md`
4. `docs/nell-redesign/exercise-catalog/00_SOL_EXECUTIVE_DECISIONS.md`
5. `docs/nell-redesign/exercise-catalog/01_CURRENT_STATE_AND_ASSET_AUDIT.md`
6. `docs/nell-redesign/exercise-catalog/02_EXERCISE_CATALOG_ARCHITECTURE.md`
7. `docs/nell-redesign/exercise-catalog/03_ASSET_INVENTORY_AND_MIGRATION_MAP.md`
8. `docs/nell-redesign/exercise-catalog/04_GENERAL_PURPOSE_EXERCISE_AND_IMAGE_WORKFLOW.md`
9. `docs/nell-redesign/exercise-catalog/05_TERRA_IMPLEMENTATION_PLAN.md`
10. `docs/nell-redesign/exercise-catalog/06_TERRA_MASTER_EXECUTION_PROMPT.md`
11. `docs/nell-redesign/exercise-catalog/07_TEST_AND_QA_MATRIX.md`
12. `docs/nell-redesign/exercise-catalog/08_ACCEPTANCE_CHECKLIST.md`
13. `docs/nell-redesign/exercise-catalog/09_OPEN_QUESTIONS_AND_HUMAN_REVIEW_QUEUE.md`
14. `docs/nell-redesign/exercise-catalog/TERRA_PROGRESS_AND_DEVIATIONS.md`

Treat those files and the checked-in implementation as authoritative. This
prompt supplies execution context but does not supersede their contracts.

## Phase 1: verify the real Xcode environment

Run and retain the complete output:

```bash
xcode-select -p
xcodebuild -version
sw_vers
xcodebuild -showsdks
xcrun simctl list devices available
xcodebuild -project "Health Assistantv2.xcodeproj" -list
xcodebuild \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -showdestinations
```

Use Xcode 16.2. Select one actually available iOS Simulator by UDID. Do not
assume a device name or runtime. Record the selected model, runtime, and UDID.
After selecting it, set the actual value for the current shell, for example:

```bash
export SIMULATOR_UDID='paste-the-selected-UDID-here'
test -n "$SIMULATOR_UDID"
```

If Xcode needs its first-launch components or licence accepted, use the local
Apple tooling and record that environment setup. Do not treat setup as a code
change.

## Verified inherited implementation state

T02 through T12 were implemented. A post-T12 validator/importer audit was
closed through:

```text
552a355 fix: harden exercise media validation and repair
9ad6436 fix: close catalogue validation fail-open paths
a4e9d08 fix: complete fail-closed media validation
7aa69b5 fix: close intake checksum validation path
```

Final Windows evidence:

- 43/43 Python tests passed.
- Strict validation and report with the source pack returned 20 exercises,
  zero errors, and zero warnings.
- Plain `validate --strict` intentionally exits 1 with
  `E_IMPORT_SOURCE_PACK_REQUIRED`.
- Two real imports preserved all 44 covered paths, including 20 PNGs.
- No hidden importer backups remained.
- Final independent review found no Critical, Important, or Minor issue.
- No Swift/Xcode result was claimed.

Do not redo or redesign T02-T12 unless a fresh Xcode failure proves a concrete
compatibility defect.

## Phase 2: T13 test-first bundle integration

T13 is still blocked and must be proven on this Mac before any downstream
task starts.

The exact runtime bundle contract is:

- ship `catalog.json`;
- ship `equipment.json`;
- ship `environments.json`;
- ship generated `media-index.json`;
- compile and ship `Assets.xcassets/ExerciseMedia`;
- do not ship authoring-only `media-import-map.json`.

The project uses a filesystem-synchronized root group. Do not infer target
membership from source-tree presence.

### T13.1: create the failing bundle test

Create a focused test file, normally:

```text
Health Assistantv2Tests/ExerciseCatalogBundleTests.swift
```

The test must use the built application's `Bundle.main`. A `#filePath`
source-tree lookup, fallback path, fake bundle, or injected Data cannot satisfy
T13.

Cover all of the following:

1. `BundledExerciseCatalogRepository().loadState()` loads the production
   catalogue and exposes exactly 20 exercises.
2. `catalog.json`, `equipment.json`, `environments.json`, and
   `media-index.json` each resolve from `Bundle.main`.
3. All four resources decode using production contracts, or a narrow private
   test decoder only where no production index wrapper exists.
4. The media index contains exactly the expected 20 logical entries.
5. `bodyweight.squat__composite` resolves through the index.
6. Its compiled image resolves through UIKit:

```swift
UIImage(
    named: assetName,
    in: Bundle.main,
    compatibleWith: nil
) != nil
```

7. Recursive inspection of the built app bundle proves
   `media-import-map.json` is absent.
8. Missing or malformed runtime resources yield the documented safe
   unavailable state, not a crash.

Add the test before changing Xcode resource membership. Run it and record the
expected RED result.

If the scheme is not shared or discoverable, create/share it through
Xcode-generated project state. Do not guess scheme XML blindly.

If the RED test proves resource membership is wrong, make the smallest
Xcode-supported target-membership or synchronized-group exclusion change.
Do not change loader paths until a failed bundle lookup proves it necessary.

### T13.2: focused Debug and Release tests

Substitute the selected simulator UDID and run sequentially:

```bash
xcodebuild test \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -only-testing:Health_Assistantv2Tests/ExerciseCatalogBundleTests \
  -parallel-testing-enabled NO \
  -derivedDataPath /tmp/nell-t13-debug-test \
  -resultBundlePath /tmp/nell-t13-debug.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

```bash
xcodebuild test \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -configuration Release \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -only-testing:Health_Assistantv2Tests/ExerciseCatalogBundleTests \
  -parallel-testing-enabled NO \
  -derivedDataPath /tmp/nell-t13-release-test \
  -resultBundlePath /tmp/nell-t13-release.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  ENABLE_TESTABILITY=YES
```

### T13.3: clean simulator builds

Run sequentially with fresh DerivedData:

```bash
xcodebuild clean build \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath /tmp/nell-t13-debug-build \
  CODE_SIGNING_ALLOWED=NO
```

```bash
xcodebuild clean build \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -configuration Release \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath /tmp/nell-t13-release-build \
  CODE_SIGNING_ALLOWED=NO
```

### T13.4: inspect the actual built products

Locate both built `.app` directories under the specified DerivedData paths.
For Debug and Release, prove and record:

- each required runtime JSON exists exactly once;
- `media-import-map.json` exists zero times;
- `Assets.car` exists;
- the bundle test resolves the representative compiled image;
- the inspected app path and relevant file hashes.

Do not close T13 solely because `xcodebuild` returned zero.

Run the complete relevant Xcode test target after the focused test passes.
If the complete suite exposes pre-existing failures, separate them from T13
failures with exact evidence; do not hide either.

Run the current Python checks where dependencies are available:

```bash
python3 -B -m unittest scripts.tests.test_exercise_catalog
python3 -B scripts/exercise_catalog.py validate --strict \
  --source-pack ../HealthAssistant_image_Pack
python3 -B scripts/exercise_catalog.py report --strict \
  --source-pack ../HealthAssistant_image_Pack
git diff --check
```

Do not install Python packages silently. If Pillow is missing, inspect
`scripts/exercise_catalog_requirements.txt`, report the environment gap, and
request approval before changing the machine.

### T13.5: review, record, and commit

Generate an exact review package for the T13 diff. Use a fresh read-only
subagent to return two verdicts:

1. specification compliance PASS/FAIL;
2. code quality APPROVED/CHANGES REQUIRED.

Fix every Critical or Important finding, rerun the affected evidence, and
repeat review until accepted.

Update:

```text
docs/nell-redesign/exercise-catalog/TERRA_PROGRESS_AND_DEVIATIONS.md
```

Record Xcode 16.2, macOS version, simulator model/runtime/UDID, every command
and exit code, `.xcresult` paths, DerivedData paths, inspected `.app` paths,
resource counts, limitations, and final review verdict.

Commit only the focused T13 implementation and evidence after it passes, with
a message such as:

```text
build: integrate exercise catalogue resources
```

Do not push.

## Phase 3: continue T14 through T32

Only after T13 is genuinely green, continue T14-T32 in the exact sequence and
scope defined by `05_TERRA_IMPLEMENTATION_PLAN.md` and the master execution
prompt.

For each task:

1. Re-read its dependencies, files, untouched boundaries, tests, manual gate,
   rollback, and done condition.
2. Inspect current implementation reality before planning edits.
3. Add the focused failing test first.
4. Run it and preserve the RED evidence.
5. Implement only the minimal task scope.
6. Run the focused test, then relevant regressions.
7. Perform required simulator, runtime, migration, accessibility, visual, or
   device verification.
8. Generate an exact diff package and obtain an independent read-only spec and
   quality review.
9. Fix all Critical/Important findings and repeat the review.
10. Update the durable ledger with exact evidence.
11. Commit only that focused task.
12. Continue to the next task.

Do not skip:

- T16 old-store migration fixtures and upgrade evidence;
- runtime loading/composition of equipment and environment taxonomies before
  eligibility/ranking consumers depend on them;
- T18 validation both at model-output acceptance and after editor confirmation;
- accessibility, VoiceOver, Dynamic Type, reduced-motion, and contrast checks;
- HR-06 blue-halo gallery/device review;
- rollback and release-safe unavailable-state checks;
- final cleanup, documentation, quality gates, and handoff.

The actual settings file is:

```text
Sources/Features/Settings/SettingsView.swift
```

Do not follow a stale plan path if repository reality differs. Record the
deviation.

If a task requires a human product/content decision not already recorded in
the executive decisions, human-review queue, or durable ledger, stop at that
exact decision. Present concrete options and impacts. Do not manufacture
approval.

## Final acceptance and handoff

At genuine completion, report:

- the T13-T32 task/commit ledger;
- exact Xcode and Python commands/results;
- focused and full-suite test counts;
- Debug and Release build evidence;
- simulator/device/manual checks actually performed;
- resource/bundle inspection evidence;
- migration and rollback evidence;
- unresolved warnings, limitations, or human decisions;
- final `git status` and branch divergence from origin;
- explicit confirmation that `main`, remote history, source assets, source
  ZIP, and every forbidden `archive` path remained untouched;
- explicit confirmation that nothing was pushed or merged.

Do not say the project is complete while a required gate is unexecuted.

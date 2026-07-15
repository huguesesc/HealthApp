# Terra progress and deviations

This log is the execution evidence for `05_TERRA_IMPLEMENTATION_PLAN.md`.
All status claims below are tied to a command, inspected file, or an explicit
environment limitation. `archive` is forbidden and has not been inspected or
modified.

## T01 - Branch and repository preflight

**Status:** complete (2026-07-14, Windows host)

### Provenance

| Check | Result |
|---|---|
| Repository root | `C:/Users/Hugues Esclapez/Desktop/Nell.app/HealthApp` |
| Remote | `origin` = `https://github.com/huguesesc/HealthApp.git` (fetch/push) |
| Active branch | `feature/nell-exercise-catalog-location-context` |
| HEAD | `61d3076ddddbc6a0f5765eec118363ddb6aaadd0` |
| Tracking branch | `origin/feature/nell-exercise-catalog-location-context` |
| Target branch ref | present at `61d3076ddddbc6a0f5765eec118363ddb6aaadd0` |
| Parent ref | `origin/feature/nell-full-brand-and-ui-system` present at `c98f6dbecc8f0852feb424a4ebc6747f437988c4` |
| Parent divergence | `origin/feature/nell-full-brand-and-ui-system...HEAD` = `0` behind, `8` ahead |
| Worktree state | normal checkout (`git_dir` and `git_common_dir` are both `.git`); work proceeds on the user-specified feature branch |

### Commands and results

```text
git -c safe.directory=<repo> -C <repo> status --short --branch
## feature/nell-exercise-catalog-location-context...origin/feature/nell-exercise-catalog-location-context
?? docs/nell-redesign/exercise-catalog/

git -c safe.directory=<repo> -C <repo> rev-list --left-right --count origin/feature/nell-full-brand-and-ui-system...HEAD
0    8

python --version
Python 3.12.10

Get-Command xcodebuild
NOT FOUND on this Windows host
```

Both target and parent refs were already available, so no fetch was required.

### Dirty-work inventory and scope decision

The only untracked paths are the ten Sol documents in
`docs/nell-redesign/exercise-catalog/` supplied for this implementation. There
are no tracked source, asset, project, or test modifications. The new progress
log is an explicitly required T01 artifact inside that supplied package.

### Required reading and verified repository facts

- Read `00` through `09` in numeric order before writing implementation code.
- `00_SOL_EXECUTIVE_DECISIONS.md` and
  `02_EXERCISE_CATALOG_ARCHITECTURE.md` are treated as normative.
- `project.yml` names an older `HealthAssistant` XcodeGen target and iOS 17.0;
  it does not describe the current `Health Assistantv2.xcodeproj`. It remains
  untouched.
- `Health Assistantv2.xcodeproj/project.pbxproj` uses filesystem-synchronized
  root groups for the app and test directories. Resource membership will still
  be proved from an Xcode build before it is claimed.
- The earlier `EXERCISE_CATALOG_LOCATION_CONTEXT_PLAN.md` is superseded by this
  package wherever it conflicts.

### Baseline limitations and queued human decisions

- iOS build/test/simulator validation: **NOT RUN**. `xcodebuild` is unavailable
  on this Windows host. This is an environment limitation, not a passing gate.
- Asset source and ZIP remain read-only. No path named `archive` was inspected
  or touched.
- HR-01, HR-03, HR-04, HR-05, and HR-06 remain pending human content/product
  decisions. They do not block schema/tooling work, but they block unapproved
  media import and any release claim for unreviewed exercise content.

### Deviations

None. The existing plan already contains the required staged approval boundary.

## T02 - Schema foundation

**Status:** complete; implementation review approved (2026-07-14). Swift
compilation and test execution are **NOT RUN** on this Windows host.

### Commits

```text
4a30949 feat: add exercise catalogue domain schema
55409cd fix: align exercise catalogue schema shape
b8babd4 fix: model environment requirements structurally
82138ab fix: allow required-only environment requirements
```

The commit sequence is one logical domain unit plus review-driven fixes. It is
not yet a release-quality test result and may be squashed during the later
logical-commit cleanup only if that does not rewrite shared history.

### Delivered scope

- Added Foundation-only immutable `Codable`, `Hashable`, `Sendable` domain
  values in `Health Assistantv2/ExerciseCatalog/Domain/`.
- Added a typed catalogue-error foundation and focused decoding/round-trip
  tests in `Health Assistantv2Tests/ExerciseCatalogDomainTests.swift`.
- Required fields are structurally nonoptional. Aliases, guidance, and
  environment requirements remain optional. Empty instructions decode without
  a crashing initializer so validation can report them later.
- The JSON shape now models equipment clauses as `{id, quantity}`, flat
  required AND clauses, nested alternative OR groups, and lifecycle as an
  object with `status` and optional `replacementExerciseID`.
- `environmentRequirements` is an optional keyed object with required values
  and optional prohibited values. This accepts both published forms:
  `{"required":["machine_access"]}` and a record that also provides
  `"prohibited": []`.
- No SwiftUI, SwiftData, persistence, assets, loader/repository, media,
  filtering, static catalogue, global singleton, strict ID validation, or
  equipment-satisfaction logic was introduced. T03-T05 retain those concerns.

### Validation and review evidence

The focused command was deliberately attempted before and after each
implementation/fix cycle:

```text
xcodebuild test -project "Health Assistantv2.xcodeproj" -scheme "Health Assistantv2" -only-testing:Health_Assistantv2Tests/ExerciseCatalogDomainTests
```

Every attempt returned PowerShell `CommandNotFoundException` because
`xcodebuild` is absent. No test pass is claimed. `git diff --check` was clean
for each committed scoped diff. Independent task review initially found and
the implementation corrected the equipment-clause, lifecycle-object, and
environment-object wire contracts. The final task review approved the final
base-to-HEAD diff (four owned files only).

### Decision / documentation ambiguity

`02_EXERCISE_CATALOG_ARCHITECTURE.md` contains both a machine example with
only `environmentRequirements.required` and a later example with required and
prohibited arrays. The safe compatibility decision is to decode both shapes
structurally. T05/T09 must make any stricter authoring/eligibility policy
explicit rather than letting the loader fail on the documented machine record.

### Durable task ledger

`T02: complete (commits 61d3076..82138ab, task review approved; Swift tests NOT RUN because xcodebuild is unavailable).`

## T03 - Stable identifiers and lifecycle references

**Status:** complete; task review accepted with one recorded minor style item
(2026-07-14). Swift compilation/tests remain **NOT RUN** on this Windows host.

### Commit

```text
2ea210c feat: add stable exercise identifiers
```

### Delivered scope

- `ExerciseID` now accepts only the exact stable lowercase dot-ID pattern and
  rejects malformed direct construction deterministically through a failable
  initializer. Malformed JSON IDs throw `DecodingError.dataCorrupted`.
- Valid IDs preserve exact Codable encoding and equality.
- `ExerciseDefinition.legacyIDs` is optional `[ExerciseID]`; human aliases
  remain separate display-name strings.
- Lifecycle status is the closed `active` / `deprecated` / `disabled` set;
  replacement remains an optional typed ID. Catalogue-wide target, cycle, and
  deprecation rules deliberately remain for T07/T09.
- Domain fixtures now use valid dot IDs and cover valid/invalid IDs, JSON
  rejection, legacy IDs, lifecycle values, a mechanics/material third segment,
  and the policy that side is session metadata by default.
- No persistence, UI, resource, loader, media, taxonomy data, filter, or
  project-file change was made.

### Validation and review evidence

The focused command was attempted before and after the T03 production change:

```text
xcodebuild test -project "Health Assistantv2.xcodeproj" -scheme "Health Assistantv2" -only-testing:Health_Assistantv2Tests/ExerciseCatalogDomainTests
```

Both attempts ended with PowerShell `CommandNotFoundException` because this
host has no `xcodebuild`; no RED/GREEN or pass result is claimed. Scoped
`git diff --check` was clean. Independent review found no functional or scope
defect: exact regex, failable construction, decoding rejection, legacy-ID
separation, and finite lifecycle values all match T03.

### Recorded minor item

`ExerciseCatalogDomainTests.swift` has one 108-character test name for the
variant-versus-side rule, above the repository `.swiftformat` 100-character
limit. It is a non-blocking style item; shorten it before the final formatter
or test-quality gate rather than silently ignoring it.

### Durable task ledger

`T03: complete (commit 82138ab..2ea210c, review accepted; one minor SwiftFormat line-length item; Swift tests NOT RUN because xcodebuild is unavailable).`

## T04 preflight decision - missing named equipment list

`02_EXERCISE_CATALOG_ARCHITECTURE.md` requires an initial equipment list
"exactly" matching a list in the Sol prompt, but neither the architecture,
master prompt, plan, asset map, acceptance checklist, nor open-question queue
contains that list. This is a plan-input omission, not evidence that the
chosen JSON architecture is unsafe.

**Safe implementation basis:** T04 will seed data-driven records from the
existing `EquipmentCategory` values and the generic/specific equipment
explicitly needed by the approved architecture examples and asset mappings
(including distinct leg press, lat-pulldown, row, leg-extension, leg-curl and
seated-calf equipment). Existing Swift enum values remain legacy evidence,
not the new source of truth. T04 will avoid adding clinical semantics and will
keep every machine-specific record distinct from generic machine access.

**Impact:** the initial JSON list is evidence-derived rather than a falsely
claimed verbatim Sol list. T07/T09 must validate every actual catalogue
reference against it; a future product owner may add data records without a
Swift-enum change. This decision does not authorize an asset import or resolve
the pending content approvals.

## T04 - Data-driven equipment taxonomy and satisfaction

**Status:** complete; final static task review approved (2026-07-14). Swift
compilation/tests remain **NOT RUN** on this Windows host.

### Commits

```text
130809b feat: add data-driven equipment taxonomy
c1a060f fix: harden equipment taxonomy validation
2ceb69f fix: validate equipment requirement groups
```

### Delivered scope

- Added schema-versioned `Resources/Authoring/equipment.json` with exactly 28
  evidence-derived records and no generic machine record.
- Added Foundation-only data records for equipment, directional fulfillments,
  lifecycle, taxonomy, inventory, and deterministic validation errors. The
  new category wrapper is `ExerciseEquipmentCategory`, avoiding a collision
  with the existing SwiftData `EquipmentCategory` legacy enum.
- Required equipment is an AND group; a complete alternate AND group can
  satisfy it. Matching is exact or one direct positive, explicit fulfillment
  relation only. It never uses parent/category/environment inference or a
  transitive equivalence chain.
- A pair of dumbbells explicitly yields two generic dumbbells. Duplicate,
  malformed, or nonpositive fulfillments yield no availability.
- Every primary/alternative group is structurally checked before matching:
  nonempty, positive quantities, and `none` as a sole clause only.
  `alternatives: []` is valid; an individual empty alternative is an error.
  A malformed unused alternative invalidates the requirement rather than
  allowing a valid primary group to bypass corrupt data.
- Validation deterministically reports duplicate equipment IDs, unknown
  parents, parent cycles, unknown/duplicate fulfillment targets, nonpositive
  multipliers/requirements, empty groups, and illegal `none` combinations.
- No AdaptiveCoach persistence, UI, project, asset, source-pack, loader,
  media, or environment-capability change was made.

### Validation and review evidence

The focused command was attempted before and after each implementation/fix
cycle:

```text
xcodebuild test -project "Health Assistantv2.xcodeproj" -scheme "Health Assistantv2" -only-testing:Health_Assistantv2Tests/ExerciseCatalogEquipmentTests
```

Every attempt stopped before compilation with PowerShell
`CommandNotFoundException` because `xcodebuild` is unavailable. No test pass
is claimed. `swiftc` was also absent. Scoped `git diff --check` was clean.
Independent review first found a legacy type-name collision, nonpositive and
duplicate-data bypasses, then empty/malformed group bypasses; the two
review-fix commits addressed all of them. Final review approved the static
implementation and confirmed exact count/ID assertions for the initial JSON.

### Durable task ledger

`T04: complete (commits 2ea210c..2ceb69f, final static review approved; Swift tests NOT RUN because xcodebuild is unavailable).`

## T05 - Location/environment taxonomy and deterministic eligibility

**Status:** complete; static task review approved (2026-07-14). Swift
compilation/tests remain **NOT RUN** on this Windows host.

### Commit

```text
480eacf feat: add exercise environment capabilities
```

### Delivered scope

- Added schema-versioned `environments.json` with six neutral preset IDs:
  home, gym, hotel, outdoors, sport venue, and custom; and six capabilities:
  floor space, wall access, anchor point, generic machine access, jumping
  allowed, and quiet space.
- Added a Foundation-only context that starts with one preset’s declared
  defaults and overlays every explicit Boolean override. Unknown presets and
  missing capabilities resolve false; labels/ranking tags do not decide hard
  eligibility.
- Added hard-constraint eligibility evaluation. Exact T04 equipment matching
  remains authoritative, so `machine_access` cannot prove a leg-press machine.
  Required capabilities must be true; prohibited capabilities must be false.
- Added deterministic typed result reasons: invalid equipment data is terminal,
  then unmet equipment, then missing required capabilities in lexical order,
  then present prohibited capabilities in lexical order.
- No ranking, generation, SwiftData, UI, persistence, asset, or project-file
  work was introduced.

### Validation and review evidence

The focused command was attempted before and after implementation:

```text
xcodebuild test -project "Health Assistantv2.xcodeproj" -scheme "Health Assistantv2" -only-testing:Health_Assistantv2Tests/ExerciseCatalogEligibilityTests
```

Both attempts ended before compilation with PowerShell
`CommandNotFoundException`; no test pass is claimed. `environments.json`
parsed successfully and scoped `git diff --check` was clean. Independent
review confirmed override precedence, fail-closed unknown capability behavior,
specific-machine separation, deterministic reason order, and absence of
scope leakage.

### Recorded authoring-validation gap

`ExerciseEnvironmentTaxonomy` currently has no integrity validator for
duplicate environment IDs or unregistered/typoed capability references. This
does not make runtime eligibility permissive — unknown values fail closed —
but it is an authoring-data risk. T09 must report these errors deterministically
rather than accepting malformed environment JSON silently.

### Durable task ledger

`T05: complete (commit 2ceb69f..480eacf, static review approved; Swift tests NOT RUN because xcodebuild is unavailable; environment authoring integrity validation deferred to T09).`

## T06 - Exercise media schema and structural validation

**Status:** complete; final static task review approved (2026-07-14). Swift
compilation/tests remain **NOT RUN** on this Windows host.

### Commits

```text
81cc7a4 feat: add exercise media schema
59113cd fix: validate exercise media endpoint order
```

### Delivered scope

- Added Foundation-only, `Codable`, `Hashable`, `Sendable` media data types
  under `ExerciseCatalog/Domain`, with all approved roles, stable logical keys,
  optional sequence/variant/appearance, and required accessibility text.
- Added optional `ExerciseDefinition.media`, preserving no-media catalogue
  records and updating the sole memberwise-initializer fixture accordingly.
- Added deterministic structural validation for blank/whitespace/duplicate
  keys, blank accessibility text, paired start/end roles, required endpoint
  sequences, start-before-end ordering, positive contiguous sequences, and
  independent alternate-variant sequence namespaces.
- A `composite` remains an explicit complete semantic artifact; it never
  substitutes for a missing `start` or `end` role. No asset path, filename,
  importer, crop, renderer, `WorkoutMotion`, SwiftUI, or project-file work was
  introduced.
- Added direct Swift-value and JSON decode / encode-decode round-trip fixtures
  for no media, composite, ordered pairs, multi-frame content, alternate
  variants, duplicate/whitespace keys, blank accessibility text, missing
  endpoint sequence, and reversed endpoint ordering.

### Validation and review evidence

```text
xcodebuild test -project "Health Assistantv2.xcodeproj" -scheme "Health Assistantv2" -only-testing:Health_Assistantv2Tests/ExerciseCatalogMediaTests
```

The command ended with PowerShell `CommandNotFoundException` because
`xcodebuild` is absent; `swiftc` is also absent. No Swift test pass is claimed.
Scoped `git diff --check` was clean and new or changed T06 lines satisfy the
100-column limit. Independent review rejected the initial commit because it
accepted sequence-less or reversed start/end pairs and did not prove the JSON
wire contract. Commit `59113cd` corrected both defects; the follow-up static
review accepted the final T06 diff.

### Durable task ledger

`T06: complete (commits 480eacf..59113cd, final static review approved; Swift tests NOT RUN because xcodebuild is unavailable).`

## T07 preflight - catalogue content approval gate

**Status:** blocked pending designated human content/product approval
(2026-07-14). No `catalog.json` has been written.

### Evidence

- `05_TERRA_IMPLEMENTATION_PLAN.md` T07 requires the initial approved
  catalogue, written instructions, equipment/capabilities, legacy aliases,
  composite keys, and a content-owner review before the manifest is done.
- `09_OPEN_QUESTIONS_AND_HUMAN_REVIEW_QUEUE.md` HR-03 explicitly places all
  new written instructions, safety material, and visual mappings behind an
  accountable content/product reviewer. It permits schema/tooling progress but
  blocks release of unreviewed exercise guidance.
- HR-01 keeps the floor-press mismatch quarantined; HR-04 blocks canonical-ID
  freeze for three terminology choices; HR-05 restricts the step-up image to
  supplementary composite/setup use until approved.
- The master prompt requires a stop when an asset requires semantic
  interpretation or product/clinical approval. Inventing neutral instructions
  or silently promoting proposed mappings would violate that boundary.

### Required human decision

Name the approving content/product owner and authorize a concrete initial set
of exercise entries (or explicitly authorize neutral draft instructions for
non-release development). Also decide HR-01, HR-04, and HR-05 for any affected
entries to include in that set. The default safe disposition remains: exclude
the floor-press mismatch, keep step-up supplementary only, and retain proposed
neutral terminology only as unshipped aliases.

### Impact

T07 cannot meet its definition of done, so sequential dependencies T08 onward
must not begin. The completed T02-T06 domain/taxonomy work remains isolated and
reversible; source assets and every forbidden `archive` path remain untouched.

## T07 - Initial approved catalogue manifest

**Status:** complete; static task review accepted (2026-07-14). Swift fixture
execution remains **NOT RUN** on this Windows host.

### Approval record

The user identified themself as the product/content approver and authorized an
initial, exactly 20-entry draft catalogue with two neutral mechanical
instruction sentences per entry. This is authorization for implementation,
not final release approval. No clinical, rehabilitation, contraindication, or
safety claim was added.

- HR-01: approved the source `bench_dumbbell_flat_chest_press..png` only for
  a future `dumbbell.floor_press` composite mapping; it is not a bench press.
  The entry is not one of the 20, so no 21st record or asset import was made.
- HR-04: approved the proposed canonical IDs/aliases for
  `barbell.lying_triceps_extension`, `machine.lying_leg_curl`, and
  `machine.seated_row`; none is in the initial 20, so all are deferred.
- HR-05: approved `bench_step_up..png` as supplementary composite media only;
  it is not start/end media and `bodyweight.step_up` is deferred.

### Commit and delivered scope

```text
6753175 feat: add initial exercise catalogue manifest
```

- Added `Health Assistantv2/ExerciseCatalog/Resources/Authoring/catalog.json`
  with `catalogSchemaVersion: 1` and exactly the approved 20 active entries.
- Every entry has one valid logical composite media key, a nonblank
  accessibility description, two nonblank draft instructions, and only
  references to checked-in equipment/capability vocabulary.
- The manifest applies explicit `floor_space` to mountain climber,
  `jumping_allowed` to jumping jack, and `machine_access` plus specific
  equipment to leg press, lat pulldown, and cable triceps pushdown.
- Added a fixture decoder that reads the checked-in manifest and verifies its
  exact ID set, content/media contract, equipment/capability references, and
  legacy-alias boundary.

### Legacy-motion deviation

T07 requested eight legacy motion aliases, but only `goblet_squat`,
`bent_over_row`, and `overhead_press` are exact semantic matches in the
approved set. They map only to their matching dumbbell records. Mapping
`split_squat`, `plank_row`, `hip_hinge`, `side_stretch`, or `yoga_balance` to
a merely similar exercise would violate the exact-resolution policy, so those
five retain their existing vector fallback until T15. This is a documented
plan-input contradiction, not a license for fuzzy compatibility mapping.

### Validation and review evidence

The fixture test was added before the manifest; an available Python assertion
then failed as expected because `catalog.json` was absent. After the write,
Python JSON/taxonomy/alias assertions, `git diff --check`, and the
100-column inspection passed. The intended Swift command:

```text
xcodebuild test -project "Health Assistantv2.xcodeproj" -scheme "Health Assistantv2" -only-testing:Health_Assistantv2Tests/ExerciseCatalogManifestFixtureTests
```

did not start because both `xcodebuild` and `swiftc` raise PowerShell
`CommandNotFoundException` on this host. This is **NOT RUN**, not a test pass.
Independent static review accepted the scoped two-file commit: exact ID set,
schema, active two-sentence instructions, composite media/a11y, valid
taxonomy references, three safe aliases only, and no scope leakage.

### Durable task ledger

`T07: complete (commit 59113cd..6753175, static review accepted; Swift fixture tests NOT RUN because xcodebuild is unavailable; draft content still requires final release review).`

## T08 - Loader and repository layer

**Status:** complete following controller self-verification (2026-07-14).
Swift compilation/tests remain **NOT RUN** on this Windows host.

### Commits

```text
4b80c90 feat: add catalogue loader and repository
968ebd2 fix: make catalogue loading single-flight
3d07c45 fix: reject colliding legacy catalogue IDs
```

### Delivered scope

- Added immutable `ExerciseCatalogManifest`, an injected async data-provider
  protocol, a small injected repository protocol, an actor-backed repository,
  a bundle-oriented provider/repository, and focused loader tests.
- The loader accepts only `catalogSchemaVersion: 1`, builds immutable O(1)
  indexes, resolves in exact stable-ID, exact legacy-ID, then normalized exact
  display/alias order, and never performs substring matching.
- Missing data, corrupt JSON, unsupported versions, duplicate stable IDs,
  duplicate legacy IDs, stable/legacy ID collisions, and cross-record
  normalized alias/display-name collisions return an explicit unavailable
  state with deterministic diagnostics; release behavior is therefore empty
  and recoverable rather than a new crash path.
- The concrete repository now stores an in-flight detached load task before
  awaiting it, then caches its final result. Concurrent callers share the same
  task rather than starting competing reads/decodes. A gated concurrent test
  covers the prior reentrancy failure mode.
- Tests use injected in-memory providers and a fake repository. No app
  composition, SwiftData repository, UI, resource phase, assets, importer,
  project metadata, source pack, or `archive` path changed.

### Resource-integration deferral

`catalog.json` exists in the filesystem but is not yet proven to be in the app
bundle. The bundled provider safely reports resource absence, while T13 retains
sole ownership of Xcode resource membership and runtime bundle proof. No
premature `Bundle.main` assumption was wired into the application.

### Validation and limitations

The focused command was attempted after each loader-fix boundary:

```text
xcodebuild test -project "Health Assistantv2.xcodeproj" -scheme "Health Assistantv2" -only-testing:Health_Assistantv2Tests/ExerciseCatalogLoadingTests
```

Every attempt ended with PowerShell `CommandNotFoundException` because
`xcodebuild` is absent; `swiftc` is absent too. The test suite has therefore
not compiled or run. No RED/GREEN or test-pass result is claimed for the Swift
fixtures. The controller performed the available proportional checks: scoped
`git diff --check`, staged-diff checks before each commit, 100-column scans,
source/API inspection of actor and `Sendable` boundaries, and JSON parsing of
the authored 20-entry catalogue. All available static checks passed.

### Durable task ledger

`T08: complete (commits 6753175..3d07c45, controller self-verified; Swift loader tests NOT RUN because xcodebuild and swiftc are unavailable; T13 still owns bundle membership proof).`

## T09 - Cross-platform catalogue validation

**Status:** complete (2026-07-14), committed as `a0a4100`.

### Delivered scope

- Added a deterministic, read-only Python validator and report command for the
  checked-in authoring taxonomy, catalogue, optional generated-media index, and
  optional asset-intake directory.
- Encoded objective checks for schema/version, stable IDs and normalized alias
  collisions, legacy-ID collisions, equipment/environment references and
  cycles, lifecycle replacements, media keys/roles/sequences, and importer
  intake naming, duplicate content, PNG integrity, dimensions, alpha, and
  case-collision conditions.
- Added a pinned Pillow requirement and nine fixture tests, including the
  regression for equipment-parent cycles and duplicate fulfillments.

### Exact verification evidence

```text
python -m unittest scripts.tests.test_exercise_catalog
.........
Ran 9 tests in 0.071s
OK

python scripts/exercise_catalog.py validate --strict
exercise-catalog validation: exercises=20 intake_assets=0 errors=0 warnings=0

python scripts/exercise_catalog.py report --strict
exercise-catalog validation: exercises=20 intake_assets=0 errors=0 warnings=0

python -m py_compile scripts/exercise_catalog.py scripts/tests/test_exercise_catalog.py
exit 0

100-column scan: line-length: OK
git diff --check: exit 0
git diff --cached --check: exit 0
```

### Limitations and scope boundary

`intake_assets=0` means only that no intake files were present to exercise the
asset-validation branch. It is **not** evidence that source images pass
validation. T10--T12 must run validation against a real, non-empty intake
before an importer claim can be made. No source assets, app code, Xcode project
metadata, or `archive` path changed. Swift/Xcode tests are not relevant to this
Python-only task and remain unavailable on this Windows host.

### Durable task ledger

`T09: complete (commit a0a4100; 9 Python tests, strict validate/report, py_compile, 100-column, and diff checks passed; non-empty asset intake validation remains pending T10--T12).`

## T07 corrective follow-up - Movement semantics and environment requirements

**Status:** complete (2026-07-14), committed as `4565bf9` in a separate,
focused correction.

### Decisions applied

- `band.lateral_squat` now explicitly instructs a lateral step into a squat,
  followed by bringing the trailing foot in and repeating in the other
  direction. It no longer describes a stationary squat.
- `floor_space` is required for dead bug, push-up, glute bridge, bird dog,
  side plank, and mountain climber because each uses the floor as its exercise
  surface. Mountain climber already had the requirement; the other five were
  added here.
- Jumping jack retains the already-approved `jumping_allowed` capability.
  Forward lunge and band lateral squat remain without an additional capability:
  they are standing movements and the current approved taxonomy has no
  separate generic standing-space capability. No clinical, rehabilitation,
  contraindication, or safety claim was added.

### Objective fixture and verification

- Added an exact manifest fixture for the six `floor_space` records, jumping
  jack's `jumping_allowed` record, the two standing records without an added
  capability, and the corrected lateral-step wording.
- Before the manifest correction, an equivalent local JSON assertion failed on
  the five absent floor requirements and the stationary-squat wording. After
  the correction, that assertion passed.
- `python scripts/exercise_catalog.py validate --strict` passed with
  `exercises=20 intake_assets=0 errors=0 warnings=0`.
- `python -m unittest scripts.tests.test_exercise_catalog` passed all 9 tests;
  the focused Swift fixture command remains **NOT RUN** because `xcodebuild`
  returns PowerShell `CommandNotFoundException` on this Windows host.
- Static review, 100-column scan, `git diff --check`, and staged
  `git diff --check` passed. The first mechanical patch incorrectly targeted
  bodyweight squat and omitted bird dog; local diff review caught it before
  validation or commit, and the final commit contains only the intended six
  floor-supported movements.

### Durable task ledger

`T07 corrective follow-up: complete (commit 4565bf9; semantic capability decisions documented; Swift fixture test NOT RUN because xcodebuild is unavailable).`

## T08 corrective follow-up - Future schema gate

**Status:** complete (2026-07-14), committed as `3dffb06` in a separate,
focused correction.

- The loader now decodes only `catalogSchemaVersion` first. Any version other
  than v1 returns `unsupportedSchemaVersion` before `ExerciseDefinition` or
  any other v1-specific structure is decoded.
- Added a version-2 payload whose exercise object deliberately lacks the v1
  fields. It asserts `unsupportedSchemaVersion(2)`, preventing the previous
  `decodingFailed` misclassification for a structurally incompatible future
  manifest.
- The actor's prior single-flight implementation, O(1) indexes, and exact
  stable-ID -> legacy-ID -> normalized-reference resolution order are unchanged.
- Local static review, 100-column scan, `git diff --check`, and staged
  `git diff --check` passed. The focused Swift test command was attempted but
  is **NOT RUN**: `xcodebuild` returns PowerShell `CommandNotFoundException`.

### Durable task ledger

`T08 corrective follow-up: complete (commit 3dffb06; future-version ordering fixture added; Swift loader tests NOT RUN because xcodebuild and swiftc are unavailable).`

## T10 - Asset approval boundary

**Status:** complete (2026-07-14), committed as `74caf05`.

### Mapping and approval boundary

- Added `Health Assistantv2/ExerciseCatalog/Resources/Authoring/media-import-map.json`.
  It contains one explicit, checksum-pinned decision for all 50 source PNGs in
  `workout_avatar`: 20 `approved_for_import`, 5
  `approved_pending_catalogue_entry`, and 25 `unreviewed` rows.
- The 20 importable rows map exactly to the approved initial manifest media
  keys. The validator now requires every active manifest media key to have one
  such approved row, and every source PNG in the declared directory to have a
  decision.
- HR-01 is mapped only as `dumbbell.floor_press` with
  `dumbbell.floor_press__composite.png`; it is not a bench press and remains
  pending an approved catalogue entry. The bench-visible alternate is a
  separate unreviewed flat-bench-press candidate.
- HR-04's three canonical terminology decisions and HR-05's supplementary
  step-up media are preserved as approved-pending rows. They cannot be imported
  until matching, approved catalogue entries exist. The step-up row is
  explicitly composite supplementary media, not a fabricated start/end pair.
- Updated the untracked Sol mapping/review documents with the approvals and
  with the distinction between approved, pending, and unreviewed items. They
  remain preserved outside the focused Git commit.

### Source and ZIP provenance

Read-only parity verification compared the external source pack with
`HealthAssistant_image_Pack.zip` and returned:

```text
source_files=65 zip_files=65 missing_from_zip=0 missing_from_source=0
size_mismatches=0 checksum_mismatches=0
```

The ZIP SHA-256 recorded in the mapping is
`a997ee69fc7f51ac283bd9caa5cf2076c469083182f5e1d45ad5d87e87a9297a`.
No source asset, ZIP, generated resource, existing asset catalog, or `archive`
path was modified.

### Validation and review evidence

- The new validator fixture was added first and failed before implementation on
  the missing `source_pack` parameter. A coverage assertion then failed before
  the source-directory coverage rule existed. Both passed after implementation.
- Initial real-map validation caught three handwritten checksum transcription
  mistakes (one wrong character and two spaces); all were corrected against the
  read-only source hashes before commit.
- `python -m unittest scripts.tests.test_exercise_catalog` passed 10 tests.
- `python scripts/exercise_catalog.py validate --strict --source-pack
  '..\\HealthAssistant_image_Pack'` and the corresponding `report` command both
  passed with `exercises=20 intake_assets=0 errors=0 warnings=0`.
- `python -m py_compile`, the 100-column scan, `git diff --check`, and staged
  `git diff --check` all passed. `intake_assets=0` still means asset-intake
  validation has not yet been exercised; the source-pack checksum validation is
  separate from the later non-empty importer intake gate.

### Durable task ledger

`T10: complete (commit 74caf05; 50 explicit source decisions, 20 importable current-manifest rows, 5 approved-pending rows, 25 unreviewed rows; source/ZIP parity and source checksums verified; no source or generated asset write).`

## T11 - Asset normalization dry run

**Status:** complete (2026-07-14), committed as `4562c9c`.

- Added `python scripts/exercise_catalog.py import --dry-run --source-pack
  '..\\HealthAssistant_image_Pack'`. It revalidates the full import map and
  source checksums before producing deterministic canonical destinations.
- The dry run enumerates all 50 source decisions. It marks only the 20
  `approved_for_import` rows as `COPY`; all five pending and 25 unreviewed rows
  are explicitly `REJECT`ed and therefore cannot become accidental copies.
- The command does not create `Assets.xcassets/ExerciseMedia`, copy, rename,
  crop, or otherwise modify source images. A post-command check confirmed that
  the generated namespace remained absent.
- A new fixture proves that only approved rows are planned, unreviewed rows are
  shown as rejected, and no asset namespace is created. It was added first and
  failed while `import` was not yet a recognized command; it passed after the
  dry-run implementation.

### Validation and review evidence

```text
python -m unittest scripts.tests.test_exercise_catalog
Ran 11 tests ... OK

python scripts/exercise_catalog.py import --dry-run --source-pack '..\\HealthAssistant_image_Pack'
approved=20 pending=5 unreviewed=25 quarantined=0
50 deterministic COPY/REJECT rows listed; exit 0

T11 dry-run write check: ExerciseMedia absent
python -m py_compile ... : exit 0
100-column scan: OK
git diff --check: exit 0
git diff --cached --check: exit 0
```

### Durable task ledger

`T11: complete (commit 4562c9c; deterministic all-row dry run, 11 Python tests, and no generated/source asset writes).`

## T12 - Generated media import

**Status:** complete (2026-07-14), committed as `9a4f025`.

### Generated scope

- Added the explicit `import --apply` path. It validates all map rows and
  source checksums first, stages generated imagesets and `media-index.json`,
  verifies staged contents/checksums, then replaces only
  `Assets.xcassets/ExerciseMedia` and
  `ExerciseCatalog/Resources/Generated/media-index.json` with rollback backups
  for an interrupted replacement.
- Imported exactly the 20 approved composite PNGs. The generated namespace has
  20 imagesets and the index has 20 matching entries; all 5 pending and 25
  unreviewed rows are reported as rejected and were not copied.
- The importer normalizes only destination names. Its source references retain
  original duplicate periods and other source spelling in provenance fields;
  it does not crop composites or manufacture frames.
- An initial real apply exposed a Windows permission defect: staging via
  `tempfile.mkdtemp` carried a restrictive ACL into `ExerciseMedia`, which made
  `git status` unable to read the directory. The importer was corrected to use
  a unique normal worktree staging directory, then reapplied. `git status`
  subsequently read the generated files normally. No asset or source content
  was lost or altered by this correction.

### Verification evidence and limitations

```text
python -m unittest scripts.tests.test_exercise_catalog
Ran 12 tests ... OK

python scripts/exercise_catalog.py import --apply --source-pack '..\\HealthAssistant_image_Pack'
approved=20 rejected_pending=5 rejected_unreviewed=25 rejected_quarantined=0

python scripts/exercise_catalog.py validate --strict --source-pack '..\\HealthAssistant_image_Pack'
exercise-catalog validation: exercises=20 intake_assets=0 errors=0 warnings=0

generated imagesets=20 media_index_entries=20 exact_match=yes
T12 idempotence: generated file hashes unchanged after second apply
post_import_source_zip_checksum_mismatches=0
python -m py_compile ... : exit 0
100-column scan: OK
git diff --check: exit 0
git diff --cached --check: exit 0
```

- Representative bodyweight (push-up), machine (leg press), and dumbbell
  (goblet squat) composites were inspected after generation. Their expected
  two-pose composites and transparent backgrounds are present. Thin blue edge
  halos are visible against the dark inspection background, consistent with
  HR-06; this is not resolved by the importer and remains for later debug-
  gallery/simulator/device review. No claim of device visual acceptance is made.
- `intake_assets=0` remains an unexercised intake-directory path. The real
  source-pack checksum and generated-namespace validations passed, but they do
  not substitute for T13 bundle proof or HR-06 device QA.

### Durable task ledger

`T12: complete (commit 9a4f025; 20 approved generated composites/index entries; transactional/idempotent importer tested; source/ZIP parity preserved; bundle/device validation remains pending).`

## T13 - Xcode resource integration

**Status:** blocked on the required macOS/Xcode-only verification (2026-07-14).

### Static audit completed

- `Health Assistantv2.xcodeproj/project.pbxproj` declares
  `Health Assistantv2` as a `PBXFileSystemSynchronizedRootGroup`, and the app
  target lists that group in `fileSystemSynchronizedGroups`. Its explicit
  `PBXResourcesBuildPhase` list is empty, as is expected with this project
  organization.
- This is not bundle evidence. It cannot prove the final locations or target
  membership of `catalog.json`, generated `media-index.json`, or the 20 asset
  catalog imagesets. In particular, the currently bundled provider looks up
  `catalog.json` by name, so a macOS build/runtime test must establish the
  actual resource path before any project-file or loader-path change is safe.
- No `project.pbxproj`, stale `project.yml`, loader, asset, or `archive` change
  was made on the basis of this static inference.

### Exact blocker

```text
xcodebuild -list -project 'Health Assistantv2.xcodeproj'
xcodebuild : Le terme «xcodebuild» n'est pas reconnu ...
CategoryInfo          : ObjectNotFound: (xcodebuild:String) [], CommandNotFoundException
FullyQualifiedErrorId : CommandNotFoundException
```

`swiftc` is also absent on this host. Therefore targeted bundle tests, Debug
and Release simulator builds, and runtime resolution are **NOT RUN**. T14 and
later media/UI tasks depend on T13's bundle proof, so continuing them here
would be speculation rather than implementation evidence.

### Required next environment

Use macOS with Xcode and run the T13 bundle-resolution test plus Debug and
Release simulator builds against the actual `Health Assistantv2.xcodeproj`.
If the filesystem-synchronized group does not include the required JSON, make
the minimum evidence-backed resource or loader-path change there, then rerun
the import validator and bundle test.

### Durable task ledger

`T13: blocked (static project audit complete; Xcode bundle/build verification NOT RUN because xcodebuild and swiftc are unavailable on Windows; no speculative project edit made).`

## Post-T12 independent validator/importer audit and correction

**Status:** complete and independently accepted (2026-07-14). This closes
Python validation/import defects found during the requested read-only review;
it does not change or advance the blocked T13 Xcode status.

### Corrective commits

```text
552a355 fix: harden exercise media validation and repair
9ad6436 fix: close catalogue validation fail-open paths
a4e9d08 fix: complete fail-closed media validation
7aa69b5 fix: close intake checksum validation path
```

Only `scripts/exercise_catalog.py` and
`scripts/tests/test_exercise_catalog.py` changed in these four commits.
Catalogue JSON, approval data, generated resources, source assets, ZIPs,
Swift/Xcode files, and every forbidden `archive` path were left unchanged.

### Closed findings

- Core JSON and taxonomy structure now fails closed for wrong top-level types,
  Boolean schema versions, missing Swift-required fields, null/wrong arrays,
  and malformed UTF-8 instead of silently accepting or throwing.
- Import-map validation rejects unsafe/control-character paths, invalid or
  non-PNG bytes, missing approval/source metadata, role/key disagreement, and
  source checksum/read failures with deterministic diagnostics.
- Strict CLI validation now requires `--source-pack` when importable approved
  rows exist. The old plain `validate --strict` command intentionally exits 1
  with `E_IMPORT_SOURCE_PACK_REQUIRED`; this prevents a false green when the
  external source pack was not checked.
- Generated validation is closed across missing/partial namespace or index,
  duplicate/orphan coverage, role/key/provenance mismatch, malformed
  `Contents.json`, invalid PNGs, Pillow bomb errors/warnings, and checksum read
  or content mismatch.
- Import preflight deliberately ignores stale generated output so apply can
  repair it, then validates the installed result. Type-aware backup cleanup
  and rollback cover reversed file/directory outputs without leftover hidden
  backups.
- Intake PNG validation no longer hashes unreadable/invalid files; checksum
  read failures produce `E_ASSET_CHECKSUM_READ` instead of a traceback.

### Fresh final evidence

```text
python -B -m unittest scripts.tests.test_exercise_catalog
Ran 43 tests ... OK

python -B scripts/exercise_catalog.py validate --strict --source-pack '..\HealthAssistant_image_Pack'
exercise-catalog validation: exercises=20 intake_assets=0 errors=0 warnings=0

python -B scripts/exercise_catalog.py report --strict --source-pack '..\HealthAssistant_image_Pack'
exercise-catalog validation: exercises=20 intake_assets=0 errors=0 warnings=0

python -B scripts/exercise_catalog.py validate --strict
ERROR E_IMPORT_SOURCE_PACK_REQUIRED ...
exit 1 (intentional; no traceback)
```

`py_compile`, the 100-column scan, and `git diff --check` passed. Two
consecutive real applies covered 44 catalogue/map/index/generated paths,
including 20 PNGs; both preserved exact bytes and left zero hidden backups.
The final independent targeted review reported no Critical, Important, or
Minor findings: spec compliance PASS and code quality APPROVED.

Native symlink creation could not be exercised on this Windows host
(`WinError 1314`). The cleanup code is explicitly symlink-aware, while the
reversed file/directory and rollback cases are behaviorally tested.

### Corrective ledger

`T09/T12 post-audit corrections: complete (commits 552a355..7aa69b5; 43 Python tests; strict real validation/report green with required source pack; double apply byte-stable; independent final review approved).`

## T13 blocker refresh after requested finish attempt

The available Xcode integration endpoint was also tried. It discovered
`Health Assistantv2.xcodeproj`, but simulator discovery failed with
`spawn xcrun ENOENT`; it is backed by this same Windows host and supplies no
macOS/Xcode execution.

The exact runtime bundle contract remains:

- ship `catalog.json`, `equipment.json`, `environments.json`, and
  generated `media-index.json`;
- compile and ship `Assets.xcassets/ExerciseMedia`;
- exclude authoring-only `media-import-map.json`.

The branch currently has neither a committed shared Xcode scheme nor a true
`Bundle.main` resolution test. Merely adding a workflow would not prove T13;
the workflow must run focused bundle tests plus clean Debug and Release iOS
simulator builds and inspect the built `.app` for those resources and
`Assets.car`.

No GitHub Actions workflow was added or pushed because external publication
was not authorized. Therefore T13 remains genuinely blocked, and sequential
T14-T32 work remains unstarted rather than falsely marked complete.

### Refreshed T13 ledger

`T13: blocked (local Xcode endpoint also fails xcrun ENOENT; shared scheme, bundle tests, Debug/Release build proof, and built-product inspection still required on macOS/Xcode or explicitly authorized macOS CI; no push/project speculation).`

## T13 macOS continuation - Xcode resource integration

**Status:** complete on 2026-07-15; independent review accepted. The complete
unit target has one pre-existing wording-test failure recorded below, separate
from T13.

### Environment and destination

```text
repository: /Users/huguesesclapez/Desktop/HealthApp
branch: feature/nell-exercise-catalog-location-context
starting HEAD: 7aa69b5e2c67012ff2477d5d2166c1ab87a35b75
Xcode: 16.2 (16C5032a)
macOS: 14.7.8 (23H730)
simulator: iPhone 16 Pro, iOS 18.3.1
UDID: F29D78A3-33A7-4EAA-857F-A79813A4CAAE
```

`xcode-select -p`, `xcodebuild -version`, `sw_vers`, `xcodebuild
-showsdks`, `xcrun simctl list devices available`, project `-list`, and scheme
`-showdestinations` were run. The initial sandboxed inventory could not access
CoreSimulator or Xcode user-library logs; the same commands were rerun with
normal local macOS service access. The project exposes the app, unit-test, and
UI-test targets and one `Health Assistantv2` scheme.

### Scheme and command deviation

The transferred project had no shared `.xcscheme`, and its autogenerated
scheme had no runnable Test action. Xcode 16.2 generated and shared
`Health Assistantv2.xcodeproj/xcshareddata/xcschemes/Health Assistantv2.xcscheme`.
An accidentally added external test-plan reference pointed to
`../../Documents/HealthApp/Health Assistantv2Tests` and failed with exit 70;
it was removed while retaining Xcode's generated unit/UI `TestableReference`
entries.

The inherited command's `-only-testing:Health_Assistantv2Tests/...` spelling
also exited 70. Xcode's actual target name contains spaces, so successful runs
use `-only-testing:"Health Assistantv2Tests/..."`. The underscored name is the
Swift module name, not an Xcode test-target identifier.

### Test-first RED and evidence-driven compatibility fixes

`Health Assistantv2Tests/ExerciseCatalogBundleTests.swift` was added before
resource-membership changes and uses the hosted application's `Bundle.main`.
The first compilable run exposed two inherited Xcode-only blockers before the
bundle assertions:

- Both tracked `NellCoachMark` PNGs matched their Git blobs but had invalid PNG
  chunk data. `file` recognized their headers, while `sips`, Pillow, and
  `actool` could not decode them; `actool` failed with `Distill failed for
  unknown reasons`. The canonical ZIP's valid `sublogo-dark.png` and
  `sublogo-light.png` entries were copied read-only into the already documented
  light/dark Coach Mark mappings. Runtime hashes are
  `fb6cecc1d04f4fa376618cc881e7112d66f0684e8af3ff2b2d743a45de3790a5`
  (dark appearance) and
  `91025c24408d0e2c25593373fce74ac65578976fff09f0c09ecfa95f13a470fa`
  (light appearance). Both now decode as 1254x1254 RGBA PNGs.
- Swift 5.10 inferred two unqualified `Array(...)` calls inside the constrained
  media-array extension as `[ExerciseMediaDefinition]`. The fix makes the
  intended integer collection explicit without changing validation behavior.

After those dependency fixes, the RED run executed the three bundle tests.
Only `applicationBundleExcludesTheAuthoringOnlyMediaImportMap()` failed:
all four runtime JSON files decoded, the production repository loaded 20
exercises, the media index contained 20 entries, and UIKit resolved
`bodyweight.squat__composite`. The failing app bundle still contained the
authoring-only map. Xcode diagnostic capture then hit `No space left on
device`; that environmental error is recorded separately and the incomplete
RED result bundle was not retained.

The minimal implementation adds one
`PBXFileSystemSynchronizedBuildFileExceptionSet` excluding only
`ExerciseCatalog/Resources/Authoring/media-import-map.json` from the app
target. No loader path or stale `project.yml` change was made.

### Focused Debug and Release proof

Both commands ran sequentially with parallel testing disabled and exit 0:

```text
xcodebuild test -quiet -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" -configuration Debug \
  -destination "platform=iOS Simulator,id=F29D78A3-33A7-4EAA-857F-A79813A4CAAE" \
  -only-testing:"Health Assistantv2Tests/ExerciseCatalogBundleTests" \
  -parallel-testing-enabled NO -derivedDataPath /tmp/nell-t13-debug-test \
  -resultBundlePath /tmp/nell-t13-debug.xcresult CODE_SIGNING_ALLOWED=NO

xcodebuild test -quiet -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" -configuration Release \
  -destination "platform=iOS Simulator,id=F29D78A3-33A7-4EAA-857F-A79813A4CAAE" \
  -only-testing:"Health Assistantv2Tests/ExerciseCatalogBundleTests" \
  -parallel-testing-enabled NO -derivedDataPath /tmp/nell-t13-release-test \
  -resultBundlePath /tmp/nell-t13-release.xcresult CODE_SIGNING_ALLOWED=NO \
  ENABLE_TESTABILITY=YES
```

`xcresulttool` reports 3 passed, 0 failed, 0 skipped and zero build warnings or
errors for each configuration. The `.xcresult` paths above are retained. Their
DerivedData directories were removed only after result extraction to recover
space on a disk that fell below 1 GiB free.

### Clean builds and built-product inspection

Both required clean generic iOS Simulator builds ran sequentially and exited
0:

```text
xcodebuild clean build -quiet -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath /tmp/nell-t13-debug-build CODE_SIGNING_ALLOWED=NO

xcodebuild clean build -quiet -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" -configuration Release \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath /tmp/nell-t13-release-build CODE_SIGNING_ALLOWED=NO
```

Inspected app paths before disk-pressure cleanup:

```text
/tmp/nell-t13-debug-build/Build/Products/Debug-iphonesimulator/Health Assistantv2.app
/tmp/nell-t13-release-build/Build/Products/Release-iphonesimulator/Health Assistantv2.app
```

Each app contained exactly one `catalog.json`, `equipment.json`,
`environments.json`, `media-index.json`, and `Assets.car`, and zero
`media-import-map.json` files recursively. Debug and Release hashes matched:

```text
catalog.json       65216614871f448f6b9afcf16a04cd875bc1dc2d71268ee98ddb2108306fa445
equipment.json     20e8229c9ff83c9ee5bf14ec0c68b5bb00aa5651f21e83e74e68675d0f99b276
environments.json  01e34ead1bb424f650181f17420503f84421ece20e742e29358d97742dfb5029
media-index.json   9a1089bd083496799cfd0dd58b463dda0cc9a9f467f4edca5b3c0ea01b9d9dda
Assets.car         e19a027727e28400c853f45b2af064b82808988382db334c26b3ebb299fe1ff0
```

The focused hosted test is the runtime proof that the representative compiled
image resolves through `UIImage(named:in:compatibleWith:)`; file presence
alone was not used as that claim.

### Relevant regressions and Python checks

The complete unit-test target ran through:

```text
xcodebuild test -quiet -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" -configuration Debug \
  -destination "platform=iOS Simulator,id=F29D78A3-33A7-4EAA-857F-A79813A4CAAE" \
  -only-testing:"Health Assistantv2Tests" -parallel-testing-enabled NO \
  -derivedDataPath /tmp/nell-t13-full-test \
  -resultBundlePath /tmp/nell-t13-full.xcresult CODE_SIGNING_ALLOWED=NO
```

Result: exit 65, 96 passed, 1 failed, 0 skipped. The build itself had zero
warnings/errors. The sole failure is pre-existing and outside the T13 diff:
`AdaptiveCoachAssistantToolTests.systemPromptKeepsUserReportsSeparateFromDiagnosis()`
expects the literal substring `never infer a condition`; production currently
says `Do not infer a medical condition`. `/tmp/nell-t13-full.xcresult` is
retained. T13 did not change `ChatEngine` or weaken the test.

The originally claimed extracted sibling pack was absent while the ZIP was
present. With explicit local permission, the matching ZIP was extracted
without overwrite beside the repository; it contains 65 PNGs and remains an
external read-only input. Afterward:

```text
python3 -B -m unittest scripts.tests.test_exercise_catalog
Ran 43 tests ... OK

python3 -B scripts/exercise_catalog.py validate --strict \
  --source-pack ../HealthAssistant_image_Pack
exercise-catalog validation: exercises=20 intake_assets=0 errors=0 warnings=0

python3 -B scripts/exercise_catalog.py report --strict \
  --source-pack ../HealthAssistant_image_Pack
exercise-catalog validation: exercises=20 intake_assets=0 errors=0 warnings=0

git diff --check
exit 0; existing CRLF-to-LF checkout warnings only
```

### Limitations and safety record

- Disk pressure reached approximately 50 MiB free during the RED diagnostic
  capture. Completed T13 DerivedData/build directories were inspected or had
  their result data extracted before removal; final focused Debug/Release and
  full-suite `.xcresult` bundles remain under `/tmp`.
- No physical-device, visual halo, accessibility, migration, or downstream UI
  claim belongs to T13; those remain later task gates.
- `main`, remote state, history, source ZIP bytes, stale `project.yml`, and all
  paths named `archive` were untouched. Nothing was pushed or merged.

### Independent read-only review

A fresh read-only reviewer inspected the exact T13 contract, scheme, bundle
tests, project exclusion, compatibility fixes, retained result bundles, and
evidence ledger. Final verdicts:

```text
specification compliance: PASS
code quality: APPROVED
Critical findings: none
Important findings: none
Minor findings: none
```

### Durable task ledger

`T13: complete (Xcode 16.2; focused Debug and Release 3/3 passed; clean Debug
and Release builds passed; built-product runtime resources/index/Assets.car
verified; authoring map absent; 43 Python tests and strict validation/report
passed; complete unit target 96/97 with one separate pre-existing wording-test
failure; independent spec PASS and quality APPROVED).`

## 2026-07-15 — T14 macOS continuation: media loading and reusable view

### Test-first boundary and implementation

The first focused Xcode 16.2 compile contained only the new
`ExerciseMediaResolverTests.swift` contract. It failed at the intended RED
boundary because `BundledExerciseMediaResolver`, `ExerciseMediaResolverError`,
`DictionaryExerciseMediaResolver`, `ExerciseMediaPresentationModel`, and
`ExerciseMediaPage` did not yet exist.

The implementation then added:

- `ExerciseMediaResolving` with exact key lookup only;
- a fail-closed bundled index resolver with typed missing-resource,
  unsupported-schema, and duplicate-key errors;
- an injectable dictionary resolver for deterministic tests and fallback
  composition;
- deterministic compact and hero ordering, appearance filtering, and missing
  index/key/compiled-image fallback policy;
- `ExerciseMediaView`, which renders transparent PNGs aspect-fit, pages multiple
  instructional items without forced animation, supplies per-item accessibility
  descriptions/page values, and falls back to the existing vector motion figure
  plus explicit text;
- local previews for production media and fallback states.

No workout-plan, Active Workout, history, or existing motion consumer was
modified. Xcode rewrote unrelated PBX group ordering and quoted the existing
T13 exclusion while it was open; both changes were manually restored, leaving
the project file identical to committed T13.

### Focused tests and Release build

Final combined command:

```text
xcodebuild test -quiet -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" -configuration Debug \
  -destination "platform=iOS Simulator,id=F29D78A3-33A7-4EAA-857F-A79813A4CAAE" \
  -only-testing:"Health Assistantv2Tests/ExerciseMediaResolverTests" \
  -only-testing:"Health Assistantv2Tests/ExerciseCatalogMediaTests" \
  -parallel-testing-enabled NO \
  -resultBundlePath /tmp/nell-t14-focused-4.xcresult \
  CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO
```

Result on iPhone 16 Pro, iOS 18.3.1: 19 passed, 0 failed, 0 skipped;
zero build/analyzer warnings and zero errors. The hosted checks load the real
`media-index.json`, resolve the real compiled squat image through UIKit, and
render real-image and fallback views through `ImageRenderer` in light/dark,
compact/hero, 160/320-point widths, and AX5 Dynamic Type configurations. Pure
policy tests cover exact lookup, malformed/unsupported/duplicate index data,
role/frame order, appearance selection, nil media, absent index keys, and
missing compiled images.

Release verification:

```text
xcodebuild build -quiet -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" -configuration Release \
  -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO
```

The full Release app target completed with exit 0 and no console diagnostics.
`git diff --check` and `plutil -lint` for the project file passed.

### Environment deviation and remaining manual coverage

The selected Simulator initially stalled and then reported `Data Migration
Failed` while disk space was critically low. With explicit local approval, only
the failed iPhone 16 Pro Simulator was erased and rebooted. A stale 178 MB
HealthApp DerivedData cache, a regenerable 73 MB index, and the already-recorded
50 MB T13 full-suite result were removed; no repository source or user document
was deleted. The repaired Simulator completed migration and all final tests.

SwiftUI's `accessibilityReduceMotion` value is read-only in this SDK, so an
attempted test-only environment override was removed after a compiler error.
The component introduces no animation API and no information depends on motion.
Interactive VoiceOver navigation, physical-device rendering, and human visual
halo review remain explicitly `NOT RUN` here and stay assigned to T26–T28; no
claim for those gates is made by T14.

### Durable task ledger

`T14: complete (exact injectable resolver; compact/hero ordered paging;
aspect-fit compiled PNG rendering; accessible vector/text fallback; production
bundle and UIKit resolution proved; 19/19 focused media tests passed with zero
warnings/errors; Release build exit 0; interactive VoiceOver/device/halo gates
deferred without a pass claim to T26–T28).`

## 2026-07-15 — T15 macOS continuation: exact legacy resolution

### Test-first boundary and compatibility implementation

The focused `LegacyExerciseResolverTests` contract was compiled before the
implementation and failed at the intended RED boundary because
`LegacyExerciseResolution` and `LegacyExerciseMatch` did not exist.

T15 then added:

- exact stable-ID, exact legacy-ID, and normalized exact display-name/alias
  resolution with explicit `resolved`, `ambiguous`, and `unresolved` outcomes;
- deterministic sorted ambiguity candidates and injectable diagnostic events;
- default OSLog diagnostics that hash user-provided references while leaving
  non-sensitive stable candidate IDs visible;
- an isolated canonical-equipment adapter for the limited legacy vector
  renderer (`none`, paired dumbbells, or one goblet-held weight);
- an exact canonical-ID-to-vector-pose bridge for the seven approved catalogue
  entries that have a semantically compatible legacy pose;
- complete removal of the registry's prior substring/contains matching branch.

Stored workout, active-session, and history records were untouched. Unknown,
custom, ambiguous, and canonical exercises without an approved legacy pose use
the generic vector fallback and preserve their supplied display text.

One intermediate focused run had 13/14 passing because the test fixture expected
`bodyweight.squat` before lexicographically earlier
`bodyweight.forward_lunge`; the expectation was corrected to the specified
deterministic ordering. An earlier compile also exposed a missing explicit
`return` after introducing a POSIX locale local variable; that compile-only
issue was corrected before any green claim.

### Validation

Final focused command:

```text
xcodebuild test -quiet -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" -configuration Debug \
  -destination "platform=iOS Simulator,id=F29D78A3-33A7-4EAA-857F-A79813A4CAAE" \
  -only-testing:"Health Assistantv2Tests/LegacyExerciseResolverTests" \
  -only-testing:"Health Assistantv2Tests/NellNavigationAndWorkoutMotionTests" \
  -parallel-testing-enabled NO \
  -resultBundlePath /tmp/nell-t15-focused-5.xcresult \
  CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO
```

Result on iPhone 16 Pro, iOS 18.3.1: 15 passed, 0 failed, 0 skipped;
zero build/analyzer warnings and zero errors. Coverage includes fixture stable
and legacy IDs, normalized exact aliases/names, explicit ambiguity, diagnostic
events, unknown/custom values, substring rejection, canonical equipment/vector
bridging, all eight existing vector display names, and exact stable-ID resolution
for all 20 production catalogue entries. The production reference `squat`
remains unresolved rather than partially matching either squat entry.

Final Release verification used the generic iOS Simulator destination with
`CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO` and completed with
exit 0 and no console diagnostics. `git diff --check` passed, and the Xcode
project file remained identical to committed T13.

### Durable task ledger

`T15: complete (exact stable/legacy/normalized-name resolution; explicit
ambiguous/unresolved outcomes with privacy-preserving diagnostics; old substring
matching removed; canonical-to-legacy-vector bridge and equipment adapter added;
15/15 focused tests passed with zero warnings/errors; Release build exit 0;
stored records untouched).`

## 2026-07-15 — T16 macOS continuation: persistence migration and compatibility

### Additive schema and compatibility behavior

T16 added optional `exerciseIDSnapshot` strings to `WorkoutStep`,
`ActiveWorkoutStep`, and `ExerciseSet`, plus typed `ExerciseID` accessors. New
data propagates the stable ID from plan to active workout to completed history;
display names, instructions, equipment wording, and completed-history names
remain independent snapshots. Compact workout-plan snapshots also carry the
optional stable ID without changing their existing text fields.

`HealthAppSchemaV2` explicitly records schema version 2.0.0. The prior app used
SwiftData's implicit 1.0.0 schema, and this version adds optional scalar columns
only, so the production container uses SwiftData's inferred lightweight
migration. A throwing store-URL initializer exists only to let migration tests
copy and open immutable fixtures without exercising the fatal production path.

The explicit `LegacyExerciseIDBackfill` repository operation fills only nil ID
fields that the T15 resolver maps to exactly one stable catalogue definition.
It never overwrites an existing ID or historical text; ambiguous, unknown, and
custom references remain nil and are counted in the report. Backfill is not an
automatic launch mutation.

### Real prior-schema fixture and automated validation

The tracked `Health Assistantv2Tests/Fixtures/T16PriorSchema` store/WAL/SHM set
was generated once by unchanged T15 model code on Xcode 16.2 / iOS Simulator
18.3.1, exported, and checkpointed once during integrity verification before its
final hashes were recorded. The final fixture is treated as immutable. SQLite
integrity is `ok`.
Hashes:

```text
HealthApp.store      543c4d5957263e11f5b09e0879d39c329f94f2eb7c35b222c3815ea5fe0ac5b5
HealthApp.store-wal  e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
HealthApp.store-shm  fd4c9fda9cd3f9ae7c962b0ddf37232294d55580e1aa165aa06129b8549389eb
```

After correcting a test-helper URL round-trip that treated `%20` as literal
text, the final focused Xcode 16.2 command used the designated iPhone 16 Pro
(`F29D78A3-33A7-4EAA-857F-A79813A4CAAE`) on iOS 18.3.1 and completed with exit
0:

```text
xcodebuild test-without-building -quiet \
  -project "Health Assistantv2.xcodeproj" -scheme "Health Assistantv2" \
  -destination "platform=iOS Simulator,id=F29D78A3-33A7-4EAA-857F-A79813A4CAAE" \
  -derivedDataPath /tmp/nell-t16-fixture-build \
  -parallel-testing-enabled NO \
  -only-testing:"Health Assistantv2Tests/ExercisePersistenceMigrationTests"
```

All three migration tests passed. They prove old-store open and reopen; profile,
location, equipment, plan, active-session, and history readability; nil decoding
for new fields; exact-only backfill with four unresolved custom/retired values;
resume from one completed set and 73 accumulated seconds; exactly one history
conversion after duplicate finish calls; unchanged renamed/retired/custom
snapshots; and new plan-to-active-to-history ID propagation.

Four surrounding suites then passed together with exit 0 on the same simulator:
`ActiveWorkoutModeTests`, `StructuredWorkoutPlanTests`,
`NellActiveWorkoutBoundaryTests`, and `LegacyExerciseResolverTests`. The final
generic iOS Simulator Release build completed with exit 0 and no console
diagnostics.

### Installed debug upgrade and rollback evidence

A disposable detached worktree at committed T15 (`8095331`) built and installed
the prior debug app. Its app container was seeded with a copied fixture and the
T15 app launched successfully. The current T16 debug app was then installed over
that app without uninstalling it. The simulator preserved the seeded data while
assigning a new container UUID; T16 launched, stayed running, and rendered the
setup screen.

After a clean stop, the installed migrated store retained 1 profile, 1 location,
1 equipment item, 1 plan/2 steps, 1 active session/2 steps, and 1 history/2 sets.
All three new columns existed as nullable `VARCHAR`; plan/active/history wording,
the active step's `completedSets == 1`, and nil legacy IDs were unchanged;
`PRAGMA integrity_check` returned `ok`. The simulator's pre-test HealthApp store,
WAL, and SHM were restored afterward and each restored file matched its backup
SHA-256 byte-for-byte. The disposable worktree, builds, backup, and screenshot
were removed.

The tracked `T16_PERSISTENCE_MIGRATION_RUNBOOK.md` records backup-as-a-set,
integrity verification, failed-working-copy retention, and the rule that an old
binary may open a migrated store only after exact compatibility is proven;
otherwise rollback restores the untouched version-1 backup with the prior app.

### Review-tool deviation and safety record

The required independent read-only reviewer attempted the configured review
workflow, but its mandatory CodeRabbit CLI was absent. The prescribed remote
installer was rejected because installing an unreviewed third-party script had
not been explicitly authorized, and that workflow forbids substituting a manual
review after CLI failure. No independent verdict is claimed. A local scoped spec
audit found no blocking mismatch, and automated plus installed-upgrade evidence
covers the T16 acceptance boundary.

Xcode's unrelated PBX group reordering and quoting of the existing T13 resource
exception were restored, leaving no project-file diff. User handoff/planning
artifacts stayed untracked and unstaged. No remote state changed, nothing was
pushed or merged, and no path named `archive` was accessed.

### Durable task ledger

`T16: complete with review-tool deviation (optional stable IDs propagate
plan→active→history; real T15 store fixture migrates/reopens/resumes/completes
once with snapshots preserved; 3/3 focused migration tests and four surrounding
suites passed on Xcode 16.2 / iPhone 16 Pro / iOS 18.3.1; Release build exit 0;
installed T15→T16 debug upgrade and SQLite integrity passed; rollback documented;
independent CodeRabbit verdict unavailable because its CLI was not installed).`

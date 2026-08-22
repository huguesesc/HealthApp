# Exercise catalogue implementation status

Updated: 2026-08-23, end of Windows phase. Branch
`feature/nell-exercise-catalog-location-context`. This is the single source
for "where is the catalogue now"; historical reasoning stays in the Sol docs.

## Catalogue statistics

| Metric | Value |
|---|---|
| Catalogue schema version | 1 |
| Exercises | 20 (all `active`) |
| Illustrated exercises | 20 |
| Known-but-unillustrated | 0 |
| Visible aliases | 11 across 6 entries (incl. RDL family added 2026-08-23) |
| Hidden legacy names (`legacyNames`) | mechanism shipped; 0 production seeds until real historical strings exist |
| Free-form policy | permanent first-class state: unresolved/ambiguous/inactive proposal references are preserved verbatim as explicit custom steps with audited demotions; bare ambiguous terms (`squat`, `row`, `lunge`, `plank`) intentionally never aliased |

## Asset statistics

| Metric | Value |
|---|---|
| Source pack PNGs | 65 total (50 workout_avatar + 7 brand_id + 8 nell_poses) |
| Import-map dispositions | 50/50 workout rows decided: 20 approved+imported, 5 approved-pending-catalogue-entry, 25 unreviewed (HR-08) |
| Generated imagesets / media-index entries | 20 / 20 (exact match) |
| Imported into app | 20 composites (1254×1254 RGBA, transparency verified) |
| Mechanical filename defects inventoried | 10 double-period sources, 1 `dumbell` misspelling — normalized only in generated copies, originals untouched |
| Exact duplicate sources | none (SHA-256 unique) |
| Unresolved images | 30 (all with explicit human-review status) |
| Inventory command | `python scripts/exercise_catalog.py inventory [--json] --source-pack <pack>` → rows=65 flagged=31 |

## Taxonomies

| System | Size |
|---|---|
| Equipment records | 28 (generic + machine-specific; `pair_of_dumbbells`→2×dumbbell fulfillment; no generic machine record) |
| Environment presets | 6: home, gym, hotel, outdoors, sport_venue, custom |
| Capabilities | 6: floor_space, wall_access, anchor_point, machine_access, jumping_allowed, quiet_space |

## Tooling

```text
python scripts/exercise_catalog.py validate --strict --source-pack ../HealthAssistant_image_Pack
python scripts/exercise_catalog.py report    --strict --source-pack ../HealthAssistant_image_Pack
python scripts/exercise_catalog.py import    --dry-run --source-pack ../HealthAssistant_image_Pack
python scripts/exercise_catalog.py import    --apply   --source-pack ../HealthAssistant_image_Pack
python scripts/exercise_catalog.py inventory --json    --source-pack ../HealthAssistant_image_Pack
python -m unittest scripts.tests.test_exercise_catalog
```

## Tests

### Run and passed on Windows (this phase's final evidence)

- `python -m unittest scripts.tests.test_exercise_catalog` → **47/47 OK**
  (was 43 at session start; +AppleDouble tolerance, +legacyNames/collision,
  +dumbell-canonical rule, +inventory disposition test)
- Strict validate/report with real source pack → `errors=0 warnings=0`
- `py_compile` clean; `git diff --check` clean on every commit

### Written this phase, awaiting Xcode

- `LegacyNameCompatibilityTests` (5 tests, pins audit decisions vs real manifest)
- `EquipmentLocationCompatibilityTests` (11 tests, compatibility matrix vs real taxonomies)
- `GeneratedWorkoutValidatorTests` rewritten for demotion semantics + messy-input cases
- Full list and run order: see `MAC_XCODE_VERIFICATION_QUEUE.md`

## Resolution architecture (shipped)

1. Stable ID → 2. legacy ID → 3. bounded-normalized display name/alias/hidden
legacy name (one shared `ExerciseReferenceNormalization`; ambiguity is an
error, never a guess; no substring matching). Proposal validation demotes
unresolvable or inactive movements to explicit custom steps instead of
dropping them; ineligible/unauthorized references remain hard failures
because they are safety gates.

## Documentation set

- `LEGACY_EXERCISE_NAME_AUDIT.md` — every harvested movement string resolved
- `../CODEBASE_INTEGRITY_AUDIT.md` — integrity findings + classifications
- `../BRAND_ASSET_REFERENCE_AUDIT.md` — screen→asset matrix
- `../MAC_XCODE_VERIFICATION_QUEUE.md` — ordered Mac session script
- `09_OPEN_QUESTIONS_AND_HUMAN_REVIEW_QUEUE.md` — HR-01…HR-10
- Sol docs 00–09 unchanged except where this file supersedes counts

## Windows validations passed (summary)

Preflight provenance re-verified (branch/HEAD `a128fd2`/remote sync/clean
tree before edits); source-pack restored to exactly 65 real PNGs after
removing 68 AppleDouble transfer artifacts; validator green after every data
or tooling change; idempotence previously proven by T12 double-apply was not
re-run because no new import was authorized.

## Outstanding for macOS/Xcode

Everything in `MAC_XCODE_VERIFICATION_QUEUE.md`: compile gate for
Windows-written Swift, full unit target, active-workout media screen checks,
demotion end-to-end chat flow, Release build, plus the standing HR-06 halo
review, T26 accessibility matrix, and T28 device QA.

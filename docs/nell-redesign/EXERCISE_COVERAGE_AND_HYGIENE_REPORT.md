# Exercise coverage and repository hygiene report

Generated 2026-08-23 by mechanical scan (`scripts/exercise_catalog.py
inventory`, git queries). Companion to `IMPLEMENTATION_STATUS.md`.

## Catalogue coverage of exercises already used by Nell

| Coverage tier | Items |
|---|---|
| Full structured metadata + real illustration | all **20** catalogue entries; every entry resolves its composite through the generated media index (0 gaps) |
| Real illustration only via catalogue bridge | the 7 vector-bridge mappings in `WorkoutMotionRegistry.legacyMovementIDByCanonicalID`: bodyweight.squat, dumbbell.goblet_squat, dumbbell.bent_over_row, dumbbell.overhead_press, bodyweight.forward_lunge, barbell.deadlift, barbell.romanian_deadlift |
| Generated vector fallback only | 5 registry templates have no catalogue entry and render generic vectors: `split_squat`, `plank_row`, `hip_hinge`, `side_stretch`, `yoga_balance`. Their proposed pack illustrations sit in the unreviewed/pending import rows; entries require HR-03 content approval first |
| No recognized definition (free-form forever) | custom/retired strings documented per string in `LEGACY_EXERCISE_NAME_AUDIT.md`; they resolve to nothing deliberately and are preserved verbatim |

Conclusion: every movement string that occurs anywhere in the repository has
an explicit tier; none depends on filename or display-text coincidence.

## Alias quality analysis

- Collisions: validator proves zero normalized collisions across
  display names + aliases + hidden legacy names (strict run green).
- Broad/short claims flagged for review: normalized `rdl`
  (barbell.romanian_deadlift) and `pushup` (display name of
  bodyweight.push_up). Both currently unique; both would surface a validation
  error the day another entry claims them — that is the intended tripwire.
- Deliberately unclaimed broad terms: squat, row, lunge, plank, balance,
  military press, dumbbell press (rationale per string in the audit doc).

## Asset-size analysis

| Scope | Size |
|---|---|
| Generated `ExerciseMedia` namespace (20 composites) | 10,775,447 bytes (10.3 MiB) |
| Entire `Assets.xcassets` tree on disk | 12,323,248 bytes (11.8 MiB) |
| Source pack workout_avatar (50 PNGs, reference only) | ~34.6 MB |

Largest imported composites (candidates for lossless re-export if app size
ever matters; originals untouched either way):

| Asset | Bytes |
|---|---|
| machine.lat_pulldown__composite.png | 904,166 |
| cable.triceps_pushdown__composite.png | 833,329 |
| dumbbell.biceps_curl__composite.png | 666,281 |
| band.lateral_squat__composite.png | 639,965 |
| machine.leg_press__composite.png | 629,733 |
| bodyweight.calf_raise__composite.png | 610,487 |

Note: actool re-encodes into `Assets.car` at build time, so shipped size will
differ from source bytes; measure the built `.app` before optimizing.

## Repository hygiene

| Check | Result |
|---|---|
| Tracked files over 1 MB | none |
| Secrets/API keys in tracked files | none (only `sk-ant-…` placeholder text in a SecureField prompt and one design doc) |
| `__pycache__/` directories | present on disk, correctly gitignored, never committed |
| AppleDouble (`._*`) metadata | removed repo-wide this phase; `.gitignore` now prevents accidental commits; validator warns instead of failing on future transfers |
| ZIP copies inside Git | none (`*.zip` ignored); both pack copies live outside the repository |
| Redundant sibling pack copy | `../HealthAssistant_image_Pack 2.zip` is byte-redundant with `../HealthAssistant_image_Pack.zip` per T10 parity evidence — classified LEAVE (outside repo, user's file) |

## Documentation consistency fixes applied this commit

- `docs/setup-mac.md`: stale XcodeGen claim corrected.
- `CODEX_SOL_MAC_CONTINUATION_PROMPT.md`: reading-list filenames aligned with
  actual Sol document names.
- `docs/nell-redesign/exercise-catalog/04_GENERAL_PURPOSE_EXERCISE_AND_IMAGE_WORKFLOW.md`:
  inventory command added to the contributor workflow.

Historical SHAs and counts inside `TERRA_PROGRESS_AND_DEVIATIONS.md` are
evidence records, intentionally not rewritten.

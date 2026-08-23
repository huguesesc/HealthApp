# Legacy exercise name audit

Audit date: 2026-08-23 (Windows phase). Scope: every distinct movement string
discovered in the repository outside `catalog.json` — the vector motion
registry (`WorkoutMotionRegistry.swift`), test fixtures, preview data,
migration stores, and proposal samples. The goal is that historical workouts
and plans keep working through deliberate resolution instead of filename or
display-text coincidence.

Resolution categories: **exact catalogue ID**, **catalogue alias** (exact after
bounded normalization), **intentional free-form** (correctly unresolved;
preserved verbatim by the proposal validator), **ambiguous / deferred**
(deliberately not mapped; see review queue).

## Vector motion registry names and aliases (8 definitions)

| String | Source | Resolution |
|---|---|---|
| Goblet Squat | registry display | catalogue alias `goblet_squat` maps to `dumbbell.goblet_squat` |
| goblet squat | registry alias | same as above |
| squat (bare) | registry alias | intentional free-form: bare "squat" must not silently choose between bodyweight/goblet/barbell variants (T15 policy kept) |
| air squat / Air squat | registry alias + resolver tests | catalogue alias `Air squat` on `bodyweight.squat` (added 2026-08-23) |
| bodyweight squat | registry alias | resolves via display-name normalization of `Bodyweight squat` |
| Bent-Over Row / bent over row / bent-over row | registry | display name of `dumbbell.bent_over_row`; normalization removes hyphens and spaces |
| dumbbell row / Dumbbell row | registry alias + tests | catalogue alias `Dumbbell row` on `dumbbell.bent_over_row` (added 2026-08-23) |
| row (bare) | registry alias | intentional free-form: too ambiguous across row/pulldown families |
| Overhead Press / overhead press | registry + WorkoutMotionView preview | catalogue alias `Overhead press` on `dumbbell.overhead_press` (added 2026-08-23) |
| Shoulder press | registry alias | catalogue alias `Shoulder press` on `dumbbell.overhead_press` (added 2026-08-23) |
| dumbbell press | registry alias | deferred: commonly means a bench press; never auto-mapped to an overhead movement (review queue) |
| military press | registry alias | deferred: strict-stance variant is a distinct coaching claim needing a content decision |
| Split Squat / split squat | registry + MovementFeedback tests | intentional free-form until an approved split-squat entry exists (pack candidate unreviewed) |
| lunge / Lunge (bare) | registry + resolver tests | free-form: could be forward/reverse/lateral; no silent narrowing |
| reverse lunge | registry alias | free-form: distinct movement needing its own entry |
| Forward lunge | registry + tests | exact display name of `bodyweight.forward_lunge` |
| Plank Row / plank row / renegade row / Renegade row | registry + tests | free-form until an approved renegade-row entry exists |
| plank (bare) | registry alias | free-form: front plank differs from catalogue `Side plank` |
| Hip Hinge / hip hinge / good morning | registry | free-form: pattern-level terms, not product-defined exercises |
| romanian deadlift / RDL / Romanian deadlift | registry aliases + mission F cases | catalogue aliases on `barbell.romanian_deadlift`: `RDL`, `Romanian deadlift`, `Barbell RDL` (added 2026-08-23); a future dumbbell RDL entry surfaces any collision at validation time |
| deadlift (bare) / Deadlift | registry alias + harvest | catalogue alias `Deadlift` on `barbell.deadlift` (added 2026-08-23; conventional deadlift is the common referent) |
| Side Stretch / side stretch / lateral stretch | registry | free-form until `mobility.standing_side_bend` content approval |
| standing side bend | registry alias | deferred: target entry blocked on HR-03 content approval |
| Yoga Balance / yoga balance / tree pose / balance | registry | free-form: no approved yoga entry; dancer-pose image unreviewed |
| single leg balance / Single-leg balance reach | registry alias + preview fixture | free-form: `ExerciseCatalogPreviewFixture` values are deliberately not production entries |

## Historical, migration, and fixture strings

| String | Source file | Resolution |
|---|---|---|
| Goblet squat renamed | ExercisePersistenceMigrationTests | historical rename snapshot test proving completed-history wording immutability |
| Coach's custom reach / Coach custom reach / Unmarked custom | migration + validator tests | custom/free-form preserved verbatim, never catalogue-endorsed |
| User custom exercise / Retired exercise name / Retired standing reach | migration fixtures + previews | retired/custom snapshots remain readable with fallback media |
| My custom arm curl finisher / Custom squat finisher / Seated custom movement | resolver/motion tests | asserted unresolved at resolver level; generic vector fallback renders them |
| Single-leg bodyweight squat variation | validator test (this session) | unilateral phrasing deliberately not mapped to bilateral entries |
| Dumbell biceps curl (misspelling) | mission F messy case | mechanism shipped: hidden `legacyNames` resolve exactly after normalization; production seeds stay empty until real historical strings exist |
| TKE / terminal knee extension | mission F case | deferred: `band.terminal_knee_extension` mapping proposed but no approved catalogue entry (HR-03); alias lands with the entry |

## Policy recorded by this audit

1. Bare pattern words (`squat`, `row`, `lunge`, `plank`, `balance`) are never
   aliased when more than one future entry could legitimately claim them.
   Free-form preservation keeps the user text visible.
2. Aliases are added only for names that are exact synonyms of exactly one
   current entry under bounded normalization.
3. Deferred strings that need a genuine human decision are tracked in
   `09_OPEN_QUESTIONS_AND_HUMAN_REVIEW_QUEUE.md`; everything else stays
   free-form permanently, which is a valid state.
4. Vector-motion aliases live in `WorkoutMotionRegistry` for illustration
   fallback only; they are not exercise identity and never bypass the
   canonical resolution chain.

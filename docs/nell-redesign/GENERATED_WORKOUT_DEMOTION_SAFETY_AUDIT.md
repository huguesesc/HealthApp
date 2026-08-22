# Generated-workout demotion safety audit

Date: 2026-08-23 · Scope: the deliberate change in
`GeneratedWorkoutValidator` from fail-closed rejection to audited free-form
preservation for identity failures. Every claim below is tied to source or a
passing test; Swift tests run on CI (GitHub macOS runner) since commit
`0156553`.

## The two categories — deliberately distinct

| Category | Example | Behavior | Rationale |
|---|---|---|---|
| **A: identity failure, movement otherwise acceptable** | unknown reference (`unresolved`), ambiguous reference, deprecated/disabled lifecycle | step is preserved verbatim as an explicit **custom exercise** with an audited `GeneratedWorkoutDemotion`; plan previews and saves | The catalogue is not a whitelist. A user asking for "Mystery machine flow" must not lose that movement; it simply receives no catalogue endorsement. Deprecated/disabled entries stay visible as user text without being re-endorsed. |
| **B: known movement that hard constraints forbid** | ineligible (equipment/capability/physical constraint), unauthorized (ID was not in the authorized candidate payload) | **hard error**; proposal rejected before preview | These are safety and anti-hallucination gates. Converting them to custom steps would silently bypass physical constraints (e.g. `jumping_allowed=false`) or let the model ignore candidate filtering entirely. |

## Safety properties verified

| Property | Evidence |
|---|---|
| Never drops a step | demotion path sets `customExercise = true`, clears only `exerciseID`; count of steps is unchanged (`demotionTouchesOnlyTheOffendingStepAndIsDeterministic`, `demotionPreservesNeighbouringStepsVerbatim`) |
| Preserves original title | title overwrite happens only on successful catalogue resolution; demoted steps keep the supplied title (tests above) |
| Preserves generated instructions and notes | neither field is touched on the demotion path (test asserts both survive verbatim) |
| No equipment claims granted | saved plans keep `equipmentNameSnapshot` only when `repo.isEquipmentNameAvailable(_:at:)` confirms it at the chosen location (`ChatEngine.saveWorkoutPlan`); demotion itself never consults or mutates inventory |
| Does not convert prohibited/ineligible movements into a bypass | category B remains errors: `ineligibleAndEligibleButUnauthorizedExercisesAreRejectedSeparately` pins `.ineligibleExercise` / `.unauthorizedCandidate` rejections |
| Does not mutate unrelated steps | isolation test walks a 3-step proposal and asserts neighbours byte-for-byte |
| Deterministic | repeated validation of one proposal yields identical proposal/demotions/errors (isolation test) |
| Remains review-before-save | nothing persists until the user taps Save (`ChatProposal.status == .saved` is still the only persistence trigger); validation runs before the card exists |
| Instruction-less unknown movements are not fabricated | `demote` returns `.missingInstruction` when there is no text to preserve honestly; inventing copy is forbidden |
| Audit trail reaches the model/user | `ChatEngine` appends a demotion list to the tool response ("Preserved unknown or retired movements as explicit custom exercises…") so regeneration cannot silently loop |

## Boundary map

```
model output
  └─> GeneratedWorkoutValidator.validate
        ├─ stable ID + active + eligible + authorized + instruction + tracking
        │    → canonicalized snapshot (repair audit if legacy/alias used)
        ├─ unresolved / ambiguous / inactive + has instruction
        │    → DEMOTE to custom (audit)            ← category A
        └─ ineligible / unauthorized / missing instruction / bad tracking
             → ERROR, whole proposal rejected      ← category B
```

## Residual risks

- A model could deliberately mark invented movements as plain titles to get
  them through as customs; acceptable because customs remain visible,
  unendorsed, and reviewable before save.
- Demoted steps keep their supplied tracking numbers without catalogue
  cross-checks; they were already user-editable on the confirmation card.
- Historical note: T18-era tests asserting full-proposal rejection for
  category A cases were rewritten in this phase; CI proves the current
  contract (151 tests green at `0156553`, expanded since).

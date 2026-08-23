# Workout location and equipment data flow

Date: 2026-08-23 · Static end-to-end trace from user-owned data to workout
execution. Every arrow below was verified in source; "lossy" marks places
where information deliberately narrows.

## Flow map

```
WorkoutLocation (@Model, AdaptiveCoachModels)
  ├─ name: String                    ── exact-match key everywhere
  ├─ categoryRaw: WorkoutLocationCategory ─┐
  │                                        ▼
  │                 LegacyWorkoutCandidateContextAdapter.environmentID
  │                   home|gym|outdoors|travel→hotel|sportVenue|custom   [LOSSY:
  │                      preset defaultCapabilities replace free text]
  └─ equipment: [EquipmentItem]
        ├─ isAvailable == false          → excluded entirely
        ├─ category .bodyweight          → dropped (nothing to satisfy)  [LOSSY]
        ├─ fixed enum categories         → canonical taxonomy IDs
        │     .dumbbells → pair_of_dumbbells (fulfills 2×dumbbell)
        │     .hamstringCurl → lying_leg_curl_machine …
        └─ category .custom              → exact displayName/alias match against
                                           ACTIVE taxonomy records; unknown names
                                           are silently dropped               [LOSSY,
                                           fail-closed by design]
                     │
                     ▼
ExerciseCandidateContext(environment, inventory)
                     │ ExerciseCandidateFilter (+ evaluator)
                     ▼
CompactExerciseCandidate payload  ── get_exercise_candidates tool result
                     │  (authorizedCandidateIDs captured into
                     │   GeneratedWorkoutValidationContext, bound to
                     │   location.name for sequencing)
                     ▼
propose_workout_plan → GeneratedWorkoutValidator
      location guard: proposal.location must equal filtered location name
      eligibility re-checked per step (category B hard gates)
                     ▼
User taps Save → ChatEngine.saveWorkoutPlan
      matchingActiveLocation(named:) → nil if deleted/deactivated/renamed
      applyWorkoutLocationSnapshot copies id/name/categoryRaw/equipmentSummary
      per step: equipmentNameSnapshot kept ONLY if isEquipmentNameAvailable
      confirms it at that location right now
                     ▼
WorkoutPlan snapshot → NellActiveWorkoutLauncherView.startActiveWorkout
      durable ActiveWorkoutSession copy (locationNameSnapshot carried)
      ⚠ NO equipment/location RE-validation at start — the plan snapshot is
        the contract (deliberate: resume/exactly-once semantics untouched)
                     ▼
Active Workout → completion → WorkoutSession history
      titles/instructions/equipment remain immutable text snapshots;
      catalogue resolution is display-only (NellExerciseDetailView)
```

## Boundary findings

| # | Boundary | Behavior | Risk class |
|---|---|---|---|
| 1 | Category → preset | `travel` maps to hotel capabilities; user's own wording ("balcony") never reaches eligibility | accepted lossiness |
| 2 | Unknown custom equipment | silently absent from inventory; exercises needing it become ineligible rather than erroring | accepted, fail-closed; UI could surface "ignored item" later (product decision) |
| 3 | Custom-name matching scope | matches taxonomy displayName **or aliases**, active lifecycle only; a retired equipment record stops fulfilling immediately | intended tripwire |
| 4 | Quantity floor | `max(item.quantity, 1)` treats zero/negative stored quantities as one | benign normalization |
| 5 | No location selected | `get_exercise_candidates` errors; `propose_workout_plan` without a prior successful filter errors (exact-location sequencing guard) | safe |
| 6 | Location renamed mid-conversation | validator's `locationName` case-insensitive comparison fails → regeneration error naming the mismatch | safe, loud |
| 7 | Location deleted before save | `matchingActiveLocation` → nil; plan still saves with empty location snapshots; steps' unavailable-equipment names are dropped | documented snapshot behavior; no corruption |
| 8 | Location changed AFTER plan creation | snapshots keep original text; starting the workout never re-filters | deliberate; preserves exactly-once execution and historical truth |
| 9 | Historical plan reopening | resolution is optional/display-only; unknown or retired movements render saved text with fallback illustration | compatibility-first policy |

## Deterministic adapter guarantees (tested)

- Pair-of-dumbbells fulfills two dumbbells; a single dumbbell does not
  (`adjustableDumbbellsPairSatisfiesTwoDumbbellRowRequirement`).
- Machine capability alone never proves a specific machine exists
  (`fullGymMachineAccessNeverProvesASpecificMachineExists`).
- Unknown equipment IDs are inert, never crash, never corrupt plans
  (`unknownEquipmentIDsAreInertAndNeverCrashOrCorruptPlans`).
- Prohibited capabilities block even when equipment passes
  (`prohibitedCapabilityBlocksEvenWhereRequiredGroupsPass`).

## Explicit non-goals

No SwiftData migration, no new persistence fields, and no UI changes were
introduced for this audit; the existing additive T16 fields already carry the
optional stable references this flow needs.

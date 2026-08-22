# Exercise catalogue architecture

## Proposed file layout

```text
Health Assistantv2/
  ExerciseCatalog/
    Domain/
      ExerciseDefinition.swift
      ExerciseTaxonomies.swift
      ExerciseMediaDefinition.swift
      ExerciseCatalogError.swift
    Loading/
      ExerciseCatalogLoader.swift
      ExerciseCatalogRepository.swift
      BundledExerciseCatalogRepository.swift
    Filtering/
      ExerciseEligibility.swift
      ExerciseCandidateFilter.swift
      GeneratedWorkoutValidator.swift
    Legacy/
      LegacyExerciseResolver.swift
      LegacyEquipmentAdapter.swift
    UI/
      ExerciseMediaView.swift
      ExerciseCatalogView.swift
      ExerciseCatalogDetailView.swift
      ExerciseCatalogDebugGallery.swift
    Resources/
      Authoring/
        catalog.json
        equipment.json
        environments.json
      Generated/
        catalog.runtime.json
        media-index.json
Health Assistantv2/Assets.xcassets/ExerciseMedia/    # generated imagesets
scripts/
  exercise_catalog.py
  exercise_catalog_requirements.txt
exercise-assets-intake/                              # gitignored except README/.gitkeep
```

Every proposed Swift file has one responsibility named by its path. Domain files depend only on Foundation. Loading depends on Domain and `Bundle`. Filtering depends on Domain/Loading, not SwiftUI. UI depends on the repository protocol. Legacy adapters isolate title/enum compatibility. Generated resources are reproducible and must never be hand-edited.

## Authoring and runtime flow

```text
catalog/equipment/environment JSON + intake PNGs
                    |
        Python validate/import/report
                    |
normalized runtime JSON + media index + generated imagesets
                    |
         bundled loader -> immutable repository
                    |
 filtering/generation/persistence adapters/UI
```

`catalog.json` remains the human-edited source. `catalog.runtime.json` may omit authoring-only metadata and include derived search terms, but CI must prove it was generated from the checked-in authoring file. If the team chooses to avoid committing derived JSON, the script can validate the authoring file directly and Xcode can bundle it as runtime JSON; there must still be only one editable truth.

## Versioning

- Top-level `catalogSchemaVersion` is a positive integer. Version 1 is accepted initially.
- Every entry also carries `schemaVersion` to support targeted transformations.
- The loader supports only an explicit closed range. A newer unsupported version returns `unsupportedSchemaVersion`, never “best effort” decoding.
- Additive optional fields do not bump the major catalogue schema. Renaming/removing fields or changing semantics does.
- Stable exercise IDs are lifecycle identifiers, not schema versions.

## Canonical schema

Required fields:

```json
{
  "id": "bodyweight.dead_bug",
  "schemaVersion": 1,
  "displayName": "Dead bug",
  "category": "strength",
  "movementPattern": "anti_extension",
  "exerciseType": "repetition",
  "equipment": { "required": [{ "id": "none", "quantity": 1 }], "alternatives": [] },
  "trackingMode": "reps",
  "instructions": ["Lie on your back with hips and knees bent.", "Extend the opposite arm and leg without arching your lower back."],
  "lifecycle": { "status": "active" }
}
```

| Field | Classification | Notes |
|---|---|---|
| `id`, `schemaVersion`, `displayName` | Required | Identity and minimum display. |
| `category`, `movementPattern`, `exerciseType` | Required | Controlled taxonomy IDs. |
| `equipment`, `trackingMode` | Required | Deterministic eligibility/execution. |
| `instructions` | Required | Non-empty written guidance; media never substitutes. |
| `lifecycle` | Required | `active`, `deprecated`, or `disabled`; replacement rules validated. |
| `shortName`, `aliases`, `localizedNames` | Optional | Alias collisions rejected; localization keys may replace inline maps later. |
| `primaryMuscles`, `secondaryMuscles` | Optional initially | Controlled IDs once populated consistently. |
| `locations`, `environmentRequirements` | Optional | Empty means no extra constraint beyond equipment. |
| `difficulty`, `mechanics`, `laterality` | Optional | Controlled values; useful for ranking/balance. |
| `defaultSets`, `defaultReps`, `defaultDuration`, `defaultRest` | Optional | Defaults, never medical prescriptions. |
| `setupInstructions`, `executionCues`, `breathingCues`, `commonMistakes`, `safetyNotes` | Optional | Arrays of written strings. |
| `contraindicationTags`, `rehabilitationTags` | Deferred | Do not ship filtering claims without clinical product ownership. |
| `media` | Optional | Empty/missing is valid. |
| `source`, `attribution` | Optional but required for third-party content | License/provenance. |
| `metadata` | Optional | Namespaced keys only; must not drive core behavior. |
| Search tokens, required capability union, media lookup keys | Derived | Generated, not hand-authored. |

### Concrete examples

Machine exercise:

```json
{"id":"machine.leg_press","schemaVersion":1,"displayName":"Leg press","category":"strength","movementPattern":"squat","exerciseType":"repetition","equipment":{"required":[{"id":"leg_press_machine","quantity":1}],"alternatives":[]},"environmentRequirements":{"required":["machine_access"]},"trackingMode":"reps","instructions":["Set the seat so the start position is controlled.","Press through the platform without locking the knees."],"media":[{"key":"machine.leg_press__composite","role":"composite","accessibilityDescription":"Two phases of a seated leg press"}],"lifecycle":{"status":"active"}}
```

Equipment substitution:

```json
{"id":"dumbbell.goblet_squat","schemaVersion":1,"displayName":"Goblet squat","category":"strength","movementPattern":"squat","exerciseType":"repetition","equipment":{"required":[{"id":"dumbbell","quantity":1}],"alternatives":[[{"id":"kettlebell","quantity":1}],[{"id":"weight_plate","quantity":1}]]},"trackingMode":"reps","instructions":["Hold one weight close to the chest.","Sit down between the hips while keeping the feet grounded."],"lifecycle":{"status":"active"}}
```

No media: omit `media` entirely. Start/end pair:

```json
"media": [
  {"key":"bodyweight.push_up__start","role":"start","sequence":1,"accessibilityDescription":"Push-up high plank start"},
  {"key":"bodyweight.push_up__end","role":"end","sequence":2,"accessibilityDescription":"Push-up lowered position"}
]
```

Multi-frame:

```json
"media": [
  {"key":"mobility.hip_90_90_switch__frame_01","role":"setup","sequence":1,"accessibilityDescription":"Seated 90-90 setup"},
  {"key":"mobility.hip_90_90_switch__frame_02","role":"mid","sequence":2,"accessibilityDescription":"Knees moving through centre"},
  {"key":"mobility.hip_90_90_switch__frame_03","role":"end","sequence":3,"accessibilityDescription":"Opposite 90-90 position"}
]
```

Deprecated exercise:

```json
{"id":"machine.seated_leg_curl","schemaVersion":1,"displayName":"Seated leg curl","category":"strength","movementPattern":"knee_flexion","exerciseType":"repetition","equipment":{"required":[{"id":"seated_leg_curl_machine","quantity":1}],"alternatives":[]},"trackingMode":"reps","instructions":["Adjust the pads before starting."],"lifecycle":{"status":"deprecated","replacementExerciseID":"machine.seated_hamstring_curl"}}
```

## Stable-ID rules

- Regex: `^[a-z0-9]+(?:_[a-z0-9]+)*\.[a-z0-9]+(?:_[a-z0-9]+)*(?:\.[a-z0-9]+(?:_[a-z0-9]+)*)?$`.
- First segment is the modality or primary defining apparatus (`bodyweight`, `dumbbell`, `barbell`, `cable`, `machine`, `band`, `mobility`, `yoga`).
- Second segment is the durable movement name. A third segment is allowed only when grip/stance/mechanics create a genuinely distinct exercise, not merely a coaching cue.
- Do not encode left/right for symmetric records. Use `laterality: unilateral` and session-side metadata. Create `.left`/`.right` IDs only when execution or clinical content truly differs.
- Holds remain the same exercise when tracking switches to duration; create `_isometric_hold` only when the held form is the product-defined movement.
- Progressions/regressions use explicit `relationships` IDs; they are distinct IDs only when instructions/eligibility differ.
- `aliases` contain names, never old IDs. Old IDs live in `legacyIDs`; deprecated IDs remain resolvable indefinitely.

## Equipment and environment

Equipment definitions are data records with `id`, display name, aliases, category, optional parent, and lifecycle. The required initial list is exactly the list in the Sol prompt, including both generic and machine-specific items. `none` cannot be combined with another required item.

An equipment clause is satisfied when all requirements in the primary group exist at required quantities, or when every requirement in one alternative group exists. Generic `dumbbell` may be fulfilled by `pair_of_dumbbells` only through an explicit taxonomy equivalence. A specific machine is never inferred from generic `machine_access`.

Locations are presets, not truth. Each preset expands to default capabilities and ranking tags. User-selected capabilities/equipment override defaults. Eligibility order:

1. Preserve explicit user exclusions and physical constraints.
2. Reject unsatisfied required equipment/quantity groups.
3. Reject missing required environment capabilities.
4. Reject present prohibited capabilities/conditions (for example `jumping_allowed=false`).
5. Rank remaining exercises by goal, duration, movement balance, preference, and location hint.
6. Media availability is not a filter.

Add `capabilitiesJSON: String?` and `equipmentTypeID: String?` only as additive migration-safe fields if SwiftData tests prove them safe; expose typed computed values. Preserve current free text and `categoryRaw` as legacy evidence.

## Media architecture

```swift
struct ExerciseMediaDefinition: Codable, Hashable, Sendable {
    let key: String
    let role: ExerciseMediaRole
    let sequence: Int?
    let variant: String?
    let appearance: ExerciseMediaAppearance?
    let accessibilityDescription: String
}

protocol ExerciseMediaResolving: Sendable {
    func assetName(for key: String) -> String?
}
```

The importer generates an image set name safe for Xcode and records it in `media-index.json`. Runtime never derives a filesystem path from display text. A missing index or asset returns `nil`; `ExerciseMediaView` presents the vector fallback and text. Future animation/video adds a `kind` and resolver implementation without changing exercise identity.

Supplied two-pose PNGs use role `composite`. `start` and `end` are reserved for separate assets or a deliberately approved crop/split workflow; Terra must not crop the supplied pack automatically.

## Runtime APIs

```swift
protocol ExerciseCatalogRepository: Sendable {
    func allExercises() async -> [ExerciseDefinition]
    func exercise(id: ExerciseID) async -> ExerciseDefinition?
    func resolve(_ reference: ExerciseReference) async -> ExerciseResolution
    func candidates(for context: ExerciseFilterContext) async -> [ExerciseCandidate]
}
```

`BundledExerciseCatalogRepository` is constructed once at app composition, loads through an actor or immutable task, and publishes immutable results. Lookup dictionaries are O(1); filters are O(n) initially and may add derived indexes after measured need. Dataset size of thousands is not justification for a database.

Resolution order is exact stable ID, exact legacy ID, normalized exact alias/name, then unresolved. No substring matching. Ambiguous alias resolution returns an error, not the first result.

## Generation integration

- Build `ExerciseFilterContext` from selected location, structured capabilities, inventory quantities, user constraints, goal, duration, and preferences.
- Send a compact candidate list (`id`, display name, tracking mode, key equipment, short caution) rather than the entire manifest.
- Structured output uses `exerciseID` and keeps `displayNameSnapshot` for review.
- `GeneratedWorkoutValidator` rejects unknown/disabled IDs, unsatisfied equipment, and contradictions. It may repair exact legacy IDs or unique aliases and records the repair. It never fuzzy-invents an ID.
- User-created exercises use an explicit custom reference with a generated UUID and written snapshot; they are not silently inserted into the bundled catalogue.
- Confirmation remains the only persistence boundary in `ChatEngine`.

## Persistence classification

| Work | Classification |
|---|---|
| Runtime exact-name/alias resolver for existing records | Compatibility shim; required before release |
| Optional `exerciseIDSnapshot` on `WorkoutStep`, `ActiveWorkoutStep`, and `ExerciseSet` | Required for new canonical data, gated by migration tests |
| Preserve title/name/instructions snapshots | Required before release |
| Add optional taxonomy IDs/capability JSON to user equipment/locations | Compatibility shim; required for deterministic filtering once enabled |
| Backfill a stable ID only on unique exact matches | Optional cleanup |
| Rewrite historical display names or discard unknown values | Forbidden |
| Convert all old records eagerly | Deferred and likely unnecessary |

## UI ownership

- `ExerciseMediaView` owns image resolution, aspect-fit, paging, fallback, accessibility labels, Reduce Motion, and size policy.
- Catalogue/detail screens own written content and search/filter state.
- Plan preview, Active Workout, history, and completion surfaces pass a stable ID plus immutable snapshots.
- Active Workout defaults to one compact composite/thumbnail and an opt-in expanded frame viewer. Timers, controls, instructions, and safety text precede media in reading order.
- Debug gallery is compiled under `#if DEBUG`, reachable only from a debug-only Settings section or launch argument, and absent from release navigation.

## Ownership boundaries

- Product/content owner approves exercise semantics, names, instructions, and ambiguous media.
- Tooling owns mechanical normalization, validation, generated resources, and reports.
- Catalogue domain owns identity and eligibility semantics.
- Persistence owns immutable workout snapshots and optional canonical references.
- Generator consumes candidates but cannot redefine taxonomy.
- UI displays definitions and fallbacks but never performs fuzzy identity resolution.


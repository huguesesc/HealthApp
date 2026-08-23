# Nell Exercise Catalogue, Location Context, and Motion-Image Plan

## Status

Planning document only. No model, UI, asset-catalogue, or Coach behaviour changes are included in this commit.

Feature branch:

`feature/nell-exercise-catalog-location-context`

Parent branch:

`feature/nell-full-brand-and-ui-system`

## Product decision

Nell's illustrated exercise catalogue will improve plan quality and motion guidance, but it will **not** restrict which exercises Nell can recommend.

Every planned exercise may be in one of three states:

1. **Known and illustrated** — stable exercise ID, metadata, written guidance, aliases, and a supplied PNG.
2. **Known but not illustrated** — stable exercise ID and written guidance, with the existing generated avatar or generic fallback.
3. **Free-form** — an exercise proposed by Nell or entered by the user that is not yet in the catalogue. It remains fully usable with written instructions and a safe generic visual fallback.

The written explanation is authoritative. Images are supplementary motion guidance.

## Location model

Two different concepts must remain separate.

### Global exercise suitability

Static catalogue metadata describes where an exercise can reasonably be performed, for example:

- anywhere
- home
- gym
- outdoors
- pool
- requires machine
- requires bench
- requires cable station

This is product metadata, not personal data.

### User-specific availability

The existing `WorkoutLocation` and `EquipmentItem` SwiftData records remain the source of truth for what the user actually has at a named place.

Examples:

- Home — mat, resistance bands, adjustable dumbbells
- Local gym — cable station, barbells, prone leg-curl machine
- Outdoors — open space, pull-up bar

Nell may use global suitability to explain an exercise, but plan generation must prioritize the user's confirmed location, equipment, space limitations, health considerations, and preferences.

## Location-selection behaviour

Nell should not ask the user to classify every exercise individually.

The intended flow is:

1. If the user explicitly says “at home”, “at my gym”, or names a saved location, use that context.
2. If one active location exists and no location is specified, preselect it and show it in the plan review.
3. If multiple locations exist and the request is ambiguous, ask one concise question or require a location selection before the plan is saved.
4. If no location exists, offer a lightweight first-use setup:
   - Home
   - Gym
   - Outdoors
   - Other
5. The user may add available equipment immediately or skip it.
6. A plan may still be created without a saved location, but Nell must label equipment assumptions clearly.
7. When starting a saved plan, the selected location remains visible and can be changed before execution.

This captures useful context once and reuses it across future plans instead of repeatedly interrupting the user.

## Proposed catalogue type

The first implementation should use a static, version-controlled catalogue rather than SwiftData. Catalogue definitions are application knowledge, while user locations and equipment are user data.

Conceptual shape:

```swift
struct ExerciseDefinition: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let aliases: [String]
    let movementPattern: ExerciseMovementPattern
    let primaryMuscleGroups: [ExerciseMuscleGroup]
    let requiredEquipment: [ExerciseEquipmentRequirement]
    let suitableEnvironments: Set<ExerciseEnvironment>
    let writtenInstructions: [String]
    let coachingCues: [String]
    let imageAssetName: String?
}
```

The first pass does not require every optional taxonomy field to be exhaustive. Stable IDs, aliases, equipment requirements, environment suitability, written instructions, and optional image names are required.

## Plan-step identity

### Phase 1 — no persistence migration

Initially, existing `WorkoutStep.title` values will be resolved against the catalogue by exact name, aliases, and normalized matching. This allows the image pack and catalogue to ship without immediately changing the SwiftData schema.

### Phase 2 — optional stable ID snapshot

After device migration testing, add an optional catalogue identifier to saved plan steps:

```swift
var exerciseIDSnapshot: String?
```

The field must remain optional so existing plans and free-form movements continue to work.

The image itself is never persisted in a workout plan. Views resolve the current image from the catalogue. Adding an image later therefore upgrades old and new plans automatically.

## Coach integration

The existing Coach already reads confirmed workout locations and available equipment before proposing a future plan. That behaviour remains.

The first catalogue integration will happen after the Coach proposes a plan:

1. Resolve each proposed step title against catalogue IDs and aliases.
2. Attach the matching ID in memory and, after migration approval, persist it as an optional snapshot.
3. Display the supplied motion image when available.
4. Preserve the written instruction from the proposal.
5. Use the generated avatar or generic fallback when no image exists.

Nell must not be instructed to use only catalogue exercises.

Preferred prompt rule:

> Use confirmed location and equipment context. Prefer a known catalogue exercise when it is equally appropriate, but do not restrict the plan to illustrated or catalogued movements.

A later optimization may expose a compact catalogue-search tool to the Coach. It is not required for the initial implementation because post-proposal resolution already provides the correct visual behaviour without increasing model context.

## Exercise-detail presentation

Each catalogue-backed exercise detail should show:

1. Exercise name
2. Motion image when available
3. Primary written setup and execution instructions
4. Short coaching cues
5. Required equipment
6. Suitable environments
7. Any user-specific plan modification

The image must not replace the written explanation.

Accessibility requirements:

- useful VoiceOver description
- no instruction conveyed only through the image
- Dynamic Type-safe written guidance
- `.scaledToFit()` for wide two-position illustrations

## Asset normalization rules

The original ZIP archives remain untouched. App-ready copies are normalized during import.

Required normalization:

- Remove accidental trailing or duplicate periods in logo filenames.
- Normalize `logo..png` to the source export name `logo.png` before mapping it to `NellLogoFullColor`.
- Remove any period immediately before another period or before the extension.
- Replace every `dumbell` occurrence with `dumbbell` in normalized filenames, runtime asset names, stable exercise IDs, display metadata, and aliases.
- Preserve a compatibility alias for the misspelling only where title matching benefits from it.
- Use `dumbbell` in all user-visible text.
- Convert source filenames into stable PascalCase Xcode asset names.
- Preserve PNG transparency for logos, Nell poses, and exercise illustrations.
- Keep the App Store icon opaque and exactly 1024×1024.

Examples:

| Raw source | Normalized source | Xcode asset |
|---|---|---|
| `brand_id/logo..png` | `brand_id/logo.png` | `NellLogoFullColor` |
| `dumbell_goblet_squat.png` | `dumbbell_goblet_squat.png` | `WorkoutMotionDumbbellGobletSquat` |

## Implementation phases

### Phase 1 — Catalogue foundation and normalized manifest

Scope:

- Create catalogue types and environment/equipment enums.
- Build the initial catalogue from the supplied workout images.
- Add a source-to-runtime asset manifest.
- Apply the period and `dumbell` normalization rules.
- Preserve the current motion registry fallback.

Expected files:

- `Health Assistantv2/ExerciseCatalog/ExerciseDefinition.swift`
- `Health Assistantv2/ExerciseCatalog/ExerciseCatalog.swift`
- `Health Assistantv2/ExerciseCatalog/ExerciseAssetManifest.swift`
- existing workout-motion registry and tests

Acceptance criteria:

- Every supplied workout image has one stable runtime asset name.
- Every illustrated exercise has a stable ID and aliases.
- Unknown exercises still resolve to a usable fallback.
- No user-facing text contains `dumbell`.
- No runtime asset name contains accidental periods.

### Phase 2 — Import app-ready image assets

Scope:

- Generate normalized PNG exports from the canonical latest ZIP.
- Add Xcode image sets and `Contents.json` files.
- Add brand, Nell-pose, and workout-motion assets in separate groups.
- Preserve all existing SwiftUI fallbacks.

Acceptance criteria:

- Production images load by runtime asset name.
- Missing assets do not crash or leave empty space.
- Wide exercise images are not cropped.
- Light and dark appearance are checked.

### Phase 3 — Exercise motion and written-guidance UI

Scope:

- Render catalogue images in workout plan rows, exercise detail, start review, active workout, and execution history where appropriate.
- Keep written instructions primary.
- Add required-equipment and suitable-environment labels to exercise detail.

Acceptance criteria:

- Illustrated movements show their image.
- Non-illustrated movements show a safe fallback.
- Free-form movements remain usable.
- No plan is rejected because an image is absent.

### Phase 4 — Location-context UX

Scope:

- Add a compact location choice to plan review/start flows.
- Reuse existing `WorkoutLocation` and `EquipmentItem` data.
- Add a lightweight first-use location setup when none exists.
- Show equipment assumptions before saving an AI plan.

Acceptance criteria:

- A home request uses the saved Home context when present.
- Multiple saved locations require a visible choice when ambiguous.
- Users can continue without completing equipment setup.
- The app never silently claims equipment is available.

### Phase 5 — Coach proposal resolution

Scope:

- Resolve proposed step names against catalogue aliases.
- Preserve free-form proposals.
- Add the optional ID to proposal structures first.
- Consider the optional SwiftData step-ID snapshot only after migration verification.
- Update prompt language to prefer, but never require, catalogue exercises.

Acceptance criteria:

- Known proposed exercises display the correct image.
- Unknown exercises remain in the plan with written instructions.
- Location and equipment constraints remain authoritative.
- No AI-generated plan is silently saved.

### Phase 6 — Persistence hardening and migration decision

Scope:

- Test existing stores on simulator and physical device.
- Decide whether to add `exerciseIDSnapshot` to `WorkoutStep` and `ActiveWorkoutStep`.
- Add migration-safe optional fields only after verification.

Acceptance criteria:

- Existing plans open after schema change.
- Active sessions resume correctly.
- Old plans can gain newly added images through catalogue resolution.

## Test plan

Unit tests:

- exact ID resolution
- alias resolution
- normalized punctuation and spacing
- `dumbell` compatibility alias resolving to canonical `dumbbell`
- unknown exercise fallback
- environment suitability filtering
- equipment compatibility
- plan proposal resolution without dropping free-form steps

Runtime tests:

- create a Home location with limited equipment
- request a home workout
- verify machine-only movements are not treated as available
- request a gym workout
- verify matching machine images appear where appropriate
- save, reopen, start, pause, resume, and complete the plan
- add an image to a previously unillustrated catalogue entry and verify an existing plan begins showing it

## Commit sequence

1. `Add Nell exercise catalogue foundation`
2. `Import normalized Nell motion assets`
3. `Render catalogue motion guidance`
4. `Add workout location selection context`
5. `Resolve Coach plans against exercise catalogue`
6. `Persist optional exercise identifiers` — only after migration approval

## Explicit non-goals

This feature does not:

- limit Nell to the illustrated exercise set
- automatically classify user health conditions
- infer that equipment exists without confirmation
- require users to catalogue every movement they perform
- make images the primary exercise instruction
- implement a complete adaptive training engine

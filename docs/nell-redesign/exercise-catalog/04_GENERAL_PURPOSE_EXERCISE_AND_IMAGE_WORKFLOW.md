# General-purpose exercise and image workflow

This is the permanent contributor contract. Terra must update commands only if implementation differs, and then keep this document exact.

## One workflow

1. Create or edit one entry in `Health Assistantv2/ExerciseCatalog/Resources/Authoring/catalog.json`.
2. Put new PNGs in `exercise-assets-intake/`; never hand-create an imageset.
3. Run `python scripts/exercise_catalog.py validate --strict`.
4. Run `python scripts/exercise_catalog.py import --dry-run`, review the mapping, then rerun with `--apply`.
5. Run `python scripts/exercise_catalog.py report` and inspect orphan/missing/duplicate sections.
6. On macOS, run targeted tests and the app’s debug gallery.
7. Verify the generated resource diff, build, accessibility states, and Git scope before committing.

Validation errors must show a JSON pointer or file, the invalid value, the rule, and a likely fix. Never bypass an error by weakening validation without a documented schema reason.

## Entry templates

### Exercise without media

```json
{
  "id": "bodyweight.wall_sit",
  "schemaVersion": 1,
  "displayName": "Wall sit",
  "aliases": [],
  "category": "strength",
  "movementPattern": "squat",
  "exerciseType": "isometric",
  "equipment": {"required": [{"id": "wall", "quantity": 1}], "alternatives": []},
  "environmentRequirements": {"required": ["wall_access"], "prohibited": []},
  "trackingMode": "duration",
  "instructions": ["Place your back against a stable wall.", "Hold a comfortable squat depth while breathing normally."],
  "lifecycle": {"status": "active"}
}
```

### One image or composite

Add `bodyweight.wall_sit__composite.png` to intake and:

```json
"media": [{
  "key": "bodyweight.wall_sit__composite",
  "role": "composite",
  "accessibilityDescription": "Setup and held position for a wall sit"
}]
```

### Start/end pair

```json
"media": [
  {"key":"bodyweight.push_up__start","role":"start","sequence":1,"accessibilityDescription":"High plank start position"},
  {"key":"bodyweight.push_up__end","role":"end","sequence":2,"accessibilityDescription":"Lowered push-up position"}
]
```

Both files are required. Never label two unrelated images start/end merely to satisfy the validator.

### Multiple frames and alternate angle

```json
"media": [
  {"key":"mobility.hip_90_90_switch__frame_01","role":"setup","sequence":1,"accessibilityDescription":"Initial 90-90 seated position"},
  {"key":"mobility.hip_90_90_switch__frame_02","role":"mid","sequence":2,"accessibilityDescription":"Knees passing through centre"},
  {"key":"mobility.hip_90_90_switch__frame_03","role":"end","sequence":3,"accessibilityDescription":"Opposite 90-90 seated position"},
  {"key":"mobility.hip_90_90_switch__alternate_01__side","role":"alternate","sequence":1,"variant":"side","accessibilityDescription":"Side view of the transition"}
]
```

Sequence numbers are contiguous within the primary instructional sequence. Alternate variants have their own sequence namespace.

## Identity and content changes

- **Replace an image:** keep the media key and exercise ID, replace only through intake/import, review the checksum diff, and rerun visual QA.
- **Change display name:** edit `displayName`; never change `id`. Add the former name to `aliases` when users or old records may contain it.
- **Add aliases:** normalized aliases must be unique across active and deprecated entries. Never use an alias to hide two different movements.
- **Progression/regression:** create a distinct ID only when eligibility or instructions differ and add `relationships.progressions` / `relationships.regressions` references.
- **Left/right:** prefer one unilateral exercise plus per-workout `side`. Create side-specific IDs only for materially different content.
- **Deprecate:** keep the full entry, set `lifecycle.status` to `deprecated`, optionally add a valid `replacementExerciseID`, and leave legacy IDs resolvable. Never delete an ID already shipped.
- **Preserve history:** stored title/instructions remain snapshots. Resolution adds current context; it does not rewrite the historical wording.

## Equipment and environments

Equipment alternatives are OR groups of AND requirements:

```json
"equipment": {
  "required": [{"id":"dumbbell","quantity":1}],
  "alternatives": [
    [{"id":"kettlebell","quantity":1}],
    [{"id":"weight_plate","quantity":1}]
  ]
}
```

To add an equipment type, add one record to `equipment.json`, define explicit equivalences, add validator/filter tests, then reference it. Do not add a Swift enum case as the primary change.

To add a location or capability, update `environments.json`, add contradiction and preset-expansion tests, then add UI copy. Location presets rank candidates; required/prohibited capabilities decide eligibility.

## Naming rules

- Lowercase ASCII, digits, dots between ID segments, underscores within a segment.
- Exactly two underscores between exercise ID and media role.
- Optional sequence `_NN`; optional variants use another `__segment`.
- One extension only. No spaces, apostrophes, consecutive periods, or `..png`.
- Spell `dumbbell`; abbreviations belong in aliases unless universally part of the product term.
- Appearance suffixes (`__light`, `__dark`) require a real contrast need. Transparent instructional PNGs should normally be appearance-independent.

## Validation failure guide

| Failure | Likely fix |
|---|---|
| Duplicate/malformed ID | Choose a unique stable ID matching the regex; never append a random number. |
| Alias collision | Remove the ambiguous alias or make the exercise distinction explicit. |
| Missing asset | Add the named intake file or remove/correct the media entry. |
| Orphan asset | Add an intentional manifest reference or remove it from intake/generated resources. |
| Invalid role/sequence | Use the controlled role and contiguous ordering; pair start/end. |
| Unknown equipment/capability | Add an approved taxonomy definition first or correct the typo. |
| Broken replacement | Point to an existing non-disabled ID and reject replacement cycles. |
| Empty instructions | Add real written instruction; an image is not a substitute. |
| Dimension/alpha warning | Get content approval, correct the source, or document an allowed exception. |
| Deprecated reference | Select the replacement for new content; retain the deprecated ID only for compatibility. |

## Tests and previews

Expected commands after Terra implements them:

```text
python scripts/exercise_catalog.py validate --strict
python scripts/exercise_catalog.py import --dry-run
xcodebuild test -project "Health Assistantv2.xcodeproj" -scheme "Health Assistantv2" -destination "platform=iOS Simulator,name=iPhone 16 Pro"
xcodebuild build -project "Health Assistantv2.xcodeproj" -scheme "Health Assistantv2" -configuration Release -destination "generic/platform=iOS Simulator"
```

Use an available simulator name if the example is absent and record it. Open the debug gallery with the implemented DEBUG-only route/launch argument. Verify all filters, missing media, deprecated entries, long names, dark/light backgrounds, at least accessibility sizes `AX1` and `AX5`, VoiceOver reading order, Reduce Motion, portrait/landscape where supported, and one small-screen plus one large-screen device.

Resource bundling check: select at least one generated media key, assert the resolver finds its asset, then temporarily inject a nonexistent key and confirm fallback without a crash. Inspect the built product or runtime resolver; a green source-level test alone does not prove an image entered the bundle.

## Clean commit gate

- `git status --short` contains only intended catalogue/tooling/assets/tests/docs.
- Generated files match a fresh importer run and no intake file is accidentally committed if policy excludes it.
- `archive` is untouched.
- Validator, targeted tests, full tests, Debug build, and Release build statuses are recorded.
- Ambiguous assets remain quarantined.
- Commit message covers one logical boundary; do not mix unrelated UI cleanup.


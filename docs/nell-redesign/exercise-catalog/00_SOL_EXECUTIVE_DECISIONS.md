# Sol executive decisions

Status: implementation architecture selected. This document is normative for Terra unless repository evidence found during implementation makes a decision unsafe. Any deviation must be logged with evidence.

## Decisions

1. **Canonical source:** checked-in, schema-versioned JSON under `Health Assistantv2/ExerciseCatalog/Resources/Authoring/`. JSON is both the authoring representation and the bundled runtime representation. The importer may normalize key ordering and generate indexes, but it must not create a second editable catalogue.
2. **Runtime:** `ExerciseCatalogLoader` decodes immutable `Codable`, `Sendable` value types. An injected `ExerciseCatalogRepository` owns one in-memory index by stable ID plus alias and legacy-name indexes. No global singleton.
3. **Stable IDs:** lowercase ASCII dot IDs, `<modality-or-primary-equipment>.<movement>[.<material-variant>]`, for example `bodyweight.dead_bug` or `machine.leg_press`. IDs never encode display text, localization, media names, or mutable product categorization.
4. **Schema:** written guidance is required and media is optional. Required fields are deliberately small: `id`, `schemaVersion`, `displayName`, `category`, `movementPattern`, `exerciseType`, `equipment`, `trackingMode`, `instructions`, and lifecycle state. Rich coaching fields remain optional. Derived search tokens and compatibility indexes are generated.
5. **Equipment:** data-driven definitions in JSON, not a closed Swift enum. An exercise has required equipment requirements with quantities and alternative requirement groups. Specific machines remain distinct. Existing `EquipmentCategory` is retained as a legacy adapter during migration.
6. **Environment:** hybrid suitability. Explicit prohibited/required capabilities are authoritative; location presets expand to capabilities and provide ranking hints. Equipment and capability checks determine eligibility. Location labels alone never override a contradiction.
7. **Media:** ordered media items support `thumbnail`, `setup`, `start`, `mid`, `end`, `alternate`, `mistake`, and `correct`, plus `composite` for the supplied two-pose illustrations. A composite is not falsely split into start/end metadata.
8. **Asset storage:** generated `.imageset` directories in `Health Assistantv2/Assets.xcassets/ExerciseMedia/`. The JSON references stable logical media keys. A generated media index maps those keys to asset-catalog names. This keeps runtime loading native while eliminating manual imageset edits.
9. **Naming:** `<exercise-id>__<role>[_NN][__<variant>][__<appearance>].png`. Lowercase ASCII only; `dumbbell` is the only spelling; exactly one `.png` extension; frame numbering is two digits. Existing names are input aliases, never canonical IDs.
10. **Tooling:** one cross-platform Python 3 command, `python scripts/exercise_catalog.py`, with `validate`, `import`, and `report` subcommands. Use the standard library plus a pinned Pillow dependency for PNG dimensions, alpha, and pixel checks. Windows can prepare assets; macOS runs the same validation before Xcode builds.
11. **Migration:** compatibility first. Phase A resolves existing title strings without changing stores. Phase B adds optional stable-ID snapshot fields to plan, active-session, and history models only after store migration tests pass. Historical display-name snapshots remain immutable. Unknown/custom values are preserved.
12. **Generation and UI:** filter eligible catalogue candidates before asking the model, require stable IDs in structured output, validate every returned ID, and leave custom exercises explicit. A reusable `ExerciseMediaView` renders optional media with the current vector avatar as fallback. Active Workout keeps written instructions visually primary.

## Rejected alternatives

- **Static Swift catalogue:** rejected because every exercise addition would require code edits, compilation, and merge-prone large files.
- **YAML authoring compiled to JSON:** rejected because it adds a parser and generated-artifact drift without enough benefit for the current team. JSON is less pleasant for comments but more portable and directly decodable.
- **SwiftData seed catalogue:** rejected because seed reconciliation, schema migration, and user-store coupling are unnecessary for immutable bundled reference data.
- **Bundled SQLite database:** rejected as premature operational complexity for a read-mostly catalogue.
- **Loose bundle PNG folders:** rejected for the primary iOS path because resource-folder semantics and name collisions are easier to break than generated imagesets. The authoring intake remains ordinary files.
- **Generated Swift asset symbols as the source of truth:** rejected because symbol generation is an Xcode implementation detail and cannot validate the authoring pack on Windows.
- **A remote catalogue/media service:** rejected. The requirement is local, reliable, and offline; remote delivery can later implement the same repository protocol.
- **A global catalogue singleton:** rejected because it hides corrupt-manifest behavior, complicates previews/tests, and prevents controlled failure injection.
- **Destructive history rewrite:** rejected. A rename must never erase the wording a user saw in a completed workout.

## Required failure behavior

- Debug/test: decoding, schema, duplicate-ID, and broken-reference failures must be loud and diagnosable; tests fail and debug UI exposes the problem.
- Release: the app must not crash because catalogue or media is missing. Load the last valid bundled subset when possible, otherwise return an empty catalogue and surface a recoverable state. Existing custom/legacy workout records must remain readable.
- Missing image: render written content plus the existing vector/fallback state; never remove an exercise from generation solely because it has no media.


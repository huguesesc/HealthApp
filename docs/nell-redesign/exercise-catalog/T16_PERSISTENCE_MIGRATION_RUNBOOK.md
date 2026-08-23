# T16 persistence migration and rollback

## Scope

Schema version 2 adds only optional `exerciseIDSnapshot` string properties to
`WorkoutStep`, `ActiveWorkoutStep`, and `ExerciseSet`. Existing title, instruction,
equipment, plan, active-session, and history snapshots remain authoritative and
are not rewritten by the lightweight migration.

The prior app used SwiftData's implicit schema version 1.0.0. Version 2 uses an
explicit `VersionedSchema`. Because the old model types no longer exist in the
shipping target and every change is an optional scalar addition, the container
uses SwiftData's inferred lightweight migration rather than a custom migration
stage. The real version-1 fixture is the release gate for that behavior.

## Immutable prior-schema fixture

The fixture in `Health Assistantv2Tests/Fixtures/T16PriorSchema` was written by
the unchanged T15 model code on Xcode 16.2 / iOS Simulator 18.3.1. Keep all three
files together and never open the tracked originals directly; tests copy them to
a unique temporary directory first.

- `HealthApp.store`: `543c4d5957263e11f5b09e0879d39c329f94f2eb7c35b222c3815ea5fe0ac5b5`
- `HealthApp.store-wal`: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- `HealthApp.store-shm`: `fd4c9fda9cd3f9ae7c962b0ddf37232294d55580e1aa165aa06129b8549389eb`

The fixture contains a health profile, a location and equipment item, a plan
with an exact catalogue title plus a custom title, a partially completed
in-progress workout, and completed history with retired/custom names.

## Pre-release backup procedure

1. Stop the app completely so no store writes are in flight.
2. Copy the store, `-wal`, and `-shm` files as one set to a release-specific
   backup location.
3. Record hashes and verify the copied main store with SQLite
   `PRAGMA integrity_check` before installing the migration build.
4. Preserve the backup read-only until the release is accepted.
5. Install and launch the version-2 build, then verify profile, locations,
   plans, the resumable active workout, and historical workout wording.

## Failure and rollback

- If migration fails before the app opens, retain diagnostics and do not mutate
  or retry against the only backup.
- Do not install an older app build over a version-2 store merely because the
  new fields are optional. Code rollback is permitted only after an automated
  test proves that exact older build can open the migrated store.
- Without that proof, stop the app, remove the failed working store as a unit,
  restore the untouched version-1 backup set, and install the prior build.
- Run the same readability checks after restoration. Keep the failed working
  copy separately for diagnosis.

The exact-only backfill is a separate, explicit repository operation. It fills
nil IDs only for stable IDs, legacy IDs, display names, or aliases that resolve
to one catalogue entry. Ambiguous, unknown, and custom snapshots remain nil and
unchanged.

# Acceptance checklist

Each item is binary. Terra checks `[x]` only with evidence in the progress/deviation log.

## Architecture and source of truth

- [ ] One checked-in JSON authoring source defines catalogue entries; no competing editable Swift/DB catalogue exists.
- [ ] Runtime schema version support/rejection is explicit and tested.
- [ ] Repository is injected/testable; no global singleton or substring identity matching.
- [ ] Generated resources are reproducible and marked as generated.

## IDs and taxonomies

- [ ] Every shipped exercise has a unique valid stable ID independent of name/media.
- [ ] Alias, legacy-ID, deprecation, replacement, and collision behavior is tested.
- [ ] Required equipment list is data-driven with quantities and explicit alternative groups.
- [ ] Location presets and all required capabilities exist; contradictions are deterministically rejected.
- [ ] Adding a taxonomy value does not require scattered Swift edits.

## Media and current assets

- [ ] No-media, single, composite, start/end, ordered frames, and alternate roles validate.
- [ ] Missing/corrupt media never crashes or prevents a workout.
- [ ] All imported media keys exist in generated resources and the built bundle; no unexplained orphans.
- [ ] Exact source/ZIP parity and source checksums are recorded before import.
- [ ] Source pack/ZIP and `archive` remain untouched.
- [ ] Duplicate-period and `dumbell` defects are normalized only in generated copies.
- [ ] The mislabeled floor/bench press and `nell_plan` remain quarantined unless explicit decisions are recorded.
- [ ] No composite was silently cropped or relabelled as separate start/end frames.

## Persistence and compatibility

- [ ] New plan, active-step, and completed-set data can carry stable exercise IDs.
- [ ] Historical display-name/instruction snapshots remain unchanged after rename/deprecation.
- [ ] Unknown and custom exercises remain readable and usable.
- [ ] Exact legacy resolution works; ambiguity does not choose arbitrarily.
- [ ] A real prior-schema store opens without loss in automated migration tests.
- [ ] In-progress workout resumes and converts to history exactly once after upgrade.
- [ ] Migration backup/rollback procedure is documented and exercised.

## Generation

- [ ] Candidates are filtered before model invocation by equipment, capabilities, user constraints, goal, and duration.
- [ ] Media availability has no effect on eligibility.
- [ ] Model output uses stable IDs and is validated before preview/persistence.
- [ ] Unknown/disabled/ineligible/ambiguous IDs are rejected; repairs are exact and audited.
- [ ] Existing workout-confirmation boundary still passes tests.

## UI and workout surfaces

- [ ] Catalogue search/filter and detail exist with loading/empty/error/no-media/deprecated states.
- [ ] Workout preview resolves canonical entries and preserves custom/legacy snapshots.
- [ ] Active Workout keeps instructions, safety, timer, and controls primary; all existing behavior tests pass.
- [ ] History displays immutable snapshot truth with optional current details.
- [ ] Reusable media component handles all roles, sizing, paging, and fallbacks.
- [ ] Debug gallery shows every entry/metadata/media/error filter and is absent from Release navigation.

## Validation, tests, and accessibility

- [ ] One documented Python command validates manifest, taxonomy, assets, replacements, and naming on Windows/macOS.
- [ ] Import dry run is reviewable; applied import is transactional and idempotent.
- [ ] All automated rows in `07_TEST_AND_QA_MATRIX.md` pass at final HEAD.
- [ ] VoiceOver reading order/labels pass on representative catalogue, detail, preview, active, and history flows.
- [ ] Default through AX5 Dynamic Type passes on small and large phones.
- [ ] Light/dark transparent-edge rendering passes; unwanted backgrounds are absent.
- [ ] Reduce Motion behavior passes and motion is never informationally required.
- [ ] Failure-injection matrix passes without crash or data loss.

## Documentation, build, QA, and Git

- [ ] Contributor guide commands/paths were executed from a fresh clone or equivalent clean checkout.
- [ ] Stale prior asset/catalogue docs are marked superseded where they conflict.
- [ ] Debug build succeeds at final HEAD.
- [ ] Release build succeeds at final HEAD.
- [ ] Full unit/integration/UI test suite succeeds at final HEAD.
- [ ] Simulator matrix includes a small and large iPhone and records iOS versions.
- [ ] Installed-upgrade flow is tested on simulator.
- [ ] Physical-device upgrade/resume/media/accessibility QA passes; if unavailable, PR is explicitly not fully device-validated.
- [ ] Working tree is clean except explicitly documented handoff artifacts.
- [ ] Commits are logical, tested, and contain no unrelated redesign or user files.
- [ ] Remote push/PR action occurred only with user authorization.
- [ ] Draft PR states migration, asset quarantine, tests/builds, simulator/device status, risks, and rollback truthfully.


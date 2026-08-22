# Open questions and human review queue

This queue contains only semantic, product, clinical/content, or access decisions. It is not a place to defer technical architecture.

## HR-01 — Floor press mislabeled as bench press (resolved 2026-07-14)

- **Affected:** `HealthAssistant_image_Pack/workout_avatar/bench_dumbbell_flat_chest_press..png`.
- **Evidence:** direct visual inspection shows the character lying on the floor with bent knees and no bench. The alternate file does show a bench.
- **Why human:** remapping it creates a new exercise/content claim (`dumbbell.floor_press`); deleting or calling it bench press would be dishonest.
- **Safe default:** quarantine; use `bench_dumbbell_flat_chest_press_alt_01..png` for `dumbbell.flat_bench_press`.
- **Exact question:** Approve this source as media for a new `dumbbell.floor_press` entry, request a corrected bench image, or discard it?
- **Blocker:** blocks only this image/new floor-press entry, not the architecture.
- **Recommendation:** approve as `dumbbell.floor_press` only if written instructions and equipment semantics are also reviewed.

**Resolution:** approved as the separate `dumbbell.floor_press` media mapping
with canonical filename `dumbbell.floor_press__composite.png`. It must never be
identified as a bench press. The bench-visible alternate remains reserved for
the distinct `dumbbell.flat_bench_press` candidate. Import remains pending
because the approved initial catalogue has no floor-press entry yet.

## HR-02 — `nell_plan.png` background

- **Affected:** `HealthAssistant_image_Pack/nell_poses/nell_plan.png`.
- **Evidence:** direct visual inspection shows a saturated blue field despite the PNG containing alpha values.
- **Why human:** it may be an intentional art direction or an unwanted export background; automatic removal risks damaging the illustration.
- **Safe default:** quarantine and keep existing app mascot resources.
- **Exact question:** Is the blue field intentional, or can design provide an approved transparent export?
- **Blocker:** not a blocker for the exercise catalogue.
- **Recommendation:** request a clean transparent source rather than algorithmic background removal.

## HR-03 — Exercise content and safety approval

- **Affected:** all new `catalog.json` written instructions, safety notes, contraindication/rehabilitation tags, and the 50 visual mappings.
- **Evidence:** Sol verified filenames and visible movement plausibility, not clinical correctness or coaching safety.
- **Why human:** exercise prescription and rehabilitation claims require accountable content/product review.
- **Safe default:** ship only neutral mechanical instructions reviewed by the designated content owner; leave contraindication and rehabilitation tags deferred.
- **Exact question:** Who is the approving owner, and which initial entries are authorized for release?
- **Blocker:** release blocker for unreviewed exercise guidance; not a blocker for schema/tooling/fallback implementation.
- **Recommendation:** approve a small initial set, record reviewer/date/version, expand incrementally.

**Resolution (2026-07-14):** the designated product/content approver authorized
the listed 20 exercises with neutral two-sentence draft instructions. These
remain pending final release review; no clinical, rehabilitation,
contraindication, or safety tags were authorized.

## HR-04 — Terminology choices (resolved 2026-07-14)

- **Affected:** proposed IDs/names `barbell.lying_triceps_extension` (source says skullcrusher), `machine.lying_leg_curl` (source says prone), and `machine.seated_row` equipment subtype.
- **Evidence:** visuals match the movement family, but consumer display terminology and taxonomy granularity are product choices.
- **Why human:** stable IDs should not churn after release; naming affects localization and legacy aliases.
- **Safe default:** use the more neutral IDs proposed in the migration map and retain source/common terms as aliases.
- **Exact question:** Approve these canonical names/IDs and aliases before the first shipped manifest?
- **Blocker:** blocks final ID freeze for those entries only.
- **Recommendation:** approve proposed neutral IDs; aliases preserve discoverability.

**Resolution:** approved the proposed IDs `barbell.lying_triceps_extension`,
`machine.lying_leg_curl`, and `machine.seated_row`, with the proposed
aliases/provenance recorded in the machine-readable map. They remain pending
matching catalogue entries before any asset import.

## HR-05 — Incomplete step-up illustration (resolved 2026-07-14)

- **Affected:** `workout_avatar/bench_step_up..png`.
- **Evidence:** the second panel shows one foot placed on the step, not the completed elevated stance.
- **Why human:** calling it full start/end instruction could overstate what the visual teaches.
- **Safe default:** retain only as `composite`/setup supplementary media and keep written instructions primary.
- **Exact question:** Is this acceptable as supplementary setup media, or is a corrected full-range illustration required?
- **Blocker:** not a technical blocker; blocks claiming a complete visual sequence.
- **Recommendation:** accept only as supplementary composite until a corrected asset exists.

**Resolution:** approved as supplementary composite media only. It must not be
represented as a complete start/end sequence, and written instructions remain
primary. It remains pending a matching catalogue entry.

## HR-06 — Blue edge halos and visual consistency

- **Affected:** many transparent workout PNG edges; `dumbbell_thruster.png` also uses a yellow outfit while most use green.
- **Evidence:** direct rendering shows thin blue edge halos around many figures; outfit color differs in the thruster image.
- **Why human:** acceptability depends on actual iOS light/dark backgrounds and brand standards; automated alpha checks cannot decide aesthetics.
- **Safe default:** import only after debug-gallery/device QA; quarantine individual failures rather than post-process all sources.
- **Exact question:** Are the halos and thruster color acceptable on approved light/dark surfaces, or should design re-export them?
- **Blocker:** conditional release blocker only for assets that visibly fail device QA.
- **Recommendation:** review in the gallery on device before requesting costly re-exports.

## HR-07 — Physical-device and signing access

- **Affected:** T28 device QA and final acceptance.
- **Evidence:** Sol’s Windows environment has no Xcode, signing, simulator, or device build access.
- **Why human:** device provisioning/access cannot be inferred or created safely without credentials/hardware.
- **Safe default:** Terra completes macOS simulator/build validation and reports physical device as `NOT RUN` until access is supplied.
- **Exact question:** Which signed physical device/OS should be used for installed-upgrade and accessibility QA?
- **Blocker:** blocks a claim of full device validation, not implementation or draft PR preparation.
- **Recommendation:** test one current small/standard iPhone on the minimum supported or representative iOS plus the latest available device if possible.

## HR-08 — Five media rows promoted to "approved-pending" remain blocked on entry content (recorded 2026-08-23)

- **Affected:** `barbell.lying_triceps_extension`, `machine.lying_leg_curl`,
  `machine.seated_row` (HR-04), `dumbbell.floor_press` (HR-01),
  `bodyweight.step_up` (HR-05).
- **Evidence:** the recorded approvals cover identity/naming/media mapping
  only. No recorded decision approves equipment semantics or written
  instructions for these five, so no catalogue entry may be authored yet.
- **Safe default:** keep `status=approved_pending_catalogue_entry` in
  `media-import-map.json`; catalogue stays at 20 entries; images stay out of
  generated resources.
- **Exact question:** approve neutral draft instructions plus the equipment
  clauses listed in the migration map for each row (floor press needs a
  dumbbell×2 + floor_space clause; step-up needs its `step`/bench equipment
  stance confirmed)?
- **Blocker:** blocks only those five entries/images; nothing else.
- **Recommendation:** approve in one batch with HR-03-style review wording so
  a single importer run promotes all five together.

## HR-09 — Alias policy confirmations (opened 2026-08-23)

- **Affected:** `docs/nell-redesign/exercise-catalog/LEGACY_EXERCISE_NAME_AUDIT.md`.
- **Evidence:** this phase added exactly-safe aliases (Air squat, Dumbbell
  row, Overhead press, Shoulder press, Deadlift, RDL family). Deliberately
  NOT aliased: `military press`, `dumbbell press` (ambiguous), bare
  `squat`/`row`/`lunge`/`plank`.
- **Why human:** aliasing is an identity claim affecting localization,
  search, and generation eligibility.
- **Safe default:** current conservative mapping stands; ambiguous strings
  resolve to free-form and are preserved verbatim.
- **Exact question:** confirm the added set, and decide whether
  `military press` should map to `dumbbell.overhead_press` or stay free-form.
- **Blocker:** non-blocking; affects compatibility only when historical data
  contains those strings.
- **Recommendation:** accept current defaults now; revisit if real user data
  shows unresolved high-frequency names.

## HR-10 — Mascot success-state fallback rendering

- **Affected:** `NellMascotSuccess` (enum case without imageset) rendered on
  the workout-completion overlay via vector/SF-symbol fallback.
- **Evidence:** brand audit matrix (`BRAND_ASSET_REFERENCE_AUDIT.md`); runtime
  fallback chain documented in `NellAssets.swift`.
- **Why human:** whether the drawn placeholder is acceptable on the most
  celebratory screen is aesthetic/product judgment, not mechanical.
- **Safe default:** keep fallback until design supplies approved art.
- **Exact question:** ship real success artwork, or bless the placeholder?
- **Blocker:** not blocking any technical work; visual QA only.

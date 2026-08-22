# Asset inventory and migration map

No source file is to be renamed during Sol planning. All workout entries below are 1254×1254 RGBA PNGs with transparency and unique SHA-256 content. Proposed role `composite` means one file contains two illustrated states; it does not imply two separately pageable frames.

Legend: action `import` means copy through the approved importer after validation; `normalize` means importer creates a canonical destination without mutating the source; `quarantine` means do not bundle.

| Current relative path | Current filename | Proposed stable ID | Role | Proposed normalized filename | Confidence | Action | Compatibility note | Human review |
|---|---|---|---|---|---|---|---|---|
| `workout_avatar/barbell_biceps_curl.png` | same | `barbell.biceps_curl` | composite | `barbell.biceps_curl__composite.png` | high | import | legacy name alias | no |
| `workout_avatar/barbell_close_grip_bench_press.png` | same | `barbell.close_grip_bench_press` | composite | `barbell.close_grip_bench_press__composite.png` | high | import | preserve title aliases | no |
| `workout_avatar/barbell_deadlift.png` | same | `barbell.deadlift` | composite | `barbell.deadlift__composite.png` | high | import | exact legacy mapping | no |
| `workout_avatar/barbell_flat_bench_press.png` | same | `barbell.flat_bench_press` | composite | `barbell.flat_bench_press__composite.png` | high | import | exact legacy mapping | no |
| `workout_avatar/barbell_overhead_triceps_extension.png` | same | `barbell.overhead_triceps_extension` | composite | `barbell.overhead_triceps_extension__composite.png` | high | import | exact legacy mapping | no |
| `workout_avatar/barbell_reverse_curl.png` | same | `barbell.reverse_curl` | composite | `barbell.reverse_curl__composite.png` | high | import | exact legacy mapping | no |
| `workout_avatar/barbell_romanian_deadlift.png` | same | `barbell.romanian_deadlift` | composite | `barbell.romanian_deadlift__composite.png` | high | import | alias `barbell RDL` | no |
| `workout_avatar/barbell_skullcrusher.png` | same | `barbell.lying_triceps_extension` | composite | `barbell.lying_triceps_extension__composite.png` | medium | approved pending catalogue entry | retain `skullcrusher` alias | HR-04 approved 2026-07-14 |
| `workout_avatar/bench_copenhagen_plank_isometric_hold_short_lever..png` | double period | `bodyweight.copenhagen_plank.short_lever` | composite | `bodyweight.copenhagen_plank.short_lever__composite.png` | high | normalize | bench is required equipment, not identity prefix | no |
| `workout_avatar/bench_dumbbell_flat_chest_press..png` | double period | `dumbbell.floor_press` | composite | `dumbbell.floor_press__composite.png` | high mismatch | approved pending catalogue entry | must never be called a bench press | HR-01 approved 2026-07-14 |
| `workout_avatar/bench_dumbbell_flat_chest_press_alt_01..png` | double period | `dumbbell.flat_bench_press` | composite | `dumbbell.flat_bench_press__composite.png` | high | normalize/import | approved canonical candidate, not “alt” | no |
| `workout_avatar/bench_dumbbell_incline_chest_press..png` | double period | `dumbbell.incline_bench_press` | composite | `dumbbell.incline_bench_press__composite.png` | high | normalize/import | normalize “chest press” alias | no |
| `workout_avatar/bench_dumbell_hip_thrust.png` | misspelling | `dumbbell.hip_thrust` | composite | `dumbbell.hip_thrust__composite.png` | high | normalize/import | retain misspelled filename only in migration report | no |
| `workout_avatar/bench_step_up..png` | double period | `bodyweight.step_up` | composite supplementary setup | `bodyweight.step_up__composite.png` | medium | approved pending catalogue entry | not a complete sequence; written instructions remain primary | HR-05 approved 2026-07-14 |
| `workout_avatar/bodyweight_bird_dog..png` | double period | `bodyweight.bird_dog` | composite | `bodyweight.bird_dog__composite.png` | high | normalize/import | unilateral tracked in session | no |
| `workout_avatar/bodyweight_calf_raise..png` | double period | `bodyweight.calf_raise` | composite | `bodyweight.calf_raise__composite.png` | high | normalize/import | exact legacy mapping | no |
| `workout_avatar/bodyweight_cat_cow..png` | double period | `mobility.cat_cow` | composite | `mobility.cat_cow__composite.png` | high | normalize/import | old bodyweight name as alias | no |
| `workout_avatar/bodyweight_dead_bug..png` | double period | `bodyweight.dead_bug` | composite | `bodyweight.dead_bug__composite.png` | high | normalize/import | exact legacy mapping | no |
| `workout_avatar/bodyweight_forward_lunge..png` | double period | `bodyweight.forward_lunge` | composite | `bodyweight.forward_lunge__composite.png` | high | normalize/import | side stored separately | no |
| `workout_avatar/bodyweight_glute_bridge.png` | same | `bodyweight.glute_bridge` | composite | `bodyweight.glute_bridge__composite.png` | high | import | exact legacy mapping | no |
| `workout_avatar/bodyweight_jumping_jack.png` | same | `bodyweight.jumping_jack` | composite | `bodyweight.jumping_jack__composite.png` | high | import | requires `jumping_allowed` | no |
| `workout_avatar/bodyweight_mountain_climber.png` | same | `bodyweight.mountain_climber` | composite | `bodyweight.mountain_climber__composite.png` | high | import | floor-space capability | no |
| `workout_avatar/bodyweight_push_up.png` | same | `bodyweight.push_up` | composite | `bodyweight.push_up__composite.png` | high | import | exact legacy mapping | no |
| `workout_avatar/bodyweight_side_plank.png` | same | `bodyweight.side_plank` | composite | `bodyweight.side_plank__composite.png` | high | import | side stored separately | no |
| `workout_avatar/bodyweight_squat.png` | same | `bodyweight.squat` | composite | `bodyweight.squat__composite.png` | high | import | exact legacy mapping | no |
| `workout_avatar/bodyweight_standing_side_bend.png` | same | `mobility.standing_side_bend` | composite | `mobility.standing_side_bend__composite.png` | high | import | old name alias | no |
| `workout_avatar/bodyweight_yoga_dancer_pose.png` | same | `yoga.dancer_pose` | composite | `yoga.dancer_pose__composite.png` | high | import | neutral setup + held pose | no |
| `workout_avatar/cable_standing_hip_extension_kickback.png` | same | `cable.standing_hip_extension` | composite | `cable.standing_hip_extension__composite.png` | high | import | `kickback` alias | no |
| `workout_avatar/cable_triceps_pushdown.png` | same | `cable.triceps_pushdown` | composite | `cable.triceps_pushdown__composite.png` | high | import | exact legacy mapping | no |
| `workout_avatar/dumbbell_bent_over_row.png` | same | `dumbbell.bent_over_row` | composite | `dumbbell.bent_over_row__composite.png` | high | import | requires pair quantity | no |
| `workout_avatar/dumbbell_biceps_curl.png` | same | `dumbbell.biceps_curl` | composite | `dumbbell.biceps_curl__composite.png` | high | import | requires pair quantity | no |
| `workout_avatar/dumbbell_bulgarian_split_squat.png` | same | `dumbbell.bulgarian_split_squat` | composite | `dumbbell.bulgarian_split_squat__composite.png` | high | import | bench required; side stored separately | no |
| `workout_avatar/dumbbell_forward_lunge.png` | same | `dumbbell.forward_lunge` | composite | `dumbbell.forward_lunge__composite.png` | high | import | pair quantity | no |
| `workout_avatar/dumbbell_goblet_squat.png` | same | `dumbbell.goblet_squat` | composite | `dumbbell.goblet_squat__composite.png` | high | import | one dumbbell | no |
| `workout_avatar/dumbbell_hammer_curl.png` | same | `dumbbell.hammer_curl` | composite | `dumbbell.hammer_curl__composite.png` | high | import | neutral grip distinct | no |
| `workout_avatar/dumbbell_lateral_raise.png` | same | `dumbbell.lateral_raise` | composite | `dumbbell.lateral_raise__composite.png` | high | import | pair quantity | no |
| `workout_avatar/dumbbell_overhead_press.png` | same | `dumbbell.overhead_press` | composite | `dumbbell.overhead_press__composite.png` | high | import | pair quantity | no |
| `workout_avatar/dumbbell_romanian_deadlift_hip_hinge.png` | same | `dumbbell.romanian_deadlift` | composite | `dumbbell.romanian_deadlift__composite.png` | high | import | `hip hinge` alias | no |
| `workout_avatar/dumbbell_thruster.png` | same | `dumbbell.thruster` | composite | `dumbbell.thruster__composite.png` | high | import | visual outfit color differs; acceptable variant | visual consistency QA |
| `workout_avatar/machine_lat_pulldown.png` | same | `machine.lat_pulldown` | composite | `machine.lat_pulldown__composite.png` | high | import | taxonomy uses `lat_pulldown_machine` | no |
| `workout_avatar/machine_leg_extension.png` | same | `machine.leg_extension` | composite | `machine.leg_extension__composite.png` | high | import | exact legacy mapping | no |
| `workout_avatar/machine_leg_press.png` | same | `machine.leg_press` | composite | `machine.leg_press__composite.png` | high | import | exact legacy mapping | no |
| `workout_avatar/machine_prone_leg_curl.png` | same | `machine.lying_leg_curl` | composite | `machine.lying_leg_curl__composite.png` | high | approved pending catalogue entry | retain `prone leg curl` alias | HR-04 approved 2026-07-14 |
| `workout_avatar/machine_seated_calf_raise.png` | same | `machine.seated_calf_raise` | composite | `machine.seated_calf_raise__composite.png` | high | import | add specific equipment definition if needed | no |
| `workout_avatar/machine_seated_row.png` | same | `machine.seated_row` | composite | `machine.seated_row__composite.png` | high | approved pending catalogue entry | retain explicit rowing-machine subtype | HR-04 approved 2026-07-14 |
| `workout_avatar/resistance_band_lateral_squat.png` | same | `band.lateral_squat` | composite | `band.lateral_squat__composite.png` | high | import | mini-band requirement | no |
| `workout_avatar/resistance_band_standing_hip_extension.png` | same | `band.standing_hip_extension` | composite | `band.standing_hip_extension__composite.png` | high | import | anchor point required | no |
| `workout_avatar/resistance_band_terminal_knee_extension_tke.png` | same | `band.terminal_knee_extension` | composite | `band.terminal_knee_extension__composite.png` | high | import | `TKE` alias; anchor point | no |
| `workout_avatar/stability_ball_glute_bridge.png` | same | `stability_ball.glute_bridge` | composite | `stability_ball.glute_bridge__composite.png` | high | import | distinct from floor bridge | no |
| `workout_avatar/stability_ball_hamstring_curl.png` | same | `stability_ball.hamstring_curl` | composite | `stability_ball.hamstring_curl__composite.png` | high | import | distinct multi-joint variant | no |

## Mechanical groups

- Safe automatic filename normalization after approval: the ten workout files ending in `..png`, plus the `dumbell` spelling defect. `logo..png` is outside the exercise importer.
- Exact/near duplicates: no exact duplicate. The two flat dumbbell press files are not duplicates; they depict different setups and must not share an ID automatically.
- Start/end pairs: none are separate files in this pack. Do not fabricate pairs by cropping.
- Multi-frame sets: none as separate files. Each exercise PNG is a single composite resource.
- Unresolved: the floor/bench press and the three terminology rows were pending
  human decisions in the original audit. Their approved decisions are recorded
  below; they remain out of generated resources until matching catalogue
  entries exist.

## Terra approval boundary (2026-07-14)

The checked-in `media-import-map.json` is the executable approval boundary for
the 50 `workout_avatar` PNGs. It records a source-relative path, exact
SHA-256, canonical exercise/media key, canonical filename, role, and explicit
status for every row. Only `approved_for_import` rows whose media keys already
exist in the current manifest may enter generated resources.

- 20 rows are approved for the initial 20-exercise catalogue.
- Five rows are approved semantically but remain
  `approved_pending_catalogue_entry`: floor press (HR-01), short-lever step-up
  supplementary media (HR-05), and the three HR-04 terminology decisions.
- The remaining 25 rows are explicitly `unreviewed`; proposed names do not
  authorize catalogue entries or asset import.

The earlier floor/bench quarantine is superseded by HR-01. It is still not
importable because no approved `dumbbell.floor_press` catalogue record exists.
The alternate bench-visible source remains a separate unreviewed
`dumbbell.flat_bench_press` candidate.

## Brand and pose assets excluded from the exercise catalogue

| Relative path | Finding | Disposition |
|---|---|---|
| `brand_id/app_icon.png` | Opaque 1254-square source | Brand pipeline; create approved 1024 app icon separately. |
| `brand_id/header_intro1.png` | 1536×1024 composite banner/reference | Do not treat as reusable atomic asset. |
| `brand_id/logo..png` | Double-period defect | Brand normalization only. |
| `brand_id/monochrome-dark.png` | Transparent logo | Existing brand system review. |
| `brand_id/monochrome-light.png` | Transparent logo | Existing brand system review. |
| `brand_id/sublogo-dark.png` | Transparent sublogo | Existing brand system review. |
| `brand_id/sublogo-light.png` | Transparent sublogo | Existing brand system review. |
| `nell_poses/nell_allfours.png` | Neutral all-fours pose | Do not label as success. |
| `nell_poses/nell_balance.png` | Balance pose | Brand/coach state system. |
| `nell_poses/nell_exercise.png` | Resistance-band exercise pose | General mascot state, not exercise instruction. |
| `nell_poses/nell_food.png` | Food pose | Nutrition mascot state. |
| `nell_poses/nell_hello.png` | Wave/hello pose | Existing wave mapping. |
| `nell_poses/nell_pensive.png` | 1122×1402 thoughtful pose | Existing thoughtful mapping. |
| `nell_poses/nell_plan.png` | Visible saturated blue field | Quarantine pending transparent-source decision. |
| `nell_poses/nell_zen.png` | Meditation pose | General mascot state. |

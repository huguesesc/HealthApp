# Uploaded Nell Image Pack Inventory

Exact PNG filenames found in the two uploaded archives. This document records source filenames only; it does not mean the files have already been added to `Assets.xcassets`.

## Archive summary

- `HealthAssistant_image_Pack(3).zip`: latest canonical pack, 65 PNG files.
- `HealthAssistant_image_Pack(2).zip`: 78 PNG files; contains the canonical filename set plus 13 alternate or legacy filenames.
- Unique filename paths across both archives: 78.

## Latest canonical pack — `HealthAssistant_image_Pack(3).zip`

### `brand_id/`

- `brand_id/app_icon.png`
- `brand_id/header_intro1.png`
- `brand_id/logo..png`
- `brand_id/monochrome-dark.png`
- `brand_id/monochrome-light.png`
- `brand_id/sublogo-dark.png`
- `brand_id/sublogo-light.png`

### `nell_poses/`

- `nell_poses/nell_allfours.png`
- `nell_poses/nell_balance.png`
- `nell_poses/nell_exercise.png`
- `nell_poses/nell_food.png`
- `nell_poses/nell_hello.png`
- `nell_poses/nell_pensive.png`
- `nell_poses/nell_plan.png`
- `nell_poses/nell_zen.png`

### `workout_avatar/`

- `workout_avatar/barbell_biceps_curl.png`
- `workout_avatar/barbell_close_grip_bench_press.png`
- `workout_avatar/barbell_deadlift.png`
- `workout_avatar/barbell_flat_bench_press.png`
- `workout_avatar/barbell_overhead_triceps_extension.png`
- `workout_avatar/barbell_reverse_curl.png`
- `workout_avatar/barbell_romanian_deadlift.png`
- `workout_avatar/barbell_skullcrusher.png`
- `workout_avatar/bench_copenhagen_plank_isometric_hold_short_lever..png`
- `workout_avatar/bench_dumbbell_flat_chest_press..png`
- `workout_avatar/bench_dumbbell_flat_chest_press_alt_01..png`
- `workout_avatar/bench_dumbbell_incline_chest_press..png`
- `workout_avatar/bench_dumbell_hip_thrust.png`
- `workout_avatar/bench_step_up..png`
- `workout_avatar/bodyweight_bird_dog..png`
- `workout_avatar/bodyweight_calf_raise..png`
- `workout_avatar/bodyweight_cat_cow..png`
- `workout_avatar/bodyweight_dead_bug..png`
- `workout_avatar/bodyweight_forward_lunge..png`
- `workout_avatar/bodyweight_glute_bridge.png`
- `workout_avatar/bodyweight_jumping_jack.png`
- `workout_avatar/bodyweight_mountain_climber.png`
- `workout_avatar/bodyweight_push_up.png`
- `workout_avatar/bodyweight_side_plank.png`
- `workout_avatar/bodyweight_squat.png`
- `workout_avatar/bodyweight_standing_side_bend.png`
- `workout_avatar/bodyweight_yoga_dancer_pose.png`
- `workout_avatar/cable_standing_hip_extension_kickback.png`
- `workout_avatar/cable_triceps_pushdown.png`
- `workout_avatar/dumbbell_bent_over_row.png`
- `workout_avatar/dumbbell_biceps_curl.png`
- `workout_avatar/dumbbell_bulgarian_split_squat.png`
- `workout_avatar/dumbbell_forward_lunge.png`
- `workout_avatar/dumbbell_goblet_squat.png`
- `workout_avatar/dumbbell_hammer_curl.png`
- `workout_avatar/dumbbell_lateral_raise.png`
- `workout_avatar/dumbbell_overhead_press.png`
- `workout_avatar/dumbbell_romanian_deadlift_hip_hinge.png`
- `workout_avatar/dumbbell_thruster.png`
- `workout_avatar/machine_lat_pulldown.png`
- `workout_avatar/machine_leg_extension.png`
- `workout_avatar/machine_leg_press.png`
- `workout_avatar/machine_prone_leg_curl.png`
- `workout_avatar/machine_seated_calf_raise.png`
- `workout_avatar/machine_seated_row.png`
- `workout_avatar/resistance_band_lateral_squat.png`
- `workout_avatar/resistance_band_standing_hip_extension.png`
- `workout_avatar/resistance_band_terminal_knee_extension_tke.png`
- `workout_avatar/stability_ball_glute_bridge.png`
- `workout_avatar/stability_ball_hamstring_curl.png`

## Additional filenames present only in `HealthAssistant_image_Pack(2).zip`

- `brand_id/header_intro.png`
- `brand_id/logo.png`
- `brand_id/monochrome_dark.png`
- `brand_id/monochrome_light.png`
- `brand_id/sublogo_dark.png`
- `brand_id/sublogo_light.png`
- `nell_poses/nell-allfours.png`
- `nell_poses/nell-balance.png`
- `nell_poses/nell-exercise.png`
- `nell_poses/nell-food.png`
- `nell_poses/nell-hello.png`
- `nell_poses/nell-pensive.png`
- `nell_poses/nell-zen.png`

## Filename cleanup notes

- `brand_id/logo..png` contains a double period.
- Several workout filenames end in `..png` and should be normalized before asset-catalog integration.
- `workout_avatar/bench_dumbell_hip_thrust.png` uses `dumbell` rather than `dumbbell`.
- The earlier archive mixes hyphenated and underscored Nell-pose filenames. The latest archive uses underscored pose names.
- The eight underscored Nell-pose paths exist in both archives but contain different image versions; the version from `HealthAssistant_image_Pack(3).zip` should be treated as the current source unless explicitly replaced.

## Intended next step

Before integration, copy the selected source images into a preserved source-assets directory, normalize production filenames, export app-ready transparent PNGs where required, and map them to stable names in `Assets.xcassets`.

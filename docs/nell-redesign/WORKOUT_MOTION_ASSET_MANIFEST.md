# Workout Motion Asset Manifest

## Character pack

```text
Style ID: nell_neutral_01
Namespace: WorkoutMotion_NellNeutral01
```

## Visual requirements

- faceless neutral humanoid
- inclusive, non-identifiable appearance
- neutral grey skin treatment
- dark neutral hair
- cream top with forest or moss green clothing accents
- calm Wii-like proportions
- transparent background
- consistent camera, crop, lighting and scale
- start and end poses must remain readable at approximately 54×64 points
- no additional limbs, malformed hands, turtle features or food elements

## Required production images

```text
WorkoutMotion_NellNeutral01_goblet_squat_Start
WorkoutMotion_NellNeutral01_goblet_squat_End

WorkoutMotion_NellNeutral01_bent_over_row_Start
WorkoutMotion_NellNeutral01_bent_over_row_End

WorkoutMotion_NellNeutral01_overhead_press_Start
WorkoutMotion_NellNeutral01_overhead_press_End

WorkoutMotion_NellNeutral01_split_squat_Start
WorkoutMotion_NellNeutral01_split_squat_End

WorkoutMotion_NellNeutral01_plank_row_Start
WorkoutMotion_NellNeutral01_plank_row_End

WorkoutMotion_NellNeutral01_hip_hinge_Start
WorkoutMotion_NellNeutral01_hip_hinge_End

WorkoutMotion_NellNeutral01_side_stretch_Start
WorkoutMotion_NellNeutral01_side_stretch_End

WorkoutMotion_NellNeutral01_yoga_balance_Start
WorkoutMotion_NellNeutral01_yoga_balance_End
```

## Asset catalogue settings

Each name should be an individual image set with:

- universal iOS idiom
- Preserve Vector Data only when supplied as PDF/SVG-compatible vector artwork
- otherwise transparent PNG at 1×, 2× and 3×
- Render As: Original Image
- no baked card background
- restrained or no baked floor shadow

## Future character packs

A future style should use a new namespace rather than replacing the stable movement IDs.

Example:

```text
Style ID: nell_neutral_02
Namespace: WorkoutMotion_NellNeutral02
WorkoutMotion_NellNeutral02_goblet_squat_Start
WorkoutMotion_NellNeutral02_goblet_squat_End
```

Add the style and corresponding records to `WorkoutMotionRegistry`; workout plans and history require no migration.

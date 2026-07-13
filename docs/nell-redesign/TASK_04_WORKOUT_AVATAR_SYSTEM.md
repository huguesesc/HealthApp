# Task 04 — Modular Workout Motion Avatar System

## Status

**Implemented in source with vector fallback figures. Xcode and visual verification pending.**

Detailed report: `IMPLEMENTATION_TASKS_03_04.md`

## Approved direction implemented

The system uses faceless, calm, theme-coloured humanoid figures that remain separate from the tortoise mascot.

- neutral grey skin
- dark neutral hair
- Nell green clothing
- simplified Wii-like proportions
- one-pose or two-pose start/finish presentation
- no extra limbs
- no turtle-human hybrids
- no realistic identifiable person

## Architecture implemented

```text
Health Assistantv2/WorkoutMotion/WorkoutAvatarStyle.swift
Health Assistantv2/WorkoutMotion/WorkoutAvatarEquipment+Codable.swift
Health Assistantv2/WorkoutMotion/WorkoutMotionRegistry.swift
Health Assistantv2/WorkoutMotion/WorkoutMotionView.swift
Health Assistantv2/Train/NellActiveWorkoutContainerView.swift
```

The initial renderer is a SwiftUI `Canvas` fallback. Future raster, vector or 3D character packs can replace the artwork while keeping the same stable movement IDs and screen API.

## Stable movement IDs

```text
goblet_squat
bent_over_row
overhead_press
split_squat
plank_row
hip_hinge
side_stretch
yoga_balance
```

Aliases such as `shoulder press`, `renegade row`, `tree pose`, `RDL` and `good morning` resolve through the registry. Unknown movements receive a generic pose rather than failing.

## Initial style

```text
styleID: nell_neutral_01
skin: neutral grey
hair: dark grey
clothing: forest and moss green
rendering: lightweight vector figure
```

## Placement implemented

- Train overview cards
- workout-plan cards and rows
- plan detail
- exercise detail
- workout history
- workout start/resume picker
- active workout through the Nell container

The motion guide remains compact during an active workout and does not replace the timer or set controls.

## Extensibility

- screen code requests a movement by stable ID or title
- title aliases resolve centrally
- character style is selected by `characterStyleID`
- a missing or unknown movement falls back safely
- artwork replacement does not require a SwiftData migration
- future character packs can be registered without rewriting workout logic

## Tests

`Health Assistantv2Tests/NellNavigationAndWorkoutMotionTests.swift` covers:

- unique stable movement IDs
- alias resolution
- safe unknown-movement fallback
- JSON round-trip of definitions
- character-style fallback

## Verification remaining

- compile Canvas renderer in Xcode
- inspect every pose for anatomical clarity
- test compact row size and active-workout size
- test light and dark mode
- verify Reduce Motion behaviour in surrounding screens
- replace or supplement vector figures with approved production artwork when available

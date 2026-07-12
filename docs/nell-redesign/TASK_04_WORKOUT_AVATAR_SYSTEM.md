# Task 04 — Modular Workout Motion Avatar System

## Goal

Add clear, replaceable exercise illustrations without coupling workout logic to one permanent character set.

## Approved direction

The reference direction uses faceless, calm, theme-coloured humanoid figures with two poses per movement. They are separate from the tortoise mascot.

Visual rules:

- faceless and inclusive
- neutral grey skin tone
- dark neutral hair
- Nell green clothing with restrained accent colours
- simplified Wii-like proportions
- clean light or transparent background
- two-pose start/end presentation where useful
- no extra limbs or malformed anatomy
- no turtle-human hybrids
- no realistic identifiable person

## Data model contract

Workout models keep movement names and optional asset identifiers. Views resolve assets through a registry.

```swift
struct WorkoutMotionAsset: Hashable, Codable {
    let movementID: String
    let characterStyleID: String
    let startAssetName: String
    let endAssetName: String?
}
```

Suggested IDs:

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

## Registry

```text
Health Assistantv2/WorkoutMotion/WorkoutMotionRegistry.swift
Health Assistantv2/WorkoutMotion/WorkoutMotionView.swift
Health Assistantv2/WorkoutMotion/WorkoutAvatarStyle.swift
```

The registry must:

- map stable movement IDs to current assets
- support one-pose and two-pose movements
- support multiple future character packs
- fall back to a neutral SF Symbol or generic movement card
- avoid forcing a SwiftData migration when artwork changes

## Initial character style

```text
styleID: nell_neutral_01
skin: neutral grey
hair: dark grey
clothing: forest/moss green
rendering: soft 2D/3D hybrid illustration
```

## Placement

Use avatars in:

- Train overview cards
- workout-plan rows
- workout detail
- exercise detail
- active workout as a compact motion guide

Do not use them as large decoration inside timers or data-heavy history rows.

## Acceptance criteria

- Replacing an image file does not require changing workout business logic.
- Adding a second character style requires registry data, not rewriting views.
- A missing image never blocks starting a workout.
- Start and end poses are clearly distinguishable.
- Assets remain legible at small row-card size.

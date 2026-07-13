# Nell Full Brand and UI System

This feature converts the existing Health Assistant interface into the Nell product system while preserving the current SwiftData models and health/workout functionality.

## Branch

`feature/nell-full-brand-and-ui-system`

Base: `feature/branded-navigation-core-ui-implementation`

## Product decisions used

- Visible product name: **Nell**
- Descriptor: **Your personal health companion**
- Main navigation: **Today | Log | Coach | Nutrition | Train**
- Primary app icon direction: Shell Bowl mark on deep forest background
- Coach mark: Care Companion sub-logo
- Mascot: restrained tortoise companion used in selected states
- Workout movement visuals: faceless, neutral, theme-coloured humanoid avatars shown as two-pose motion pairs

## Implementation status

1. Brand foundation and asset contract — **implemented in source**
2. Shared Nell component library — **implemented in source**
3. App shell and core screens — **implemented in source**
4. Modular workout motion avatar system — **implemented in source**
5. Active Workout, completion and factual Progress — **implemented in source**
6. Profile, Settings, onboarding and QA preparation — **implemented in source**

Implementation reports:

```text
IMPLEMENTATION_TASKS_01_02.md
IMPLEMENTATION_TASKS_03_04.md
IMPLEMENTATION_TASKS_05_06.md
```

Asset documentation:

```text
WORKOUT_MOTION_ASSET_MANIFEST.md
IMAGE_PACK_MAPPING.md
```

## Implemented product structure

- first-run Nell onboarding
- optional preferred name, goals, training context and movement considerations
- optional Apple Health and Coach connections
- Today overview using recorded values only
- explicit central Log routing for meal, workout, sleep and check-in
- existing Coach engine inside the Nell shell
- Nutrition overview without food photography
- workout plans, exercise details and active-session resume
- modular two-pose workout-motion figures
- focused active-workout frame
- restrained completion state
- factual workout Progress screen
- profile, appearance, privacy, safety and About Nell settings

## Workout-avatar rules

The exercise visuals are not mascot illustrations and must not use realistic people.

- faceless and inclusive
- neutral grey skin tone
- simple Wii-like humanoid proportions
- dark neutral hair
- Nell green clothing and muted accents
- usually two poses: start and end
- no anatomical distortion
- no extra limbs
- no turtle-human hybrids
- no embedded food imagery
- stable movement IDs allow characters and artwork to be replaced without rewriting workout views

## Supplied image pack

The supplied logo, identity-board and tortoise files have been reviewed and mapped to the typed asset registry. Source filenames are documented in `IMAGE_PACK_MAPPING.md`.

The source artwork is retained as production reference. Final in-app exports still require transparent backgrounds, consistent crops and asset-catalog sizing. The workout humanoid system remains separate from the tortoise mascot.

## Remaining merge blockers

The source implementation is complete for the defined six-task feature, but PR #6 remains a draft until the following are verified:

- clean Xcode build
- complete unit-test run
- physical-iPhone regression pass
- active-workout background/resume/completion behaviour
- light and dark mode
- Dynamic Type, VoiceOver and Reduce Motion
- Apple Health denied, empty and connected states
- offline and no-key Coach states
- production transparent logo and mascot exports
- final 1024×1024 App Store icon

The branch must not be described as release-ready until those checks pass.

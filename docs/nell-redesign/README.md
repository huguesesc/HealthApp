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

## Implementation sequence

1. Brand foundation and asset contract — **implemented in source; device verification pending**
2. Shared Nell component library — **implemented in source; device verification pending**
3. App shell and core screens — **implemented in source; device verification pending**
4. Modular workout motion avatar system — **implemented in source; visual verification pending**
5. Active Workout and completion visual redesign
6. Progress, profile, settings, onboarding, production assets, and final visual QA

Each task has its own Markdown specification. Implementation reports are available in:

```text
IMPLEMENTATION_TASKS_01_02.md
IMPLEMENTATION_TASKS_03_04.md
```

## Rules for the workout avatar system

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

## Current status

Tasks 01 through 04 are committed. The application root now uses the Nell five-tab shell, the central Log flow preserves Meal and Workout text, Nutrition and Train have dedicated overview screens, and the workout-motion registry is integrated into plan, exercise, start/resume and active-workout paths.

The branch has not been compiled in the assistant environment or verified on the physical iPhone. Final production raster assets—including the App Store icon, transparent mascot exports and future rendered workout character packs—remain pending asset-catalog integration.

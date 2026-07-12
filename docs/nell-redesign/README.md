# Nell Full Brand and UI System

This feature converts the existing Health Assistant interface into the Nell product system while preserving the current SwiftData models and health/workout functionality.

## Branch

`feature/nell-full-brand-and-ui-system`

Base: `feature/branded-navigation-core-ui-implementation`

## Product decisions used

- Visible product name: **Nell**
- Descriptor: **Your personal health companion**
- Main navigation: **Today | Log | Coach | Nutrition | Train**
- Primary app icon: Shell Bowl mark on deep forest background
- Coach mark: Care Companion sub-logo
- Mascot: restrained tortoise companion used in selected states
- Workout movement visuals: faceless, neutral, theme-coloured humanoid avatars shown as two-pose motion pairs

## Implementation sequence

1. Brand foundation and asset contract — **implemented in source; device verification pending**
2. Shared Nell component library — **implemented in source; device verification pending**
3. Root navigation, product naming, and app icon
4. Today and Coach redesign
5. Nutrition and Log redesign
6. Train, workout plan, and workout-motion avatar system
7. Active Workout and completion states
8. Progress, profile, settings, onboarding, and final visual QA

Each task has its own Markdown specification in this folder. Tasks 01 and 02 also have a detailed implementation report in `IMPLEMENTATION_TASKS_01_02.md`.

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
- asset names are data-driven so characters can be replaced or expanded later without rewriting workout views

## Current status

Task 01 and Task 02 code is committed. The branch has no CI result and has not yet been compiled in Xcode or verified on the physical iPhone. Production raster logo, app-icon, mascot, and workout-avatar exports remain separate from the source contracts and will be integrated in later tasks.

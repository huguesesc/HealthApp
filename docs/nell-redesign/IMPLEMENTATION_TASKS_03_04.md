# Implementation Report — Tasks 03 and 04

## Branch

`feature/nell-full-brand-and-ui-system`

## Status

Implemented in source and pushed to draft PR #6. The code has not been compiled in the assistant environment and has not yet received a physical-device regression pass.

---

# Task 03 — App Shell and Core Screens

## New application root

`RootView` now opens `NellAppShellView`.

The shell implements:

```text
Today | Log | Coach | Nutrition | Train
```

The central Coach control uses the Care Companion mark and remains visually distinct. Log is a modal action flow rather than a permanent empty destination.

## Today

`NellTodayView` provides:

- contextual greeting and restrained mascot
- daily energy, sleep, steps and meal metrics
- Apple Health values only when imported
- quick check-in
- deterministic Coach observation
- streak or local insight
- resumable workout entry

The screen deliberately avoids invented readiness, recovery and hydration values.

## Log

`NellLogSheetView` requires the user to select a category before continuing.

- Meal text passes to `MealEntryView(initialText:)`.
- Workout text passes to `WorkoutLogView(initialFreeformText:)`.
- Sleep and Check-in use dedicated forms.
- Meal and Workout use the existing lightweight structured AI routes.
- Parsed results remain editable and unsaved until explicit confirmation.

This removes the previous defect where central Log silently treated input as a meal and dropped the original text.

## Coach

`NellCoachScreen` adds the branded header and mascot while preserving:

- `ChatEngine`
- Markdown responses
- proposal cards
- explicit write confirmation
- existing profile and repository context

## Nutrition

`NellNutritionView` separates the overview from the entry form.

- today totals
- macro totals
- meal timeline
- recent history
- manual or AI-assisted meal entry
- no food photography

## Train

The new training hierarchy includes:

- `NellTrainHomeView`
- `NellWorkoutPlansView`
- `NellWorkoutPlanDetailView`
- `NellExerciseDetailView`
- `NellWorkoutStartView`
- `NellActiveWorkoutContainerView`

Workout plans, start/resume, history and movement feedback are no longer dependent on Settings as their primary entry point.

---

# Task 04 — Workout Motion Avatar System

## Separation from the mascot

The tortoise remains the wellbeing companion. Exercise technique uses a separate faceless humanoid system.

## Registry

`WorkoutMotionRegistry` maps stable movement IDs and aliases to pose definitions.

Initial IDs:

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

Unknown movement titles receive a generic fallback based on the workout-step type.

## Character style

`WorkoutAvatarStyleRegistry` begins with:

```text
nell_neutral_01
```

The style defines neutral skin, dark hair, Nell green clothing, light shoes and neutral equipment. A future character style can be registered by ID.

## Renderer

`WorkoutAvatarFigure` uses SwiftUI Canvas to render a lightweight faceless figure from joint coordinates. It supports:

- standing
- squat
- hip hinge
- row
- overhead press
- split squat
- plank and plank row
- side stretch
- tree balance

`WorkoutMotionView` provides compact, pair and hero presentations.

## Active-workout integration

`NellActiveWorkoutContainerView` adds a compact movement guide above the existing durable execution screen. Timers, set completion, rest recovery and exactly-once conversion remain owned by the existing active-workout implementation.

## Extensibility

The UI depends on stable movement definitions rather than hard-coded image filenames. Future artwork may be raster, vector or 3D and can be introduced behind the same registry contract without modifying SwiftData workout records.

---

# Tests added

```text
Health Assistantv2Tests/NellNavigationAndWorkoutMotionTests.swift
```

Tests cover stable IDs, aliases, generic fallback, Codable definitions and character-style fallback.

---

# Verification checklist

1. Pull the branch.
2. Build the application target.
3. Run all tests.
4. Open every main tab.
5. Verify Log preserves Meal and Workout input.
6. Start and resume a saved workout.
7. Inspect all eight approved motion definitions.
8. Test small and large iPhones.
9. Test light and dark mode.
10. Test large Dynamic Type and VoiceOver.

The branch should remain draft until those checks pass.

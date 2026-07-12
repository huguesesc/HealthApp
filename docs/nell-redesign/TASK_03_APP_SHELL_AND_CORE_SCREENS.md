# Task 03 — App Shell and Core Screens

## Status

**Implemented in source. Xcode and physical-device verification pending.**

Detailed report: `IMPLEMENTATION_TASKS_03_04.md`

## Navigation implemented

```text
Today | Log | Coach | Nutrition | Train
```

- `NellAppShellView` is now the application root.
- Coach uses the shared Care Companion mark in a raised central control.
- Log opens a focused sheet rather than an empty tab.
- Profile/settings is available from the relevant top bars.
- Main content receives a safe bottom inset.

## Today implemented

- branded greeting and restrained mascot placement
- honest daily metrics from logs and Apple Health summaries
- quick check-in
- deterministic Nell observation
- local streak/insight card
- resumable active-workout card

No readiness, hydration, recovery or other metric is fabricated when the app has no source data.

## Coach implemented

- branded Coach header
- Care Companion identity
- restrained waving companion
- existing Markdown conversation and write-confirmation engine preserved
- Settings access retained

## Nutrition implemented

- today calorie and macro totals
- today meal timeline
- recent meal history
- prominent log-meal action
- editable AI estimate flow
- no food photography or generated food imagery

## Train implemented

- resumable session card
- next workout plan
- saved plan rows
- workout history
- movement feedback
- honest weekly workout count and logged duration
- direct integration with the modular motion-avatar system

## Central Log defect resolved

- category selection is explicit
- Meal and Workout text is preserved into the destination editor
- the lightweight structured model produces an editable draft
- no category is silently guessed
- Sleep and Check-in use dedicated manual forms

## Primary files

```text
Health Assistantv2/Navigation/NellAppShellView.swift
Health Assistantv2/Today/NellTodayView.swift
Health Assistantv2/Coach/NellCoachScreen.swift
Health Assistantv2/Log/NellLogSheetView.swift
Health Assistantv2/Nutrition/NellNutritionView.swift
Health Assistantv2/Train/NellTrainHomeView.swift
Health Assistantv2/Train/NellWorkoutPlansView.swift
Health Assistantv2/Train/NellWorkoutStartView.swift
Sources/Features/Nutrition/MealEntryView.swift
Sources/Features/Workout/WorkoutLogView.swift
Sources/App/RootView.swift
```

## Verification remaining

- clean Xcode build
- full tests
- physical iPhone navigation pass
- keyboard and sheet behaviour
- dark mode
- largest Dynamic Type
- VoiceOver tab order

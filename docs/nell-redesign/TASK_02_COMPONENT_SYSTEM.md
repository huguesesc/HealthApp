# Task 02 — Shared Nell Component System

## Goal

Build reusable visual primitives before restyling screens, so the app does not become a collection of one-off layouts.

## Components

```text
NellScreen
NellCard
NellFeaturedCard
NellMetricTile
NellPrimaryButton
NellSecondaryButton
NellTextField
NellSectionHeader
NellStatusChip
NellProgressRing
NellMiniBarChart
NellEmptyState
NellErrorState
NellConfirmationCard
NellCoachSuggestionCard
NellMascotHero
```

## Design rules

- Warm cream and forest-tinted surfaces.
- Minimal elevation; borders instead of heavy shadows.
- 4-point spacing grid.
- 18-point standard card radius and 24-point featured radius.
- System fonts for app UI; wordmark styling remains separate.
- Dynamic Type and minimum 44-point touch targets.
- Semantic colours tint cards at low opacity rather than colouring full screens.

## States

Each component must define:

- normal
- pressed
- disabled
- loading
- empty
- error where relevant
- reduced-motion behaviour

## Acceptance criteria

- Main screens can be assembled without duplicating card/button styles.
- Components support light and dark mode.
- Components do not require mascot artwork.
- Long text expands vertically without clipping.
- VoiceOver labels exist for non-text controls.

# Phase 4 Implementation Plan — Movement Feedback and Markdown Chat

Date: 2026-07-11
Branch: `feature/movement-feedback-and-markdown-chat`
Base: `feature/active-workout-mode`

## Delivered slices

### 1. Additive persistence

- Add `MovementFeedbackEntry`.
- Store workout, step, set, signal, area, side, impact, adjustment, note, and planned-versus-actual snapshots.
- Register the entity in the shared SwiftData schema.
- Keep existing persisted entities unchanged.

### 2. Repository seam

- Add append-only feedback creation.
- Add session and step reads.
- Add compact `MovementFeedbackSnapshot` values for future assistant context.
- Reuse the existing step-skip operation when the user explicitly records a skipped-step adjustment.

### 3. Active Workout integration

- Add a neutral **Adjust** button for the current step.
- Present the feedback editor as a sheet.
- Show the most recent feedback inline.
- Preserve pause, timer, set, navigation, and completion behavior.

### 4. History UI

- Add Settings navigation.
- Add chronological feedback history.
- Add a read-only detail screen with exact context and planned-versus-actual values.

### 5. Markdown assistant bubbles

- Add `MarkdownMessageView` using native attributed-string Markdown parsing.
- Render assistant messages through that view.
- Keep user messages verbatim and proposal cards structured.
- Enable text selection and link tinting.

### 6. Tests

- Test exact execution snapshots.
- Test user-reported flags and compact snapshots.
- Test skipped-step behavior.
- Test Markdown parsing removes source markers from displayed characters.

## Required Mac verification

```bash
xcrun simctl list devices available
SIMULATOR="<AVAILABLE IPHONE NAME>"

rm -rf build/MovementFeedbackDerivedData

xcodebuild \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -destination "platform=iOS Simulator,name=${SIMULATOR},OS=latest" \
  -derivedDataPath "$PWD/build/MovementFeedbackDerivedData" \
  clean build

xcodebuild \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -destination "platform=iOS Simulator,name=${SIMULATOR},OS=latest" \
  -derivedDataPath "$PWD/build/MovementFeedbackDerivedData" \
  test
```

## Manual checks

1. Start a saved plan and open **Adjust** on the current step.
2. Save each category of feedback, including body area and side.
3. Record **Skipped this step** and confirm the workout advances once.
4. Relaunch and confirm feedback history persists.
5. Ask the assistant for a reply containing bold, a list, inline code, and a link.
6. Confirm raw `**`, backticks, and link syntax are not shown as source markup.
7. Regression-test timers, completion logging, meal proposals, workout-plan proposals, and Apple Health.

## Deferred

- in-workout assistant questions and coaching;
- automatic plan adaptation;
- model-written profile or feedback changes;
- notifications, Live Activities, watchOS, payments, credits, and backend work.

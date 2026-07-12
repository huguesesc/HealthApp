# 0010 - Movement feedback and Markdown chat

Date: 2026-07-11

## Git provenance

- Base branch: `feature/active-workout-mode`
- Implementation branch: `feature/movement-feedback-and-markdown-chat`
- Main was not modified or merged.

## Product boundary

This branch implements the next planned slice after Active Workout Mode:

- neutral movement feedback during a specific workout step;
- exact workout, exercise, set, and planned-versus-actual snapshots;
- read-only feedback history;
- rendered Markdown for assistant replies.

It does not implement in-workout AI coaching, diagnosis, rehabilitation advice, automatic plan adaptation, profile rewriting, payments, backend work, or watchOS.

## New files

- `Health Assistantv2/MovementFeedback/MovementFeedbackModels.swift`
- `Health Assistantv2/MovementFeedback/HealthDataRepository+MovementFeedback.swift`
- `Health Assistantv2/MovementFeedback/MovementFeedbackViews.swift`
- `Sources/Features/Chat/MarkdownMessageView.swift`
- `Health Assistantv2Tests/MovementFeedbackAndMarkdownTests.swift`
- `docs/superpowers/specs/2026-07-11-movement-feedback-and-markdown-design.md`
- `docs/superpowers/plans/2026-07-11-movement-feedback-and-markdown.md`
- this journal entry.

## Modified files

- `Health Assistantv2/ActiveWorkout/ActiveWorkoutViews.swift`
- `Sources/Features/Chat/ChatView.swift`
- `Sources/Features/Settings/SettingsView.swift`
- `Sources/Persistence/PersistenceController.swift`

## Persistence decisions

`MovementFeedbackEntry` is an additive SwiftData entity. Existing entities were not changed. Feedback stores snapshot IDs and display values rather than relationships to mutable workout rows.

Entries are append-only user reports. They do not become `HealthConsideration` rows automatically, and the assistant receives no write tool for them.

## Active Workout behavior

The current step now has an **Adjust** button. The editor records:

- observation;
- impact;
- optional body area and side;
- adjustment made;
- optional note;
- exact planned-versus-actual context.

The latest adjustment appears below the current step. Selecting **Skipped this step** also invokes the existing skip operation; other choices are recorded without silently changing exercise parameters.

## Markdown behavior

Assistant text bubbles now render through native `AttributedString(markdown:)` in `MarkdownMessageView`. User text remains verbatim. Structured confirmation cards remain normal SwiftUI views.

Text selection is enabled, and Markdown links use the app tint.

## Verification status

The code and tests are committed through GitHub, but this environment cannot run Xcode, SwiftData migration, SwiftUI, or the simulator. No build or test success is claimed.

Required Mac checks:

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

## Manual verification checklist

1. Preserve existing Phase 1–3 data during migration.
2. Start a plan and save feedback from **Adjust**.
3. Verify area, side, impact, action, note, and set context.
4. Verify **Skipped this step** advances once.
5. Background and relaunch; confirm feedback remains.
6. Open Settings → Movement feedback and inspect details.
7. Ask the assistant for bold, bullets, inline code, and a link.
8. Confirm Markdown renders rather than exposing source markers.
9. Regression-test Active Workout timers and exactly-once completion logging.
10. Regression-test meal/workout-plan proposals and Apple Health.

## Known risks

- The additive SwiftData migration has not been tested against the user's existing store.
- Native SwiftUI attributed-string Markdown does not provide the full layout control of a third-party Markdown renderer; visual review is required for long lists and code-heavy replies.
- The new files rely on the existing file-system-synchronized Xcode groups for target inclusion.
- The large Active Workout and Chat view files were modified and need a clean compiler pass.

## Next planned phase

Add the in-workout assistant and compact similar-history context. It should read current step context, user-confirmed profile data, recent feedback, and recovery summaries, then provide conservative adjustments without diagnosis or autonomous writes.

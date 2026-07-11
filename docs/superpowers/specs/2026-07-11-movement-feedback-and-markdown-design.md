# Movement Feedback and Markdown Chat — Phase 4 Design

Date: 2026-07-11
Status: implemented on `feature/movement-feedback-and-markdown-chat`; Mac verification required
Base: `feature/active-workout-mode`

## Objective

Add a neutral **Adjust** flow to Active Workout Mode and render assistant replies as formatted Markdown instead of exposing raw Markdown characters.

This phase records what the user reports during a specific exercise. It does not diagnose, prescribe rehabilitation, automatically rewrite the health profile, or let the model modify feedback.

## Movement-feedback behavior

During an in-progress workout, the current exercise shows an **Adjust** button. The form records:

- exact workout, step, and current set snapshots;
- what the user noticed: harder than expected, too easy, less controlled, one side felt different, tight, weak, unsteady, uncomfortable, equipment issue, or other;
- optional body area and side where relevant;
- whether it was merely noticed, changed the movement, or stopped the exercise;
- what adjustment the user made;
- an optional free-text note;
- planned-versus-actual reps, load, and duration at the time of the report.

Entries are append-only user reports. They are intentionally separate from `HealthConsideration`, because a workout observation is not automatically a durable profile fact.

Selecting **Skipped this step** records the feedback and performs the existing skip action. Other adjustment choices are recorded without silently changing load, range, or exercise selection; the user applies those changes through the normal workout controls.

## Data model

`MovementFeedbackEntry` is a new additive SwiftData entity. It stores stable snapshot identifiers and strings rather than relationships to mutable workout rows. This preserves history if a plan or execution is later edited.

The model includes `userReported = true` so future assistant context can distinguish confirmed reports from model inference.

`HealthDataRepository+MovementFeedback.swift` owns writes and compact snapshots. Phase 4 does not expose a model-write tool to the assistant.

## UI

- Active Workout Mode: **Adjust** button under the current step.
- The most recent adjustment for that step appears inline.
- Settings → Movement feedback: read-only history and detail screens.
- Copy remains neutral and explicitly states that entries are not diagnoses or treatment advice.

## Markdown rendering

Assistant bubbles now use `MarkdownMessageView`, backed by Foundation `AttributedString(markdown:)` and SwiftUI `Text`.

The renderer supports native inline Markdown such as:

- headings and paragraph emphasis where supported by SwiftUI text rendering;
- bold and italic text;
- inline code;
- links;
- line breaks and list presentation supplied by the native attributed-string parser.

User messages remain verbatim text. Proposal cards remain structured SwiftUI views rather than Markdown.

## Safety boundary

- Feedback is the user's observation, not a medical assessment.
- No diagnosis, condition inference, treatment, or rehabilitation prescription.
- No automatic promotion into the long-term profile.
- No model-written movement feedback.
- No automatic plan adaptation in this phase.

## Out of scope

- in-workout assistant questions;
- similar-history coaching responses;
- deterministic stop-and-review coaching rules;
- automatic exercise substitution;
- automatic health-profile proposals;
- Live Activities, watchOS, HealthKit workout writing, StoreKit, credits, or backend work.

## Verification requirements

Before merge, run a clean simulator build and tests, then manually verify:

- migration with existing Phase 1–3 data;
- Adjust from an active exercise;
- body-area and side fields;
- skipped-step adjustment advances correctly;
- feedback survives relaunch;
- history and detail screens;
- Markdown bold, links, lists, inline code, and plain-text fallback;
- existing meal, workout-plan, Active Workout, and HealthKit behavior.

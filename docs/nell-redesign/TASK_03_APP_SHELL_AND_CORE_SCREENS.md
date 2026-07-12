# Task 03 — App Shell and Core Screens

## Goal

Apply the Nell information architecture and concept-board hierarchy to the main navigation and highest-traffic screens.

## Navigation

Final structure:

```text
Today | Log | Coach | Nutrition | Train
```

- Coach uses the Care Companion mark in a raised central control.
- Log opens an action-focused sheet.
- Profile/settings is accessed from the appropriate top bar rather than occupying a tab.
- Content receives a bottom inset so the raised Coach control never hides the last row.

## Today

Rebuild around:

- concise greeting and daily state
- small contextual mascot
- daily overview metrics
- one Coach observation
- quick check-in
- relevant insight or resume-workout card

## Coach

Rebuild around:

- Care Companion identity
- restrained mascot greeting when the thread is empty
- suggested prompts
- Markdown response blocks
- confirmation cards for write actions
- specific thinking/loading state

## Nutrition

Rebuild as a data-led overview rather than only a form:

- today summary
- calories/macros
- meal timeline
- recent meal history
- prominent log-meal action
- AI estimate review

## Train

Rebuild as the training home:

- current/resumable session
- next plan
- saved plans
- workout history
- movement feedback
- recovery/readiness context

## Central Log defect

The current central Log input must be fixed so the entered text is preserved and routed deliberately. Until a general classifier exists, the user must explicitly select Meal or Workout before analysis.

## Acceptance criteria

- All five destinations are visually coherent.
- Training tools are not hidden in Settings.
- Nutrition is not merely the old logging form.
- Log never silently assumes a category.
- Existing records and navigation links remain functional.

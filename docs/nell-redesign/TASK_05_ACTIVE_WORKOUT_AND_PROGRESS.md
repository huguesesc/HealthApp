# Task 05 — Active Workout, Completion, and Progress

## Goal

Make workout execution the most focused and dependable area of the product while adopting the Nell visual system.

## Active Workout

- Deep forest focused surface.
- Current exercise, set number, reps/load/time, and rest remain visible.
- Large monospaced metrics.
- Maximum two primary actions at once.
- Compact two-pose motion avatar guide.
- No full tortoise mascot during sets or timers.
- Movement feedback remains available through a neutral Adjust action.
- Pause, background, and resume state must remain recoverable.

## Exercise Detail

- Two-pose avatar panel.
- concise setup and execution cues
- muscles worked as optional chips
- equipment and side information
- clear Add to Workout or return action

## Completion

- completed session summary
- duration, exercises, sets, and available health aggregates
- restrained success state
- tortoise celebration permitted only here
- no exaggerated reward pressure

## Progress

Build an honest summary from data that currently exists:

- workouts completed
- duration or volume where calculable
- streak
- recent movement feedback
- weight trend when available

Do not fabricate a recovery score or readiness metric until a deterministic calculation exists.

## Acceptance criteria

- Existing active-workout persistence and exactly-once workout conversion remain intact.
- The avatar guide does not interfere with controls.
- No fake analytics are presented as live data.
- Completion works without internet.
- Dark mode remains high contrast.

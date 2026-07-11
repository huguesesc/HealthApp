# Active Workout Mode — Phase 3 Design

Date: 2026-07-11
Status: implemented on `feature/active-workout-mode`; Mac verification required
Base: `feature/structured-workout-plans` @ `8fb7d07`

## Objective

Turn a saved `WorkoutPlan` into a durable, step-by-step workout execution that can survive navigation, backgrounding, and app interruption while keeping planned and actual values separate.

This phase executes plans. It does not add movement-feedback classification, in-workout AI coaching, diagnosis, payments, watchOS, or live HealthKit workout recording.

## User flow

1. Open Settings → Start or continue workout.
2. Select a saved plan with at least one step.
3. The app snapshots the plan and starts a durable execution.
4. Complete sets, run timers, record actual reps/load/distance, skip or reopen steps, and move backward or forward.
5. Pause and resume the whole workout.
6. Finish with perceived effort and notes.
7. The app creates one existing `WorkoutSession`, preserving dashboard, streak, rollup, and history behavior.

An unfinished execution for the same plan is resumed rather than duplicated.

## Persistence

Two additive SwiftData entities are introduced:

### ActiveWorkoutSession

- identity and timestamps;
- status: in progress, paused, completed, abandoned;
- source plan ID plus title, goal, location, and target-effort snapshots;
- current step index;
- accumulated active time plus current active-segment timestamp;
- rest countdown start/end timestamps;
- completion effort and notes;
- guard preventing duplicate legacy workout logs;
- cascade-owned execution steps.

### ActiveWorkoutStep

- source plan-step ID and explicit order;
- copied type, title, instruction, planned volume/time/distance/load/rest/side/equipment/notes;
- status: pending, active, completed, skipped;
- actual sets, reps, time, distance, load, and notes;
- persisted timer start and accumulated seconds.

Plan edits after workout start cannot rewrite execution history.

## Timer model

Timers are timestamp based rather than tick-count based:

- the UI redraws once per second;
- elapsed values are derived from persisted start dates;
- step timers continue correctly after backgrounding;
- pause converts the active interval to accumulated seconds;
- rest uses an absolute end date and stores remaining time when the whole workout is paused;
- no background thread is required.

Local notifications and watch complications remain future work.

## Step execution

- Repetition-based steps expose current set, actual reps, actual load, and Complete set.
- Rest starts between sets when configured.
- Timed steps expose start, pause, reset, countdown/count-up display, and completion.
- Distance steps record actual distance.
- All steps support Skip and Done.
- Back and Next navigate the copied execution steps.
- Completed or skipped steps can be reopened.

## Completion integration

Finishing creates exactly one existing `WorkoutSession`:

- title becomes workout type;
- elapsed active time becomes duration;
- completion effort becomes perceived effort;
- completed rep-based execution steps become `ExerciseSet` rows;
- `HealthDataRepository.addWorkout` records the normal activity event;
- today's rollup is refreshed.

Ending early keeps the execution history but does not create a completed workout log.

## Safety and scope

This phase is mechanical execution only. It does not interpret discomfort, infer injury, prescribe rehabilitation, modify the health profile, or automatically alter plans. The neutral Adjust / movement-feedback flow remains Phase 4.

## Verification requirements

Before merge, verify on macOS/iOS:

- additive migration from the Phase 2 store;
- start, pause, resume, background and relaunch recovery;
- set completion and rest countdown;
- timed step start/pause/reset;
- skip, reopen, back and next;
- final effort and notes;
- exactly one legacy workout log per completion;
- ending early creates no completed workout log;
- existing meal, workout, chat, HealthKit, profile, location, and plan behavior remains intact.

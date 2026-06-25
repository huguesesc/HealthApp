# Roadmap

Staged, testable modules. Each milestone should leave the app runnable.

## M0 — Skeleton ✅ (done)

- Project structure, docs, lint/format configs, XcodeGen spec
- SwiftData models, `AIClient` protocol + stub
- Placeholder screens

## M0.5 — Architecture hardening ✅ (done, overnight pass)

- SwiftData local store stabilized for the simulator build
- `HealthDataRepository` as the cross-module read/write seam
- `DailyRollup` compact daily-history layer
- `ActivityEvent` stream + `RewardsEngine` stub
- AI protocol expanded with clean stubs (parse meal/workout, summarize, assistant
  Q&A, future image/voice)

## M1 — Local logging ✅ (runs in simulator)

- Meal entry (text + optional manual macros) + history
- Workout log (type, effort, duration, sets) + history
- Sleep entry (bedtime/wake/quality/naps/tiredness) + history
- Daily check-in (energy/mood/soreness/focus/stress/note) + history
- Dashboard: today's status, streak, latest rollup, entry points
- All offline, all persisted, writes routed through the repository

## M2 — AI interpretation (next)

- Enable `ClaudeAIClient` via `AIClientFactory` (key in Keychain)
- Meal text → estimate; one-tap daily summary into `DailyRollup.summaryText`
- Central assistant question box over `RollupSnapshot` history
- Hedged, safety-reviewed prompts

## M3 — Screen Time (priority feature; real device + entitlement)

- Family Controls authorization, picker, thresholds
- App Group container and entitlements wired for real-device builds
- DeviceActivityMonitor extension → coarse signal via App Group
- Rollup + summary consume the coarse signal
- Later: enforcement (shields), overrides feeding the rewards engine

## M4 — Apple Health (read-only, opt-in)

- HealthKit: steps, workouts, active energy, sleep, resting HR, body weight
- Requires paid Apple Developer Program + per-type permission + privacy review
  (see the 5.1.3 compliance note in architecture.md)

## Later / research

- Rewards/streak rewards (incl. screen-time currency), reminders, widgets
- Voice logging (Apple Speech → parseWorkout)
- Premium tier + backend proxy (photo estimation)
- Smart alarms / sleep-cycle — research only, not committed

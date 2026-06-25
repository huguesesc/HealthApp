# 0002 — Overnight development pass

Date: 2026-06-23

Scope: architecture hardening + M1 local logging + dashboard + AI stubs, per the
product-direction update. No AI calls, no Screen Time enforcement, no premium, no
voice/image — all deferred by constraint.

Update 2026-06-26: the App Group-backed SwiftData store described below was not
kept for the M1 simulator baseline because it crashed without entitlements in the
manual Xcode project. See `journal/0003-m1-simulator-stabilization.md`; current M1
uses the default local SwiftData store.

## Done

**Phase 1 — architecture hardening**
- SwiftData store now targets the App Group container (`PersistenceController`),
  with a safe fallback to the local store when the entitlement is absent.
- `HealthDataRepository` added as the cross-module read/write seam; writes also emit
  `ActivityEvent`s.
- `DailyRollup` model added (compact daily history); `DailySummary` removed (folded
  in).
- `ActivityEvent` model + `RewardsEngine` stub (pure streak logic).
- `DailyCheckIn` gained a `note` field.

**Phase 2 — M1 screens**
- Nutrition: text + optional manual macros + history.
- Workout: list + add sheet with dynamic set entry + history.
- Sleep: split into its own screen (bedtime/wake/quality/naps/tiredness) + history.
- Check-in: energy/mood/soreness/focus/stress/note + history.

**Phase 3 — Dashboard**
- Today's status, headline streak (from `RewardsEngine`), latest rollup summary,
  entry points to all modules. Refreshes today's rollup on appear.
- Navigation reworked: `RootView` = one `NavigationStack` with the dashboard as
  home (replaced the old `RootTabView`).

**Phase 4 — AI foundation**
- `AIClient` expanded: `parseMeal`, `parseWorkout`, `summarizeDay`, `ask`,
  `estimateMeal(image:)` (future). `StubAIClient` implements all; `ClaudeAIClient`
  implements the text ones and throws `notImplemented` for image.
- `AIClientFactory` returns the stub by default. `VoiceTranscriber` seam stubbed
  (Apple Speech planned). Backend/proxy fit documented.

**Phase 5 — Screen Time**
- `docs/screen-time.md` written (capabilities, hard limits, isolation guarantee).
- Module untouched functionally; `ScreenTimeView` de-nested for the new nav.

## Open questions / still pending

- Nothing compiled — authored on Windows. First build on a Mac will surface fixes.
- App Group identifier + Family Controls entitlement + Apple Team still placeholders.
- M2 (turn on Claude) and real Screen Time wiring are the next real milestones.

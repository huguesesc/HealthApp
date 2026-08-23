# Product honesty audit

Date: 2026-08-23 · Scope: every user-visible health/fitness claim and metric
in reachable surfaces, searched for the risk vocabulary (readiness, recovery,
score, risk, target, calories, recommended, optimal, healthy, confidence,
diagnos-) plus manual review of each displayed metric's source/definition/
units/missing-data behavior.

## Verdict

**Nell's baseline honesty is unusually strong.** Every hit on clinical
vocabulary is a *disclaimer*, the Progress screen explicitly denies inferring
readiness/recovery/health status from missing data, Nutrition states it does
not invent targets, and no fake composite scores exist anywhere.

## Metric-by-metric provenance table

| Surface metric | Source | Missing-data behavior | Verdict |
|---|---|---|---|
| Today · Energy "4/5" | self-reported check-in | "—" + "Not checked in" | honest |
| Today · Sleep | Apple Health hours → logged bedtime/wake → perceived quality → bare "Logged" | "—" + "No recent entry"; detail line names the source of whichever value shown | honest (source-labeled) |
| Today · Steps | Apple Health rollup | "—" + "Apple Health not synced" | honest |
| Today · Meals count/kcal | today's Meal records | "No calorie total" when kcal unknown but meals exist — never fabricates 0 | honest |
| Today · streak | local ActivityEvent consecutive-day computation; headline only, never a score | explicit "No current logging streak" | honest |
| Today · Insight text | AI daily summary **when present** | fallback text is factual/local | **gap fixed this phase**: AI prose now carries a "Generated from today's logs by the assistant…" attribution caption |
| Nutrition tiles | sum of logged macros only | "—"/"Logged total"; disclaimer: no invented targets | exemplary |
| Train weekly Workouts/Duration | completed sessions this week | "—" + "Completed this week"/no-duration wording | honest |
| Progress volume | Σ reps × recorded load | "—" + "No weighted sets recorded" | honest |
| Progress week-over-week | factual delta copy ("N fewer…") | neutral same-count wording | honest |
| Active Workout % progress | persisted step/set state | n/a | honest |
| Completion claims | container gates on `workoutLogCreated` exactly-once flag | inner finished card previously claimed completion on status alone — **fixed this phase** to require durability ("Finishing workout…" meanwhile) | fixed |
| Meal proposal card | model estimate with "~" prefixes, per-item grams/kcal/macros, `· confidence low/medium/high`, persisted uncertaintyNote | "No estimate provided" branch | acceptable: estimates are visually hedged and confidence is the model's own label; kept under watch (P3: consider renaming to "estimate confidence") |
| Plan proposal card | validated steps incl. preserved custom movements | demoted customs keep supplied titles (never catalogue-endorsed) | honest per demotion audit |

## Search-term findings

- `diagnos-`: 10 occurrences, all disclaimers ("does not diagnose…").
- `readiness` / `recovery score` / `health score` / `risk`: appear only inside
  the Progress disclaimer denying such inference.
- `recommended` / `optimal` / `healthy`: zero user-facing hits.
- `guarantee`: two disclaimer uses ("not a guarantee…").
- `confidence`: model-estimate label on meal cards + system prompt enum;
  surfaced with tilde-hedged numbers.
- `calorie target`: absent; Nutrition explicitly says goals appear only when
  the user sets them.

## Fixed this phase

1. AI summary attribution caption on Today's insight card.
2. Completion claim gating aligned to durable write (see backlog AW-2).

## Watchlist (no change without product decision)

- Estimate-confidence chip naming on meal cards (P3).
- `"Saved progress · <elapsed>"` resume-card phrasing asserts persistence
  before tap; factually true (timestamp-based), left as-is.

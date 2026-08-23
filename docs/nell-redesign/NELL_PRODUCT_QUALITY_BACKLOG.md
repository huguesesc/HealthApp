# Nell product quality backlog

Date: 2026-08-23 · Phase 3 baseline `ad8c04a`. Findings from the whole-app
product map, design-system audit, and screen inventories. P0 = broken/unsafe,
P1 = serious UX or core-flow weakness, P2 = worthwhile polish, P3 = later.

| ID | Area | Problem | User impact | Sev | Conf | Solution | Cost | Visual verify | Status |
|---|---|---|---|---|---|---|---|---|---|
| CONV-1 | Nell conversation | Transcript wiped on every tab switch (engine created per ChatView.onAppear; shell rebuilds destination) | Users lose coaching context constantly | **P0** | certain | Shell owns one engine per session, injected into ChatView | S | yes | **FIXED** (`6969410`) |
| DS-1 | Design system / chat | Conversation uses system grays instead of Nell surfaces | flagship screen reads generic, background shifts mid-app | **P1** | certain | Nell surfaces/borders/palette in transcript+composer | S | yes | **FIXED** (`6969410`) |
| DS-2 | Chat loading state | Plain spinner while branded Reduce-Motion-aware indicator exists unused | missed brand moment; duplicated language | **P1** | certain | use NellThinkingIndicator | XS | yes | **FIXED** (`6969410`) |
| CHAT-2 | Chat empty state | Suggestions were decorative text | users miss the fastest path in | **P1** | certain | tappable 44pt rows that send directly | XS | yes | **FIXED** (`6969410`) |
| NAV-1 | Nutrition tab | No path to Profile/Settings from this destination | inconsistent shell contract | **P1** | certain | add logo button to toolbar | XS | yes | **FIXED** (`a3b03d5`) |
| AW-2 | Active Workout | Inner finished card claims "Workout completed" on status alone, racing the durable write gate | premature completion claim violates product honesty rule | **P1** | certain | gate label on workoutLogCreated; show "Finishing workout…" meanwhile | XS | yes | **FIXED** (`a3b03d5`) |
| TR-3 | Train empty states | Plan-less states are dead-end text | new users stuck at first run | **P1** | certain | "Open plan manager" action on both empty states | XS | yes | **FIXED** (`a3b03d5`) |
| HON-1 | Today insight | AI-generated daily summary shown as unlabeled prose | overstates certainty of generated text | **P1** | certain | attribution caption under AI summaries | XS | yes | **FIXED** (`2952fd5`+) |
| A11Y-1 | Train/ActiveWorkout | Zero accessibility modifiers across Train files; unlabeled icon menu + progress bars in execution | VoiceOver unusable on core flows | **P1** | high | label icon-only controls, ProgressView values, combine rows | M | simulator/VoiceOver | open |
| A11Y-2 | Legacy entry forms | Meal/Sleep/CheckIn/WorkoutLog forms have no a11y pass | logging is a daily flow | **P1** | high | labels/hints/headers sweep | M | yes | open |
| SET-1 | Settings root | Stock Form chrome vs branded cards elsewhere; Apple Health connection state resets on view recreation | settings feels template-y; Health status unreliable | **P1** | high | persist last-sync date (AppStorage) + branded section headers | M | yes | open |
| ONB-1 | Onboarding | Integrations page promises value without enabling anything; no API-key setup step despite being required for flagship features | false expectation at first run | **P1** | medium | defer: reword copy to "optional, set up anytime in Settings" | S | yes | open |
| PROF-1 | Profile editing | Fields bind live; Save only timestamps — edits exist before Save with no revert | user belief that discarding exists | **P2** | certain | either explicit draft copy or rename button to "Update saved profile" | S | yes | open |
| NUT-1 | Nutrition list | Meal rows not tappable; recent-history section vanishes silently when empty | cannot review/edit past entries; layout jump | **P2** | certain | row detail sheet (read-first), keep section header with mini empty line | M | yes | open |
| PLAN-1 | Plan detail | Archived plans route into legacy editor bypassing review screen | inconsistent mental model | **P2** | high | route archived rows to same detail view | S | yes | open |
| TR-4 | Train home | Five equal-weight tool links compete; catalogue link sits above start-workout | diluted hierarchy | **P2** | medium | group tools under one section header, order Start→History→Catalogue→Log | S | yes | open |
| DS-3 | Typography tokens | FontToken fixed sizes don't track Dynamic Type while legacy system styles do | accessibility inversion between screens | **P1** | certain | switch tokens to relative styles (`.relativeTo`) behind visual QA | M | mandatory | open (queued for screenshot-verified pass) |
| DS-4 | Settings branding | See SET-1 chrome half | — | P2 | certain | shared branded Form wrapper | M | yes | merged into SET-1 |
| DS-6 | Empty-state idioms | Three idioms (NellEmptyState / ContentUnavailableView / ad-hoc) | inconsistent tone | **P2** | certain | migrate touched screens only | Ongoing | yes | policy set |
| DS-7 | Magic numbers | Chat radii/paddings untokenized | drift risk | **P2** | certain | tokenize during next chat touch | XS | no | partial (bubbles now bordered) |
| MASC-1 | Mascot placement | Success pose falls back to vector art (no imageset); unused poses declared | completion moment weaker than designed | **P2** | certain | HR-10 decision then asset drop | XS after art | yes | blocked on HR-10 |
| DEAD-1 | Dead code | DashboardView(+ScreenTimeView), legacy WorkoutStartView compiled but unreachable | build time/maintenance noise | **P2** | certain | separate approved cleanup commit | S | no | awaiting approval |
| CONV-2 | Conversation persistence | Nothing survives relaunch (session-only after CONV-1 fix) | users expect chat history like Messages | **P3→PD** | certain | needs persistence-model decision (transcript store) + privacy wording | L | yes | **decision queue PD-1** |
| HK-1 | Apple Health sync | Manual-only sync; no automatic periodic import | stale Today tiles without manual action | **P3** | certain | background delivery entitlement already present; schedule design needed | M | n/a | open |
| MEAL-2 | Estimator | "Lightweight estimator" unnamed in UI copy | vague provenance | **P3** | medium | name it or fold into Nell voice | S | yes | open |

## Decision queue (product owner)

- **PD-1**: Persist conversation transcripts across launches? Requires new
  SwiftData models + retention/privacy wording. Not started without approval.
- **PD-2**: Adopt lossless PNG recompression pipeline change (HR-11).
- **PD-3**: Rename meal-card confidence chip to "estimate confidence"? (P3.)

## Implemented this phase so far

CONV-1, DS-1, DS-2, CHAT-2, NAV-1, AW-2, TR-3, HON-1 — all small commits,
each CI-verified.

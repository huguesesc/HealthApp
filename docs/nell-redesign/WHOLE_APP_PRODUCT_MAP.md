# Whole-app product map

Date: 2026-08-23 · Phase 3 baseline at `ad8c04a`. Classification of every
meaningful surface, verified in source. Reachability = traceable from app
entry (`RootView` → shell) on a DEBUG or Release install.

## Composition facts

- Entry: `HealthAssistantApp` → `PersistenceController.shared.container`
  (SwiftData `HealthAppSchemaV2`, 17 models) → `RootView`.
- Gate: `@AppStorage("nell.onboarding.completed")`; replay exists in Settings.
- Shell: custom bottom bar — Today | Log | **Nell** | Nutrition | Train.
  Log is an ACTION: it presents `NellLogSheetView` (detents medium/large)
  instead of selecting a tab. Each destination owns its own NavigationStack.

## Screen-by-screen map

| Surface | Route | Status | Notes |
|---|---|---|---|
| Onboarding (5 pages) | gate | REACHABLE, partial | Goals→name/context→movement notes→integrations info; saves drafts→`NellOnboardingProfileSynchronizer` writes HealthProfile+HealthConsideration once (migration key). Replay works. No Health permission ask, no API-key entry step (informational only). |
| Today | tab 1 | REACHABLE, coherent | Greeting+mascot wave → resume card → 4-tile overview (Energy/Sleep/Steps/Meals) → quick check-in → observation card → streak/summary insight. Honest labeling throughout ("Only values available…"). Empty day degrades to "—" placeholders; no loading/error UI needed (local data). |
| Log sheet | action | REACHABLE, minimal | 4 options (meal/workout/sleep/check-in) → legacy entry screens. No header branding, only "Done". |
| Meal logging | sheet/nav | REACHABLE | `MealEntryView`: free-text + optional lightweight estimator draft → structured review before save. |
| Workout logging | nav | REACHABLE | `WorkoutLogView`: structured sets entry with review list. |
| Sleep / check-in | nav | REACHABLE | Simple structured forms. |
| Nell conversation | tab 3 | REACHABLE — **ephemeral** ⚠ | `ChatEngine` created per `ChatView.onAppear`; shell rebuilds `NavigationStack` on each tab selection ⇒ transcript is wiped by leaving the tab and on relaunch. Only confirmed proposals persist. Visual language diverges from Nell (system grays, plain spinner, non-tappable suggestions). |
| Proposal review | inline cards | REACHABLE, strong | Save/Edit/Discard footers; plan editor sheet with full step editing; nothing persists before explicit confirm. |
| Nutrition | tab 4 | REACHABLE, sparse-honest | 4 honest tiles ("—"/"Logged total"), meal timeline, disclaimer about not inventing targets. Gaps: no settings access from this tab, meal rows not tappable, recent-history section vanishes silently when empty. |
| Train home | tab 5 | REACHABLE, crowded-equal | Resume hero → plans → tools grid (catalogue/start/history/log) → weekly metrics. Empty states lack actions. Zero accessibility modifiers in file. |
| Exercise Catalogue | Train→tool | REACHABLE, new | Search/filters/detail with written-first guidance and media fallback chain. |
| Exercise detail | catalogue/plans | REACHABLE | Consumer-appropriate; developer metadata lives in DEBUG gallery. |
| Plan detail/review | Train | REACHABLE | Header meta, numbered steps w/ planned targets, Start CTA; archived rows bypass detail into legacy editor (inconsistent); assistant badge present. |
| Locations/equipment | Settings | REACHABLE | Editor with quick suggestions; availability toggles; save semantics documented inline. |
| Active Workout | multiple entries | REACHABLE, engine solid | Durable timestamp-based resume; exactly-once conversion guarded. Presentation issues: two competing completion claims (container gates on `workoutLogCreated`, inner `finishedCard` claims completion on status alone); icon-only menu unlabeled; progress view unlabeled inside legacy screen. |
| Completion overlay | active workout | REACHABLE | Shown only after durable write (correct gate). Mascot success pose falls back to vector art (HR-10). |
| Execution history | Train | REACHABLE | Continue/Recent split; factual summaries incl. abandoned-without-record wording. |
| Progress | Train | REACHABLE, exemplary honesty | Week tiles + 7-day bars + explicit "does not infer readiness…" disclaimer. |
| Profile | Settings→ | REACHABLE | Live-binding Form; Save timestamps rather than commits (edits exist pre-Save — mild honesty wrinkle). |
| Appearance | Settings | REACHABLE | System/Light/Dark writing `nell.appearance`; accessibility section is informational text only. |
| Apple Health | Settings | REACHABLE | Connect/Sync buttons; status line resets on view recreation (not durable). |
| API key/offline | Settings+Chat | REACHABLE | Keychain storage; clear error strings for 401/network/no-key. |
| Privacy/safety | Settings | REACHABLE | Informational links + disclaimers. |

## Dead code inventory (compiled but unreachable)

- `DashboardView` (+ its embedded `ScreenTimeView`) — legacy home, preview-only.
- `WorkoutStartView` (legacy) — superseded by `NellWorkoutStartView`.
- `.log` case branch in the shell switch — unreachable because Log never selects.

## Cross-cutting findings feeding the backlog

1. Conversation ephemerality (P0 product defect).
2. Two visual languages: Nell component system vs ChatView's system chrome.
3. Settings access inconsistent across tabs (missing on Nutrition).
4. Accessibility coverage is near-zero outside hand-built v2 components.
5. Empty states across Train lack next-action affordances.
6. Competing completion claims inside Active Workout.
7. Apple Health connection state not durably surfaced.

# Design-system consistency audit

Date: 2026-08-23 · Phase 3. Verdict up front: **Nell has one real design
language — the tokenized NellPalette/NellLayout/Theme system consumed through
`NellScreen`, `NellCard`, `NellSectionHeader`, `NellStatusChip`,
`NellEmptyState/ErrorState/MascotView/ThinkingIndicator` — but its flagship
surface (the Nell conversation) and every legacy `Sources/Features` entry
form render in a second, un-tokenized visual language.**

## Token layer (healthy)

- `Theme.ColorToken`: 16 dynamic light/dark tokens matching the approved
  cream/forest spec; `NellPalette` provides semantic aliases; legacy aliases
  (`evergreen/clay/honey`) resolve to the SAME tokens, so color values are
  consistent even where call-site naming is old.
- Typography: `FontToken` fixed-size system fonts. **Known trade-off: these
  do not track Dynamic Type** (fixed `size:`), whereas ChatView's raw
  `.title3/.caption` styles DO scale. The component system therefore scales
  worse than the "legacy" chat text — an accessibility inversion to fix in
  one place (see backlog DS-3).
- Spacing/radii/sizes: complete (`Spacing`, `Radius`, `Size`, `NellLayout`).

## Divergences found

| ID | Where | Divergence | Impact |
|---|---|---|---|
| DS-1 | `ChatView.swift` transcript/composer | `Color(.systemGroupedBackground)`, `.secondarySystemGroupedBackground`, `.bar`; user bubble `Theme.evergreen` | The flagship conversation reads as a generic iOS chat, not Nell; background shifts from cream (Today) to system gray mid-app |
| DS-2 | `ChatView.swift` thinking state | plain `ProgressView + "Thinking…"` while branded `NellThinkingIndicator` (Reduce-Motion aware) sits unused | missed brand moment; duplicated loading language |
| DS-3 | `FontToken` definitions vs chat/system styles | fixed sizes don't scale; system text styles elsewhere do | inconsistent Dynamic Type behavior across one screen boundary |
| DS-4 | Settings root (`SettingsView`) | stock `Form` over branded background; children mixed (two Forms, one card-based About) | settings feels like a template dump relative to card screens |
| DS-5 | Legacy entry forms (`MealEntryView`, `SleepEntryView`, `CheckInView`, `WorkoutLogView`) | system Form/List chrome, no Nell headers | Log sheet opens into visually unrelated screens |
| DS-6 | Empty-state duplication | `ContentUnavailableView` (ProfileViews), `NellEmptyState` (v2), ad-hoc inline text (Train rows, Today tiles) | three empty-state idioms |
| DS-7 | Magic numbers | ChatView radii 18/20/16, paddings 9/14/10/48; Today tile minHeight 116 inside `NellMetricTile` (tokenized ✓); scattered fixed icon `.system(size:)` | drift risk where un-tokenized |
| DS-8 | Mascot usage | Today greeting (wave), Coach header (thoughtful), completion (success), onboarding — intentional; unused poses have no imagesets and fall back to vectors | acceptable; HR-10 tracks success-art decision |

## What is already consistent (do not regress)

- Cards/chips/buttons: single implementation each (`NellCard`,
  `NellStatusChip`, `.nellPrimary` style) used across all v2 screens.
- Navigation chrome: custom shell tab bar with one coach-tab treatment;
  logo-as-profile-button pattern on Today/Coach/Train.
- Progress/metric components: `NellMetricTile`, progress ring — tokenized.

## Recommended direction (executed in this phase where P1)

Fix shared primitives first: give the conversation surface Nell surfaces +
branded thinking indicator (DS-1, DS-2); route empty states through
`NellEmptyState` where screens are touched anyway (DS-6). Token-level Dynamic
Type support (DS-3) is a single-file change with wide blast radius — queued
with visual verification rather than rushed.

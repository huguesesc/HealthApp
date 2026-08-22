# Nell brand and asset reference audit

Audit date: 2026-08-23 (Windows phase, static analysis). Matrix: screen →
current asset/control → intended asset/control → status.

Confirmed product decisions applied as ground truth:

1. The bottom destination is **Nell**, not Coach.
2. The real Nell logo is the Profile/Settings root-screen button.
3. Real mascot assets replace placeholders **selectively**.
4. Standard actions keep standard system icons.
5. The tortoise is not the workout-motion character.

## Screen matrix

| Screen / surface | Current | Intended | Status |
|---|---|---|---|
| Shell tab bar (`NellAppShellView`) | Destination enum case `.coach` renders label **"Nell"**, mascot coach-mark icon, dedicated `coachTab` view; the empty-symbol branch for `.coach` inside `standardTab` is dead but harmless | Same | DONE (decision 1); optionally delete dead `""` symbol cases later — MAC |
| Today header settings button | `NellSettingsLogoButton` (logoFullColor) via `NellLogoView` | Same | DONE (decision 2) |
| Train screen settings button | Nell logo button | Same | DONE |
| Assistant header settings control | Nell logo button | Same | DONE |
| Legacy `Sources/Features/Settings/SettingsView.swift:41` | `person.crop.circle` row label in the unwired legacy settings stack | N/A while legacy stack is unreferenced | LEAVE (legacy stack cleanup is separate) |
| Nell Coach screen | `.thoughtful` mascot + `.coachMark`; title "Nell" | Same | DONE |
| Onboarding | `.wave` mascot used; page titled "Coach connection" with "Coach context" copy | Rename user-facing copy to Nell wording? | PRODUCT (copy decision, not asset) |
| Train empty states (`NellWorkoutPlansView:21`, `NellWorkoutStartView:66`) | Copy says "ask the Coach…" | "ask Nell…" | SAFE-FIX: corrected this commit (clearly covered by decision 1's naming direction) |
| Settings footnotes (`NellSettingsSections.swift:51,84,142`) | "Coach context" / "Nell Coach" mixed wording | Consistent Nell voice | PRODUCT (voice review); no placeholder involved |
| App Store line (`NellBrand.swift:8`) | `"Nell: AI Health & Fitness Coach"` | Marketing-approved string | LEAVE |
| `NellBrand.swift:9` `coachName = "Coach"` constant | Declared, never referenced anywhere | Remove or repurpose | OBSOLETE? left in place pending component cleanup (removal is trivially safe but zero user value) |
| Completion overlay (`NellActiveWorkoutContainerView`) | `.success` pose | Real success art exists? `NellMascotSuccess` has NO imageset → falls back to vector/SF rendering at runtime | MAC visual check; if unacceptable, PRODUCT decides between new art or keeping fallback |
| Mascot states Nutrition/Training/Recovery/Progress/Balance | Enum cases exist without imagesets; `NellStates` falls back to drawn placeholders per documented design | Selective real-art replacement later | PRODUCT (which states get real art) |
| Workout-motion character (`WorkoutAvatarStyle`) | Faceless human figure `nell_neutral_01`; no animal assets anywhere | Same | DONE (decision 5); tortoise comment-only reference in `NellBrand.swift:14` |
| Exercise catalogue rows/details | Real composites via `ExerciseMediaView`, vector fallback otherwise | Same | DONE this phase |

## Asset inventory cross-check

- Imagesets on disk: NellLogoFullColor, NellLogoMonochrome (declared, missing),
  NellAppIconReference, NellCoachMark, NellMascotWave, NellMascotThoughtful,
  plus 20 generated ExerciseMedia sets.
- Enum declares 12 brand cases; 7 have no imageset by design and fall back
  through `NellAssets.swift` draw/SF-symbol chain. No dangling `Image("...")`
  string literals exist anywhere (all access is enum/rawValue or resolver).
- No old-brand colors found outside `NellPalette`; no tortoise/hare imagery.

## Actions taken this phase

- Corrected two user-facing "ask the Coach" strings to name Nell
  (`NellWorkoutPlansView`, `NellWorkoutStartView`) — directly covered by
  decision 1.
- Everything else above is recorded, not redesigned.

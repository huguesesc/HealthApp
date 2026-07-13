# Nell Asset Integration and Coach Plan

## Objective

Integrate the latest uploaded Nell image pack into the application without replacing scalable SwiftUI interface elements with screenshots or composite artwork. Restore the visible Coach composer and make the assistant explicitly Nell throughout the conversation experience.

Canonical source archive:

- `HealthAssistant_image_Pack(3).zip`
- 7 brand-reference PNGs
- 8 Nell mascot-pose PNGs
- 50 transparent two-position workout illustrations

`HealthAssistant_image_Pack(2).zip` remains a legacy/reference archive and must not be imported in parallel because it contains duplicate and alternate exports.

## Decisions

1. The latest pack is the canonical import source.
2. Original filenames are recorded, but runtime asset names will be normalized.
3. The raw ZIP and duplicate legacy files will not be committed into the app bundle.
4. App-ready optimized exports will be committed to `Assets.xcassets`.
5. SwiftUI fallbacks remain functional when an asset is absent.
6. `header_intro1.png` is a composite reference, not the primary responsive app header. Its separate logo and mascot elements will be used instead.
7. All 50 workout illustrations will be available in the asset catalogue, but title-to-image registration will be explicit and testable.
8. The central assistant is named **Nell**, not “Coach.” “Coach” remains the navigation-function label where useful.

---

## Phase 1 — Prepare and normalize app-ready exports

### Scope

Extract the latest archive and produce deterministic runtime filenames.

### Processing rules

- Preserve transparency for all logo, mascot and workout images.
- Resize workout illustrations to a maximum 900 × 900 pixel canvas; this is sufficient for approximately 300 pt display at 3× scale.
- Resize mascot poses to a maximum 900 px long edge.
- Keep full-resolution source files outside the runtime asset catalogue.
- Produce the App Store icon as exactly 1024 × 1024, RGB, with no alpha.
- Remove accidental double periods from names.
- Correct runtime spelling such as `dumbell` → `dumbbell` while preserving source-name provenance in the manifest.
- Do not crop poses independently in a way that changes relative character scale between exercises.

### Brand runtime mapping

| Source | Runtime asset | Use |
|---|---|---|
| `brand_id/logo..png` | `NellLogoFullColor` | Primary standalone product mark |
| `brand_id/monochrome-dark.png` | `NellLogoMonochrome` light appearance | Monochrome mark on light surfaces |
| `brand_id/monochrome-light.png` | `NellLogoMonochrome` dark appearance | Monochrome mark on dark surfaces |
| `brand_id/sublogo-dark.png` | `NellCoachMark` light appearance | Compact Nell/Coach symbol |
| `brand_id/sublogo-light.png` | `NellCoachMark` dark appearance | Compact Nell/Coach symbol |
| `brand_id/app_icon.png` | `AppIcon` and `NellAppIconReference` | Installed application icon and settings/about reference |
| `brand_id/header_intro1.png` | `NellHeaderIntroReference` | Reference/optional marketing preview; not default responsive UI |

### Mascot runtime mapping

| Source | Runtime asset | Primary role |
|---|---|---|
| `nell_allfours.png` | `NellMascotNeutral` | Neutral greeting and general empty states |
| `nell_balance.png` | `NellMascotBalance` | Balance/mobility context |
| `nell_exercise.png` | `NellMascotTraining` | Training guidance |
| `nell_food.png` | `NellMascotNutrition` | Nutrition context |
| `nell_hello.png` | `NellMascotWave` | Onboarding and greeting |
| `nell_pensive.png` | `NellMascotThoughtful` | Nell conversation and reflection |
| `nell_plan.png` | `NellMascotProgress` | Plans and progress |
| `nell_zen.png` | `NellMascotRecovery` | Recovery and calm context |

`NellMascotSuccess` will initially reuse `NellMascotWave` until a dedicated success export is supplied. The code must make this alias explicit rather than duplicating image files.

### Expected files

- `Health Assistantv2/Assets.xcassets/...`
- `Health Assistantv2/Brand/NellAssets.swift`
- `docs/nell-redesign/IMAGE_PACK_MAPPING.md`
- `docs/nell-redesign/WORKOUT_MOTION_ASSET_MANIFEST.md`

### Acceptance criteria

- Every production asset loads through a stable runtime name.
- Dark/light variants render correctly.
- Missing assets still display safe fallbacks.
- No duplicate legacy exports enter the application bundle.
- The App Store icon has no transparency warning.

---

## Phase 2 — Replace placeholder branding and mascot usage

### Scope

Use the production assets in selected high-value locations while avoiding mascot overuse.

### Screen mapping

#### Onboarding

- Replace the current SwiftUI shell placeholder with `NellMascotWave`.
- Keep the responsive SwiftUI wordmark and descriptor rather than embedding the composite header image.
- Use `NellMascotRecovery` or `NellMascotThoughtful` only on the relevant later page, not every page.

#### Today

- Use `NellMascotNeutral` in the greeting hero.
- Use the compact `NellCoachMark` for Nell observations.
- Do not repeat a full mascot inside every metric or card.

#### Coach/Nell

- Header title becomes `Nell`.
- Use `NellMascotThoughtful` as the assistant identity in the header/empty state.
- Use `NellCoachMark` as the compact assistant-message avatar.

#### Nutrition

- Use `NellMascotNutrition` only in the meaningful empty state or guidance state.

#### Train

- Use `NellMascotTraining` only for an empty-plan or guidance moment.
- Workout movement illustrations remain humanoid and separate from Nell.

#### Progress and completion

- Use `NellMascotProgress` for plan/progress empty states.
- Use the temporary success alias only after a workout is actually persisted.

### Acceptance criteria

- No screen displays the fallback shell mark when a production asset exists.
- Nell remains recognizable without appearing in every card.
- Layout works in light and dark appearance.
- Assets have appropriate accessibility labels and decorative images are hidden from VoiceOver when duplicated by text.

---

## Phase 3 — Make the conversational assistant Nell and restore the composer

### Current defect

`ChatView` already owns a text composer through `.safeAreaInset(edge: .bottom)`. Inside `NellCoachScreen`, that inset is nested beneath the custom app tab bar and is therefore not visibly usable on device. Adding a second input bar would create competing state and should not be done.

### Implementation direction

- Refactor `ChatView` into reusable conversation content and a separately exposed composer.
- Let `NellCoachScreen` own the final vertical layout and reserve space above the custom tab bar.
- Keep one `draft` state and one send path.
- Rename visible assistant labels from `Assistant` or generic `Coach` to `Nell`.
- Add a compact Nell avatar to assistant responses.
- Keep user messages visually distinct.
- Show suggestions only for an empty conversation.
- Preserve proposal review/save/discard behavior.
- Preserve missing-key, thinking, offline and error states.
- Ensure keyboard dismissal and scrolling to the latest message work.

### Expected files

- `Health Assistantv2/Coach/NellCoachScreen.swift`
- `Sources/Features/Chat/ChatView.swift`
- possibly a new focused composer/message component under `Health Assistantv2/Coach/`
- `Health Assistantv2/Navigation/NellAppShellView.swift` only if an explicit tab-bar inset contract is required

### Acceptance criteria

- A visible `Message Nell…` field is always available above the tab bar.
- The composer moves above the keyboard.
- Sending creates one user message and one engine request.
- Existing structured proposals still require confirmation before saving.
- The empty screen no longer leaves a large unused area.
- The visible assistant identity is Nell.

---

## Phase 4 — Import and register the 50 workout illustrations

### Runtime model change

Extend `WorkoutMotionDefinition` with an optional image asset name, for example:

```swift
let imageAssetName: String?
```

The existing programmatic `WorkoutAvatarFigure` remains the fallback.

Each supplied PNG already contains a two-position movement pair. The application should render that complete image rather than splitting it into artificial start/end files.

### Runtime naming

Use normalized names such as:

- `WorkoutMotionBarbellBicepsCurl`
- `WorkoutMotionBodyweightSquat`
- `WorkoutMotionDumbbellGobletSquat`
- `WorkoutMotionMachineProneLegCurl`
- `WorkoutMotionStabilityBallHamstringCurl`

The source-to-runtime mapping must be generated and documented, not manually inferred inside views.

### Registry work

- Add definitions for every supplied exercise.
- Add practical aliases for user-entered titles.
- Correct known distinctions such as leg extension versus prone leg curl.
- Keep machine, bench, cable, band, stability-ball, barbell, dumbbell and bodyweight categories explicit.
- Return the generic SwiftUI figure for exercises without a mapped image.

### View behavior

- `.compact`: display the supplied pair image cropped/scaled for list use.
- `.pair`: display the full two-position PNG.
- `.hero`: display the full PNG plus movement title.
- Use `.scaledToFit()` and a transparent background.
- Avoid clipping wide machine illustrations.

### Expected files

- `Health Assistantv2/Assets.xcassets/WorkoutMotion...`
- `Health Assistantv2/WorkoutMotion/WorkoutMotionRegistry.swift`
- `Health Assistantv2/WorkoutMotion/WorkoutMotionView.swift`
- `docs/nell-redesign/WORKOUT_MOTION_ASSET_MANIFEST.md`
- focused registry and fallback tests

### Acceptance criteria

- All 50 supplied workout assets are loadable.
- Every imported asset has at least one registry definition or a documented deferred mapping.
- Common aliases resolve correctly.
- Unknown exercises still render safely.
- Active Workout, plan detail, history and rows do not stretch or crop images incorrectly.

---

## Phase 5 — Visual cleanup prompted by the device review

This phase follows asset integration and should not be mixed with the binary import commit.

### Approved cleanup

- Remove the duplicate Nutrition add affordance and keep one clear primary action.
- Fix content being obscured by the custom tab bar.
- Reduce oversized empty regions in Coach and Log.
- Standardize page-top padding and profile/settings buttons.
- Confirm the central Coach tab uses the compact Nell mark rather than a fallback.
- Recheck empty states after real artwork changes their visual weight.

### Acceptance criteria

- No actionable content is covered by the tab bar.
- Every screen has one obvious primary action.
- No duplicate add controls remain.
- The main destinations feel visually related without using identical cards everywhere.

---

## Commit sequence

1. `Prepare Nell production image exports`
2. `Integrate Nell brand and mascot assets`
3. `Make the conversational assistant Nell`
4. `Register workout motion image pack`
5. `Refine Nell screen hierarchy after asset integration`

Keeping these commits separate allows visual and functional regressions to be isolated.

---

## Verification sequence

After every phase:

1. Clean build in Xcode.
2. Run relevant tests.
3. Launch on the physical iPhone used for the current review.
4. Check Today, Log, Nell, Nutrition and Train.
5. Check onboarding replay.
6. Check light and dark appearance.
7. Check the smallest supported iPhone simulator.
8. Check Dynamic Type and VoiceOver labels.
9. For workout images, inspect portrait and landscape-shaped illustrations in compact and hero contexts.
10. Confirm the app bundle and archive size remain reasonable after optimization.

## Main risks

- App-size growth from importing 50 large transparent PNGs.
- Incorrect title aliases causing the wrong movement illustration to appear.
- Wide machine illustrations being clipped in compact rows.
- Duplicate composer state if the Coach screen is patched rather than refactored.
- Dark/light artwork being assigned to the wrong appearance variant.
- SwiftData or workout logic being unintentionally touched during presentation-only work.

## Recommended execution order

Begin with Phases 1 and 2 together as the first implementation task, then complete Phase 3 before registering all workout images. This gives the app its real identity and repairs the most visible functional defect before the larger registry expansion.
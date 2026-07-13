# Nell Image Pack Mapping

The supplied `HealthAssistant_image_Pack` is the visual source for the Nell logo and tortoise companion system. Source filenames are intentionally separated from the stable runtime asset names used by SwiftUI.

## Logo and mark mapping

| Source file | Runtime asset name | Intended use |
|---|---|---|
| `logo.png` | `NellLogoFullColor` | Primary shell/bowl logo |
| `monochrome.png` | `NellLogoMonochrome` | Single-colour logo use |
| `sublogo1.png` | `NellCoachMark` | Compact Care Companion mark |
| `altlogo.png` | `NellAppIconReference` | App-icon production reference |
| `Capture d'écran 2026-07-12 165838.png` | Reference only | Wordmark typography reference |

## Mascot mapping

| Source file | Runtime asset name | Semantic pose |
|---|---|---|
| `01_Thoughtful_Standing.png` | `NellMascotThoughtful` | Thoughtful guidance |
| `02_Coach_Wave.png` | `NellMascotWave` | Welcome and greeting |
| `03_Nutrition_Healthy_Bowl.png` | `NellMascotNutrition` | Nutrition context |
| `04_Training_Resistance_Band.png` | `NellMascotTraining` | Training context outside active sets |
| `05_Recovery_Meditation.png` | `NellMascotRecovery` | Recovery and calm states |
| `06_Progress_Clipboard.png` | `NellMascotProgress` | Progress summaries |
| `07_Balance_Mobility.png` | `NellMascotBalance` | Mobility and balance |
| `11_AllFours_Greeting.png` | `NellMascotSuccess` | Restrained completion state |

The all-fours variants remain reserve artwork and should not replace the separate humanoid workout-motion system.

## Concept-board files

The broad visual boards are implementation references rather than runtime images:

- `ChatGPT Image Jul 12, 2026, 04_58_03 PM (1).png`
- `ChatGPT Image Jul 12, 2026, 04_58_04 PM (2).png`
- `ChatGPT Image Jul 12, 2026, 05_31_41 PM.png`
- the horizontal and vertical Nell identity boards

They define hierarchy, spacing, palette and screen direction. They should not be placed directly into the app.

## Production export requirements

Before final distribution, runtime exports should be prepared as follows:

- transparent background for mascot and in-app logo images
- tightly cropped with consistent visual scale
- universal image sets with appropriate 1×, 2× and 3× files
- original rendering mode for full-colour artwork
- no baked card background
- restrained or no baked shadow
- 1024×1024 opaque App Store icon using the selected deep-forest shell/bowl treatment

The SwiftUI asset registry already provides safe fallbacks, so artwork can be replaced without changing feature logic.

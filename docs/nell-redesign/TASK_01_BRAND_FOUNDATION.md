# Task 01 — Brand Foundation and Asset Contract

## Goal

Create the single source of truth for Nell branding before individual screens are redesigned.

## Work

- Rename all user-facing product references from Health Assistant to Nell.
- Keep the Xcode project, target, module, and bundle identifier unchanged during this feature.
- Add semantic brand tokens for light and dark mode.
- Add reusable SwiftUI representations of the Shell Bowl mark and Care Companion mark where raster artwork is unnecessary.
- Prepare the asset catalogue contract for app icon, mascot poses, and workout movement avatars.
- Add a typed asset registry so screens never use raw image-name strings.

## Proposed source files

```text
Health Assistantv2/Brand/NellBrand.swift
Health Assistantv2/Brand/NellAssets.swift
Health Assistantv2/Brand/NellLogoView.swift
Health Assistantv2/Brand/NellCoachMark.swift
Health Assistantv2/Brand/NellMascotView.swift
```

## Asset groups

```text
NellLogoFullColor
NellLogoMonochrome
NellCoachMark
NellMascotThoughtful
NellMascotWave
NellMascotNutrition
NellMascotTraining
NellMascotRecovery
NellMascotProgress
NellMascotBalance
```

## Acceptance criteria

- No new screen hard-codes a brand hex value.
- No new screen references a mascot filename directly.
- Logo and Coach mark render in light and dark mode.
- App display name is Nell.
- Existing persistence remains compatible.
- Asset failures degrade to a safe SwiftUI placeholder rather than crashing.

## Verification

- Build on the physical iPhone.
- Inspect icon, launch, Coach tab, and one mascot state in both appearances.
- Verify Dynamic Type does not distort the brand lockup.

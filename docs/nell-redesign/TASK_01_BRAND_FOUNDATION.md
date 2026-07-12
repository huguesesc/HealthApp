# Task 01 — Brand Foundation and Asset Contract

## Status

**Implemented in source. Physical-device build verification pending.**

Detailed implementation report: `IMPLEMENTATION_TASKS_01_02.md`

## Goal

Create the single source of truth for Nell branding before individual screens are redesigned.

## Work completed

- Added central product naming for **Nell** and **Your personal health companion**.
- Added semantic brand and layout aliases.
- Added typed identifiers for logo, Coach mark, and mascot assets.
- Added safe missing-asset fallbacks.
- Added reusable SwiftUI Shell Bowl and Care Companion marks.
- Updated the central Coach tab to use the shared mark.
- Added the Nell installed-app display name through `Base.lproj/InfoPlist.strings`.
- Updated Settings and Apple Health permission wording to Nell.
- Added brand-foundation tests.

## Source files

```text
Health Assistantv2/Brand/NellBrand.swift
Health Assistantv2/Brand/NellAssets.swift
Health Assistantv2/Brand/NellLogoView.swift
Health Assistantv2/Base.lproj/InfoPlist.strings
Health Assistantv2Tests/NellBrandFoundationTests.swift
```

## Asset groups

```text
NellLogoFullColor
NellLogoMonochrome
NellAppIconReference
NellCoachMark
NellMascotThoughtful
NellMascotWave
NellMascotNutrition
NellMascotTraining
NellMascotRecovery
NellMascotProgress
NellMascotBalance
NellMascotSuccess
```

## Acceptance criteria

- No new screen hard-codes a brand hex value.
- No new screen references a mascot filename directly.
- Logo and Coach mark render in light and dark mode.
- App display name is Nell.
- Existing persistence remains compatible.
- Asset failures degrade to a safe SwiftUI placeholder rather than crashing.

## Remaining verification

- Build on the physical iPhone.
- Inspect installed name, Coach tab, logo fallback, and one mascot state.
- Verify light/dark appearance and Dynamic Type.
- Add final production raster assets after export cleanup.

# 0006 - HealthKit read-only branch

Date: 2026-07-08
Branch: `feature/healthkit-readonly`
Base checkpoint: `working-before-healthkit-2026-07-08` (`0d466a5`)
Status: authored on Windows, not compiled with Xcode.

## What changed

- Preserved the working app before this work:
  - Git tag pushed: `working-before-healthkit-2026-07-08`
  - Local backup folder: `Desktop/HealthApp-working-before-healthkit-2026-07-08`
- Created isolated worktree:
  - `Desktop/HealthApp-healthkit`
  - branch `feature/healthkit-readonly`
- Added read-only HealthKit import:
  - `HealthKitService` requests read permission and fetches recent daily aggregates.
  - `HealthKitDailyImport` is the only data shape leaving the HealthKit layer.
  - `DailyRollup` stores compact health fields.
  - `HealthDataRepository.applyHealthImports(_:)` upserts health aggregates.
  - `SettingsView` has Connect Apple Health and Sync Apple Health controls.
  - `DashboardView` shows a compact Apple Health card when imported data exists.
  - Chat and daily summary context include compact health aggregates.
- Added HealthKit entitlement and `NSHealthShareUsageDescription`.

## Privacy boundary

Raw HealthKit records stay inside `HealthKitService`. The assistant receives only
compact daily summaries through `DailyContext` and `RollupSnapshot`.

## Verification not done here

This Windows machine cannot run `xcodebuild`, HealthKit permissions, or an iPhone
device sync. Treat this branch as authored, not proven.

## Mac verification

```bash
cd ~/Desktop
git clone https://github.com/huguesesc/HealthApp.git HealthApp-healthkit
cd HealthApp-healthkit
git checkout feature/healthkit-readonly

xcodebuild \
  -project "Health Assistantv2.xcodeproj" \
  -scheme "Health Assistantv2" \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
  clean build
```

Then run on a real iPhone:

1. Open Settings in the app.
2. Tap Connect Apple Health.
3. Grant Health permissions.
4. Tap Sync Apple Health.
5. Confirm dashboard Apple Health stats appear.
6. Ask the assistant "How was my week?"
7. Confirm the answer references only summarized Health data.

## Likely compile-risk areas

- `HealthKitService.swift`: HealthKit enum availability or query type inference.
- `project.pbxproj`: HealthKit source registration and entitlement path.
- SwiftData migration: new optional `DailyRollup` fields should be lightweight, but
  existing device installs need testing.

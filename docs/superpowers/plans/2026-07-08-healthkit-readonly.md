# HealthKit Read-Only Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import read-only Apple Health data into compact daily rollups for dashboard, daily summary, and chat context.

**Architecture:** Add a HealthKit service for authorization/querying, pure aggregate mapping helpers for tests, repository upsert methods for rollups, and Settings UI controls to connect/sync. The AI layer continues to receive compact `RollupSnapshot` values, not raw HealthKit samples.

**Tech Stack:** SwiftUI, SwiftData, HealthKit, Swift Testing, Xcode 16.2.

---

## File Structure

- Create `Sources/Integrations/HealthKit/HealthKitImport.swift`: pure import aggregate types and merge helpers.
- Create `Sources/Integrations/HealthKit/HealthKitService.swift`: HealthKit availability, authorization, and recent aggregate queries.
- Modify `Sources/Models/DailyRollup.swift`: add optional HealthKit aggregate fields.
- Modify `Sources/Data/HealthDataRepository.swift`: merge HealthKit aggregates into rollups and snapshots.
- Modify `Sources/Features/Settings/SettingsView.swift`: Apple Health connect/sync controls.
- Modify `Sources/Features/Dashboard/DashboardView.swift`: expose imported health stats when present.
- Modify `Sources/AI/AIClient.swift`: add health fields to `RollupSnapshot` and `DailyContext`.
- Modify `Health Assistantv2.xcodeproj/project.pbxproj`: target membership, HealthKit entitlement, Info.plist usage string.
- Create `Health Assistantv2/Health Assistantv2.entitlements`: HealthKit entitlement.
- Modify `Health Assistantv2Tests/Health_Assistantv2Tests.swift`: tests for import merge behavior.
- Add journal handoff with verification instructions.

## Tasks

### Task 1: Pure Import Model and Tests

- [ ] Add `HealthKitDailyImport` with date, steps, active energy, exercise minutes, workout count, workout summary, sleep hours, resting heart rate.
- [ ] Add a merge helper that preserves manual meal/workout data while filling HealthKit fields.
- [ ] Add Swift Testing tests for merge behavior.
- [ ] Commit.

### Task 2: Rollup Persistence

- [ ] Add optional HealthKit fields to `DailyRollup`.
- [ ] Add repository method `applyHealthImports(_:)` that upserts one rollup per day.
- [ ] Extend `RollupSnapshot` and `todayContext()` so chat and summary see imported health stats.
- [ ] Commit.

### Task 3: HealthKit Service

- [ ] Add HealthKit authorization and query code behind `HealthKitService`.
- [ ] Read recent samples for steps, active energy, exercise time, workouts, sleep, and resting heart rate.
- [ ] Return compact `[HealthKitDailyImport]`.
- [ ] Commit.

### Task 4: Settings and Dashboard UI

- [ ] Add Apple Health controls to Settings.
- [ ] Add sync state and clear user-facing error messages.
- [ ] Add imported stats to dashboard cards without displacing manual logging.
- [ ] Commit.

### Task 5: Xcode Project, Entitlements, Docs

- [ ] Register new Swift files and entitlement file in the Xcode project.
- [ ] Add `NSHealthShareUsageDescription`.
- [ ] Add HealthKit capability.
- [ ] Update architecture docs and journal.
- [ ] Push `feature/healthkit-readonly`.

## Verification

Windows verification is static only. Mac verification must run:

```bash
cd ~/Desktop/HealthApp-healthkit
git pull
xcodebuild -project "Health Assistantv2.xcodeproj" -scheme "Health Assistantv2" -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" clean build
```

Real HealthKit verification must run on an iPhone:

1. Build to device.
2. Open Settings in the app.
3. Tap Connect Apple Health.
4. Grant permissions.
5. Tap Sync Apple Health.
6. Confirm dashboard stats update.
7. Ask the assistant "How was my week?" and verify it mentions imported health data only as summaries.

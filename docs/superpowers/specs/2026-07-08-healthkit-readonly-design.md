# HealthKit Read-Only Import Design

Date: 2026-07-08
Status: approved for `feature/healthkit-readonly`

## Goal

Connect the iPhone app to Apple Health through HealthKit so the assistant can answer
questions from Apple Watch / Apple Health data without building a watchOS app.

## Scope

Build read-only HealthKit import for compact daily aggregates:

- steps
- active energy burned
- Apple exercise time
- workouts
- sleep analysis
- resting heart rate if available

Do not build:

- watchOS target
- live workout tracking
- HealthKit writes
- raw HealthKit record upload to Claude

## Architecture

Add a small HealthKit integration layer that requests authorization and reads recent
health data into local aggregate structs. `HealthDataRepository` stores those
aggregates into `DailyRollup`, which remains the cheap history layer for dashboard,
daily summary, and chat.

The AI layer keeps reading `RollupSnapshot`; it never receives raw HealthKit samples.
This protects privacy and keeps API costs low.

## UI

`SettingsView` gets an Apple Health section:

- availability/status text
- "Connect Apple Health"
- "Sync Apple Health"
- last sync result or error

The dashboard can show imported health stats once available, but the first useful
integration point is the assistant context.

## Privacy

The app adds `NSHealthShareUsageDescription` and HealthKit entitlement. The copy must
say the app reads Apple Health activity, workout, sleep, and heart data for personal
summaries and coaching.

No HealthKit data is used for advertising, marketing, or data mining. Health data is
summarized locally before any AI request.

## Verification Boundary

Windows can author and statically inspect this branch, but cannot compile HealthKit
or exercise Health permissions. Final verification requires Xcode on a Mac and a real
iPhone with Health data.

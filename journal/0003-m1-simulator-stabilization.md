# 0003 - M1 simulator stabilization

Date: 2026-06-26

## What changed

- The app was manually imported into a fresh Xcode iOS project on a Mac and reached
  the Today dashboard in the iPhone simulator.
- The previous App Group-backed SwiftData setup crashed on launch because the
  throwaway simulator project did not have the App Group entitlement.
- `PersistenceController` now uses the default local SwiftData store for M1.
- App Group storage is deferred to the Screen Time / real-device milestone, where
  the app target, extension target, App Group identifier, and entitlements can be
  configured together.

## Practical rule

For the current simulator build, `Sources/Persistence/PersistenceController.swift`
must not reference `groupContainer`, `AppGroup.identifier`, or
`forSecurityApplicationGroupIdentifier`.

Run this check before sending the project to the Mac:

```bash
python -B scripts/check_m1_simulator_safe.py
```

## Next

1. Re-import this updated `Sources/` folder into the Mac Xcode project, or create a
   fresh Xcode project and add `Sources/` again.
2. Confirm the simulator still opens the Today dashboard.
3. Commit this M1 baseline.
4. Start M2: API key settings, Claude client opt-in, meal estimate, daily summary.

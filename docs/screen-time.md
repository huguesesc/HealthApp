# Screen Time — capabilities, limits, and design

A priority feature, but Apple's Screen Time stack is privacy-sandboxed in ways that
shape what's possible. This documents what we can and can't do so the design doesn't
assume access it won't get.

## The three frameworks

| Framework | Purpose |
|-----------|---------|
| **FamilyControls** | Authorization + the `FamilyActivityPicker` for choosing apps/categories. Selections are **opaque tokens**, not names. |
| **DeviceActivity** | Schedule monitoring windows and fire callbacks when usage thresholds are crossed. Runs in a separate **extension** sandbox. |
| **ManagedSettings** | Apply restrictions/shields to selected apps (used later for enforcement). |

## What we CAN do

- Ask for **individual (self-monitoring) authorization** (`AuthorizationCenter.requestAuthorization(for: .individual)`).
- Let the user pick apps/categories (`FamilyActivityPicker`).
- Set a **daily time threshold** and get a callback (`eventDidReachThreshold`) when the user crosses it on the selected apps.
- Apply/lift **shields** on those apps (enforcement, a later milestone).
- Share a **coarse signal** from the extension to the app via an **App Group** (e.g. `exceededLimit = true`).

## What we CANNOT do

- **Read precise per-app durations in the app.** "2h14m on Instagram" stays inside
  the system / the report extension behind opaque tokens. It cannot be pulled into
  the main app, and therefore cannot be sent verbatim into an AI prompt.
- **Prevent the user from removing their own restrictions.** Individual
  authorization is self-imposed; the user can always revoke. Streaks/overrides are
  *our* bookkeeping on top, not an OS-enforced lock.

## Hard requirements

- **Family Controls entitlement** — request from Apple. The distribution entitlement
  needs their approval. (User is handling this.)
- **A real device** — none of these APIs do anything useful in the simulator.

## How it's wired here

```
App  ──FamilyActivityPicker──►  selection (opaque tokens)
App  ──DeviceActivityCenter──►  schedule + threshold event
                                      │  (usage crosses threshold)
                                      ▼
DeviceActivityMonitorExtension  ──writes coarse signal──►  App Group
App / DailyRollup  ◄──reads coarse signal────────────────  App Group
```

- `Sources/Features/ScreenTime/ScreenTimeService.swift` — authorization, selection,
  scheduling, reading the coarse signal.
- `Sources/Features/ScreenTime/ScreenTimeView.swift` — the UI (optional; reached from
  the dashboard).
- `DeviceActivityMonitorExtension/` — the extension target; writes the coarse signal.
- `Sources/Shared/AppGroup.swift` — the shared identifier + keys. Keep the
  identifier in sync with the copy inside the extension.

The only data that reaches the daily rollup / AI is the **coarse boolean**, by
design. A richer aggregate (total monitored minutes) would need a
`DeviceActivityReport` extension and is a later step.

## Isolation guarantee

Nothing outside the ScreenTime module depends on Screen Time being functional. If
authorization is denied or the entitlement is absent, the rest of the app
(nutrition, workout, sleep, check-in, dashboard) works normally — the dashboard
simply shows no screen-time signal.

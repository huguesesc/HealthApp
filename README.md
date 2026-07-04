# Health Assistant (working title)

An iPhone-first personal AI assistant for daily health, fitness, recovery, habits,
and lifestyle tracking. Local-first, low-cost, text-driven. Not a medical device.

See `docs/vision.md` for what it's trying to become, `docs/roadmap.md` for the staged
plan, and `docs/architecture.md` for the technical decisions.

## Status

The app is centered on a **chat assistant** (`Sources/Features/Chat/`): freeform
logging ("I had two eggs and toast") drafts inline confirmation cards showing the
model's per-food assumptions, and questions are answered from compact daily
rollups. Around it: manual + AI-assisted logging for meals/workouts/sleep/
check-ins, a one-tap AI daily summary, and streaks. The AI layer is behind a
protocol (`Sources/AI/AIClient.swift`); with no API key everything still runs
offline on the stub. The user's Claude key is entered once in Settings
(Keychain via `APIKeyStore`).

## Building

> ⚠️ Requires **macOS + Xcode**. The Swift toolchain, SwiftLint, and SwiftFormat do
> not run on Windows. Files can be edited anywhere; they only build on a Mac.

The Xcode project is committed directly — open `Health Assistantv2.xcodeproj`
and build the **Health Assistantv2** scheme. Note: `Sources/` is referenced as
classic groups, so any NEW .swift file must be added to the target (or to
`project.pbxproj`) by hand.

Then in Xcode:
1. Set your Development Team and a unique bundle ID prefix (replace `com.example`).
2. Build & run on the simulator for everything *except* Screen Time.
3. Screen Time features require a **real device** + the **Family Controls**
   entitlement (request from Apple).

## Module map

| Area        | Path                          |
|-------------|-------------------------------|
| App entry / root nav | `Sources/App/`         |
| Data models | `Sources/Models/` (SwiftData) |
| Persistence | `Sources/Persistence/` (local SwiftData store for M1) |
| Repository (read/write seam) | `Sources/Data/`      |
| Rewards engine | `Sources/Rewards/`         |
| AI layer    | `Sources/AI/`                 |
| Shared utils | `Sources/Shared/`            |
| Features    | `Sources/Features/<Module>/`  |
| Screen Time extension | `DeviceActivityMonitorExtension/` |

Navigation: `RootView` → `DashboardView` (home) → module screens via entry points.
All data writes go through `HealthDataRepository`. See `docs/architecture.md`.

## Working with AI agents

- Claude Code: architecture, planning, larger refactors, the AI-integration layer.
- Codex: focused feature implementation.
- Keep modules separated; update `docs/` when a decision changes; log open questions
  in `journal/`.
- The current M1 simulator build uses local SwiftData storage. Do not put the main
  app store back in the App Group until Screen Time is being tested on a real
  device with entitlements.
- Never hardcode API keys. The Claude key is read from the iOS Keychain at runtime
  (`Sources/AI/APIKeyStore.swift`).

# Health Assistant (working title)

An iPhone-first personal AI assistant for daily health, fitness, recovery, habits,
and lifestyle tracking. Local-first, low-cost, text-driven. Not a medical device.

See `docs/vision.md` for what it's trying to become, `docs/roadmap.md` for the staged
plan, and `docs/architecture.md` for the technical decisions.

## Status

M1 simulator build: local logging, dashboard, and SwiftData persistence. Nothing
here makes live AI calls yet; the AI layer is behind a protocol
(`Sources/AI/AIClient.swift`) with a stub implementation so the app runs fully
offline.

## Building

> ⚠️ Requires **macOS + Xcode**. The Swift toolchain, SwiftLint, and SwiftFormat do
> not run on Windows. Files can be edited anywhere; they only build on a Mac.

This project uses [XcodeGen](https://github.com/yonsm/XcodeGen) to generate the
`.xcodeproj` from `project.yml`, so the project file itself is never hand-edited.

```bash
brew install xcodegen swiftlint swiftformat
xcodegen generate      # produces HealthAssistant.xcodeproj
open HealthAssistant.xcodeproj
```

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

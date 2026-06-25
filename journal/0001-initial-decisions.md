# 0001 — Initial decisions

Date: 2026-06-23

## Decided

- **Native iOS, SwiftUI, SwiftData.** Not cross-platform. iPhone-first, best
  HealthKit + Screen Time access, best fit for Claude Code / Codex.
- **AI behind an `AIClient` protocol.** Stub implementation first; `ClaudeAIClient`
  (raw HTTPS, no official Swift SDK) wired in M2. Default model `claude-haiku-4-5`.
- **API key in Keychain**, entered by the user. Serverless. No key in source.
- **Screen Time is an MVP priority** (user decision), built as threshold + coarse
  signal via a DeviceActivityMonitor extension + App Group bridge.
- **XcodeGen** generates the `.xcodeproj` from `project.yml` (diffable, AI-friendly).
- **SwiftLint + SwiftFormat** configured from the start.

## Open questions

- **Build machine.** Development requires macOS + Xcode; primary dev machine is
  currently Windows. Need a Mac (or alternative) before anything compiles.
- **Family Controls entitlement.** Distribution entitlement needs Apple approval;
  user is handling this. Screen Time also needs a real device to test.
- **Bundle ID prefix + Apple Developer Team** are placeholders (`com.example`) until
  an account is set up.
- **App Group identifier** must be created in the Apple Developer account and wired
  into both the app and the extension before the Screen Time bridge works.

## Next step

Flesh out M1 local-logging screens and the SwiftData wiring once a build machine is
available to verify compilation.

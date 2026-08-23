# iOS CI status

Created 2026-08-23 (Windows phase). Purpose: remove the Mac-compile
bottleneck by letting GitHub-hosted runners prove compilation and unit tests
for every push on the exercise-catalogue branch.

| Item | Value |
|---|---|
| CI existed before | No (no `.github/` directory at any earlier commit) |
| Workflow path | `.github/workflows/nell-ios-verification.yml` |
| Triggers | push to `feature/nell-exercise-catalog-location-context` (markdown-only pushes ignored), PRs touching `main`/the branch, manual `workflow_dispatch` |
| Runner A | `ubuntu-latest` — catalogue JSON/tooling job (validator, report, inventory, full Python suite) |
| Runner B | `macos-15` — Xcode discovery (newest 16.x selected at runtime), clean Debug build for generic simulator, unit tests via `-only-testing:"Health Assistantv2Tests"` on a dynamically discovered iPhone simulator |
| Signing behavior | `CODE_SIGNING_ALLOWED=NO` everywhere (simulator-only proof, exactly as the T13 Mac session did); no entitlements touched; no production signing changed |
| Scope guardrail | triggers limited to the feature branch until proven stable; `concurrency` cancels superseded runs |
| Project facts discovered, not assumed | shared scheme `Health Assistantv2.xcscheme` is committed; targets app/unit/UI; deployment target 18.2 (app/tests), 17.6 (extension) |

## Execution log

| Date | Commit | Result | Notes |
|---|---|---|---|
| 2026-08-23 | `f372e81` (run 32605169576) | ubuntu FAILED, macOS skipped | one test assumed the sibling source pack exists; 51 environmental errors |
| 2026-08-23 | `eedf398` (run 32605289584) | ubuntu GREEN, macOS build FAILED | first real macOS compile: `demote` static/instance mismatch at 3 call sites in GeneratedWorkoutValidator.swift |
| 2026-08-23 | `0156553` (run 32605735972) | **ALL GREEN** | **Xcode 26.3 on macos-15; clean Debug build OK; unit suite "151 tests in 24 suites passed"; simulator iPhone discovered dynamically** |
| 2026-08-23 | `2a8b704` (run 32605851893) | macOS test-step failed | Swift Testing API misuse caught by compiler: runtime String cannot fill `Comment?` in `#expect` |
| 2026-08-23 | `bc3e801`→`c47445e` | cancelled → superseded | concurrency group working |
| 2026-08-23 | `40bb173` (debug gallery) | macOS build FAILED | gallery referenced a file-private type; promoted to internal (`e2a47b0`) |

**Defects CI caught in Windows-written code: 3** (static-method call, Swift
Testing Comment conversion, file-private type access). Each was fixed within
one push cycle — this is exactly the Mac-bottleneck elimination the workflow
was created for.

Runner facts observed: macos-15 image exposes Xcode 16.4 and 26.x; newest is
selected automatically; iOS Simulator runtimes include 18.x with multiple
iPhone devices.

## Known limitations

- The source image pack lives outside the repository, so CI runs structural
  validation **without** source-pack checksum verification
  (`E_IMPORT_SOURCE_PACK_REQUIRED` under strict mode is expected there).
  Checksum-pinned import verification remains a Windows/Mac-local step.
- UI-test target exists but is deliberately not executed in CI yet (slow,
  headless flake risk); add later as its own step if wanted.
- If the repo ever goes private, macOS minutes bill at a 10x multiplier.

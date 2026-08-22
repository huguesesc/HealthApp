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
| 2026-08-23 | workflow added in `ci: add simulator build and test verification` | pending first real run | first run triggered by the push of this commit; results appended below |

## Known limitations

- The source image pack lives outside the repository, so CI runs structural
  validation **without** source-pack checksum verification
  (`E_IMPORT_SOURCE_PACK_REQUIRED` under strict mode is expected there).
  Checksum-pinned import verification remains a Windows/Mac-local step.
- UI-test target exists but is deliberately not executed in CI yet (slow,
  headless flake risk); add later as its own step if wanted.
- If the repo ever goes private, macOS minutes bill at a 10x multiplier.

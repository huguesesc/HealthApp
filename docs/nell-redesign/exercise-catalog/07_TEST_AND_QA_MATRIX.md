# Test and QA matrix

Automation status below is the required target, not a claim that Sol ran iOS tests. `A` = automated, `M` = manual, `A+M` = both. Task IDs own implementation.

| Group | Purpose and setup | Expected result | Status | Owner |
|---|---|---|---|---|
| Manifest happy path | Decode minimal, rich, no-media, pair, multi-frame, deprecated fixtures | Values round-trip and indexes build | A | T02–T08 |
| Schema version | Load supported, older transform fixture, and newer unsupported version | Supported loads; newer returns typed error; no silent best effort | A | T08 |
| Unique IDs | Duplicate, case-fold collision, malformed regex fixtures | Validation fails at exact entries | A | T03, T09 |
| Aliases/legacy IDs | Unique aliases, collision, ambiguous title, exact legacy ID | Exact unique resolves; ambiguous is explicit; no substring match | A | T08, T15 |
| Equipment taxonomy | Every required type; quantities; alternatives; pair/single equivalence; cycles | Correct deterministic satisfaction; invalid definitions rejected | A | T04, T09 |
| Environments | Preset expansion plus floor/wall/anchor/machine/jump/noise contradictions | Hard capability rules override preset ranking | A | T05 |
| Asset existence | Manifest keys against generated media index/imagesets | Missing references fail with exact key/file | A | T09, T12–T13 |
| Orphan detection | Add unreferenced generated/intake fixture | Orphan reported; allowlist requires reason | A | T09 |
| PNG integrity | Invalid PNG, extension, double period, dimensions, alpha, case collision | Strict errors/warnings follow policy and suggest fix | A | T09–T12 |
| Duplicate content | Same SHA file under two keys; optional near-duplicate report | Exact duplicate rejected/reported; no automatic semantic merge | A+M | T09–T10 |
| Media roles/order | No media, one, composite, start only, end only, gaps, duplicate sequence | Valid forms pass; pair/order defects fail | A | T06, T09 |
| Media fallback | Inject absent index/key/UIImage | Written UI and vector/state fallback render; no crash | A+M | T14, T23 |
| Bundle integration | Resolve runtime JSON, index, and sample asset in Debug/Release built product | All present in both configurations | A+M | T13, T27 |
| Catalogue repository | Fake bundle, corrupt JSON, duplicate index, cancellation/concurrent reads | One safe load, immutable results, typed diagnostics | A | T08 |
| Filtering | Context matrices for equipment/location/capability/goal/duration | Ineligible removed; ranking stable; media ignored | A | T05, T17 |
| Generation payload | Stub client captures compact candidates | Only eligible IDs and required compact metadata sent | A | T17 |
| Invalid generated IDs | Unknown, deprecated, disabled, ambiguous, ineligible, exact legacy alias | Reject or audited exact repair before preview/save | A | T18 |
| Confirmation boundary | Stub proposal before/after confirmation | Nothing saved before confirmation; valid IDs saved after | A | T18; existing suite |
| Custom exercise | UUID-backed custom proposal/history with no catalogue definition | Saved snapshots remain readable with fallback | A+M | T16, T18, T22 |
| Old plan mapping | Old title-only plan with exact, ambiguous, unknown titles | Exact resolves optionally; ambiguous/unknown preserved | A | T15–T16 |
| Old active session | Open prior-store in-progress session; resume/skip/complete | State preserved; exactly one history conversion | A+M | T16, T21 |
| Completed history | Rename/deprecate current definition after fixture completion | Historical name/instructions unchanged; current detail optional | A+M | T16, T22 |
| SwiftData migration | Copy old schema store with profile/locations/plans/active/history | Store opens without loss; optional new fields decode nil/valid | A+M | T16, T27–T28 |
| Migration rollback | Exercise documented pre-release backup/failed migration path | No original fixture destroyed; recovery steps work | M | T16, T28 |
| Catalogue list/search | Long/short names, aliases, empty/error/deprecated/no-media | Correct search/filter/state and stable navigation | A+M | T19 |
| Detail/media paging | Single/composite/pair/multi-frame/alternate | Correct order, role labels, aspect fit, written text primary | A+M | T14, T19 |
| Workout preview | Canonical/no-media/custom/unknown steps | Review and confirmation remain usable | A+M | T20 |
| Active Workout UI | Media present/missing with timers and controls | No crowding; controls/text precede image; behavior unchanged | A+M | T21 |
| History UI | Snapshot vs current resolution/deprecated/custom | Snapshot truth is primary and clearly labelled | A+M | T22 |
| Debug gallery | All entries plus invalid/missing/deprecated filters | Full inventory visible in DEBUG | A+M | T24 |
| Release exclusion | Build Release and inspect route/symbol/navigation behavior | Gallery cannot be reached from release UI | A+M | T24, T27 |
| VoiceOver | Catalogue, detail, preview, active, history, gallery on representative entries | Logical text-first order; useful labels; decorative images hidden | M (UI assertions where possible) | T26 |
| Dynamic Type | Default, AX1, AX5 on small/large phones | No clipped instructions/controls; scrolling remains usable | A+M | T26 |
| Dark mode | Transparent-edge media and fallbacks on light/dark surfaces | No unreadable halos/backgrounds; contrast acceptable | A+M | T26 |
| Reduce Motion | Paging/transitions with setting enabled | No essential information depends on animation | M | T26 |
| Simulator matrix | Current minimum-supported iOS and latest installed; small/large iPhone | Core flow and upgrade flow pass; versions recorded | M | T27 |
| Physical device | Install-over-existing, offline, resume, media gallery, VoiceOver | Real-device flow passes; memory/rendering acceptable | M | T28 |
| Release build | Clean generic simulator/device Release build as signing permits | Build succeeds with no missing resources | A | T27 |
| Failure injection | Corrupt manifest, unsupported version, missing media, invalid model ID, old store | Typed/debug diagnostics; release-safe behavior; no data loss | A+M | T08, T18, T23, T27 |
| Import idempotence | Run approved import twice | Second run produces no Git diff | A | T12, T30 |
| Contributor workflow | Follow docs from fresh clone with fixture asset | Commands succeed without hidden manual Xcode edits | A+M | T29 |

## Required evidence format

For every executed row record date, commit, command or manual procedure, host/OS, simulator/device, result, and linked defect. A skipped or unavailable row is `NOT RUN`, never `PASS`. Physical-device and real old-store upgrade rows remain release risks until executed.


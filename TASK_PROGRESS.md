# Task Progress

Updated: 2026-07-27 10:01 CST (Asia/Shanghai)

## macOS Internet Angel Interaction Regression Fix (2026-07-27 09:34 CST)

- [verified] Work continues on `codex/macos-internet-angel-parity` and ready
  PR #8. The worktree was clean at `d4d9be8` before this follow-up. Scope is
  restricted to the two exact bundled Internet Angel preset IDs; Gothic and
  imported themes must remain unaffected.
- [verified] Real CDP pointer input reproduces the auxiliary workspace failure.
  The Browser tab becomes selected, but the themed workspace root collapses
  from `991px` to `86px` and its tab panel from `945px` to `40px`. Clicking an
  Edited files row selects Review, but the broken root expands the Review panel
  to `16807px`, removes its bounded scroll container and prevents native file
  positioning from being visible.
- [verified] Temporarily restoring the workspace root's native
  `position: absolute` returns the root to `991px`, Browser/Review to `945px`
  and Review to a bounded `905px` scroll viewport. The cause is the macOS
  overlay marking multiple nested workspace candidates and forcing
  `position: relative !important`; it is not a browser network/load failure.
- [verified] The sidebar scroll root remains `871px` high with `2806px` of
  content. The themed `1px` border reduces each fixed row to a `28px` client
  box around `29px` of content, producing a nested `1px` vertical scroll range
  that consumes wheel input. Temporarily clipping row vertical overflow keeps
  row `scrollTop` at zero and routes wheel input to the native sidebar scroller.
- [verified] Red-green regressions now require exactly one innermost workspace
  mark, forbid workspace positioning overrides and positioned decoration, and
  require fixed-height sidebar rows to clip vertical overflow. The classifier
  selects only the smallest valid right-docked workspace. The CSS paints its
  cyan/blue/pink top stripe as a background layer and no longer changes native
  position, dimensions, overflow or z-index.
- [verified] Source hot injection and real input checks pass. A first wheel event
  over a sidebar row moves the native root from `scrollTop=0` to `420` while all
  rows stay at zero. Opening `Browser` from the right-panel add menu produces a
  full `945px` `New tab` panel with the native address field and Start browsing
  surface. Clicking `macos/tests/internet-angel-macos.test.mjs` from Edited
  files switches from Browser to Review, scrolls Review to `4641`, and leaves
  the requested file header visible at panel `y=92`.
- [verified] The targeted native-window screenshot shows the complete Browser
  surface without clipping, overlap or document overflow. Computer Use refused
  access to `com.openai.codex` by policy and CDP screenshots block while the
  embedded browser is open, so the visual capture used macOS window-level
  `screencapture`; interaction and geometry assertions remain CDP-derived.
- [verified] `CODEX_DREAM_SKIN_SKIP_DOCTOR=1 macos/tests/run-tests.sh` passes
  all shell/Node, shared runtime, Safe CSS, import/ZIP and 10 Swift XCTest cases.
  A temporary arm64 app build passes strict code-signature verification, reports
  an arm64 Mach-O executable and contains byte-identical overlay CSS/JS assets.
  `git diff --check` also passes.
- [in progress] Complete the final scoped diff review, commit the implementation
  and progress evidence, and push the exact head to existing ready PR #8. No
  install, merge, version bump, tag or Release is part of this follow-up.

## macOS Internet Angel Complete Surface Audit (2026-07-27 01:22 CST)

- [verified] Performed a bidirectional parity audit between the Windows
  renderer/CSS component inventory and the currently open macOS Codex DOM. The
  scope remains exact Internet Angel preset IDs only; Gothic and imported themes
  must remain unaffected.
- [verified] Live CDP evidence reproduces all newly reported gaps. The open
  Environment flyout contains two native sections, but the macOS classifier marks
  only the first header/section; the Sources header therefore keeps its native
  black background. The left sidebar currently has 195 `sidebar-row` marks,
  including nested folder controls and screen-reader-only buttons, and applies a
  visible rest-state plate to all of them. Its native inner scroll container is
  still functional (`clientHeight=871`, `scrollHeight=2161`), so the defect is
  visual hierarchy loss rather than a broken scrollbar.
- [verified] Windows has dedicated `changes-pill`, `changes-shell` and
  `changes-clip-host` classification and CSS for the compact changed-files status;
  the macOS overlay currently has none of those components. Windows also keeps
  ordinary sidebar buttons transparent at rest and reserves the full plate for
  selected rows, unlike the current macOS overlay.
- [verified] Added red-green DOM/CSS regressions and exact-theme-gated coverage for
  both Environment/Sources sections, the compact changed-files shell/clip/pill,
  transparent sidebar rest states, native selected rows, the composer goal-mode
  trigger and settings app-main controls. A direct Windows-to-macOS component
  contract now checks the remaining interaction surfaces for classifier and CSS
  coverage.
- [verified] A real `920x820` macOS window exposed a second Environment rendering
  path: a visible Radix popover exists beside the exiting `absolute z-40` portal.
  The old classifier accepted only the latter and mislabeled the visible panel as
  `summary-panel`. The classifier now accepts both portal hosts while retaining
  the existing dual-section, button-count and Git/semantic safety gates. The
  theme never writes portal position or translation overrides.
- [verified] Source hot injection and real-window evidence pass at `920x820` and
  restored `1694x991`. The visible Radix panel is inside `x=542..842`, the restored
  panel is inside `x=1378..1678`, both Environment/Sources headers are themed,
  only the active sidebar task has a selection plate, expanded project folders
  remain transparent, and the composer/changed-files pill/document have no
  horizontal overflow. The native window was restored to its original bounds.
- [verified] `CODEX_DREAM_SKIN_SKIP_DOCTOR=1 macos/tests/run-tests.sh`
  completed with shell/Node syntax checks, shared runtime synchronization,
  Safe CSS, import/ZIP/runtime coverage and 10 Swift XCTest cases passing; the
  live Doctor was explicitly skipped. An arm64 menu-bar `.app` built into `/tmp`,
  passed strict `codesign` verification, reported an arm64 Mach-O executable and
  contained byte-identical Internet Angel CSS/JS assets.
- [verified] Final focused Internet Angel regression, both touched Node syntax
  checks and `git diff --check` pass. The worktree contains only the four intended
  follow-up files.
- [verified] Implementation and regressions were committed as `7447acc` and
  pushed to the existing ready PR #8 branch. This progress-only update records
  the completed verification and push. No merge, install, version bump or Release
  was performed.

## macOS Internet Angel Detail Parity Follow-up (2026-07-27 00:18 CST)

- [complete] Re-audited the current macOS renderer against the Windows Internet
  Angel implementation for Output, expanded Edited files details and the full
  conversation surface. Scope remains exact-theme-ID gated and must not affect
  Gothic or imported themes.
- [verified] Live Codex 26.721.41059 DOM inspection shows the Edited files card
  shell is classified, but its icon, action group, distinct Undo/Review states,
  file-list rows and Show-more footer have no component markers. The existing
  macOS summary fixture is an Environment lookalike, so it does not exercise a
  real Output panel.
- [verified] The current renderer no longer exposes `[data-message-author-role]`;
  user bubbles, assistant responses, message actions, historical activities and
  streaming activities now use current structural markers. Inline command/output
  bodies and the right-side Outputs summary receive dedicated theme surfaces.
- [complete] Expanded Edited files cards now classify and style the icon, action
  group, distinct Undo/Review buttons, file-list surface, clickable rows, paths,
  per-file statistics and Show-more footer. The later generic resource-card rule
  explicitly excludes classified edited cards so it cannot overwrite the
  dedicated cyan/pink treatment.
- [verified] Focused red/green regressions, JavaScript syntax, all macOS shell
  syntax, the complete macOS repository suite and 10 Swift XCTest cases pass.
  Live Codex checks at 1694x991 and an emulated 900x900 viewport show no horizontal
  overflow; the card controls and paths remain contained. The current Outputs
  panel, Edited files details, conversation bubble and computed styles were
  checked from source-injected screenshots.
- [verified] A fresh arm64 app build completed. Strict code-signature verification,
  arm64 Mach-O inspection and byte-for-byte packaged overlay asset comparisons
  pass. The build was not installed or published.
- [complete] Follow-up commit `2111c3b` is pushed to the account fork and ready
  PR #8 now points at that exact implementation. GitHub reports the PR open and
  `BLOCKED` with no check rollup; CI and maintainer review remain separate gates.
  No merge, release or install is claimed.

## macOS Internet Angel Visual Parity (2026-07-26 21:48 CST)

- [complete] Branch `codex/macos-internet-angel-parity` adds a macOS-only,
  exact-theme-ID overlay for both bundled Internet Angel presets. It covers the
  composer, Environment/Changes, left navigation and footer, Add palette, turn
  navigation, settings, terminal/summary, selection, edited-file, overlay and
  subagent surfaces without activating for Gothic or custom themes.
- [complete] Rebased the implementation onto current `origin/main@78497ca`
  (v1.5.7). Conflict resolution preserves the current native-window readiness
  gate, validated Safe CSS composition and current version while adding the
  Internet Angel surface gate to the final renderer assessment.
- [verified] Shared runtime synchronization, the complete macOS suite, 10 Swift
  XCTest cases, signed-runtime checks and live Doctor all pass on the rebased tree.
  The current Codex 26.721.41059 renderer reports `pass: true` with the composer,
  Environment, sidebar footer, turn rail and scroll-to-bottom coverage active and
  no horizontal overflow.
- [verified] An arm64 `Codex Dream Skin.app` build completed at version 1.5.7.
  Strict code-signature verification, Mach-O architecture and packaged overlay
  asset presence all pass. The temporary build was not installed or published.
- [complete] Commits `88afb57` and `e7bdd80` are pushed to the account fork.
  Ready PR #8 targets upstream `main@78497ca`:
  `https://github.com/EmiyaKatuz/Codex-Dream-Skin-Needy-Girl-Overdose/pull/8`.
- [pending] GitHub checks and maintainer review have not completed. The PR is
  open and currently reports `BLOCKED` with no check rollup yet; it is not
  merged or released. No version bump, tag, Release publication or installation
  is in scope.

## v1.5.1 Version Release (2026-07-25 08:28 HKT)

- [complete] Created `codex/release-v1.5.1` from the exact synchronized
  `origin/main@3593e8f`. No remote `v1.5.1` tag or GitHub Release existed at
  preflight.
- [complete] Updated the six release version sources to `1.5.1`, the two
  macOS current-version assertions, and the dated macOS/Windows changelog
  headings. The Windows readiness fixture added by #249 also encoded the
  current injected version; its `1.5.0` value initially made the two positive
  readiness cases fail after the bump, so that corresponding assertion now
  reports `1.5.1`. Historical changelog entries and unrelated fixture data
  remain unchanged.
- [verified] Six-source consistency, semantic/unpublished-tag preflight,
  focused macOS update/common version assertions, Bash and Node syntax, both
  injector payload checks, 21 macOS and 11 Windows portable Node regressions,
  and `git diff --check` pass locally. The Windows suite was rerun after the
  fixture correction and passed all 11 tests.
- [complete] Release commit `3289f64` is pushed to
  `codex/release-v1.5.1`; ready PR #250 targets `main` with that exact head.
- [verified] Initial CI run `30136427124` passed Static checks; both Windows
  suites passed their regressions/static checks and macOS passed regressions
  plus its native build before the required durable-progress checkpoint.
- [in progress] Push this progress-only docs commit to PR #250, then require a
  fresh Static checks, Windows PowerShell 5.1, PowerShell 7, and macOS run for
  the new exact head. The superseded CI head is not merge evidence.
- [pending] After merge, verify the automatic Release workflow creates a
  `v1.5.1` tag at the exact merge commit and publishes non-empty DMG, Setup.exe,
  and `SHA256SUMS.txt` assets. No manual package, tag, or Release publication is
  permitted.

## v1.5.1 Installer Preflight Fix (2026-07-25 07:36 HKT)

- [complete] Branch `codex/fix-macos-installer-preflight-v1.5.1` moves
  `discover_codex_app` before the outer running-app guard, so `CODEX_EXE` and
  the exact app bundle are bound before any engine bytes can be deployed.
- [complete] A real outer-installer regression covers the closed-app inner
  failure rollback and a compiled matching app process rejected before deploy;
  it verifies that the prior engine stays intact and no installing, previous or
  broken staging tree remains.
- [verified] Root reran Bash syntax, the focused installer preflight regression,
  `git diff --check`, and the complete macOS CI-parameter suite with signed
  runtime and Doctor integrations explicitly skipped. All applicable checks
  passed; full-Xcode SwiftPM/XCTest remains an environment skip.
- [complete] Fix commit `747c618` was pushed in PR #247. GitHub Actions run
  `30134848593` passed Static checks, both Windows jobs and macOS repository
  regressions; the PR was squash-merged to `main@3aa89d7` after bypassing only
  the impossible same-account self-review requirement.
- [complete] The post-merge Release guard run `30135002941` skipped duplicate
  publication successfully because the version remained 1.5.0. Post-merge CI
  run `30135002980` also passed all four jobs, including DMG and Setup builds.
- [in progress] Public v1.5.0 remains unsuitable for website enablement. ChatGPT
  26.721.41059 currently reaches CDP without a native window; an independent
  worktree is implementing correct post-CDP app activation and fail-closed
  visible-window verification before the separate v1.5.1 version PR.
- [in progress] A Windows parity audit found the same release-blocking class:
  the current verifier can accept hidden or minimized L0/L1 renderers without
  native-window evidence. A separate origin/main worktree owns Windows window
  binding, DOM visibility and non-minimized readiness tests. Both platform fixes
  must merge before the v1.5.1 version bump.
- [complete] macOS readiness commit `1d76a86` plus test-isolation follow-up
  `e7cc38c` passed all four PR CI jobs in run `30135795473`; PR #248 was
  squash-merged to `main@ea5f37f`.
- [complete] Windows readiness commit `fc454cb` passed all four PR CI jobs in
  run `30135894880`, including the new PowerShell 5.1 startup rollback fixture;
  PR #249 was squash-merged to `main@3593e8f`.
- [in progress] Prepare the separate v1.5.1 version-only branch from
  `main@3593e8f`, update all six sources, both assertions and both changelogs,
  then require CI before merge and automatic Release publication.

## v1.5.0 Installed Release Finding (2026-07-25 07:18 HKT)

- [complete] Public v1.5.0 Release/tag/DMG/Setup.exe/SHA256SUMS were independently
  downloaded and verified. The DMG installs and registers `dreamskin`, but a
  real engine upgrade exposed a release P1: the outer installer invokes
  `codex_is_running` before `discover_codex_app`, so its pre-copy running-app
  guard expands undefined `CODEX_EXE` and fails open under `set -u`.
- [complete] The failed real upgrade atomically restored the entire previous
  v1.4.0 engine tree; no mixed tree or installer staging residue remains and the
  original active theme bytes are unchanged.
- [blocked] Current ChatGPT `26.721.41059` opens a loopback CDP target but has no
  native window after launch on this host. The v1.5.0 injector applies its exact
  payload to that target but correctly refuses visible verification, so the
  outer installer rolls back. Do not enable the website for v1.5.0.
- [in progress] Prepare a focused v1.5.1 installer-preflight fix with functional
  regression coverage, then retest a public build and the current renderer
  before enabling the website.

## Final Publication Gate (2026-07-25 06:23 HKT)

- [complete] PR #245 passed all four CI jobs and was squash-merged to client
  `main` as `71f30f0`. The v1.4.0 Release guard completed successfully without
  publishing a duplicate because the feature PR did not change versions.
- [complete] Separate branch `codex/release-v1.5.0` changes only the six version
  sources, two version assertions and the macOS/Windows changelog headings.
  Version consistency, stale-reference scan, all 24 portable Node regressions,
  the CI-mode macOS suite and `git diff --check` pass locally.
- [complete] Version-only commit `3c43752` was pushed and Draft PR #246 targets
  `main`.
- [complete] PR #246 passed all four CI jobs and was squash-merged to client
  `main` as `aad9fc0`.
- [in progress] Automatic Release run `30131800275` is building v1.5.0 from
  that exact main commit. No public v1.5.0 tag/assets, website enablement or
  deployment exists yet.
- [complete] Initial PR #245 CI run `30130742965` exposed three gaps. The
  macOS-only Swift fixture now reports a real Node test skip on non-Darwin
  hosts; the signed package-identity shell integration honors the repository's
  existing CI skip; and Windows runtime fingerprinting recursively
  canonicalizes object keys so active-image renaming cannot change content
  identity.
- [verified] Root reproduced the Windows fingerprint mismatch with portable
  PowerShell, then proved the saved/active hashes are identical after the fix.
  CI-mode macOS regressions, 20 macOS and 4 Windows Node regressions, all
  PowerShell parse/encoding checks and `git diff --check` pass locally. Repair
  commit `3a2c809` is pushed; fresh CI run `30131282832` is the active gate.
- [complete] Feature commit `c44b434` was pushed to
  `codex/one-click-theme-apply`; Draft PR #245 targets `main`. All release
  version sources intentionally remain `1.4.0`.
- [in progress] PR #245 must pass Static checks, Windows PowerShell 5.1,
  PowerShell 7 and macOS repository regressions before it is marked ready or
  merged.
- [complete] The independent final Windows read-only audit reports PASS with no
  P0/P1 findings. `git diff --check` passes. Native PowerShell 5.1, compiled
  Setup.exe protocol registration and a real Windows renderer transaction remain
  required PR CI/Windows-host gates rather than local macOS claims.
- [complete] Root reran all 24 portable macOS/Windows Node regressions and the
  complete macOS repository suite on the final stable tree. Both passed; only
  the documented full-Xcode XCTest and installed-app Doctor branches skipped on
  this Command Line Tools host.
- [complete] Final static checks and an x86_64 native app build passed, including
  strict codesign, exact `dreamskin` URL-scheme registration and packaged helper
  inventory.
- [fact] The public client remains v1.4.0 and the website one-click action remains
  correctly disabled until the automatic v1.5.0 Release is public and verified.

## Root Integrated macOS Recheck (2026-07-25 05:50 HKT)

- [complete] Root independently reran the exact pre-switch community transaction
  regression, private ZIP identity regression, focused bounded-HTTP/import/
  staging Node tests, relevant Bash syntax, plist validation and
  `git diff --check`; all passed on the combined macOS tree.
- [complete] All 13 currently approved production ZIPs were exercised through
  the current strict macOS importer with an isolated temporary HOME. Every one
  failed closed on the missing required `theme.css`, and the isolated saved-theme
  library remained empty. The real user theme library and active renderer were
  not changed by this rejection test.
- [pending] Windows click-time baseline closure, combined cross-platform CI,
  final public Release install and website-button acceptance remain.

## macOS Rollback Pre-Switch Closure (2026-07-25 05:43 HKT)

- [complete] Inside the inherited community operation lock, the macOS
  transaction now snapshots the active theme and runs `injector --verify`
  against that exact snapshot and current CDP port before the first switch.
  The injector therefore checks both the rollback theme ID and computed payload
  revision against the renderer; a mismatch exits before any theme switch.
- [complete] The transaction fixture now records exact renderer-verification
  calls. A state mismatch proves zero verification and zero switches; an
  injected renderer-verification failure proves one verification and zero
  switches. Success, verified rollback and failed rollback cases continue to
  pass under one inherited lock.
- [complete] Rollback retention now distinguishes a snapshot promoted to the
  private `recovery/` tree, a structurally validated snapshot retained in its
  original operation directory when promotion fails, and no confirmed
  snapshot. The App does not delete an in-place fallback, startup stale cleanup
  skips community operations containing such a snapshot, and UI/docs no longer
  promise that retaining a snapshot means recovery succeeded.
- [verified] `macos/tests/community-apply-transaction.test.sh`, focused
  `bash -n`, `git diff --check`, and a standalone Swift recovery-promotion
  failure smoke pass. A direct x86_64 app build with the macOS 14.4 SDK passed at
  `/tmp/CodexDreamSkin-one-click-macos-closure.app`; strict ad-hoc signature,
  exact bundled transaction-script bytes, and the `dreamskin` URL scheme were
  rechecked. The build was not installed.
- [remaining] The owner must rerun the combined macOS suite after all agents
  finish, rebuild the final integrated app, reinstall it, verify bundled engine
  identity, and repeat the installed renderer transaction. Full SwiftPM/XCTest
  remains a CI/full-Xcode gate on this Command Line Tools-only host.

## Windows Transaction Hardening (2026-07-25 05:06 HKT)

- [complete] Community downloads now pass their approved byte count and SHA-256
  into the strict ZIP importer. The importer opens the archive exclusively,
  checks both values on that same FileStream, rewinds it, and extracts from the
  still-open handle. Replacement, truncation and wrong-hash regressions were
  added.
- [complete] Imported and duplicate results now return a stable runtime-content
  fingerprint. One-click apply copies the saved theme into a private transaction
  snapshot, recomputes the exact fingerprint, and refuses to write active files
  unless it still matches.
- [complete] The Windows operation lock now covers the exact active snapshot and
  active-file write. The parent releases it before invoking
  start-dream-skin.ps1, because that script acquires the same lock and only
  exits after exact renderer verification. Failed writes and failed startup
  restore under lock, restart, and verify the previous renderer; a newer manual
  theme choice is detected and never overwritten.
- [complete] Native confirmation metadata rejects Unicode Format, bidi,
  line-separator and paragraph-separator characters. Mocked transaction tests
  cover success, wrong private identity, partial writes, verified rollback,
  rollback file/renderer failure, and concurrent supersession.
- [in progress] Independent PowerShell 5.1/transaction review is running. This
  macOS host has no powershell.exe or pwsh, so executable Windows tests,
  Setup.exe protocol registration, and the real renderer transaction remain
  Windows CI/host gates. git diff --check currently passes.

## Active Scope

- Worktree: `/private/tmp/dreamskin-one-click.36Mjwl`
- Branch: `codex/one-click-theme-apply` based on public v1.4.0/main `277b520`
- Goal: strict `dreamskin://apply?version=ver_...` website-to-client apply for macOS and Windows.
- User primary client worktree was not touched.

## Root Repeated Installed Acceptance (2026-07-25 04:41 HKT)

- Root independently re-imported the three compliant official fixtures through
  the installed strict importer; each returned `duplicate`, validated Safe CSS
  and the expected stable content fingerprint.
- Root switched all three themes live again. Exact renderer verification passed
  each theme ID/revision with visible shell/sidebar/composer/home, zero business
  class pollution and no horizontal overflow. Fresh evidence is under
  `/private/tmp/dreamskin-installed-smoke.iVev9i/`.
- A deliberately wrong imported-content fingerprint exercised the parent
  transaction failure path. It returned exit `20`, reapplied the exact previous
  snapshot and visibly reverified it. Root then reapplied the exact original
  snapshot; `preset-gothic-void-crusade` is active and verified now.
- macOS metadata display validation now explicitly rejects bidi controls and
  line/paragraph separators that could visually spoof the native confirmation.
  Targeted tests and the final rebuild/reinstall remain after this edit.

## macOS Safety Closure

- Implemented fixed-origin bounded HTTP with explicit redirect failure, header/chunked size bounds, cancellation, and exactly-once completion coverage.
- Community ZIP import rechecks approved byte count and SHA-256 on the private no-follow snapshot used for extraction.
- Import publishing returns a runtime content fingerprint; staging calculates the same fingerprint and switching requires an exact match.
- Community apply holds one cross-process transaction lock across exact active-theme snapshot, apply/render verification, and verified rollback. Fresh ownerless locks fail closed; only a dead owner or an ownerless lock at least 10 minutes old is reclaimable.
- The rollback snapshot contains the exact active `theme.json`, referenced image, optional `theme.css`, and content identity even when the active theme is not in `themes/<id>`.
- Hot apply now runs exact injector verification; cold apply already runs `injector --verify` against the active theme before success. Failed community apply re-applies and verifies the exact snapshot; exit 20 means verified recovery, exit 21 means recovery was not verified.
- Quit/menu termination is blocked while network, import, apply, recovery, engine install, or runtime operations are busy. Startup removes only stale private operation directories older than 24 hours and preserves community operation roots that still contain a structurally validated rollback snapshot.
- Native confirmation states that a cold apply may restart ChatGPT and that unsent input should be saved. Menu progress covers metadata, download, import, snapshot/apply, and recovery state.

## Verification

- Root independently reran `CODEX_DREAM_SKIN_SKIP_DOCTOR=1
  macos/tests/run-tests.sh`: PASS, with only the documented full-Xcode
  SwiftPM/XCTest and explicitly skipped Doctor branches omitted.
- Root built and installed `/tmp/CodexDreamSkin-one-click-root.app`, verified
  its ad-hoc signature, `dreamskin` URL scheme, complete runtime inventory,
  and byte-identical deployed engine. The previous 1.3.3 app, engine and user
  state are recoverably backed up at
  `/tmp/dreamskin-before-one-click.g6pClo`.
- The real installed importer added three official four-file fixtures as
  `local-one-click-1/2/3`; all reported `safeCssStatus=validated` and a stable
  content fingerprint without changing the active theme during import.
- The installed switcher applied all three fixtures to the real ChatGPT/Codex
  renderer. Exact `injector --verify` passed each theme ID/revision, Safe CSS,
  visible shell/sidebar/composer/card geometry, matching text colors, zero
  business-class pollution and no document overflow. Screenshots are
  `/tmp/dreamskin-local-one-click-1.png`,
  `/tmp/dreamskin-local-one-click-2.png`, and
  `/tmp/dreamskin-local-one-click-3.png`.
- Root restored `preset-gothic-void-crusade`; its active theme/image are
  byte-identical to the pre-test backup (SHA-256 `8316c6ad...` and
  `b76a7cbe...`), exact renderer verify passes, and deep status reports
  `session=active`, `injectorAlive=true`, `cdpOk=true`.
- LaunchServices delivered malformed and canonical production legacy
  `dreamskin://` links to the installed app as native warning windows. The
  production exact-metadata route currently returns 404, so the legacy link
  failed closed and did not change the active theme. A successful end-to-end
  network apply still requires a deployed compatible package.

- `CODEX_DREAM_SKIN_SKIP_DOCTOR=1 macos/tests/run-tests.sh`: PASS. SwiftPM/XCTest skipped because this Command Line Tools host has no matching full Xcode platform; Doctor intentionally skipped. Signed-runtime switch and runtime-state integration passed.
- Direct Swift x86_64 typecheck with macOS 14.4 SDK: PASS.
- Bounded HTTP redirect/oversize/chunked/cancel/exactly-once fixture: PASS.
- Community import private-snapshot byte/SHA identity fixture: PASS.
- Community transaction success/verified rollback/rollback-failure and inherited-lock fixture: PASS.
- `DREAMSKIN_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX14.4.sdk DREAMSKIN_ARCHS=x86_64 macos/scripts/build-menubar-app.sh --skip-tests --output /tmp/CodexDreamSkin-one-click-hardened.app`: PASS. Built Mach-O x86_64; packaged runtime helpers and `dreamskin` URL scheme verified.
- `git diff --check`: PASS before final build.

## Remaining Integrated Work

- No commit, push, PR, merge, replacement Release, or deployment has occurred.
  A local development build is installed and fully backed up; public v1.4.0
  still does not contain one-click apply.
- A complete fixed-origin network success smoke still requires a deployed
  approved `applyCompatible: true` package. Existing approved legacy
  production packages are intentionally preview/download-only.
- Real Windows PowerShell 5.1 and Setup.exe protocol install require Windows CI/host verification.

# macOS Internet Angel Visual Parity Implementation Plan

> **Implementation status:** Completed locally on 2026-07-26. Steps use checkbox (`- [x]`) syntax to preserve the executed verification record.

**Goal:** Reproduce the Windows Internet Angel visual system across the macOS Codex interface for both bundled Internet Angel presets while leaving every other theme unchanged.

**Architecture:** Keep the canonical macOS runtime as the safe base and add a packaged macOS-only Internet Angel CSS/JS overlay. Compose it for an exact theme-ID allowlist, classify dynamic native surfaces with removable data attributes, and validate the real renderer with CDP screenshots and computed styles.

**Tech Stack:** macOS Bash 3.2, Node.js 24 from the signed ChatGPT bundle, JavaScript ESM, Chromium CSS, CDP, SwiftPM menu-bar packaging.

---

### Task 1: Lock Conditional Activation With Failing Tests

**Files:**
- Create: `macos/tests/internet-angel-macos.test.mjs`
- Modify: `macos/tests/run-tests.sh`
- Modify: `macos/tests/injector-bootstrap.test.mjs`

- [x] **Step 1: Add an activation matrix test**

Test exact IDs with exported `usesInternetAngelMacosOverlay(theme)`:

```js
assert.equal(usesInternetAngelMacosOverlay({ id: "preset-internet-angel" }), true);
assert.equal(usesInternetAngelMacosOverlay({ id: "preset-internet-angel-default" }), true);
assert.equal(usesInternetAngelMacosOverlay({ id: "preset-gothic-void-crusade" }), false);
assert.equal(usesInternetAngelMacosOverlay({ id: "custom-internet-angel-copy" }), false);
assert.equal(usesInternetAngelMacosOverlay({ id: "custom-1", name: "INTERNET ANGEL" }), false);
```

- [x] **Step 2: Add asset/lifecycle assertions**

Assert that the overlay source contains `data-angel-component`, a cleanup
function, bounded observer options, and no pointer-enabled decoration or broad
transcript observer.

- [x] **Step 3: Register the test and run it red**

Run:

```bash
/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node \
  macos/tests/internet-angel-macos.test.mjs
```

Expected: failure because the overlay files and exported activation helper do
not exist.

### Task 2: Add The Conditional Payload Layer

**Files:**
- Create: `macos/assets/internet-angel-macos.css`
- Create: `macos/assets/internet-angel-macos.js`
- Modify: `macos/scripts/injector.mjs`
- Modify: `macos/menubar-app/Sources/CodexDreamSkinMenuBar/AppDelegate.swift`
- Modify: `macos/tests/injector-bootstrap.test.mjs`

- [x] **Step 1: Export the exact allowlist helper**

Add an immutable allowlist and a pure helper:

```js
const INTERNET_ANGEL_MACOS_THEME_IDS = new Set([
  "preset-internet-angel",
  "preset-internet-angel-default",
]);

export function usesInternetAngelMacosOverlay(theme) {
  return INTERNET_ANGEL_MACOS_THEME_IDS.has(String(theme?.id || "").trim());
}
```

- [x] **Step 2: Cache all four static assets**

Load the base CSS/template and both overlay files together. Compose CSS as
`baseCss + overlayCss` only when the helper returns true. Always append the
overlay lifecycle payload so a switch to Gothic can clean a previous session.
Include the composed CSS and overlay JavaScript in style/payload revisions.

- [x] **Step 3: Watch overlay files**

Treat changes to `internet-angel-macos.css` and
`internet-angel-macos.js` as static payload invalidations beside the existing
base assets.

- [x] **Step 4: Require the packaged assets**

Add both paths to `requiredEngineRelativePaths` so an older or incomplete
engine is repaired before use.

- [x] **Step 5: Run the focused activation tests green**

Run the Task 1 command and expect all activation and asset checks to pass.

### Task 3: Isolate Existing Internet Angel Home Styling

**Files:**
- Modify: `runtime/dream-skin.css`
- Generate: `macos/assets/dream-skin.css`
- Modify: `tools/renderer-runtime.test.mjs`
- Test: `macos/tests/runtime-css-nested-has.test.mjs`

- [x] **Step 1: Add a failing isolation assertion**

Parse the Internet Angel home section and assert every selector is rooted at
`html[data-dream-skin="active"][data-dream-theme="internet-angel"]`.

- [x] **Step 2: Gate existing home rules**

Add the `data-dream-theme="internet-angel"` root gate to legacy/current home,
command-deck, sidebar, and HUD selectors without changing their declarations.

- [x] **Step 3: Regenerate compiled macOS assets**

Run:

```bash
/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node \
  tools/sync-runtime-assets.mjs
```

Expected: only `macos/assets/dream-skin.css`, renderer compilation output when
needed, and selector copies are regenerated.

- [x] **Step 4: Verify generic themes remain generic**

Run the renderer runtime test for `preset-standard` and assert no Angel deck,
data attribute, or Angel-specific home selector can match.

### Task 4: Migrate Composer And Conversation Controls

**Files:**
- Modify: `macos/assets/internet-angel-macos.css`
- Modify: `macos/assets/internet-angel-macos.js`
- Test: `macos/tests/internet-angel-macos.test.mjs`

- [x] **Step 1: Add composer fixture assertions**

Create fixture nodes for `.composer-surface-chrome`, sticky bottom controls,
goal progress, access mode, model, and reasoning controls. Assert classification
adds only `data-angel-component` attributes and cleanup removes them.

- [x] **Step 2: Port the Windows visual grammar**

Implement the cyan/blue/pink composer frame, focus state, caret/selection,
send/stop button, attachment/menu controls, goal chip, access/model/reasoning
pills, and context strips. Keep native dimensions and click targets.

- [x] **Step 3: Run fixture tests green**

Expect exact component attributes and cleanup counts with no class writes.

### Task 5: Migrate Environment, Changes, And Side Workspaces

**Files:**
- Modify: `macos/assets/internet-angel-macos.css`
- Modify: `macos/assets/internet-angel-macos.js`
- Test: `macos/tests/internet-angel-macos.test.mjs`

- [x] **Step 1: Reproduce the current Environment DOM**

The fixture must include the real macOS structure: absolute `z-40` floating
host, pointer-events wrapper, `rounded-3xl bg-token-dropdown-background`
surface, section/header toggle, Changes, Local, branch, commit, and compare rows.

- [x] **Step 2: Classify without relying on English text alone**

Require the right floating geometry, section-toggle structure, Git row/icon
signals, and dropdown surface. Text may corroborate but cannot be the only
match. Mark the panel, header, changes section, and action rows.

- [x] **Step 3: Apply Windows-equivalent styling**

Use the broadcast panel frame, tricolor top rail, cyan/pink separators, themed
row hover/focus states, readable disabled actions, and semantic green/red diff
counts. Apply the same grammar to right browser/terminal/task workspaces while
preserving panel geometry.

- [x] **Step 4: Verify cleanup and uncertain-surface fallback**

An incomplete lookalike fixture must remain untouched. A valid fixture must be
fully unmarked after cleanup.

### Task 6: Migrate Remaining Thread And Overlay Surfaces

**Files:**
- Modify: `macos/assets/internet-angel-macos.css`
- Modify: `macos/assets/internet-angel-macos.js`
- Test: `macos/tests/internet-angel-macos.test.mjs`

- [x] **Step 1: Cover thread resources and status surfaces**

Port high-contrast user messages, assistant content readability, edited/change
cards, permission banners, summaries, selection actions, optional comments,
system toasts, and goal states from the Windows reference.

- [x] **Step 2: Cover portals**

Theme native `menu`, `listbox`, `dialog`, composer palette, tooltips, and
selection states under the Internet Angel root gate. Do not change portal
positioning or focus ownership.

- [x] **Step 3: Add reduced-motion and narrow-window rules**

At narrow widths remove decorative labels/rails first, retain the composer and
Environment actions, and keep text within each control. Disable decorative
animation under `prefers-reduced-motion`.

### Task 7: Extend Verification To Detect Visual Coverage

**Files:**
- Modify: `macos/scripts/injector.mjs`
- Modify: `macos/tests/injector-bootstrap.test.mjs`
- Modify: `macos/references/qa-inventory.md`

- [x] **Step 1: Report optional Internet Angel component probes**

For Internet Angel sessions, report composer border/background and any visible
Environment panel classification/background. Treat a present-but-unclassified
Environment panel as verification failure; an absent panel remains optional.

- [x] **Step 2: Add regression assertions**

Assert the verifier checks a visible composer on thread routes and checks a
visible Environment surface when present.

- [x] **Step 3: Update visual acceptance inventory**

Record normal/narrow composer, Environment, goal chip, menu/dialog, and theme
switch cleanup checks.

### Task 8: Run Full Automated Verification

**Files:**
- Verify all touched and generated files.

- [x] **Step 1: Run focused tests**

```bash
/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node \
  macos/tests/internet-angel-macos.test.mjs
/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node \
  macos/tests/renderer-inject.test.mjs
```

- [x] **Step 2: Run the complete macOS suite**

```bash
cd macos
./tests/run-tests.sh
```

- [x] **Step 3: Build the arm64 menu-bar app**

```bash
cd macos
DREAMSKIN_ARCHS=arm64 ./scripts/build-menubar-app.sh
```

- [x] **Step 4: Inspect Git diff and generated assets**

Run `git diff --check`, confirm no unrelated files changed, and verify the two
new overlay assets are included in the built app engine.

### Task 9: Verify In The Live macOS Renderer

**Files:**
- Create temporary screenshots under `/tmp`; do not add them to Git.

- [x] **Step 1: Apply the source payload once**

Use the verified loopback CDP port and current theme directory:

```bash
/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node \
  macos/scripts/injector.mjs --once --port 9341 \
  --theme-dir "$HOME/Library/Application Support/CodexDreamSkinStudio/theme"
```

- [x] **Step 2: Capture normal-width evidence**

Run the source verifier with a `/tmp` screenshot. Confirm composer,
Environment, goal chip, sidebar, header, and thread text are themed and do not
overlap.

- [x] **Step 3: Capture narrow-width evidence**

Resize the real Codex window without hiding essential controls, recapture, and
confirm no horizontal overflow or clipped labels.

- [x] **Step 4: Verify theme isolation**

Switch temporarily to Gothic, verify no `data-angel-component` attributes or
overlay styles remain, then restore the original Internet Angel preset and
verify again. Preserve user theme data throughout.

- [x] **Step 5: Report persistence boundary**

Live one-shot injection validates the source without restarting Codex. Updating
the installed engine requires an explicitly authorized Codex restart; do not
perform that restart implicitly.

### Task 10: Lock The Remaining Windows Delta With Failing Tests

**Files:**
- Modify: `macos/tests/internet-angel-macos.test.mjs`

- [x] Add structural fixtures for sidebar controls/footer, Add palette, turn
  navigation, settings, terminal/summary, selection/comment, edited cards, and
  subagent collaboration.
- [x] Assert exact `data-angel-component` values, cleanup, and specific-before-
  generic precedence.
- [x] Assert the CSS contains every new component contract and remains rooted
  at the exact Internet Angel theme gate.
- [x] Run the focused test and confirm it fails before implementation.

### Task 11: Complete Dynamic Component Classification

**Files:**
- Modify: `macos/assets/internet-angel-macos.js`

- [x] Classify stable role/ARIA and structural signals first; use localized
  labels only for corroboration where Codex exposes no semantic identifier.
- [x] Cover sidebar/footer, palette, turn navigation/preview, settings,
  terminal/summary/side chat, selection/comment, edited cards, toasts, and
  subagents.
- [x] Keep bounded observers, coalesced refresh, attribute-only marking, and
  complete theme-switch cleanup.

### Task 12: Port The Remaining Windows Visual Grammar

**Files:**
- Modify: `macos/assets/internet-angel-macos.css`

- [x] Port the Windows sidebar control deck and footer while retaining the
  existing macOS ornament layer.
- [x] Port the bespoke Add/slash palette, turn navigation, scroll button, and
  preview tooltip.
- [x] Port settings, terminal/bottom drawer, output/side chat, selection,
  edited-card, toast, and subagent states.
- [x] Preserve native geometry, focus, scrolling, hit areas, reduced-motion,
  and narrow-window behavior.

### Task 13: Extend Live Verification

**Files:**
- Modify: `macos/scripts/injector.mjs`
- Modify: `macos/tests/injector-bootstrap.test.mjs`
- Modify: `macos/references/qa-inventory.md`

- [x] Require visible sidebar/new-chat/footer controls to be classified for
  Internet Angel.
- [x] When the Add palette is open, require its surface and visible items to be
  classified and non-native gray.
- [x] Record turn-navigation, settings, bottom/right workspace, selection, and
  collaboration checks as conditional live surfaces.

### Task 14: Full Regression And Live Acceptance

- [x] Run the focused red/green test, JavaScript syntax checks, and the complete
  macOS suite.
- [x] Build the arm64 menu-bar release and verify overlay assets are packaged.
- [x] Apply the source payload to the already-running Codex renderer without
  restarting it.
- [x] Capture normal thread, open Add palette, and any available auxiliary
  surface screenshots; inspect computed styles and viewport containment.
- [x] Inspect `git diff --check` and report the persistent-install restart
  boundary without closing Codex.

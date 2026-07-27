# macOS Internet Angel Interaction Regressions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore native sidebar scrolling, edited-file Review focusing and auxiliary browser rendering while keeping the fix exclusive to the two bundled Internet Angel theme IDs.

**Architecture:** Keep the macOS overlay paint-only over native interaction geometry. Select exactly one right-docked workspace surface, never rewrite its native positioning, and prevent fixed-height sidebar rows from becoming nested vertical scroll containers after themed borders are applied.

**Tech Stack:** JavaScript DOM classifier, scoped CSS, Node.js `vm` regression fixture, CDP live verification, Swift Package Manager/macOS app build.

---

### Task 1: Lock the interaction contracts

**Files:**
- Modify: `macos/tests/internet-angel-macos.test.mjs`

- [x] **Step 1: Add a nested workspace fixture**

  Extend `makeOverlayFixture()` with an outer right-docked workspace and a smaller inner right-docked workspace, both containing workspace evidence. Return both nodes from the fixture.

- [x] **Step 2: Assert single-node classification**

  Add assertions equivalent to:

  ```js
  assert.equal(component(fixture.workspace), "side-workspace");
  assert.equal(component(fixture.workspaceOuter), null);
  ```

- [x] **Step 3: Assert paint-only workspace and non-scrolling rows**

  Add CSS contracts equivalent to:

  ```js
  assert.doesNotMatch(sideWorkspaceRule, /position\s*:/);
  assert.match(sidebarRowRule, /overflow-y:\s*clip\s*!important/);
  ```

- [x] **Step 4: Run the focused test and confirm RED**

  Run:

  ```bash
  node macos/tests/internet-angel-macos.test.mjs
  ```

  Expected: failure because the current classifier marks both workspace candidates and the current CSS overrides workspace positioning without clipping row overflow.

### Task 2: Preserve native layout geometry

**Files:**
- Modify: `macos/assets/internet-angel-macos.js`
- Modify: `macos/assets/internet-angel-macos.css`
- Test: `macos/tests/internet-angel-macos.test.mjs`

- [x] **Step 1: Select one workspace candidate**

  Collect right-docked candidates with workspace evidence, sort by visible area, and mark only the smallest structural surface. Let reconciliation remove any stale duplicate marks.

- [x] **Step 2: Make workspace decoration paint-only**

  Remove the `position: relative !important` override and replace the positioned top pseudo-element with a top-aligned background layer. Preserve the cyan/blue/pink stripe, border, foreground and surface treatment without changing native `position`, `overflow`, dimensions or z-index.

- [x] **Step 3: Remove sidebar scroll traps**

  Add `overflow-y: clip !important` only to `[data-angel-component="sidebar-row"]`. Preserve native horizontal clipping and the existing exact-theme hover/selection appearance.

- [x] **Step 4: Run the focused test and confirm GREEN**

  Run:

  ```bash
  node macos/tests/internet-angel-macos.test.mjs
  node --check macos/assets/internet-angel-macos.js
  ```

  Expected: both commands exit `0`.

### Task 3: Verify the live native interactions

**Files:**
- No repository files modified.

- [x] **Step 1: Hot-inject the source assets**

  Run the signed bundled Node injector once against the active Codex CDP endpoint and the current saved Internet Angel theme directory.

- [x] **Step 2: Verify sidebar wheel input**

  Reset the native sidebar scroll root and its rows, dispatch one real `mouseWheel` event over a row, and require the root `scrollTop` to increase while the row remains at `scrollTop === 0`.

- [x] **Step 3: Verify browser rendering**

  Click the Browser tab with real pointer events and require its active tab panel to fill the available right workspace height rather than collapse to `40px`.

- [x] **Step 4: Verify edited-file focusing**

  Click an Edited files row with real pointer events and require Review to become active with a bounded, vertically scrollable panel. Confirm the requested file is visible in the Review viewport after native focus handling.

- [x] **Step 5: Capture and inspect desktop evidence**

  Capture a full-window screenshot with the browser or Review panel active and confirm there is no blank/clipped workspace, incoherent overlap or horizontal overflow.

### Task 4: Repository verification and PR update

**Files:**
- Modify: `TASK_PROGRESS.md`

- [x] **Step 1: Run repository checks**

  Run:

  ```bash
  CODEX_DREAM_SKIN_SKIP_DOCTOR=1 macos/tests/run-tests.sh
  git diff --check
  ```

  Expected: the complete macOS test suite and diff validation pass.

- [x] **Step 2: Build and inspect the macOS app**

  Build to a temporary directory, verify its code signature and arm64 executable, and compare the packaged overlay CSS/JS bytes with the source assets.

- [x] **Step 3: Record evidence**

  Update `TASK_PROGRESS.md` with the exact live geometry, test commands, build results and remaining GitHub review/CI status.

- [ ] **Step 4: Commit and push**

  Stage only the scoped plan, progress, test, CSS and classifier changes. Create focused implementation/progress commits and push `codex/macos-internet-angel-parity` to update PR #8.

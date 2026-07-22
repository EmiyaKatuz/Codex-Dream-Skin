import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const windowsRoot = path.resolve(here, "..");
const template = await fs.readFile(path.join(windowsRoot, "assets", "renderer-inject.js"), "utf8");
const css = await fs.readFile(path.join(windowsRoot, "assets", "dream-skin.css"), "utf8");
const buildPayload = (config = {}) => template
  .replace("__DREAM_CSS_JSON__", JSON.stringify(".fixture { color: blue; }"))
  .replace("__DREAM_ART_JSON__", JSON.stringify("data:image/png;base64,AA=="))
  .replace("__DREAM_THEME_JSON__", JSON.stringify(config));
const payload = buildPayload();

assert.match(template, /速率限制重置机会\|rate limit reset opportunity/i,
  "The renderer must classify the native rate-limit reset toast.");
assert.ok(css.includes('.dream-system-toast,')
  && css.includes('aside[class~="relative"][class~="isolate"][class~="w-full"][class~="overflow-hidden"][class~="rounded-2xl"]'),
  "The native system toast must receive its Internet Angel component skin on the first frame and after classification.");
assert.ok(template.includes("resetToastSurface")
  && template.includes('aside[class~="rounded-2xl"]'),
  "The system-toast classifier must skin the rendered aside rather than its transparent banner stack.");
assert.ok(template.includes('const FALLBACK_PRESETS_ID = "codex-dream-skin-presets"')
  && template.includes("ensureFallbackPresets(home, matchedNativePresets.size)")
  && template.includes("nativePresetCount < fallbackPresetDefinitions.length")
  && template.includes('else deck.setAttribute("hidden", "")')
  && template.includes('deck.removeAttribute?.("hidden")')
  && template.includes('const primedFallbackDeck = document.getElementById(FALLBACK_PRESETS_ID)')
  && template.includes("if (isPresetRendered(button)) matchedNativePresets.add(button)")
  && css.includes('.dream-home:has(#codex-dream-skin-presets[data-dream-ready="true"]) .group\\/home-suggestions'),
  "Home must retain a primed fallback and show it whenever the complete visible native preset set is unavailable.");
assert.ok(template.includes('.ProseMirror[contenteditable="true"]')
  && template.includes('document.execCommand?.("insertText", false, prompt)')
  && template.includes('new InputEvent("input"'),
  "Fallback presets must write through the real Codex composer and emit its input event.");
assert.ok(template.includes('[...(deck.querySelectorAll?.("button.dream-generated-preset") || [])].forEach((button, index)')
  && template.includes('button.classList.add("dream-codex-preset", "dream-generated-preset", preset.className)'),
  "Fallback presets must restore their per-channel classes after every managed-class cleanup pass.");
for (const presetClass of ["dream-preset-explore", "dream-preset-build", "dream-preset-review", "dream-preset-fix"]) {
  assert.ok(template.includes(presetClass), `Fallback Home must provide ${presetClass}.`);
  assert.ok(css.includes(`button.${presetClass}`), `${presetClass} must keep a distinct channel color.`);
  assert.ok(css.includes(`button.dream-generated-preset.${presetClass}`),
    `Generated ${presetClass} cards must override the generic fallback channel color.`);
}
assert.match(css, /#codex-dream-skin-presets\s*\{[^}]*position:\s*absolute[^}]*container:\s*dream-presets/s,
  "The recovered preset deck must occupy the Home stage without reflowing the native composer.");
assert.match(css, /#codex-dream-skin-presets\s*\{[^}]*top:\s*clamp\(250px, 42cqh, 350px\)/s,
  "The full-height fallback deck must clear the tracked face and blink region.");
assert.match(css, /button\.dream-generated-preset\s*\{[^}]*grid-template:[^}]*min-height:\s*126px[^}]*border:\s*2px[^}]*background:/s,
  "Recovered preset buttons must be full Internet Angel command cards, not plain text fallbacks.");
assert.ok(template.includes('const SIDEBAR_CHROME_ID = "codex-dream-sidebar-ornaments"')
  && template.includes("ensureSidebarOrnaments(shellSidebar, Boolean(settingsNav))")
  && template.includes('ornaments.setAttribute("aria-hidden", "true")'),
  "The normal sidebar must mount a non-interactive ornament deck and omit it on Settings.");
for (const sidebarOrnament of ["dream-sidebar-signal", "dream-sidebar-halo", "dream-sidebar-pixels", "dream-sidebar-online", "dream-sidebar-packet"]) {
  assert.ok(template.includes(sidebarOrnament), `Sidebar chrome must mount ${sidebarOrnament}.`);
  assert.ok(css.includes(`.${sidebarOrnament}`), `Sidebar chrome must style ${sidebarOrnament}.`);
}
assert.match(css, /#codex-dream-sidebar-ornaments,[\s\S]*?pointer-events:\s*none\s*!important/s,
  "Sidebar ornaments must never intercept navigation controls.");
for (const composerUiClass of [
  "dream-composer-palette",
  "dream-composer-palette-scroll",
  "dream-composer-palette-heading",
  "dream-composer-palette-item",
  "dream-composer-context-strip",
  "dream-active-goal-strip",
  "dream-goal-progress-group",
  "dream-goal-step",
  "dream-goal-mode-trigger",
]) {
  assert.ok(template.includes(composerUiClass), `The renderer must classify ${composerUiClass}.`);
  assert.ok(css.includes(`.${composerUiClass}`), `${composerUiClass} must receive a dedicated theme.`);
}
const goalStepRule = css.match(/html\.codex-dream-skin \.dream-goal-step\s*\{[^}]*\}/s)?.[0] || "";
assert.match(goalStepRule, /box-sizing:\s*border-box\s*!important/,
  "The goal progress pill must measure its full outline inside its reported geometry.");
assert.match(goalStepRule, /overflow:\s*visible\s*!important[\s\S]*?border:\s*1\.5px solid transparent\s*!important[\s\S]*?border-radius:\s*999px\s*!important/,
  "The goal progress pill must expose one complete, uniformly rounded border.");
assert.match(goalStepRule, /padding-box[\s\S]*?border-box\s*!important/,
  "The goal progress pill must paint its surface and cyan-to-pink outline as separate layers.");
assert.doesNotMatch(goalStepRule, /inset\s+4px\s+0/,
  "The goal progress pill must not recreate the clipped duplicate block on its left edge.");
assert.match(css, /\[class~="overflow-hidden"\]\[class~="rounded-3xl"\]:has\(\.dream-goal-step\)\s*\{[^}]*overflow:\s*visible\s*!important[^}]*clip-path:\s*none\s*!important/s,
  "The native short progress shell must not clip the upper and lower arcs of the goal pill.");
assert.ok(template.includes('div.vertical-scroll-fade-mask[class~="overflow-y-auto"]')
  && template.includes('button[class~="w-full"][class~="shrink-0"][class~="rounded-lg"][class~="text-left"]'),
  "Add and slash-command panels must use their language-independent structural palette selector.");
assert.match(css, /dream-composer-palette,[\s\S]*?vertical-scroll-fade-mask[\s\S]*?\)\s*\{[^}]*border:\s*2px solid var\(--angel-blue\)[^}]*background:/s,
  "Composer palettes must replace the native olive surface on the first frame.");
assert.match(css, /dream-composer-context-strip,[\s\S]*?sticky[\s\S]*?border-x[\s\S]*?\)\s*\{[^}]*min-height:\s*42px[^}]*border:\s*1\.5px solid var\(--angel-blue\)/s,
  "Conversation context and goal strips must receive the themed rail before classification.");
assert.ok(template.includes('deck.setAttribute("data-dream-ready", "false")')
  && template.includes('deck.setAttribute("data-dream-ready", String(ready))')
  && template.includes('else deck.setAttribute("hidden", "")')
  && css.includes('#codex-dream-skin-presets[data-dream-ready="true"]'),
  "Fallback presets must stay primed in the Home DOM and reveal without a two-frame blank transition.");
for (const panelClass of ["dream-terminal-panel", "dream-side-workspace", "dream-side-chat-panel", "dream-summary-panel"]) {
  assert.match(template, new RegExp(panelClass), `The renderer must classify ${panelClass}.`);
  if (panelClass === "dream-terminal-panel") {
    assert.ok(
      css.includes(':where(.dream-terminal-panel, [class*="contain:layout_paint"]:has(.xterm), [class*="contain:layout_paint"]:has(> [class~="h-toolbar-pane"] [role="tablist"]))'),
      "The terminal must receive its component skin before xterm mount and after renderer classification.",
    );
  } else if (panelClass === "dream-side-chat-panel") {
    assert.ok(
      css.includes('main.main-surface aside > [class*="contain:layout_paint"]:has(.thread-scroll-container):has(.composer-surface-chrome)'),
      "A newly mounted side conversation must receive its background before renderer classification.",
    );
  } else if (panelClass === "dream-summary-panel") {
    assert.ok(
      css.includes('[class*="rounded-3xl"][class*="bg-token-dropdown-background"]:has(> [class*="overflow-y-auto"] [class*="group/summary-panel-item"])'),
      "The pinned summary must receive its component skin on its first mounted frame.",
    );
  } else {
    assert.match(css, new RegExp(`\\.${panelClass}\\s*\\{`), `${panelClass} must receive a dedicated component skin.`);
  }
}
assert.ok(template.includes('const SIDE_WORKSPACE_BRAND_ID = "codex-dream-side-workspace-brand"')
  && template.includes('brand.setAttribute("aria-hidden", "true")')
  && template.includes("ensureSideWorkspaceBrand(sideWorkspace)")
  && template.includes("node.parentElement !== workspace"),
"The right auxiliary workspace must mount one inert, idempotent Internet Angel brand deck and retire stale copies.");
assert.match(css, /\.dream-side-workspace-brand\s*\{[^}]*position:\s*absolute\s*!important[^}]*grid-template-columns:[^}]*border:\s*1px solid transparent[^}]*border-box/s,
  "The inert side-workspace brand must be a positioned broadcast readout rather than a native flex child.");
assert.ok(template.includes("browserMarkers")
  && template.includes("terminalMarkers")
  && template.includes("structuralSideWorkspace")
  && template.includes('candidate.contains?.(marker)')
  && template.includes('isRightDockedSurface'),
"A right launcher containing only Browser and Terminal shortcuts must still be classified as the side workspace.");
for (const layoutClass of ["dream-home-side-open", "dream-home-bottom-open", "dream-home-dual-panel"]) {
  assert.ok(template.includes(layoutClass), `The renderer must synchronize ${layoutClass}.`);
}
assert.ok(template.includes('const panelStateTargets = new Set([root, shellMain, home].filter(Boolean))')
  && template.includes('target.classList.toggle("dream-home-side-open", sideOpen)')
  && template.includes('target.classList.toggle("dream-home-bottom-open", bottomOpen)')
  && template.includes('target.classList.toggle("dream-home-dual-panel", sideOpen && bottomOpen)'),
"Home panel state must be mirrored to html, the shell main, and the semantic Home surface in one synchronous pass.");
assert.ok(template.includes('root?.classList.remove(...HOME_PANEL_STATE_CLASSES)')
  && template.includes('node.classList.remove(...HOME_PANEL_STATE_CLASSES)')
  && template.includes('document.getElementById(SIDE_WORKSPACE_BRAND_ID)?.remove()'),
"Cleanup must remove panel-layout state and the injected side-workspace brand without residue.");
for (const interactionClass of [
  "dream-selection-actions",
  "dream-selection-action",
  "dream-selected-fragment",
  "dream-optional-comment",
  "dream-optional-comment-input",
  "dream-edited-card",
  "dream-edited-card-header",
  "dream-edited-card-icon",
  "dream-edited-card-title",
  "dream-edited-card-stats",
  "dream-edited-card-actions",
  "dream-edited-card-undo",
  "dream-edited-card-review",
]) {
  assert.match(template, new RegExp(interactionClass), `The renderer must classify ${interactionClass}.`);
  assert.match(css, new RegExp(`\\.${interactionClass}(?:\\s|,|\\))`), `${interactionClass} must receive an Internet Angel component skin.`);
}
assert.match(template, /\\u5728\\u4fa7\\u8fb9\\u804a\\u5929\\u4e2d\\u63d0\\u95ee/,
  "The selection toolbar classifier must recognize the Chinese ask-in-sidebar action without relying on source encoding.");
assert.match(template, /\\u5df2\\u9009\\u6587\\u672c\\u7247\\u6bb5/,
  "The composer classifier must recognize the selected-text-fragment badge.");
assert.ok(
  css.includes('input[placeholder*="optional comment" i]') && css.includes('input[placeholder*="可选评论"]'),
  "Optional comment inputs must receive a first-frame skin in both English and Chinese.",
);
assert.match(css, /html\.codex-dream-skin ::selection\s*\{/,
  "Selected Chinese and English text must use the readable Internet Angel highlight palette.");
assert.ok(
  template.indexOf("sideLauncher?.closest?.('[class*=\"contain:layout_paint\"]')") <
    template.indexOf("sideLauncher?.closest?.('[class*=\"bg-token-main-surface-primary\"]')"),
  "The right workspace classifier must prefer the complete contain:layout_paint panel over its sticky child surface.",
);
assert.match(template, /changedText\?\.closest\?\.\("button"\)/,
  "The changed-files skin must prefer the real button instead of expanding its shared progress wrapper.");
assert.match(template, /CHANGES_SHELL_CLASS/,
  "The changed-files progress shell must receive its own spacing class.");
assert.match(template, /--dream-summary-safe-height/,
  "The floating output summary must be capped above the changed-files/composer barrier.");
assert.match(template, /\[class\*="group\/turn-diff-header"\]/,
  "Edited resource cards must be classified from their dedicated turn-diff header.");
assert.match(template, /candidate\.childElementCount === 0/,
  "Edited resource card classification must only tag the leaf title, not its parent row.");
assert.match(template, /editedCard\?\.querySelector\?\.\("\.turn-diff-default-subtitle"\)/,
  "Edited resource cards must expose diff statistics before receiving the component skin.");
assert.match(template, /\^\(\?:\\u64a4\\u9500\|undo\)\$/i,
  "Edited resource card classification must recognize Undo in Chinese and English.");
assert.match(template, /\^\(\?:\\u5ba1\\u6838\|review\)\$/i,
  "Edited resource card classification must recognize Review in Chinese and English.");
assert.match(css, /\[class\*="contain:layout_paint"\]:has\(\.xterm\)\)\s+\.xterm-selection-layer/,
  "The terminal selection layer must use the Internet Angel palette before the classifier runs.");
assert.ok(
  css.includes('[role="tablist"] [role="button"]:has(> [role="tab"])'),
  "The terminal skin must theme the native outer tab shell instead of leaving its token fallback exposed.",
);
assert.ok(
  css.includes('[class~="relative"][class~="z-30"][class~="min-h-0"][class~="w-full"][class~="shrink-0"][class~="overflow-visible"]')
    && css.includes('> [class~="absolute"][class~="inset-x-0"][class~="top-0"][class~="min-h-0"][class~="border-t"][class~="bg-token-main-surface-primary"]'),
  "The bottom drawer token shell must be themed before terminal children mount, preventing an original-theme first frame.",
);
assert.ok(
  css.includes('[role="tablist"] ~ [class~="bg-token-main-surface-primary"] > button'),
  "The terminal new-tab action must be drawn on the button while its sticky native wrapper stays transparent.",
);
assert.match(
  css,
  /\[role="tab"\]\s+\[class\*="app-shell-tab-background"\]\s*\{[^}]*background:\s*linear-gradient/s,
  "The terminal title fade must blend into the themed tab instead of the native dark token.",
);
assert.match(
  css,
  /\[role="tablist"\]\s*~\s*\[class~="bg-token-main-surface-primary"\]\s*\{[^}]*background:\s*transparent\s*!important/s,
  "The terminal new-tab wrapper must not expose the native olive/black surface.",
);
assert.match(css, /\.dream-changes-shell\s*\{[^}]*z-index:\s*2[^}]*margin-bottom:\s*12px/s,
  "The changed-files shell must keep a dedicated optical gap above the composer.");
assert.match(css, /\.dream-changes-shell\s*\{[^}]*border:\s*0[^}]*box-shadow:\s*none/s,
  "The changed-files layout shell must not compete with the pill for the visible frame.");
assert.match(css, /\.dream-changes-clip-host,[\s\S]*?overflow-hidden[\s\S]*?rounded-3xl[\s\S]*?\)\s*\{[^}]*overflow:\s*visible[^}]*border-radius:\s*0[^}]*clip-path:\s*none/s,
  "The changed-files host must release the larger overflow mask that clips both upper corners.");
assert.ok(
  css.includes('button:has([class*="git-decoration-added"]):has([class*="git-decoration-deleted"])'),
  "The changed-files pill must receive its skin before runtime classification.",
);
assert.match(css, /\.dream-changes-pill,[\s\S]*?\)\s*\{[^}]*overflow:\s*visible[^}]*border:\s*2\.5px solid transparent[^}]*border-radius:\s*12\.5px[^}]*padding-box,[^}]*border-box[^}]*background-clip:\s*padding-box, border-box/s,
  "The changed-files pill must paint its complete scaled frame with a two-layer opaque background.");
assert.ok(template.includes('const CHANGES_CLIP_HOST_CLASS = "dream-changes-clip-host"'),
  "The renderer must classify the changed-files overflow host for durable corner repair.");
assert.ok(template.includes("changedClipHost.classList.add(CHANGES_CLIP_HOST_CLASS)"),
  "The renderer must mark the changed-files overflow host after live DOM updates.");
assert.ok(template.includes('"dream-route-settings"')
  && template.includes("nav:has([data-settings-panel-slug])")
  && template.includes('if (settingsNav) route = "settings"'),
  "Settings must be detected before the default task route without localized text.");
for (const settingsClass of [
  "dream-settings-sidebar",
  "dream-settings-nav",
  "dream-settings-search",
  "dream-settings-content",
  "dream-settings-surface",
  "dream-settings-row",
  "dream-settings-control",
  "dream-settings-input",
  "dream-settings-segment-group",
  "dream-settings-segment",
  "dream-settings-menu",
  "dream-settings-app-row",
  "dream-settings-app-main",
]) {
  assert.ok(template.includes(settingsClass), `The renderer must classify ${settingsClass}.`);
}
assert.ok(template.includes('button[aria-haspopup][aria-controls]')
  && template.includes('document.getElementById(menuId)'),
  "Settings portal menus must be paired with their trigger through aria-controls.");
assert.ok(template.includes('div[class~="flex"][class~="flex-col"][class~="overflow-hidden"][class~="rounded-2xl"]')
  && css.includes('.dream-settings-content div[class~="flex"][class~="flex-col"][class~="overflow-hidden"][class~="rounded-2xl"]'),
  "Every settings card nesting variant must be classified and receive a first-frame structural skin.");
assert.ok(template.includes('const NEW_TASK_CLASS = "dream-new-task-button"')
  && template.includes('/^(?:\\u65b0\\u5efa\\u4efb\\u52a1|new task)$/i')
  && css.includes('.dream-new-task-button'),
  "The native new-task action must receive its own language-safe control skin.");
assert.match(css, /\.dream-sidebar-packet\s*\{[^}]*writing-mode:\s*vertical-rl/s,
  "Sidebar affection telemetry must use the reserved edge rail instead of overlapping the new-task row.");
assert.ok(template.includes('const withoutManagedClasses = (value)')
  && template.includes('const MUTATION_REFRESH_INTERVAL_MS = 120')
  && template.includes('scheduleEnsure(MUTATION_REFRESH_INTERVAL_MS)')
  && template.includes('if (scheduler.dueAt <= dueAt) return;')
  && template.includes('window.requestAnimationFrame(runEnsure)')
  && template.includes('attributeOldValue: true')
  && template.includes('window.addEventListener("resize", resizeHandler'),
  "Route changes must use a time-bounded observer throttle and ignore skin-owned class mutations.");
assert.ok(template.includes('const STYLE_REVISION = "8"')
  && template.includes('existingStyle.dataset.dreamVersion = STYLE_REVISION')
  && !template.includes('existingStyle.dataset.dreamVersion = "3"'),
  "Reinjection must not parse and apply the full stylesheet twice for one refresh.");
assert.doesNotMatch(template, /querySelectorAll\(["']body \*["']\)/,
  "Renderer refreshes must not force visibility/style reads across the entire document.");
assert.ok(template.indexOf('.filter(({ text }) => pattern.test(text))')
    < template.indexOf('.filter(({ node }) => measureTextCandidate(node).visible)'),
  "Portal fallback labels must be matched by text before any layout/style measurement.");
assert.ok(template.includes('const runEnsureSafely = () =>')
  && template.includes('setInterval(runEnsureSafely, 5000)')
  && template.includes('ensure: runEnsureSafely'),
  "Observer, interval, and external renderer refreshes must share an exception boundary.");
assert.ok(template.includes('new ResizeObserver(() => scheduleEnsure())')
  && template.includes('resizeObserver.observe(target)')
  && template.includes('resizeObserver.unobserve(target)')
  && template.includes('state?.resizeObserver?.disconnect()'),
  "Split-pane geometry changes must refresh the skin during panel animation and release observers on cleanup.");
assert.ok(template.includes('if (previous?.resizeHandler) window.removeEventListener("resize", previous.resizeHandler)')
  && template.includes('previous?.motionQuery?.removeEventListener?.("change", previous.motionHandler)')
  && template.includes('motionQuery?.addEventListener?.("change", motionHandler)'),
  "Reinjection must release old geometry and motion listeners before the new renderer state takes ownership.");
assert.match(css, /@media \(max-width: 900px\)[\s\S]*?group\\\/home-suggestions > div > div\s*\{[^}]*grid-template-columns:\s*repeat\(2,[^}]*\)[^}]*\}[\s\S]*?group\\\/home-suggestions > div > div > \*\s*\{[^}]*display:\s*block\s*!important/s,
  "Narrow Home must preserve all four native presets in a two-by-two grid.");
for (const subagentClass of [
  "dream-subagent-frame",
  "dream-subagent-shell",
  "dream-subagent-toolbar",
  "dream-subagent-panel",
  "dream-subagent-scroller",
  "dream-subagent-section",
  "dream-subagent-section-live",
  "dream-subagent-section-archive",
  "dream-subagent-list",
  "dream-subagent-row",
  "dream-subagent-row-live",
  "dream-subagent-row-archive",
  "dream-subagent-more",
]) {
  assert.ok(template.includes(subagentClass), `The renderer must classify ${subagentClass}.`);
  assert.ok(css.includes(`.${subagentClass}`), `${subagentClass} must receive a dedicated collaboration-panel skin.`);
}
assert.ok(
  template.includes('[role="tabpanel"] > [class~="h-full"][class~="min-h-0"][class~="overflow-y-auto"][class~="px-3"][class~="py-5"]')
    && template.includes(':scope > [class~="relative"][class~="z-10"] > button[class~="items-start"][class~="w-full"]'),
  "The subagent classifier must use the language-independent tabpanel/list structure.",
);
assert.ok(
  css.includes('[role="tabpanel"] > [class~="h-full"][class~="min-h-0"][class~="overflow-y-auto"][class~="px-3"][class~="py-5"]')
    && css.includes('button[class~="items-start"][class~="w-full"]'),
  "The collaboration panel must lose its native olive surface on the first mounted frame.",
);
assert.match(css, /.dream-subagent-row,[\s\S]*?button\[class~="items-start"\][\s\S]*?\) > svg:first-child\s*\{[^}]*width:\s*30px[^}]*border:[^}]*background:\s*linear-gradient/s,
  "Agent avatars must become framed Internet Angel channel icons.");
assert.match(css, /.dream-subagent-more,[\s\S]*?section\[class~="mt-6"\] > button:not\(\[class~="items-start"\]\)[\s\S]*?\)\s*\{[^}]*min-height:\s*28px[^}]*border-radius:\s*7px/s,
  "The show-more action must be a full keyboard-focusable broadcast control, not a tiny native pill.");
assert.match(css, /.dream-subagent-more,[\s\S]*?section\[class~="mt-6"\] > button:not\(\[class~="items-start"\]\)[\s\S]*?\)\s*\{[^}]*display:\s*inline-flex\s*!important[^}]*justify-content:\s*center\s*!important[^}]*padding:\s*5px 14px 5px 17px\s*!important[^}]*text-align:\s*center\s*!important[^}]*text-indent:\s*0\s*!important/s,
  "The show-more label must stay optically centered and clear of the broadcast accent at every count.");
assert.match(css, /.dream-subagent-more,[\s\S]*?button:not\(\[class~="items-start"\]\)[\s\S]*?\) > :where\(span, div\)\s*\{[^}]*justify-content:\s*center\s*!important[^}]*transform:\s*none\s*!important[^}]*translate:\s*none\s*!important/s,
  "Nested show-more labels must not retain native offsets that push text into the frame.");
assert.match(css, /@container dream-subagent \(max-width: 340px\)[\s\S]*?\.dream-subagent-row[\s\S]*?\.dream-subagent-more/s,
  "Subagent rows and the archive control must adapt when the right panel is narrow.");
assert.match(css, /@media \(prefers-reduced-motion: reduce\)[\s\S]*?\.dream-subagent-row > svg:first-child[\s\S]*?animation:\s*none/s,
  "The live-agent pulse must respect reduced-motion preferences.");
assert.match(css, /\.dream-settings-content \[role="switch"\] > span\[data-state\][\s\S]*?\.dream-settings-content \[role="switch"\]\[data-state="checked"\] > span\[data-state\]/,
  "Settings switches must skin the real track child in both unchecked and checked states.");
assert.ok(template.includes("button[aria-pressed]")
  && template.includes('segment.classList.add("dream-settings-segment", "dream-settings-control")')
  && css.includes('button[aria-pressed="true"]')
  && css.includes('button[aria-pressed="false"]'),
  "Unwrapped settings segment buttons must expose unmistakable selected and unselected states.");
assert.ok(template.includes('button[class~="appearance-none"][class~="bg-transparent"][class~="p-0"][class~="text-left"]')
  && css.includes('.dream-settings-app-row')
  && css.includes('.dream-settings-app-main'),
  "Application-permission rows must use one stable parent hover paint instead of competing child-button paints.");
assert.ok(css.includes('[role="menuitemradio"]') && css.includes('[role="menuitemcheckbox"]'),
  "Renderer-owned menus must theme radio and checkbox items as well as plain items.");
for (const ornamentClass of [
  "dream-angel-stage",
  "dream-angel-halo",
  "dream-angel-telemetry",
  "dream-angel-chat-rain",
  "dream-angel-dose-strip",
  "dream-angel-window-stack",
  "dream-angel-spark-field",
  "dream-angel-webcam-card",
  "dream-angel-face-orbit",
  "dream-angel-blink",
  "dream-angel-live-ticker",
  "dream-angel-id-chip",
  "dream-angel-reaction-deck",
  "dream-angel-heartbeat",
  "dream-angel-now-playing",
]) {
  assert.ok(template.includes(ornamentClass), `The renderer must mount ${ornamentClass} in the inert home overlay.`);
  assert.ok(css.includes(`.${ornamentClass}`), `The home ornament deck must style ${ornamentClass}.`);
}
assert.ok(template.includes('chrome.setAttribute("aria-hidden", "true")')
  && css.includes('#codex-dream-skin-chrome *')
  && css.includes('pointer-events: none !important'),
  "Broadcast ornaments must stay hidden from accessibility and pointer hit-testing.");
assert.ok(template.includes('"--dream-main-left"')
  && template.includes('"--dream-main-width"')
  && template.includes('"--dream-composer-top"')
  && template.includes('"--dream-blink-left"')
  && template.includes('"--dream-face-x"'),
  "The ornament stage must follow measured Codex geometry instead of hard-coded sidebar offsets.");
assert.ok(template.includes("CHOTEN_ART_GEOMETRY")
  && template.includes("updateChotenArtGeometry(chrome, mainBox)")
  && template.includes("artGeometryReady")
  && template.includes('root.classList.toggle("dream-choten-art", config.chotenArt)')
  && template.includes('root.classList.toggle("dream-reduced-motion"'),
  "Character-specific motion must be gated to the Choten preset and share the fixed-cover art geometry.");
assert.match(css, /dream-home-shell\.dream-art-motion-ready[\s\S]*?dream-angel-face-orbit[\s\S]*?dream-angel-blink/,
  "Eye motion must stay hidden until the artwork geometry is measured.");
assert.ok(template.includes('shape-rendering="crispEdges"')
  && template.includes('class="dream-blink-frame dream-blink-half"')
  && template.includes('class="dream-blink-frame dream-blink-closed"')
  && template.includes('class="dream-blink-eye dream-blink-eye-left"')
  && template.includes('class="dream-blink-eye dream-blink-eye-right"')
  && template.includes("dream-blink-pixel-skin")
  && !template.includes("dream-blink-skin"),
  "The Choten blink must use discrete, eye-specific crisp-edged pixel sprites instead of one symmetric vector mask.");
assert.ok(template.includes('d="M23 27H47V29H55V31H59V33H63V35H67V39H69V43H71V47H73V61')
  && template.includes('d="M151 33H173V35H181V37H187V39H191V41H195V43H199V45H201V49H199V57')
  && template.includes('<rect x="19" y="31" width="4" height="4"/>')
  && template.includes('<rect x="19" y="39" width="4" height="4"/>'),
  "The eye-specific masks must retain the traced apertures and move the upper lid downward between half and closed frames.");
assert.match(css, /\.dream-blink-half\s*\{[^}]*dream-choten-blink-half 11\.4s steps\(1, end\)/s,
  "The half-blink sprite must advance as an integer frame without interpolated scaling.");
assert.match(css, /\.dream-blink-closed\s*\{[^}]*dream-choten-blink-closed 11\.4s steps\(1, end\)/s,
  "The closed-eye sprite must advance as an integer frame without interpolated scaling.");
assert.match(css, /@keyframes dream-choten-blink-half[\s\S]*?88%[\s\S]*?90%/,
  "The pixel half-blink must remain a brief transition frame.");
assert.match(css, /@keyframes dream-choten-blink-closed[\s\S]*?88\.4%[\s\S]*?89\.6%/,
  "The pixel closed-eye sprite must remain a brief hold frame.");
assert.doesNotMatch(css, /@keyframes dream-choten-blink\s*\{|\.dream-angel-blink\s*\{[^}]*scaleY\(/s,
  "The legacy smooth scaleY blink must not return.");
assert.match(css, /@media \(prefers-reduced-motion: reduce\)[\s\S]*?\.dream-angel-blink[\s\S]*?animation:\s*none\s*!important[\s\S]*?opacity:\s*0\s*!important/s,
  "The character blink must become a static, invisible layer for reduced-motion users.");
assert.match(css, /dream-reduced-motion[\s\S]*?\.dream-angel-blink[\s\S]*?animation:\s*none\s*!important[\s\S]*?opacity:\s*0\s*!important/s,
  "The renderer's live reduced-motion class must provide the same no-animation fallback.");
assert.match(css, /:has\(\.dream-system-toast\)[\s\S]*?dream-angel-dose-strip[\s\S]*?dream-angel-now-playing[\s\S]*?display:\s*none\s*!important/s,
  "Transient system notices must reserve a quiet band instead of competing with lower Home ornaments.");
assert.match(css, /:has\(#codex-dream-skin-presets\[data-dream-ready="true"\]\)[\s\S]*?dream-angel-webcam-card[\s\S]*?dream-angel-heartbeat[\s\S]*?display:\s*none\s*!important/s,
  "The richer fallback deck must retire overlapping legacy ornaments in the same band.");
assert.match(css, /@container angel-stage \(max-width: 900px\)[\s\S]*?dream-angel-webcam-card[\s\S]*?display:\s*none/s,
  "Large ornaments must collapse before compact Codex layouts become crowded.");
assert.match(css, /\[role="tooltip"\],[\s\S]*?\[data-slot="tooltip-content"\][\s\S]*?\)\s*\{[^}]*z-index:\s*10000[^}]*border:\s*1\.25px solid var\(--angel-cyan\)[^}]*background:/s,
  "Portal tooltips must receive the Internet Angel skin on their first frame.");
for (const turnClass of [
  "dream-turn-nav-rail",
  "dream-turn-nav-row",
  "dream-turn-nav-marker",
  "dream-turn-nav-marker-active",
  "dream-turn-preview-tooltip",
  "dream-turn-preview-surface",
  "dream-turn-preview-title",
  "dream-turn-preview-excerpt",
]) {
  assert.ok(template.includes(turnClass), `The renderer must classify ${turnClass}.`);
  assert.ok(css.includes(`.${turnClass}`), `${turnClass} must receive a dedicated conversation-navigation skin.`);
}
assert.ok(template.includes('button[class*="navigation-row"]')
  && template.includes('[role="tooltip"] div[class~="w-80"][class*="bg-token-dropdown-background"]'),
  "Conversation navigator markers and their nested preview surface must be detected without localized text.");
assert.match(css, /\[role="tooltip"\] div\[class~="w-80"\]\[class\*="bg-token-dropdown-background"\][\s\S]*?background:[\s\S]*?var\(--angel-violet\)/,
  "The nested conversation preview surface must replace the native olive dropdown background on its first frame.");
assert.ok(css.includes('button[aria-label="滚动到底部"]')
  && css.includes('button[aria-label="Scroll to bottom"]')
  && css.includes('[class~="sticky"][class~="bottom-0"] [class~="relative"][class~="h-0"]'),
  "The scroll-to-bottom affordance must be themed in both languages and before its aria label settles.");
assert.doesNotMatch(css, /button\[aria-label="(?:滚动到底部|Scroll to bottom)"\][\s\S]{0,180}\btransform\s*:/,
  "The scroll-to-bottom skin must not override the native centering transform.");
assert.match(
  css,
  /\.dream-summary-panel,[\s\S]*?\)\s*\{[^}]*overflow:\s*clip[^}]*border:\s*2px solid color-mix[^}]*border-radius:\s*12px[^}]*background-clip:\s*padding-box/s,
  "The pinned summary must use one opaque clipped frame instead of a transparent gradient with scaled-corner gaps.",
);
assert.match(css, /\.dream-summary-panel,[\s\S]*?\) > \[class\*="overflow-y-auto"\]\s*\{[^}]*scrollbar-gutter:\s*stable/s,
  "The pinned summary must reserve its scrollbar gutter so expanded sections cannot jitter the right edge.");
assert.ok(
  css.includes('[class*="--thread-resource-card-row-padding-x:"]:has(> [class*="group/turn-diff-header"])')
    && css.includes('[class~="font-medium"][class*="text-token-foreground"]')
    && css.includes('.turn-diff-default-subtitle')
    && css.includes('[class*="pointer-events-auto"]:has(> button + button) > button'),
  "Edited resource card shells, titles, statistics, and actions must all have first-frame structural skins.",
);
assert.match(css, /\.dream-edited-card,[\s\S]*?\)\s*\{[^}]*overflow:\s*clip[^}]*border:\s*2px solid color-mix[^}]*border-radius:\s*12px[^}]*background-clip:\s*padding-box/s,
  "Edited resource cards must use one uniform opaque clipped frame.");

assert.doesNotMatch(
  css,
  /main\.main-surface\s*>\s*header\.app-header-tint\s*\{[^}]*\b(?:position|z-index)\s*:/,
  "The skin must preserve Codex's native fixed header so the side-panel toggle remains reachable.",
);

function createFixture({
  shellPresent,
  mainPresent = shellPresent,
  sidebarPresent = shellPresent,
  staleSkin = false,
  homePresent = false,
  homeHeadingPresent = false,
  utilityPresent = false,
  shellAppearance = "dark",
  computedColorScheme = "",
  osAppearance = "light",
  analysisFixture = null,
  throwOnTextScan = false,
  textScanCandidates = [],
}) {
  const nodes = new Map();
  const rootClasses = new Set(staleSkin ? ["codex-dream-skin"] : []);
  const rootStyles = new Map(staleSkin ? [["--dream-art", "url(\"blob:stale\")"]] : []);
  const revokedUrls = [];
  const observers = [];
  let objectUrlCount = 0;
  let hasMain = mainPresent;
  let hasSidebar = sidebarPresent;
  let timeoutCalls = 0;
  let textCandidateStyleReads = 0;
  const textCandidateSet = new Set(textScanCandidates);
  let root;

  const queueRootClassMutation = () => {
    for (const observer of observers) {
      if (observer.target !== root || !observer.options?.attributes) continue;
      if (observer.options.attributeFilter && !observer.options.attributeFilter.includes("class")) continue;
      observer.records.push({ type: "attributes", attributeName: "class", target: root });
    }
  };
  const makeClassList = (classes = new Set(), onMutation = () => {}) => ({
    add(...values) {
      let changed = false;
      for (const value of values) {
        if (!classes.has(value)) { classes.add(value); changed = true; }
      }
      if (changed) onMutation();
    },
    remove(...values) {
      let changed = false;
      for (const value of values) changed = classes.delete(value) || changed;
      if (changed) onMutation();
    },
    toggle(value, enabled) {
      const changed = enabled ? !classes.has(value) : classes.has(value);
      if (enabled) classes.add(value);
      else classes.delete(value);
      if (changed) onMutation();
    },
    contains(value) { return classes.has(value); },
  });

  root = {
    className: shellAppearance,
    classList: makeClassList(rootClasses, queueRootClassMutation),
    getAttribute() { return null; },
    style: {
      setProperty(key, value) { rootStyles.set(key, value); },
      removeProperty(key) { rootStyles.delete(key); },
    },
    appendChild(node) {
      node.parentElement = root;
      nodes.set(node.id, node);
    },
  };
  const body = {
    className: "",
    getAttribute() { return null; },
    appendChild(node) {
      node.parentElement = body;
      nodes.set(node.id, node);
    },
  };
  const shellMain = {
    classList: makeClassList(),
    querySelectorAll(selector) {
      if (homeHeadingPresent && selector === 'h1, h2, [role="heading"]') return [homeHeading];
      return [];
    },
    getBoundingClientRect() {
      return { left: 290, top: 36, width: 990, height: 784 };
    },
  };
  const routeClasses = new Set();
  const utilityClasses = new Set();
  const utilityNode = { classList: makeClassList(utilityClasses) };
  const routeMain = {
    classList: makeClassList(routeClasses),
    children: [],
    appendChild(node) {
      node.parentElement = routeMain;
      routeMain.children.push(node);
      if (node.id) nodes.set(node.id, node);
      return node;
    },
    querySelectorAll(selector) {
      if (selector === '[class*="_homeUtilityBar_"]' && utilityPresent) return [utilityNode];
      return [];
    },
  };
  const homeHeading = {
    textContent: "我们该构建什么？",
    closest(selector) { return selector === '[role="main"]' ? routeMain : null; },
  };
  const staleHome = { classList: makeClassList(new Set(["dream-home"])) };
  const staleShell = { classList: makeClassList(new Set(["dream-home-shell"])) };

  const createElement = (tagName) => {
    if (tagName === "canvas" && analysisFixture) {
      return {
        width: 0,
        height: 0,
        getContext() {
          return {
            drawImage() {},
            getImageData() { return { data: analysisFixture.pixels }; },
          };
        },
      };
    }
    return {
      id: "",
      dataset: {},
      style: {},
      classList: makeClassList(),
      className: "",
      children: [],
      parentElement: null,
      textContent: "",
      innerHTML: "",
      setAttribute() {},
      appendChild(node) {
        node.parentElement = this;
        this.children.push(node);
        if (node.id) nodes.set(node.id, node);
        return node;
      },
      addEventListener() {},
      remove() { nodes.delete(this.id); },
    };
  };
  if (staleSkin) {
    const style = createElement();
    style.id = "codex-dream-skin-style";
    nodes.set(style.id, style);
    const chrome = createElement();
    chrome.id = "codex-dream-skin-chrome";
    nodes.set(chrome.id, chrome);
  }

  const document = {
    documentElement: root,
    head: root,
    body,
    createElement,
    getElementById(id) { return nodes.get(id) ?? null; },
    querySelector(selector) {
      if (selector === "main.main-surface") return hasMain ? shellMain : null;
      if (selector === "main") return hasMain ? shellMain : null;
      if (selector === "aside.app-shell-left-panel") return hasSidebar ? {} : null;
      if (selector === '[role="main"]:has([data-testid="home-icon"])') {
        return hasMain && homePresent ? routeMain : null;
      }
      if (selector === '[role="main"]') return hasMain ? routeMain : null;
      return null;
    },
    querySelectorAll(selector) {
      if (throwOnTextScan && selector.startsWith("body button")) {
        throw new Error("forced text scan failure");
      }
      if (selector.startsWith("body button")) return textScanCandidates;
      if (selector === '[role="main"]') return hasMain ? [routeMain] : [];
      if (selector === ".dream-task") return routeClasses.has("dream-task") ? [routeMain] : [];
      if (selector === ".dream-home-utility") {
        return utilityClasses.has("dream-home-utility") ? [utilityNode] : [];
      }
      if (!staleSkin) return [];
      if (selector === ".dream-home") return [staleHome];
      if (selector === ".dream-home-shell") return [staleShell];
      return [];
    },
  };
  const context = {
    window: {
      matchMedia() { return { matches: osAppearance === "dark" }; },
      addEventListener() {},
      removeEventListener() {},
    },
    document,
    MutationObserver: class {
      constructor(callback) {
        this.callback = callback;
        this.records = [];
        this.target = null;
        this.options = null;
        observers.push(this);
      }
      observe(target, options = {}) {
        this.target = target;
        this.options = options;
      }
      disconnect() {
        this.target = null;
        this.records = [];
      }
      takeRecords() {
        const records = this.records;
        this.records = [];
        return records;
      }
    },
    URL: {
      createObjectURL() { objectUrlCount += 1; return `blob:fixture-${objectUrlCount}`; },
      revokeObjectURL(value) { revokedUrls.push(value); },
    },
    Blob,
    Uint8Array,
    atob,
    setInterval: () => 1,
    clearInterval: () => {},
    setTimeout: () => { timeoutCalls += 1; return timeoutCalls + 1; },
    clearTimeout: () => {},
    getComputedStyle(candidate) {
      if (textCandidateSet.has(candidate)) textCandidateStyleReads += 1;
      return { colorScheme: computedColorScheme };
    },
    console: { error() {} },
  };
  if (analysisFixture) {
    context.Image = class {
      naturalWidth = analysisFixture.naturalWidth;
      naturalHeight = analysisFixture.naturalHeight;
      set src(_) { this.onload(); }
    };
  }

  return {
    context,
    nodes,
    observers,
    rootClasses,
    rootStyles,
    revokedUrls,
    routeClasses,
    utilityClasses,
    getTimeoutCalls() { return timeoutCalls; },
    getTextCandidateStyleReads() { return textCandidateStyleReads; },
    setShellPresent(value) {
      hasMain = value;
      hasSidebar = value;
    },
    setSidebarPresent(value) { hasSidebar = value; },
    setMainPresent(value) { hasMain = value; },
  };
}

const main = createFixture({ shellPresent: true });
const mainResult = vm.runInNewContext(payload, main.context);
assert.equal(mainResult.installed, true);
assert.equal(main.rootClasses.has("codex-dream-skin"), true);
assert.equal(main.rootStyles.get("--dream-art"), 'url("blob:fixture-1")');
assert.equal(main.nodes.has("codex-dream-skin-style"), true);
assert.equal(main.nodes.has("codex-dream-skin-chrome"), true);
assert.equal(main.rootClasses.has("dream-theme-dark"), true);
assert.equal(main.rootClasses.has("dream-art-standard"), true);
assert.equal(main.rootClasses.has("dream-task-ambient"), true);
assert.equal(main.routeClasses.has("dream-task"), true);
assert.equal(main.context.window.__CODEX_DREAM_SKIN_STATE__.cleanup(), true);
assert.equal(main.rootClasses.has("codex-dream-skin"), false);
assert.equal(main.rootClasses.has("dream-theme-dark"), false);
assert.equal(main.nodes.has("codex-dream-skin-style"), false);
assert.equal(main.nodes.has("codex-dream-skin-chrome"), false);
assert.deepEqual(main.revokedUrls, ["blob:fixture-1"]);

const mutationBurst = createFixture({ shellPresent: true });
vm.runInNewContext(payload, mutationBurst.context);
const mutationObserver = mutationBurst.observers[0];
const applicationMutation = [{ type: "childList", target: mutationBurst.context.document.body }];
mutationObserver.callback(applicationMutation);
mutationObserver.callback(applicationMutation);
mutationObserver.callback(applicationMutation);
assert.equal(mutationBurst.getTimeoutCalls(), 1,
  "A burst of renderer mutations must queue one throttled refresh instead of one refresh per record batch.");

const irrelevantTextCandidates = Array.from({ length: 1000 }, () => ({
  textContent: "ordinary streaming response content",
  childElementCount: 0,
  getBoundingClientRect() { return { width: 100, height: 20 }; },
}));
const selectiveTextScan = createFixture({
  shellPresent: true,
  textScanCandidates: irrelevantTextCandidates,
});
vm.runInNewContext(payload, selectiveTextScan.context);
assert.equal(selectiveTextScan.getTextCandidateStyleReads(), 0,
  "Irrelevant streaming text must be rejected before expensive visibility/style measurement.");

const guardedRefresh = createFixture({ shellPresent: true, throwOnTextScan: true });
const guardedResult = vm.runInNewContext(payload, guardedRefresh.context);
assert.equal(guardedResult.installed, true,
  "A transient native DOM failure must not escape the renderer injection boundary.");
assert.equal(guardedRefresh.context.window.__CODEX_DREAM_SKIN_STATE__.ensure(), false,
  "A guarded refresh must report failure without throwing into Codex's renderer event loop.");

const reinjected = createFixture({ shellPresent: true });
vm.runInNewContext(payload, reinjected.context);
const firstState = reinjected.context.window.__CODEX_DREAM_SKIN_STATE__;
vm.runInNewContext(payload, reinjected.context);
const secondState = reinjected.context.window.__CODEX_DREAM_SKIN_STATE__;
assert.notEqual(secondState.installToken, firstState.installToken);
assert.equal(secondState.artUrl, "blob:fixture-2");
assert.equal(reinjected.rootStyles.get("--dream-art"), 'url("blob:fixture-2")');
assert.deepEqual(reinjected.revokedUrls, ["blob:fixture-1"]);
assert.equal(firstState.cleanup(), false);
assert.equal(secondState.cleanup(), true);

const auxiliary = createFixture({ shellPresent: false, staleSkin: true });
const auxiliaryResult = vm.runInNewContext(payload, auxiliary.context);
assert.equal(auxiliaryResult.installed, true);
assert.equal(auxiliary.rootClasses.has("codex-dream-skin"), false);
assert.equal(auxiliary.rootStyles.has("--dream-art"), false);
assert.equal(auxiliary.nodes.has("codex-dream-skin-style"), false);
assert.equal(auxiliary.nodes.has("codex-dream-skin-chrome"), false);

auxiliary.setShellPresent(true);
auxiliary.context.window.__CODEX_DREAM_SKIN_STATE__.ensure();
assert.equal(auxiliary.rootClasses.has("codex-dream-skin"), true);
assert.equal(auxiliary.nodes.has("codex-dream-skin-style"), true);
assert.equal(auxiliary.nodes.has("codex-dream-skin-chrome"), true);

// Collapsing the left rail removes aside.app-shell-left-panel while the main
// surface remains. The active theme must stay applied instead of flashing the
// native Codex chrome.
const collapsedSidebar = createFixture({
  shellPresent: true,
  mainPresent: true,
  sidebarPresent: false,
  staleSkin: true,
});
const collapsedResult = vm.runInNewContext(payload, collapsedSidebar.context);
assert.equal(collapsedResult.installed, true);
assert.equal(collapsedSidebar.rootClasses.has("codex-dream-skin"), true);
assert.equal(collapsedSidebar.rootStyles.has("--dream-art"), true);
assert.equal(collapsedSidebar.nodes.has("codex-dream-skin-style"), true);
assert.equal(collapsedSidebar.nodes.has("codex-dream-skin-chrome"), true);
assert.equal(collapsedSidebar.rootClasses.has("dream-theme-dark"), true);

collapsedSidebar.setSidebarPresent(false);
collapsedSidebar.context.window.__CODEX_DREAM_SKIN_STATE__.ensure();
assert.equal(collapsedSidebar.rootClasses.has("codex-dream-skin"), true);
assert.equal(collapsedSidebar.nodes.has("codex-dream-skin-style"), true);

collapsedSidebar.setMainPresent(false);
collapsedSidebar.context.window.__CODEX_DREAM_SKIN_STATE__.ensure();
assert.equal(collapsedSidebar.rootClasses.has("codex-dream-skin"), false);
assert.equal(collapsedSidebar.nodes.has("codex-dream-skin-style"), false);

const configured = createFixture({
  shellPresent: true,
  homePresent: true,
  utilityPresent: true,
});
const configuredPayload = buildPayload({
  appearance: "light",
  palette: { accent: "#d45a70" },
  art: { focusX: .15, focusY: .8, safeArea: "right", taskMode: "off" },
});
const configuredResult = vm.runInNewContext(configuredPayload, configured.context);
assert.equal(configuredResult.adaptive, true);
assert.equal(configured.rootClasses.has("dream-theme-light"), true);
assert.equal(configured.rootClasses.has("dream-theme-dark"), false);
assert.equal(configured.rootClasses.has("dream-focus-left"), true);
assert.equal(configured.rootClasses.has("dream-safe-right"), true);
assert.equal(configured.rootClasses.has("dream-task-off"), true);
assert.equal(configured.rootStyles.get("--dream-art-position"), "15% 80%");
assert.equal(configured.rootStyles.get("--dream-accent"), "#d45a70");
assert.equal(configured.routeClasses.has("dream-home"), true);
assert.equal(configured.routeClasses.has("dream-task"), false);
assert.equal(configured.utilityClasses.has("dream-home-utility"), true);
assert.equal(configured.context.window.__CODEX_DREAM_SKIN_STATE__.cleanup(), true);
assert.equal(configured.utilityClasses.has("dream-home-utility"), false);

const headingOnlyHome = createFixture({
  shellPresent: true,
  homeHeadingPresent: true,
});
vm.runInNewContext(payload, headingOnlyHome.context);
assert.equal(headingOnlyHome.routeClasses.has("dream-home"), true);
assert.equal(headingOnlyHome.routeClasses.has("dream-task"), false);

const analysisPixels = new Uint8ClampedArray(48 * 12 * 4);
for (let index = 0; index < 48 * 12; index += 1) {
  const offset = index * 4;
  const x = index % 48;
  const subject = x >= 34 && x <= 42;
  analysisPixels[offset] = subject ? 210 : 246;
  analysisPixels[offset + 1] = subject ? 84 : 239;
  analysisPixels[offset + 2] = subject ? 112 : 237;
  analysisPixels[offset + 3] = 255;
}
const analyzed = createFixture({
  shellPresent: true,
  analysisFixture: { naturalWidth: 1200, naturalHeight: 400, pixels: analysisPixels },
});
vm.runInNewContext(payload, analyzed.context);
await Promise.resolve();
assert.equal(analyzed.rootClasses.has("dream-theme-dark"), true);
assert.equal(analyzed.rootClasses.has("dream-theme-light"), false);
assert.equal(analyzed.rootClasses.has("dream-art-wide"), true);
assert.equal(analyzed.rootClasses.has("dream-task-banner"), true);
assert.equal(analyzed.rootClasses.has("dream-safe-left"), true);
assert.notEqual(analyzed.rootStyles.get("--dream-accent"), "rgb(216 104 119)");

const standardArt = createFixture({
  shellPresent: true,
  analysisFixture: { naturalWidth: 800, naturalHeight: 800, pixels: analysisPixels },
});
vm.runInNewContext(payload, standardArt.context);
await Promise.resolve();
assert.equal(standardArt.rootClasses.has("dream-art-standard"), true);
assert.equal(standardArt.rootClasses.has("dream-task-ambient"), true);
assert.equal(standardArt.rootClasses.has("dream-task-banner"), false);

const mediumWide = createFixture({
  shellPresent: true,
  analysisFixture: { naturalWidth: 2100, naturalHeight: 1000, pixels: analysisPixels },
});
vm.runInNewContext(payload, mediumWide.context);
await Promise.resolve();
assert.equal(mediumWide.rootClasses.has("dream-art-wide"), true);
assert.equal(mediumWide.rootClasses.has("dream-task-ambient"), true);
assert.equal(mediumWide.rootClasses.has("dream-task-banner"), false);

const nativeLight = createFixture({ shellPresent: true, shellAppearance: "light" });
vm.runInNewContext(payload, nativeLight.context);
assert.equal(nativeLight.rootClasses.has("dream-theme-light"), true);
assert.equal(nativeLight.rootClasses.has("dream-theme-dark"), false);

const nativeComputedDark = createFixture({
  shellPresent: true,
  shellAppearance: "",
  computedColorScheme: "dark",
  osAppearance: "light",
});
vm.runInNewContext(payload, nativeComputedDark.context);
assert.equal(nativeComputedDark.rootClasses.has("dream-theme-dark"), true);
assert.equal(nativeComputedDark.rootClasses.has("dream-theme-light"), false);
nativeComputedDark.context.window.__CODEX_DREAM_SKIN_STATE__.ensure();
assert.equal(nativeComputedDark.rootClasses.has("dream-theme-dark"), true);
const nativeObserver = nativeComputedDark.observers[0];
nativeObserver.takeRecords();
nativeComputedDark.context.window.__CODEX_DREAM_SKIN_STATE__.ensure();
assert.equal(nativeObserver.takeRecords().length, 0,
  "Sampling the native computed color-scheme must not queue a self-triggering root mutation pass.");

const metadataWide = createFixture({ shellPresent: true });
vm.runInNewContext(buildPayload({ artMetadata: { ratio: 16 / 9 } }), metadataWide.context);
assert.equal(metadataWide.rootClasses.has("dream-art-wide"), true);
assert.equal(metadataWide.rootClasses.has("dream-art-standard"), false);

console.log("PASS: renderer applies adaptive theme metadata, keeps skin without a sidebar, and preserves transparent auxiliary windows.");

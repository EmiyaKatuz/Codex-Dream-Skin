import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";
import { usesInternetAngelExtension } from "../scripts/injector.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const macosRoot = path.resolve(here, "..");
const injectorPath = path.join(macosRoot, "scripts", "injector.mjs");
const doctorPath = path.join(macosRoot, "scripts", "doctor-macos.sh");
const appDelegatePath = path.join(
  macosRoot,
  "menubar-app",
  "Sources",
  "CodexDreamSkinMenuBar",
  "AppDelegate.swift",
);
const overlayCssPath = path.join(macosRoot, "assets", "internet-angel-extension.css");
const overlayScriptPath = path.join(macosRoot, "assets", "internet-angel-extension.js");
const windowsRoot = path.resolve(macosRoot, "..", "windows");
const shellSelector = 'main:is(.main-surface, [data-app-shell-main-surface], [class*="_MainContentSurface_"])';
const composerSelector = ':is(.composer-surface-chrome, [data-composer-surface-variant])';
const composerFooterSelector = ':is([class*="_footer_"], [data-composer-footer-responsive])';

async function isFile(filePath) {
  try {
    return (await fs.stat(filePath)).isFile();
  } catch {
    return false;
  }
}

assert.equal(usesInternetAngelExtension({ id: "preset-internet-angel" }), true);
assert.equal(usesInternetAngelExtension({ id: "preset-internet-angel-default" }), true);
assert.equal(usesInternetAngelExtension({ id: "preset-gothic-void-crusade" }), false);
assert.equal(usesInternetAngelExtension({ id: "custom-internet-angel-copy" }), false);
assert.equal(usesInternetAngelExtension({ id: "custom-1", name: "INTERNET ANGEL" }), false);

assert.equal(await isFile(overlayCssPath), true, "The macOS Angel CSS overlay must be packaged.");
assert.equal(await isFile(overlayScriptPath), true, "The macOS Angel lifecycle must be packaged.");

const injectorSource = await fs.readFile(injectorPath, "utf8");
const doctorSource = await fs.readFile(doctorPath, "utf8");
const appDelegateSource = await fs.readFile(appDelegatePath, "utf8");
const overlayCss = await fs.readFile(overlayCssPath, "utf8");
const overlayScript = await fs.readFile(overlayScriptPath, "utf8");
const baseCss = await fs.readFile(path.join(macosRoot, "assets", "dream-skin.css"), "utf8");
const windowsRenderer = await fs.readFile(path.join(windowsRoot, "assets", "renderer-inject.js"), "utf8");
const windowsCss = await fs.readFile(path.join(windowsRoot, "assets", "dream-skin.css"), "utf8");
for (const assetName of ["internet-angel-extension.css", "internet-angel-extension.js"]) {
  assert.match(injectorSource, new RegExp(assetName.replaceAll(".", "\\.")));
  assert.match(appDelegateSource, new RegExp(assetName.replaceAll(".", "\\.")));
  assert.match(doctorSource, new RegExp(assetName.replaceAll(".", "\\.")));
}
assert.match(injectorSource, /internetAngelExtension/);
assert.match(
  injectorSource,
  /\.update\(internetAngelTemplate\)/,
  "Overlay lifecycle changes must invalidate the injected payload revision.",
);
assert.match(
  injectorSource,
  /`\$\{basePayload\};\\n\$\{internetAngelTemplate/,
  "The base and overlay IIFEs must be separated before renderer evaluation.",
);

for (const component of [
  "composer",
  "composer-footer",
  "context-strip",
  "goal-progress",
  "goal-step",
  "goal-mode-trigger",
  "environment",
  "environment-section",
  "environment-header",
  "environment-action",
  "changes-shell",
  "changes-clip-host",
  "changes-pill",
  "side-workspace",
  "sidebar",
  "sidebar-control",
  "sidebar-new-task",
  "sidebar-section",
  "sidebar-row",
  "sidebar-footer",
  "sidebar-profile",
  "sidebar-help",
  "composer-palette",
  "composer-palette-scroll",
  "composer-palette-heading",
  "composer-palette-item",
  "turn-nav-rail",
  "turn-nav-row",
  "turn-nav-marker",
  "turn-nav-marker-active",
  "turn-preview",
  "turn-preview-surface",
  "scroll-bottom",
  "settings-sidebar",
  "settings-nav",
  "settings-search",
  "settings-content",
  "settings-surface",
  "settings-row",
  "settings-control",
  "settings-input",
  "settings-segment-group",
  "settings-segment",
  "settings-menu",
  "settings-app-row",
  "settings-app-main",
  "terminal-panel",
  "terminal-toolbar",
  "terminal-tab",
  "summary-panel",
  "message-user",
  "message-assistant",
  "message-action",
  "activity",
  "activity-header",
  "activity-detail",
  "activity-command",
  "activity-output",
  "side-chat",
  "selection-actions",
  "selection-action",
  "selected-fragment",
  "optional-comment",
  "optional-comment-input",
  "edited-card",
  "edited-card-header",
  "edited-card-icon",
  "edited-card-actions",
  "edited-card-undo",
  "edited-card-review",
  "edited-card-files",
  "edited-card-file-row",
  "edited-card-file-path",
  "edited-card-file-stats",
  "edited-card-more",
  "system-toast",
  "subagent-frame",
  "subagent-toolbar",
  "subagent-section",
  "subagent-row",
]) {
  assert.match(overlayCss, new RegExp(`data-angel-component=["']${component}["']`));
}
for (const selector of [
  '[data-message-author-role="user"]',
  '[role="dialog"]',
  '[role="menu"]',
  '[role="listbox"]',
]) {
  assert.ok(overlayCss.includes(selector), `Missing Angel surface styling for ${selector}`);
}
assert.match(overlayCss, /@media \(max-width:/);
assert.match(overlayCss, /prefers-reduced-motion: reduce/);
assert.ok(
  overlayCss.includes('div[class~="border-token-border"][class*="bg-token-dropdown-background"]'),
  "The Add palette needs a theme-gated structural first-frame fallback before lifecycle classification.",
);
assert.ok(
  overlayCss.includes('[data-angel-component="settings-content"] [role="switch"]'),
  "Settings switches need the Windows cyan/pink track and thumb instead of the native blue state.",
);
assert.ok(
  overlayCss.includes(
    `[data-dream-art-wide="true"]:not(:has(${shellSelector} [role="main"])) ${shellSelector} .composer-surface-chrome[data-angel-component="composer"]`,
  ),
  "Task composer styling must outrank the canonical immersive reset without widening theme scope.",
);
assert.ok(
  overlayCss.includes(
    `[data-dream-art-wide="true"]:not(:has(${shellSelector} [role="main"])) ${shellSelector} [data-composer-surface-variant][data-angel-component="composer"]`,
  ),
  "The Codex 26.730 composer must receive the same immersive Internet Angel override.",
);
assert.match(overlayCss, /outline:\s*2px solid var\(--angel-blue\)\s*!important/);
assert.ok(
  overlayScript.includes('[data-testid="app-shell-floating-left-panel"]'),
  "The collapsed hover sidebar must enter the same Internet Angel component lifecycle as the fixed sidebar.",
);
assert.match(
  baseCss,
  /\[data-testid="app-shell-floating-left-panel"\][^{]*\{[^}]*background(?:-image)?:[^;}]*var\(--dream-skin-art\)/,
  "Floating sidebar paint must draw the theme art directly instead of dimming through the main surface.",
);
assert.match(
  baseCss,
  /html\[data-dream-skin="active"\]\[data-dream-theme="internet-angel"\][^{]+\[data-testid="app-shell-floating-left-panel"\][^{]*\{[^}]*background-size:[^;}]*max\(100vw,\s*177\.7778vh\)\s+max\(56\.25vw,\s*100vh\)/,
  "Floating Internet Angel art must use viewport-sized 16:9 cover coordinates without affecting other themes.",
);
assert.match(
  baseCss,
  /\[data-testid="app-shell-floating-left-panel"\][^{]*button\[class~="group\/section-toggle"\]::before\s*\{[^}]*content:\s*"♥"/,
  "Floating sidebar sections must keep the fixed sidebar's safe Internet Angel ornaments.",
);
assert.match(
  baseCss,
  /:is\(aside\.app-shell-left-panel, \[data-testid="app-shell-floating-left-panel"\]\) button\[aria-label\^="切换模式"\]\s*\{[^}]*color:\s*var\(--ds-accent\)\s*!important/,
  "The floating Codex mode switch must reuse the fixed sidebar's theme accent.",
);
assert.match(
  baseCss,
  /:is\(aside\.app-shell-left-panel, \[data-testid="app-shell-floating-left-panel"\]\) button\[aria-label\^="切换模式"\]::after\s*\{[^}]*content:\s*" ·"/,
  "The floating Codex mode switch must keep the fixed sidebar's themed suffix.",
);
assert.match(
  baseCss,
  /:is\(aside\.app-shell-left-panel, \[data-testid="app-shell-floating-left-panel"\]\) \[class\*="text-token-input-placeholder-foreground"\]\s*\{[^}]*color:\s*rgb\(var\(--ds-muted-rgb\) \/ \.92\)\s*!important/,
  "The floating mode arrow must reuse the fixed sidebar's specific muted tint.",
);
assert.match(
  baseCss,
  /\[data-dream-theme="internet-angel"\][^{]*:is\(aside\.app-shell-left-panel, \[data-testid="app-shell-floating-left-panel"\]\) :is\(button, a\)\s*\{[^}]*border-radius:\s*3px 10px 3px 10px\s*!important/,
  "Floating Internet Angel controls must keep the fixed sidebar's corner shape.",
);
assert.match(
  baseCss,
  /:is\(aside\.app-shell-left-panel, \[data-testid="app-shell-floating-left-panel"\]\) :is\(button, a\)\s*\{[^}]*color:\s*var\(--ds-text\)\s*!important[^}]*transition:/,
  "Floating sidebar controls must reuse the fixed sidebar's base theme colors.",
);
assert.match(
  baseCss,
  /:is\(aside\.app-shell-left-panel, \[data-testid="app-shell-floating-left-panel"\]\) \[class\*="text-token-foreground"\]\s*\{[^}]*color:\s*var\(--ds-text\)\s*!important/,
  "Floating sidebar foreground text must reuse the fixed sidebar's theme color.",
);
assert.match(
  baseCss,
  /:is\(aside\.app-shell-left-panel, \[data-testid="app-shell-floating-left-panel"\]\) svg\s*\{[^}]*color:\s*rgb\(var\(--ds-muted-rgb\) \/ \.96\)\s*!important/,
  "Floating sidebar icons must reuse the fixed sidebar's theme tint.",
);
assert.match(
  baseCss,
  /:is\(aside\.app-shell-left-panel, \[data-testid="app-shell-floating-left-panel"\]\) :is\(button, a\):hover\s*\{[^}]*background:\s*rgb\(var\(--ds-accent-rgb\) \/ \.09\)\s*!important/,
  "Floating sidebar hover controls must reuse the fixed sidebar's theme paint.",
);
assert.match(
  baseCss,
  /:is\(aside\.app-shell-left-panel, \[data-testid="app-shell-floating-left-panel"\]\) :is\(button, a\):hover svg\s*\{[^}]*color:\s*var\(--ds-accent\)\s*!important/,
  "Floating sidebar hover icons must reuse the fixed sidebar's theme tint.",
);
assert.match(
  baseCss,
  /:is\(aside\.app-shell-left-panel, \[data-testid="app-shell-floating-left-panel"\]\) :is\(\[class~="bg-token-list-hover-background"\], \[aria-current="page"\]\)\s*\{[^}]*background:\s*rgb\(var\(--ds-accent-rgb\) \/ \.12\)\s*!important/,
  "Floating selected rows must reuse the fixed sidebar's base selection paint.",
);
assert.match(
  baseCss,
  /:is\(aside\.app-shell-left-panel, \[data-testid="app-shell-floating-left-panel"\]\) \[aria-current="page"\] svg\s*\{[^}]*color:\s*var\(--ds-accent\)\s*!important/,
  "Floating current-page icons must reuse the fixed sidebar's base highlight.",
);
assert.match(
  baseCss,
  /\[data-dream-theme="internet-angel"\][^{]*:is\(aside\.app-shell-left-panel, \[data-testid="app-shell-floating-left-panel"\]\) :is\(\[class~="bg-token-list-hover-background"\], \[aria-current="page"\]\)\s*\{[^}]*box-shadow:[^}]*var\(--angel-pink\)/,
  "Floating selected rows must reuse the fixed Internet Angel selection plate.",
);
assert.match(
  baseCss,
  /\[data-dream-theme="internet-angel"\][^{]*:is\(aside\.app-shell-left-panel, \[data-testid="app-shell-floating-left-panel"\]\) :is\(\[class~="bg-token-list-hover-background"\], \[aria-current="page"\]\) svg\s*\{[^}]*filter:\s*drop-shadow/,
  "Floating selected-row icons must reuse the fixed Internet Angel highlight.",
);
assert.match(
  overlayCss,
  /\[data-angel-component=["']sidebar-row["']\][\s\S]*?background:\s*transparent\s*!important/,
  "Ordinary sidebar rows must stay transparent at rest like the Windows skin.",
);
assert.ok(
  overlayCss.includes('[class~="bg-token-list-hover-background"]'),
  "The native selected sidebar class must receive the Windows cyan/pink selection plate.",
);
assert.ok(
  overlayCss.includes('button[data-angel-component="sidebar-row"]'),
  "Only real sidebar buttons may receive the Windows hover plate; expanded folder rows are not selected.",
);
assert.match(
  overlayCss,
  /\[data-angel-component=["']sidebar-row["']\]\s*\{[\s\S]*?overflow-y:\s*clip\s*!important/,
  "Themed fixed-height sidebar rows must not become nested vertical scroll containers.",
);
const sideWorkspaceRule = overlayCss.match(
  /\[data-angel-component=["']side-workspace["']\]\s*\{([^}]*)\}/,
)?.[1] || "";
assert.notEqual(sideWorkspaceRule, "", "The side workspace paint rule must remain present.");
assert.doesNotMatch(
  sideWorkspaceRule,
  /position\s*:/,
  "The side workspace skin must preserve the native positioning contract.",
);
assert.doesNotMatch(
  overlayCss,
  /\[data-angel-component=["']side-workspace["']\]::before/,
  "Workspace decoration must be paint-only and must not require a positioned pseudo-element.",
);
assert.ok(
  overlayCss.includes('button:has([class*="git-decoration-added"]):has([class*="git-decoration-deleted"])'),
  "The compact changed-files pill needs the same first-frame structural fallback as Windows.",
);
assert.doesNotMatch(
  `${overlayScript}\n${overlayCss}`,
  /--angel-environment-shift-x/,
  "The theme layer must not retain a stale horizontal correction after the native portal reflows.",
);
assert.ok(
  overlayCss.includes("max-width: calc(100vw - 32px)"),
  "The Environment/Sources portal must fit narrow macOS windows.",
);
assert.doesNotMatch(overlayScript, /classList\.(?:add|remove|toggle)/);
assert.doesNotMatch(overlayScript, /subtree\s*:\s*true/);

const windowsToMacosParity = [
  ["composer-palette", "composer-palette"],
  ["composer-context-strip", "context-strip"],
  ["active-goal-strip", "active-goal-strip"],
  ["goal-progress-group", "goal-progress"],
  ["goal-step", "goal-step"],
  ["goal-mode-trigger", "goal-mode-trigger"],
  ["changes-shell", "changes-shell"],
  ["changes-clip-host", "changes-clip-host"],
  ["changes-pill", "changes-pill"],
  ["permission-banner", "permission"],
  ["terminal-panel", "terminal-panel"],
  ["side-workspace", "side-workspace"],
  ["side-chat-panel", "side-chat"],
  ["summary-panel", "summary-panel"],
  ["selection-actions", "selection-actions"],
  ["selection-action", "selection-action"],
  ["selected-fragment", "selected-fragment"],
  ["optional-comment", "optional-comment"],
  ["optional-comment-input", "optional-comment-input"],
  ["edited-card", "edited-card"],
  ["edited-card-header", "edited-card-header"],
  ["edited-card-icon", "edited-card-icon"],
  ["edited-card-actions", "edited-card-actions"],
  ["edited-card-undo", "edited-card-undo"],
  ["edited-card-review", "edited-card-review"],
  ["turn-nav-rail", "turn-nav-rail"],
  ["turn-nav-row", "turn-nav-row"],
  ["turn-nav-marker", "turn-nav-marker"],
  ["turn-preview-tooltip", "turn-preview"],
  ["turn-preview-surface", "turn-preview-surface"],
  ["settings-sidebar", "settings-sidebar"],
  ["settings-content", "settings-content"],
  ["settings-app-row", "settings-app-row"],
  ["settings-app-main", "settings-app-main"],
  ["subagent-frame", "subagent-frame"],
  ["subagent-toolbar", "subagent-toolbar"],
  ["subagent-section", "subagent-section"],
  ["subagent-row", "subagent-row"],
  ["system-toast", "system-toast"],
];
for (const [windowsComponent, macosComponent] of windowsToMacosParity) {
  assert.ok(
    `${windowsRenderer}\n${windowsCss}`.includes(`dream-${windowsComponent}`),
    `Windows parity source no longer exposes dream-${windowsComponent}.`,
  );
  assert.ok(
    overlayScript.includes(`"${macosComponent}"`),
    `macOS lifecycle does not classify the Windows ${windowsComponent} equivalent.`,
  );
  assert.match(
    overlayCss,
    new RegExp(`data-angel-component=["']${macosComponent}["']`),
    `macOS CSS does not skin the Windows ${windowsComponent} equivalent.`,
  );
}

class FixtureNode {
  constructor({ className = "", rect = {}, text = "" } = {}) {
    this.attributes = new Map();
    this.className = className;
    this.isConnected = true;
    this.parentElement = null;
    this.queries = new Map();
    this.closestNodes = new Map();
    this.rect = { left: 0, top: 0, width: 0, height: 0, ...rect };
    this.textContent = text;
  }

  addQuery(selector, nodes) {
    const values = Array.isArray(nodes) ? nodes : [nodes];
    this.queries.set(selector, values);
    for (const node of values) {
      if (!node.parentElement) node.parentElement = this;
    }
    return this;
  }

  getAttribute(name) { return this.attributes.get(name) ?? null; }
  setAttribute(name, value) { this.attributes.set(name, String(value)); }
  removeAttribute(name) { this.attributes.delete(name); }
  querySelector(selector) { return this.querySelectorAll(selector)[0] || null; }
  querySelectorAll(selector) { return this.queries.get(selector) || []; }
  closest(selector) { return this.closestNodes.get(selector) || null; }
  getBoundingClientRect() {
    return {
      ...this.rect,
      right: this.rect.left + this.rect.width,
      bottom: this.rect.top + this.rect.height,
    };
  }
}

function makeOverlayFixture({ modernComposer = false } = {}) {
  const nodes = [];
  const makeNode = (options) => {
    const node = new FixtureNode(options);
    nodes.push(node);
    return node;
  };
  const composer = makeNode({ className: modernComposer ? "_ComposerLayoutRoot_fixture" : "composer-surface-chrome" });
  if (modernComposer) composer.setAttribute("data-composer-surface-variant", "default");
  const composerFooter = makeNode({ className: modernComposer ? "flex items-center" : "_footer_fixture" });
  if (modernComposer) composerFooter.setAttribute("data-composer-footer-responsive", "true");
  const editor = makeNode();
  const send = makeNode();
  const goalMode = makeNode({ text: "Goal" });
  goalMode.setAttribute("aria-label", "Goal mode");
  composer
    .addQuery(composerFooterSelector, composerFooter)
    .addQuery('[contenteditable="true"]', editor)
    .addQuery("button", [send, goalMode]);

  const sticky = makeNode();
  const contextStrip = makeNode();
  const goalLabel = makeNode({ text: "Step 1 / 6" });
  const goalStep = makeNode({ className: "inline-flex" });
  const goalProgress = makeNode({ className: "rounded-3xl items-center" });
  goalLabel.closestNodes.set('span[class~="inline-flex"]', goalStep);
  goalStep.closestNodes.set('div[class~="rounded-3xl"][class~="items-center"]', goalProgress);
  sticky
    .addQuery('div[class~="relative"][class~="min-w-0"][class~="overflow-clip"][class~="border-x"][class~="border-t"]', contextStrip)
    .addQuery("span", goalLabel);

  const environmentHost = makeNode({ className: "absolute pointer-events-none z-40" });
  const environment = makeNode({
    className: "relative rounded-3xl bg-token-dropdown-background",
    rect: { left: 1800, top: 58, width: 300, height: 199 },
    text: "Environment Changes Local main branch commit",
  });
  const environmentSection = makeNode();
  const environmentHeader = makeNode({ className: "group/section-toggle" });
  const environmentAction = makeNode();
  const sourcesSection = makeNode();
  const sourcesHeader = makeNode({ className: "group/section-toggle", text: "Sources" });
  const sourcesAction = makeNode({ text: "View all" });
  const gitSignal = makeNode();
  environmentHeader.parentElement = environmentSection;
  sourcesHeader.parentElement = sourcesSection;
  environment.closestNodes.set('[class~="absolute"][class~="z-40"]', environmentHost);
  environment
    .addQuery('button[class~="group/section-toggle"]', [environmentHeader, sourcesHeader])
    .addQuery("button", [environmentHeader, environmentAction, sourcesHeader, sourcesAction])
    .addQuery('[data-testid*="git"], [aria-label*="git" i], [class*="git-"]', gitSignal);

  const radixEnvironmentHost = makeNode();
  radixEnvironmentHost.setAttribute("data-radix-popper-content-wrapper", "");
  const radixEnvironment = makeNode({
    className: "relative rounded-3xl bg-token-dropdown-background",
    rect: { left: 1300, top: 47, width: 300, height: 317 },
    text: "Environment Changes Local main branch commit Sources View all",
  });
  const radixEnvironmentSection = makeNode();
  const radixEnvironmentHeader = makeNode({ className: "group/section-toggle", text: "Environment" });
  const radixEnvironmentAction = makeNode({ text: "Changes" });
  const radixSourcesSection = makeNode();
  const radixSourcesHeader = makeNode({ className: "group/section-toggle", text: "Sources" });
  const radixSourcesAction = makeNode({ text: "View all" });
  const radixGitSignal = makeNode();
  radixEnvironmentHeader.parentElement = radixEnvironmentSection;
  radixSourcesHeader.parentElement = radixSourcesSection;
  radixEnvironment.closestNodes.set('[data-radix-popper-content-wrapper]', radixEnvironmentHost);
  radixEnvironment
    .addQuery('button[class~="group/section-toggle"]', [radixEnvironmentHeader, radixSourcesHeader])
    .addQuery("button", [
      radixEnvironmentHeader,
      radixEnvironmentAction,
      radixSourcesHeader,
      radixSourcesAction,
    ])
    .addQuery('[data-testid*="git"], [aria-label*="git" i], [class*="git-"]', radixGitSignal);

  const lookalike = makeNode({
    className: "rounded-3xl bg-token-dropdown-background",
    rect: { left: 1400, top: 300, width: 278, height: 150 },
    text: "Environment",
  });
  lookalike.closestNodes.set('[class~="absolute"][class~="z-40"]', environmentHost);

  const workspaceOuter = makeNode({
    className: "absolute bg-token-main-surface-primary",
    rect: { left: 1220, top: 28, width: 458, height: 840 },
  });
  const workspace = makeNode({
    className: "contain:layout_paint bg-token-main-surface-primary",
    rect: { left: 1240, top: 48, width: 438, height: 820 },
  });
  const workspaceEvidence = makeNode();
  workspaceOuter.addQuery(
    '[role="tablist"], [role="tabpanel"], .xterm, .thread-scroll-container',
    workspaceEvidence,
  );
  workspace.addQuery(
    '[role="tablist"], [role="tabpanel"], .xterm, .thread-scroll-container',
    workspaceEvidence,
  );
  workspace.parentElement = workspaceOuter;

  const makeSidebarControls = () => {
    const mode = makeNode();
    mode.setAttribute("aria-label", "Switch mode, current mode: Codex");
    const search = makeNode();
    search.setAttribute("aria-label", "Search");
    const newTask = makeNode({ text: "New chat" });
    const section = makeNode({ className: "group/section-toggle", text: "Projects" });
    const row = makeNode({ text: "Codex-Dream-Skin" });
    row.setAttribute("aria-current", "page");
    const footer = makeNode();
    const profile = makeNode({ text: "OpenAI" });
    profile.setAttribute("aria-label", "Open profile menu");
    const help = makeNode();
    help.setAttribute("aria-label", "Open help menu");
    profile.parentElement = footer;
    help.parentElement = footer;
    const buttons = [mode, search, newTask, section, row, profile, help];
    return { buttons, footer, help, mode, newTask, nodes: [footer, ...buttons], profile, row, search, section };
  };

  const sidebarSelector = 'aside.app-shell-left-panel, [data-testid="app-shell-floating-left-panel"]';
  const settingsNavSelector = 'nav:has([data-settings-panel-slug])';
  const settingsContentSelector = '[class~="scrollbar-stable"][class~="flex-1"][class~="overflow-y-auto"][class~="p-panel"]';
  const sidebar = makeNode({ className: "app-shell-left-panel" });
  const sidebarControls = makeSidebarControls();
  sidebar.addQuery("button, [role=button]", sidebarControls.buttons);
  const floatingSidebar = makeNode({ className: "flex h-full min-h-0 flex-col overflow-hidden" });
  floatingSidebar.setAttribute("data-testid", "app-shell-floating-left-panel");
  const floatingSidebarControls = makeSidebarControls();
  floatingSidebar.addQuery("button, [role=button]", floatingSidebarControls.buttons);
  const fixedSidebarNodes = [sidebar, ...sidebarControls.nodes];
  const floatingSidebarNodes = [floatingSidebar, ...floatingSidebarControls.nodes];
  for (const node of floatingSidebarNodes) node.isConnected = false;

  const settingsLayout = makeNode();
  const settingsSidebar = makeNode({ className: "app-shell-left-panel" });
  const settingsNav = makeNode();
  const settingsContent = makeNode();
  const settingsScroll = makeNode({ className: "flex-1 scrollbar-stable overflow-y-auto p-panel" });
  const unrelatedSettingsContent = makeNode();
  const unrelatedSettingsScroll = makeNode({ className: "flex-1 scrollbar-stable overflow-y-auto p-panel" });
  settingsSidebar.parentElement = settingsLayout;
  settingsNav.parentElement = settingsSidebar;
  settingsNav.closestNodes.set(sidebarSelector, settingsSidebar);
  settingsScroll.parentElement = settingsContent;
  settingsContent.parentElement = settingsLayout;
  unrelatedSettingsScroll.parentElement = unrelatedSettingsContent;
  settingsLayout.addQuery(settingsContentSelector, settingsScroll);

  const palette = makeNode({ className: "border-token-border bg-token-dropdown-background/90 relative overflow-hidden rounded-2xl p-1" });
  const paletteScroll = makeNode({ className: "vertical-scroll-fade-mask overflow-y-auto" });
  const paletteHeading = makeNode({ className: "sticky top-0 z-10", text: "Add" });
  const paletteItem = makeNode({ className: "w-full shrink-0 rounded-lg text-left", text: "Add files" });
  paletteScroll.parentElement = palette;
  paletteScroll
    .addQuery('[class~="sticky"][class~="top-0"][class~="z-10"]', paletteHeading)
    .addQuery('button[class~="w-full"][class~="shrink-0"][class~="rounded-lg"][class~="text-left"]', paletteItem);

  const turnRail = makeNode();
  const turnRow = makeNode({ className: "navigation-row" });
  const turnMarker = makeNode({ className: "marker opacity-60" });
  turnRow.parentElement = turnRail;
  turnRow.addQuery('[class*="_marker_"]', turnMarker);

  const summaryPanel = makeNode({ className: "rounded-3xl bg-token-dropdown-background" });
  const userUnit = makeNode();
  userUnit.setAttribute("data-content-search-unit-key", "turn:0:user");
  const userBubble = makeNode({ className: "rounded-2xl", text: "User message" });
  const userMessageAction = makeNode();
  userMessageAction.setAttribute("aria-label", "Copy message");
  userUnit
    .addQuery('[data-user-message-bubble="true"]', userBubble)
    .addQuery('[class*="flex-row-reverse"][class*="items-center"] button[aria-label]', userMessageAction);
  const assistantUnit = makeNode();
  assistantUnit.setAttribute("data-content-search-unit-key", "turn:3:assistant");
  const assistantMessage = makeNode({ className: "group flex min-w-0 flex-col" });
  assistantMessage.setAttribute("data-response-annotation-target", "message-3");
  const assistantMessageAction = makeNode();
  assistantMessageAction.setAttribute("aria-label", "Copy response");
  assistantMessage.addQuery(
    ':scope > [class*="items-center"][class*="h-5"] button[aria-label]',
    assistantMessageAction,
  );
  assistantUnit.addQuery('[data-response-annotation-target]', assistantMessage);

  const activity = makeNode();
  activity.setAttribute("data-local-conversation-item-target-ids", "exec-1");
  const activityHeader = makeNode({ className: "group/activity-header" });
  const activityDetail = makeNode({ className: "flex flex-col overflow-clip" });
  const activityCommand = makeNode({ className: "group/command" });
  const activityOutput = makeNode({ className: "group/output" });
  activityHeader.parentElement = activity;
  activityCommand.parentElement = activityDetail;
  activityOutput.parentElement = activityDetail;
  activityDetail.parentElement = activity;
  activity
    .addQuery('[class*="group/activity-header"]', activityHeader)
    .addQuery('[class*="group/command"]', activityCommand)
    .addQuery('[class*="group/output"]', activityOutput);
  const streamingActivity = makeNode({ className: "min-w-0 text-size-chat relative overflow-visible" });
  const streamingActivityHeader = makeNode({ className: "group/activity-header", text: "Ran command" });
  streamingActivityHeader.parentElement = streamingActivity;
  streamingActivityHeader.closestNodes.set(
    'div[class~="text-size-chat"][class~="relative"][class~="overflow-visible"]',
    streamingActivity,
  );
  streamingActivity.addQuery('[class*="group/activity-header"]', streamingActivityHeader);

  const editedCard = makeNode({
    className: "rounded-lg bg-token-dropdown-background [--thread-resource-card-row-padding-x:0.75rem]",
  });
  const editedHeader = makeNode({ className: "group/turn-diff-header" });
  const editedIcon = makeNode({ className: "size-10 rounded-lg" });
  const editedTitle = makeNode({ className: "font-medium text-token-foreground", text: "Edited 8 files" });
  const editedStats = makeNode({ className: "turn-diff-default-subtitle", text: "+1,319 -18" });
  const editedActions = makeNode({ className: "pointer-events-auto flex items-center gap-2" });
  const editedUndo = makeNode({ text: "Undo" });
  const editedReview = makeNode({ text: "Review" });
  const editedFiles = makeNode({ className: "flex flex-col border-t" });
  const editedFileRow = makeNode({ className: "thread-diff-virtualized" });
  const editedFileButton = makeNode();
  const editedFilePath = makeNode({ className: "flex min-w-0 flex-1 items-center", text: "macos/assets/internet-angel-macos.css" });
  const editedFileStats = makeNode({ className: "inline-flex tabular-nums", text: "+66 -0" });
  const editedMore = makeNode({ text: "Show 5 more files" });
  editedHeader.parentElement = editedCard;
  editedHeader.closestNodes.set('[class*="rounded-lg"][class*="bg-token-dropdown-background"]', editedCard);
  editedHeader
    .addQuery('span[class~="font-medium"][class*="text-token-foreground"]', editedTitle)
    .addQuery('[class~="size-10"][class~="rounded-lg"]:has(> svg)', editedIcon);
  editedUndo.parentElement = editedActions;
  editedReview.parentElement = editedActions;
  editedActions.parentElement = editedHeader;
  editedCard
    .addQuery(".turn-diff-default-subtitle", editedStats)
    .addQuery("button, [role=button]", [editedUndo, editedReview])
    .addQuery(':scope > [class~="flex"][class~="flex-col"][class~="border-t"]', editedFiles);
  editedFiles
    .addQuery(".thread-diff-virtualized", editedFileRow)
    .addQuery(":scope > button", editedMore);
  editedFileRow.addQuery("button", editedFileButton);
  editedFileButton
    .addQuery('[class~="min-w-0"][class~="flex-1"][class~="items-center"]', editedFilePath)
    .addQuery('[class~="tabular-nums"]', editedFileStats);

  const changesClipHost = makeNode({ className: "relative overflow-hidden rounded-3xl" });
  const changesShell = makeNode({ className: "rounded-3xl border-token-border" });
  const changesWrapper = makeNode();
  const changesPill = makeNode({ text: "4 files changed +526 -12" });
  const changesAdded = makeNode({ className: "git-decoration-added", text: "+526" });
  const changesDeleted = makeNode({ className: "git-decoration-deleted", text: "-12" });
  changesPill.parentElement = changesWrapper;
  changesPill
    .addQuery('[class*="git-decoration-added"]', changesAdded)
    .addQuery('[class*="git-decoration-deleted"]', changesDeleted);
  changesWrapper.closestNodes.set(':not(button)[class*="rounded-3xl"][class*="border"]', changesShell);
  changesWrapper.closestNodes.set(
    ':not(button)[class~="overflow-hidden"][class~="rounded-3xl"]',
    changesClipHost,
  );

  const shell = makeNode();
  const body = makeNode();
  sidebar.parentElement = body;
  const documentQueries = new Map([
    [composerSelector, [composer]],
    [`${shellSelector} [class~="sticky"][class~="bottom-0"]`, [sticky]],
    ['div[class*="bg-token-dropdown-background"][class~="rounded-3xl"]', [
      environment,
      radixEnvironment,
      lookalike,
    ]],
    ['[class*="contain:layout_paint"], [class~="bg-token-main-surface-primary"]', [
      workspaceOuter,
      workspace,
    ]],
    ['[class*="rounded-3xl"][class*="bg-token-dropdown-background"]:has(> [class*="overflow-y-auto"] [class*="group/summary-panel-item"])', [
      environment,
      radixEnvironment,
      summaryPanel,
    ]],
    ['[data-user-message-bubble="true"]', [userBubble]],
    ['[data-content-search-unit-key$=":user"]', [userUnit]],
    ['[data-content-search-unit-key$=":assistant"]', [assistantUnit]],
    ['[data-local-conversation-item-target-ids]', [activity]],
    ['[class*="group/activity-header"]', [activityHeader, streamingActivityHeader]],
    ['[class*="group/turn-diff-header"]', [editedHeader]],
    ['button:has([class*="git-decoration-added"]):has([class*="git-decoration-deleted"])', [changesPill]],
    [sidebarSelector, [sidebar]],
    ['div.vertical-scroll-fade-mask[class~="overflow-y-auto"]', [paletteScroll]],
    ['button[class*="navigation-row"]', [turnRow]],
    [settingsNavSelector, [settingsNav]],
    [settingsContentSelector, [unrelatedSettingsScroll, settingsScroll]],
  ]);
  const document = {
    body,
    querySelector(selector) {
      if (selector === shellSelector) return shell;
      return (documentQueries.get(selector) || [])[0] || null;
    },
    querySelectorAll(selector) {
      if (selector === "[data-angel-component]") {
        return nodes.filter((node) => node.isConnected && node.attributes.has("data-angel-component"));
      }
      return (documentQueries.get(selector) || []).filter((node) => node.isConnected);
    },
  };
  const observers = [];
  class MockMutationObserver {
    constructor(callback) { this.callback = callback; observers.push(this); }
    observe(target, options) { this.target = target; this.options = options; }
    disconnect() { this.disconnected = true; }
  }
  const listeners = new Map();
  const navigation = {
    addEventListener(type, callback) { listeners.set(`navigation:${type}`, callback); },
    removeEventListener(type) { listeners.delete(`navigation:${type}`); },
  };
  let nextTimer = 0;
  const timers = new Map();
  const window = {
    navigation,
    addEventListener(type, callback) { listeners.set(type, callback); },
    removeEventListener(type) { listeners.delete(type); },
  };
  const notifyBodyMutation = (record) => {
    const observer = observers.find((candidate) => candidate.target === body);
    if (!observer) throw new Error("Body mutation observer was not installed");
    observer.callback([record]);
  };
  return {
    composer,
    composerFooter,
    context: {
      document,
      innerWidth: 1678,
      MutationObserver: MockMutationObserver,
      window,
      setTimeout(callback) { const id = ++nextTimer; timers.set(id, callback); return id; },
      clearTimeout(id) { timers.delete(id); },
    },
    contextStrip,
    editor,
    environment,
    environmentAction,
    environmentHeader,
    environmentSection,
    floatingSidebar,
    floatingSidebarFooter: floatingSidebarControls.footer,
    floatingSidebarHelp: floatingSidebarControls.help,
    floatingSidebarMode: floatingSidebarControls.mode,
    floatingSidebarNewTask: floatingSidebarControls.newTask,
    floatingSidebarProfile: floatingSidebarControls.profile,
    floatingSidebarRow: floatingSidebarControls.row,
    floatingSidebarSearch: floatingSidebarControls.search,
    floatingSidebarSection: floatingSidebarControls.section,
    radixEnvironment,
    radixEnvironmentAction,
    radixEnvironmentHeader,
    radixEnvironmentSection,
    radixSourcesAction,
    radixSourcesHeader,
    radixSourcesSection,
    sourcesAction,
    sourcesHeader,
    sourcesSection,
    activity,
    activityCommand,
    activityDetail,
    activityHeader,
    activityOutput,
    assistantMessage,
    assistantMessageAction,
    editedActions,
    editedCard,
    editedFileButton,
    editedFilePath,
    editedFileRow,
    editedFileStats,
    editedFiles,
    editedHeader,
    editedIcon,
    editedMore,
    editedReview,
    editedStats,
    editedTitle,
    editedUndo,
    changesClipHost,
    changesPill,
    changesShell,
    goalProgress,
    goalStep,
    goalMode,
    listeners,
    lookalike,
    nodes,
    observers,
    send,
    sidebar,
    sidebarFooter: sidebarControls.footer,
    sidebarHelp: sidebarControls.help,
    sidebarMode: sidebarControls.mode,
    sidebarNewTask: sidebarControls.newTask,
    sidebarProfile: sidebarControls.profile,
    sidebarRow: sidebarControls.row,
    sidebarSearch: sidebarControls.search,
    sidebarSection: sidebarControls.section,
    settingsContent,
    settingsNav,
    settingsSidebar,
    unrelatedSettingsContent,
    summaryPanel,
    streamingActivity,
    streamingActivityHeader,
    palette,
    paletteHeading,
    paletteItem,
    paletteScroll,
    turnMarker,
    turnRail,
    turnRow,
    userBubble,
    userMessageAction,
    timers,
    flushTimers() {
      const queued = [...timers.values()];
      timers.clear();
      for (const callback of queued) callback();
    },
    removeFixedSidebar() {
      documentQueries.set(sidebarSelector, []);
      for (const node of fixedSidebarNodes) node.isConnected = false;
      sidebar.parentElement = null;
      notifyBodyMutation({ type: "childList", target: body, addedNodes: [], removedNodes: [sidebar] });
    },
    mountFloatingSidebar() {
      for (const node of floatingSidebarNodes) node.isConnected = true;
      floatingSidebar.parentElement = body;
      documentQueries.set(sidebarSelector, [floatingSidebar]);
      notifyBodyMutation({ type: "childList", target: body, addedNodes: [floatingSidebar], removedNodes: [] });
    },
    mountFloatingSidebarAlongsideFixed() {
      for (const node of floatingSidebarNodes) node.isConnected = true;
      floatingSidebar.parentElement = body;
      documentQueries.set(sidebarSelector, [sidebar, floatingSidebar]);
      notifyBodyMutation({ type: "childList", target: body, addedNodes: [floatingSidebar], removedNodes: [] });
    },
    window,
    workspace,
    workspaceOuter,
  };
}

const fixture = makeOverlayFixture();
vm.runInNewContext(
  overlayScript.replace("__INTERNET_ANGEL_EXTENSION_ENABLED_JSON__", "true"),
  fixture.context,
);
const component = (node) => node.getAttribute("data-angel-component");
assert.equal(component(fixture.composer), "composer");
assert.equal(component(fixture.composerFooter), "composer-footer");
assert.equal(component(fixture.editor), "composer-input");
assert.equal(component(fixture.send), "composer-action");
assert.equal(component(fixture.contextStrip), "context-strip");
assert.equal(component(fixture.goalStep), "goal-step");
assert.equal(component(fixture.goalProgress), "goal-progress");
assert.equal(component(fixture.goalMode), "goal-mode-trigger");

const modernComposerFixture = makeOverlayFixture({ modernComposer: true });
assert.equal(modernComposerFixture.composer.className.includes("composer-surface-chrome"), false,
  "The modern-only fixture must not accidentally retain the legacy composer class.");
assert.equal(modernComposerFixture.composerFooter.className.includes("_footer_"), false,
  "The modern-only fixture must not accidentally retain the legacy footer class.");
vm.runInNewContext(
  overlayScript.replace("__INTERNET_ANGEL_EXTENSION_ENABLED_JSON__", "true"),
  modernComposerFixture.context,
);
assert.equal(component(modernComposerFixture.composer), "composer",
  "Codex 26.730 data-composer-surface-variant must enter the Internet Angel lifecycle.");
assert.equal(component(modernComposerFixture.composerFooter), "composer-footer",
  "Codex 26.730 data-composer-footer-responsive must avoid a native footer paint.");
assert.equal(component(modernComposerFixture.editor), "composer-input");
assert.equal(component(modernComposerFixture.send), "composer-action");
assert.equal(component(modernComposerFixture.goalMode), "goal-mode-trigger");
assert.equal(component(fixture.environment), "environment");
assert.equal(component(fixture.environmentSection), "environment-section");
assert.equal(component(fixture.environmentHeader), "environment-header");
assert.equal(component(fixture.environmentAction), "environment-action");
assert.equal(component(fixture.sourcesSection), "environment-section");
assert.equal(component(fixture.sourcesHeader), "environment-header");
assert.equal(component(fixture.sourcesAction), "environment-action");
assert.equal(component(fixture.radixEnvironment), "environment");
assert.equal(component(fixture.radixEnvironmentSection), "environment-section");
assert.equal(component(fixture.radixEnvironmentHeader), "environment-header");
assert.equal(component(fixture.radixEnvironmentAction), "environment-action");
assert.equal(component(fixture.radixSourcesSection), "environment-section");
assert.equal(component(fixture.radixSourcesHeader), "environment-header");
assert.equal(component(fixture.radixSourcesAction), "environment-action");
assert.equal(component(fixture.changesShell), "changes-shell");
assert.equal(component(fixture.changesClipHost), "changes-clip-host");
assert.equal(component(fixture.changesPill), "changes-pill");
assert.equal(component(fixture.workspace), "side-workspace");
assert.equal(
  component(fixture.workspaceOuter),
  null,
  "Only the innermost right-docked workspace surface may be themed.",
);
assert.equal(component(fixture.sidebar), "sidebar");
assert.equal(component(fixture.sidebarMode), "sidebar-control");
assert.equal(component(fixture.sidebarSearch), "sidebar-control");
assert.equal(component(fixture.sidebarNewTask), "sidebar-new-task");
assert.equal(component(fixture.sidebarSection), "sidebar-section");
assert.equal(component(fixture.sidebarRow), "sidebar-row");
assert.equal(component(fixture.sidebarFooter), "sidebar-footer");
assert.equal(component(fixture.sidebarProfile), "sidebar-profile");
assert.equal(component(fixture.sidebarHelp), "sidebar-help");
assert.equal(component(fixture.settingsSidebar), "settings-sidebar");
assert.equal(component(fixture.settingsNav), "settings-nav");
assert.equal(component(fixture.settingsContent), "settings-content");
assert.equal(
  component(fixture.unrelatedSettingsContent),
  null,
  "Settings classification must stay inside the layout that owns the settings navigation.",
);
fixture.removeFixedSidebar();
fixture.flushTimers();
assert.equal(
  fixture.context.document.querySelector('aside.app-shell-left-panel, [data-testid="app-shell-floating-left-panel"]'),
  null,
  "The classifier must tolerate the empty interval after the fixed sidebar is removed.",
);
assert.equal(component(fixture.floatingSidebar), null, "The floating sidebar must not exist before its portal mounts.");
fixture.mountFloatingSidebar();
fixture.flushTimers();
assert.equal(component(fixture.floatingSidebar), "sidebar");
assert.equal(component(fixture.floatingSidebarMode), "sidebar-control");
assert.equal(component(fixture.floatingSidebarSearch), "sidebar-control");
assert.equal(component(fixture.floatingSidebarNewTask), "sidebar-new-task");
assert.equal(component(fixture.floatingSidebarSection), "sidebar-section");
assert.equal(component(fixture.floatingSidebarRow), "sidebar-row");
assert.equal(component(fixture.floatingSidebarFooter), "sidebar-footer");
assert.equal(component(fixture.floatingSidebarProfile), "sidebar-profile");
assert.equal(component(fixture.floatingSidebarHelp), "sidebar-help");

const overlappingSidebars = makeOverlayFixture();
vm.runInNewContext(
  overlayScript.replace("__INTERNET_ANGEL_EXTENSION_ENABLED_JSON__", "true"),
  overlappingSidebars.context,
);
overlappingSidebars.mountFloatingSidebarAlongsideFixed();
overlappingSidebars.flushTimers();
assert.equal(component(overlappingSidebars.floatingSidebar), "sidebar",
  "The floating portal must be classified when the fixed sidebar still exists during transition");
assert.equal(component(fixture.palette), "composer-palette");
assert.equal(component(fixture.paletteScroll), "composer-palette-scroll");
assert.equal(component(fixture.paletteHeading), "composer-palette-heading");
assert.equal(component(fixture.paletteItem), "composer-palette-item");
assert.equal(component(fixture.turnRail), "turn-nav-rail");
assert.equal(component(fixture.turnRow), "turn-nav-row");
assert.equal(component(fixture.turnMarker), "turn-nav-marker-active");
assert.equal(component(fixture.summaryPanel), "summary-panel");
assert.equal(component(fixture.userBubble), "message-user");
assert.equal(component(fixture.assistantMessage), "message-assistant");
assert.equal(component(fixture.userMessageAction), "message-action");
assert.equal(component(fixture.assistantMessageAction), "message-action");
assert.equal(component(fixture.activity), "activity");
assert.equal(component(fixture.activityHeader), "activity-header");
assert.equal(component(fixture.activityDetail), "activity-detail");
assert.equal(component(fixture.activityCommand), "activity-command");
assert.equal(component(fixture.activityOutput), "activity-output");
assert.equal(component(fixture.streamingActivity), "activity");
assert.equal(component(fixture.streamingActivityHeader), "activity-header");
assert.equal(component(fixture.editedCard), "edited-card");
assert.equal(component(fixture.editedHeader), "edited-card-header");
assert.equal(component(fixture.editedIcon), "edited-card-icon");
assert.equal(component(fixture.editedTitle), "edited-card-title");
assert.equal(component(fixture.editedStats), "edited-card-stats");
assert.equal(component(fixture.editedActions), "edited-card-actions");
assert.equal(component(fixture.editedUndo), "edited-card-undo");
assert.equal(component(fixture.editedReview), "edited-card-review");
assert.equal(component(fixture.editedFiles), "edited-card-files");
assert.equal(component(fixture.editedFileButton), "edited-card-file-row");
assert.equal(component(fixture.editedFilePath), "edited-card-file-path");
assert.equal(component(fixture.editedFileStats), "edited-card-file-stats");
assert.equal(component(fixture.editedMore), "edited-card-more");
assert.equal(component(fixture.lookalike), null, "An incomplete Environment lookalike must stay native.");
assert.ok(fixture.observers.length >= 2, "Shell and portal mount points must be observed.");
assert.ok(fixture.observers.every((observer) => observer.options?.childList === true));
assert.ok(fixture.observers.every((observer) => observer.options?.subtree !== true));
assert.equal(typeof fixture.listeners.get("click"), "function");
assert.equal(typeof fixture.listeners.get("resize"), "function");
assert.notEqual(
  fixture.listeners.get("resize"),
  fixture.listeners.get("click"),
  "Window resize must not share the mutation debounce that can retain stale portal coordinates.",
);
assert.equal(fixture.listeners.has("transitionend"), false);
assert.equal(typeof fixture.listeners.get("compositionstart"), "function");
assert.equal(typeof fixture.listeners.get("compositionend"), "function");

vm.runInNewContext(
  overlayScript.replace("__INTERNET_ANGEL_EXTENSION_ENABLED_JSON__", "false"),
  fixture.context,
);
assert.equal(
  fixture.nodes.some((node) => node.isConnected && component(node)),
  false,
  "Theme switch cleanup must remove marks from the connected document.",
);
assert.ok(fixture.observers.every((observer) => observer.disconnected === true));
assert.equal(fixture.timers.size, 0);
assert.equal(fixture.listeners.has("click"), false);
assert.equal(fixture.listeners.has("resize"), false);
assert.equal(fixture.listeners.has("transitionend"), false);
assert.equal(fixture.listeners.has("compositionstart"), false);
assert.equal(fixture.listeners.has("compositionend"), false);

console.log("PASS: Internet Angel macOS overlay activation is exact and isolated.");

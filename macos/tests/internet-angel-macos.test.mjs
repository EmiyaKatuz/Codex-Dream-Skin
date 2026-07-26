import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";
import { usesInternetAngelMacosOverlay } from "../scripts/injector.mjs";

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
const overlayCssPath = path.join(macosRoot, "assets", "internet-angel-macos.css");
const overlayScriptPath = path.join(macosRoot, "assets", "internet-angel-macos.js");

async function isFile(filePath) {
  try {
    return (await fs.stat(filePath)).isFile();
  } catch {
    return false;
  }
}

assert.equal(usesInternetAngelMacosOverlay({ id: "preset-internet-angel" }), true);
assert.equal(usesInternetAngelMacosOverlay({ id: "preset-internet-angel-default" }), true);
assert.equal(usesInternetAngelMacosOverlay({ id: "preset-gothic-void-crusade" }), false);
assert.equal(usesInternetAngelMacosOverlay({ id: "custom-internet-angel-copy" }), false);
assert.equal(usesInternetAngelMacosOverlay({ id: "custom-1", name: "INTERNET ANGEL" }), false);

assert.equal(await isFile(overlayCssPath), true, "The macOS Angel CSS overlay must be packaged.");
assert.equal(await isFile(overlayScriptPath), true, "The macOS Angel lifecycle must be packaged.");

const injectorSource = await fs.readFile(injectorPath, "utf8");
const doctorSource = await fs.readFile(doctorPath, "utf8");
const appDelegateSource = await fs.readFile(appDelegatePath, "utf8");
const overlayCss = await fs.readFile(overlayCssPath, "utf8");
const overlayScript = await fs.readFile(overlayScriptPath, "utf8");
for (const assetName of ["internet-angel-macos.css", "internet-angel-macos.js"]) {
  assert.match(injectorSource, new RegExp(assetName.replaceAll(".", "\\.")));
  assert.match(appDelegateSource, new RegExp(assetName.replaceAll(".", "\\.")));
  assert.match(doctorSource, new RegExp(assetName.replaceAll(".", "\\.")));
}
assert.match(injectorSource, /internetAngelMacosOverlay/);
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
  "context-strip",
  "goal-progress",
  "goal-step",
  "environment",
  "environment-header",
  "environment-action",
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
  "terminal-panel",
  "terminal-toolbar",
  "terminal-tab",
  "summary-panel",
  "side-chat",
  "selection-actions",
  "selection-action",
  "selected-fragment",
  "optional-comment",
  "optional-comment-input",
  "edited-card",
  "edited-card-header",
  "edited-card-action",
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
    '[data-dream-art-wide="true"]:not(:has(main.main-surface [role="main"])) main.main-surface .composer-surface-chrome[data-angel-component="composer"]',
  ),
  "Task composer styling must outrank the canonical immersive reset without widening theme scope.",
);
assert.match(overlayCss, /outline:\s*2px solid var\(--angel-blue\)\s*!important/);
assert.doesNotMatch(overlayScript, /classList\.(?:add|remove|toggle)/);
assert.doesNotMatch(overlayScript, /subtree\s*:\s*true/);

class FixtureNode {
  constructor({ className = "", rect = {}, text = "" } = {}) {
    this.attributes = new Map();
    this.className = className;
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

function makeOverlayFixture() {
  const nodes = [];
  const makeNode = (options) => {
    const node = new FixtureNode(options);
    nodes.push(node);
    return node;
  };
  const composer = makeNode({ className: "composer-surface-chrome" });
  const editor = makeNode();
  const send = makeNode();
  composer
    .addQuery('[contenteditable="true"]', editor)
    .addQuery("button", send);

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
    rect: { left: 1378, top: 58, width: 300, height: 199 },
    text: "Environment Changes Local main branch commit",
  });
  const environmentSection = makeNode();
  const environmentHeader = makeNode({ className: "group/section-toggle" });
  const environmentAction = makeNode();
  const gitSignal = makeNode();
  environmentHeader.parentElement = environmentSection;
  environment.closestNodes.set('[class~="absolute"][class~="z-40"]', environmentHost);
  environment
    .addQuery('button[class~="group/section-toggle"]', environmentHeader)
    .addQuery("button", [environmentHeader, environmentAction])
    .addQuery('[data-testid*="git"], [aria-label*="git" i], [class*="git-"]', gitSignal);

  const lookalike = makeNode({
    className: "rounded-3xl bg-token-dropdown-background",
    rect: { left: 1400, top: 300, width: 278, height: 150 },
    text: "Environment",
  });
  lookalike.closestNodes.set('[class~="absolute"][class~="z-40"]', environmentHost);

  const workspace = makeNode({
    className: "contain:layout_paint bg-token-main-surface-primary",
    rect: { left: 1240, top: 48, width: 438, height: 820 },
  });
  workspace.addQuery('[role="tablist"], [role="tabpanel"], .xterm, .thread-scroll-container', makeNode());

  const sidebar = makeNode({ className: "app-shell-left-panel" });
  const sidebarMode = makeNode();
  sidebarMode.setAttribute("aria-label", "Switch mode, current mode: Codex");
  const sidebarSearch = makeNode();
  sidebarSearch.setAttribute("aria-label", "Search");
  const sidebarNewTask = makeNode({ text: "New chat" });
  const sidebarSection = makeNode({ className: "group/section-toggle", text: "Projects" });
  const sidebarRow = makeNode({ text: "Codex-Dream-Skin" });
  sidebarRow.setAttribute("aria-current", "page");
  const sidebarFooter = makeNode();
  const sidebarProfile = makeNode({ text: "OpenAI" });
  sidebarProfile.setAttribute("aria-label", "Open profile menu");
  const sidebarHelp = makeNode();
  sidebarHelp.setAttribute("aria-label", "Open help menu");
  sidebarProfile.parentElement = sidebarFooter;
  sidebarHelp.parentElement = sidebarFooter;
  sidebar.addQuery("button, [role=button]", [
    sidebarMode,
    sidebarSearch,
    sidebarNewTask,
    sidebarSection,
    sidebarRow,
    sidebarProfile,
    sidebarHelp,
  ]);

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

  const shell = makeNode();
  const body = makeNode();
  const documentQueries = new Map([
    [".composer-surface-chrome", [composer]],
    ['main.main-surface [class~="sticky"][class~="bottom-0"]', [sticky]],
    ['div[class*="bg-token-dropdown-background"][class~="rounded-3xl"]', [environment, lookalike]],
    ['[class*="contain:layout_paint"], [class~="bg-token-main-surface-primary"]', [workspace]],
    ['[class*="rounded-3xl"][class*="bg-token-dropdown-background"]:has(> [class*="overflow-y-auto"] [class*="group/summary-panel-item"])', [environment]],
    ["aside.app-shell-left-panel", [sidebar]],
    ['div.vertical-scroll-fade-mask[class~="overflow-y-auto"]', [paletteScroll]],
    ['button[class*="navigation-row"]', [turnRow]],
  ]);
  const document = {
    body,
    querySelector(selector) {
      if (selector === "main.main-surface") return shell;
      return (documentQueries.get(selector) || [])[0] || null;
    },
    querySelectorAll(selector) {
      if (selector === "[data-angel-component]") {
        return nodes.filter((node) => node.attributes.has("data-angel-component"));
      }
      return documentQueries.get(selector) || [];
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
  return {
    composer,
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
    goalProgress,
    goalStep,
    listeners,
    lookalike,
    nodes,
    observers,
    send,
    sidebar,
    sidebarFooter,
    sidebarHelp,
    sidebarMode,
    sidebarNewTask,
    sidebarProfile,
    sidebarRow,
    sidebarSearch,
    sidebarSection,
    palette,
    paletteHeading,
    paletteItem,
    paletteScroll,
    turnMarker,
    turnRail,
    turnRow,
    timers,
    window,
    workspace,
  };
}

const fixture = makeOverlayFixture();
vm.runInNewContext(
  overlayScript.replace("__INTERNET_ANGEL_MACOS_ENABLED_JSON__", "true"),
  fixture.context,
);
const component = (node) => node.getAttribute("data-angel-component");
assert.equal(component(fixture.composer), "composer");
assert.equal(component(fixture.editor), "composer-input");
assert.equal(component(fixture.send), "composer-action");
assert.equal(component(fixture.contextStrip), "context-strip");
assert.equal(component(fixture.goalStep), "goal-step");
assert.equal(component(fixture.goalProgress), "goal-progress");
assert.equal(component(fixture.environment), "environment");
assert.equal(component(fixture.environmentHeader), "environment-header");
assert.equal(component(fixture.environmentAction), "environment-action");
assert.equal(component(fixture.workspace), "side-workspace");
assert.equal(component(fixture.sidebar), "sidebar");
assert.equal(component(fixture.sidebarMode), "sidebar-control");
assert.equal(component(fixture.sidebarSearch), "sidebar-control");
assert.equal(component(fixture.sidebarNewTask), "sidebar-new-task");
assert.equal(component(fixture.sidebarSection), "sidebar-section");
assert.equal(component(fixture.sidebarRow), "sidebar-row");
assert.equal(component(fixture.sidebarFooter), "sidebar-footer");
assert.equal(component(fixture.sidebarProfile), "sidebar-profile");
assert.equal(component(fixture.sidebarHelp), "sidebar-help");
assert.equal(component(fixture.palette), "composer-palette");
assert.equal(component(fixture.paletteScroll), "composer-palette-scroll");
assert.equal(component(fixture.paletteHeading), "composer-palette-heading");
assert.equal(component(fixture.paletteItem), "composer-palette-item");
assert.equal(component(fixture.turnRail), "turn-nav-rail");
assert.equal(component(fixture.turnRow), "turn-nav-row");
assert.equal(component(fixture.turnMarker), "turn-nav-marker-active");
assert.equal(component(fixture.lookalike), null, "An incomplete Environment lookalike must stay native.");
assert.ok(fixture.observers.length >= 2, "Shell and portal mount points must be observed.");
assert.ok(fixture.observers.every((observer) => observer.options?.childList === true));
assert.ok(fixture.observers.every((observer) => observer.options?.subtree !== true));
assert.equal(typeof fixture.listeners.get("click"), "function");
assert.equal(typeof fixture.listeners.get("transitionend"), "function");

vm.runInNewContext(
  overlayScript.replace("__INTERNET_ANGEL_MACOS_ENABLED_JSON__", "false"),
  fixture.context,
);
assert.equal(fixture.nodes.some((node) => component(node)), false, "Theme switch cleanup must remove all marks.");
assert.ok(fixture.observers.every((observer) => observer.disconnected === true));
assert.equal(fixture.timers.size, 0);
assert.equal(fixture.listeners.has("click"), false);
assert.equal(fixture.listeners.has("transitionend"), false);

console.log("PASS: Internet Angel macOS overlay activation is exact and isolated.");

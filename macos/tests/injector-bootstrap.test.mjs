import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";
import { earlyPayloadFor } from "../scripts/injector.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const injectorPath = path.resolve(here, "../scripts/injector.mjs");
const source = await fs.readFile(injectorPath, "utf8");

function createFixture() {
  const domReady = [];
  const timers = new Map();
  const intervals = new Map();
  let nextTimer = 1;
  let nextInterval = 1;
  const markers = { shell: false, sidebar: false, main: false, settings: false };
  let root = {};
  const context = {
    window: { installs: [] },
    location: { protocol: "app:" },
    document: {
      get documentElement() { return root; },
      addEventListener(type, callback) { if (type === "DOMContentLoaded") domReady.push(callback); },
      querySelector(selector) {
        if (selector === ":is(main.main-surface, main[data-app-shell-main-surface])") {
          return markers.shell ? {} : null;
        }
        if (selector === "aside.app-shell-left-panel") return markers.sidebar ? {} : null;
        if (selector === "[role=\"main\"]") return markers.main ? {} : null;
        if (selector.includes("appearance-theme") || selector.includes("theme-preview")) {
          return markers.settings ? {} : null;
        }
        return null;
      },
    },
    setTimeout(callback) {
      const id = nextTimer++;
      timers.set(id, callback);
      return id;
    },
    clearTimeout(id) { timers.delete(id); },
    setInterval(callback) {
      const id = nextInterval++;
      intervals.set(id, callback);
      return id;
    },
    clearInterval(id) { intervals.delete(id); },
  };
  return {
    context,
    markers,
    makeNotReady() { root = null; },
    makeReady() { root = {}; },
    fireDomReady() { for (const callback of [...domReady]) callback(); },
    tick() { for (const callback of [...intervals.values()]) callback(); },
    observers: [],
  };
}

const guarded = createFixture();
vm.runInNewContext(earlyPayloadFor('window.installs.push("guarded")', "guarded"), guarded.context);
assert.deepEqual(guarded.context.window.installs, [], "Auxiliary app targets must remain untouched.");
assert.equal(guarded.observers.length, 0, "Early bootstrap must not install a broad MutationObserver.");
guarded.markers.shell = true;
guarded.tick();
assert.deepEqual(guarded.context.window.installs, [], "A shell without its sidebar is not sufficient for identity.");
guarded.markers.sidebar = true;
guarded.tick();
assert.deepEqual(guarded.context.window.installs, ["guarded"]);

const generations = createFixture();
generations.makeNotReady();
generations.markers.shell = true;
generations.markers.sidebar = true;
vm.runInNewContext(earlyPayloadFor('window.installs.push("old")', "old"), generations.context);
vm.runInNewContext(earlyPayloadFor('window.installs.push("new")', "new"), generations.context);
generations.makeReady();
generations.fireDomReady();
assert.deepEqual(
  generations.context.window.installs,
  ["new"],
  "A stale early script must yield to the newest watcher generation.",
);
assert.equal(generations.context.window.__CODEX_DREAM_SKIN_EARLY_APPLIED__, "new");

const earlyStart = source.indexOf("export function earlyPayloadFor");
const earlySource = source.slice(earlyStart, earlyStart + 2200);
assert.ok(earlyStart >= 0, "Early payload helper must remain exported for bootstrap tests.");
assert.doesNotMatch(earlySource, /MutationObserver|childList|subtree/,
  "Early bootstrap must not observe the entire renderer DOM.");
assert.match(earlySource, /DOMContentLoaded/);
assert.match(earlySource, /setInterval\(install, 250\)/);
const discoveryStart = source.indexOf("record.earlyScriptId = await registerEarly");
const probeStart = source.indexOf("const probe = await waitForCodexProbe", discoveryStart);
assert.ok(discoveryStart >= 0 && probeStart > discoveryStart, "Early registration must happen before full shell probing.");
assert.match(
  source,
  /finally\s*\{[\s\S]*Promise\.all\(\[\.\.\.sessions\.values\(\)\][\s\S]*removeEarly\(record\)/,
  "Watcher shutdown must unregister persistent Page scripts before closing CDP sessions.",
);
const probeSessionStart = source.indexOf("async function probeSession");
const probeSessionSource = source.slice(probeSessionStart, probeSessionStart + 1800);
assert.ok(probeSessionStart >= 0, "Codex target discovery probe must exist.");
assert.match(
  probeSessionSource,
  /data-settings-panel-slug/,
  "Every settings panel must be recognized, not only Appearance with a theme preview.",
);
assert.match(
  source,
  /const earlyApplied = await session\.evaluate\([\s\S]*if \(!earlyApplied\) \{[\s\S]*applyToSession/,
  "The watcher must not run the full payload twice after a successful early install.",
);
assert.match(
  source,
  /const suggestionLabelColorsMatch = visibleSuggestionLabels\.every\(/,
  "Live verification must reject visible home suggestion labels that diverge from the themed card color.",
);
assert.match(source, /visibleSuggestionLabels\.length >= result\.visibleCardCount/);
assert.match(source, /result\.cardLabelCoverage\.filter\(Boolean\)\.length >= result\.visibleCardCount/);
assert.match(source, /angelCards\.length === 4/);
assert.match(source, /angelDeckPass/);
assert.match(source, /suggestionLabelColorsMatch/);
assert.match(
  source,
  /composerAngelPass/,
  "Internet Angel verification must reject a visible native-gray task composer.",
);
assert.match(source, /outlineWidth/);
assert.match(
  source,
  /environmentAngelPass/,
  "Internet Angel verification must reject a present but unclassified Environment panel.",
);
assert.match(source, /composerClearOfSidebar/);
assert.match(source, /composerInsideViewport/);
assert.match(source, /environmentInsideViewport/);
assert.match(source, /data-angel-component/);
assert.match(
  source,
  /sidebarAngelPass/,
  "Internet Angel verification must reject visible native sidebar controls missed by classification.",
);
assert.match(source, /sidebar-new-task/);
assert.doesNotMatch(
  source,
  /sidebarCoverage\.length\s*>=\s*1/,
  "Settings and other alternate routes may legitimately omit thread sidebar controls.",
);
assert.match(
  source,
  /paletteAngelPass/,
  "An open composer Add palette must be classified and styled before verification passes.",
);
assert.match(source, /composer-palette-item/);
assert.match(
  source,
  /turnNavigationAngelPass/,
  "Visible turn-navigation and scroll controls must be classified for Internet Angel.",
);
assert.match(
  source,
  /const siblingCandidates = [\s\S]{0,260}const heroChain = \[\]/,
  "Home verification must tolerate Codex wrapper-depth changes.",
);
assert.match(source, /\?\.querySelector\(.*game-source.*\)\?\.parentElement/);
assert.match(
  source,
  /Math\.min\(options\.timeoutMs, 30000\)/,
  "Initial watcher verification must tolerate a slow cold renderer first paint.",
);

console.log("PASS: early injection is L0-ready, generation-safe, and removed on shutdown.");

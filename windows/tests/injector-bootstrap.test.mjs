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
  const markers = {
    shell: false,
    sidebar: false,
    header: false,
    composer: false,
    main: false,
    settings: false,
  };
  let root = {};
  let body = {};
  const context = {
    window: { installs: [] },
    location: { protocol: "app:" },
    document: {
      get documentElement() { return root; },
      get body() { return body; },
      addEventListener(type, callback) { if (type === "DOMContentLoaded") domReady.push(callback); },
      querySelector(selector) {
        if (selector === "main.main-surface") return markers.shell ? {} : null;
        if (selector === "header.app-header-tint") return markers.header ? {} : null;
        if (selector === "aside.app-shell-left-panel") return markers.sidebar ? {} : null;
        if (selector === ".composer-surface-chrome") return markers.composer ? {} : null;
        if (selector.includes("[role=\"main\"]")) return markers.main ? {} : null;
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
    makeNotReady() { root = null; body = null; },
    makeReady() { root = {}; body = {}; },
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
assert.deepEqual(guarded.context.window.installs, [], "A bare shell is not sufficient for identity.");
guarded.markers.header = true;
guarded.tick();
assert.deepEqual(guarded.context.window.installs, [], "A header without a composer or sidebar is not sufficient.");
guarded.markers.composer = true;
guarded.tick();
assert.deepEqual(guarded.context.window.installs, ["guarded"],
  "A verified shell and composer must support the collapsed-sidebar renderer.");

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
const registrationStart = source.indexOf("earlyScriptId = await registerEarlyPayload");
const evaluateStart = source.indexOf("await session.evaluate(earlyPayloadFor", registrationStart);
const probeStart = source.indexOf("const probe = await waitForCodexProbe", registrationStart);
assert.ok(registrationStart >= 0 && evaluateStart > registrationStart && probeStart > evaluateStart,
  "New targets must register and run the early payload before full shell probing.");
assert.match(source, /fallbackTargets\.set\(target\.id, earlyInjectionFallback\);\s*attachLoadFallback\(/,
  "Every verified renderer must retain a load-event reinjection safety net.");
assert.match(source, /if \(!fallbackTargets\.has\(id\) \|\| session\.closed\) return;/,
  "Load listeners must remain active while their renderer target is managed.");
assert.match(source, /const fallbackListeners = new Map\(\);[\s\S]*?fallbackListeners\.set\(id, unsubscribe\);/,
  "Watcher load fallbacks must retain one removable listener per renderer target.");
assert.match(source, /clearLoadFallbackTimer\(id\);[\s\S]*?fallbackTimers\.set\(id, timer\);/,
  "Repeated load events must coalesce to one pending fallback reinjection.");
const liveUpdateStart = source.indexOf("if (pauseChanged || payloadChanged)");
const pausedStart = source.indexOf("if (paused) {", liveUpdateStart);
const resumedStart = source.indexOf("} else {", pausedStart);
assert.ok(liveUpdateStart >= 0 && pausedStart > liveUpdateStart && resumedStart > pausedStart);
const pausedBlock = source.slice(pausedStart, resumedStart);
assert.doesNotMatch(pausedBlock, /detachLoadFallback|fallbackListeners\.delete/,
  "Pausing a live renderer must not forget its still-attached load listener and duplicate it after resume.");
assert.match(pausedBlock, /clearLoadFallbackTimer\(id\)/,
  "Pausing must cancel a queued fallback reinjection before removing the active skin.");
assert.match(source, /process\.off\("SIGINT", stop\);\s*process\.off\("SIGTERM", stop\);/,
  "Watcher shutdown must release process signal listeners.");
assert.match(source, /Page\.removeScriptToEvaluateOnNewDocument/,
  "Watcher shutdown and theme refresh must unregister persistent Page scripts.");
assert.match(source, /markers\.shell && \(markers\.sidebar \|\| \(markers\.header && markers\.composer\)\)/,
  "Collapsed-sidebar renderers must require the native header and composer identity anchors.");
assert.match(source, /Boolean\(result\.sidebar\) \|\| Boolean\(result\.header\)/,
  "Post-install verification must accept a collapsed sidebar when the native header remains present.");
assert.match(source, /result\.stylePresent && structurePass && payloadPass/,
  "Post-install verification must retain upstream staged theme and payload revision checks.");

console.log("PASS: Windows early injection is selector-guarded, generation-safe, revision-verified, and reload-resilient.");

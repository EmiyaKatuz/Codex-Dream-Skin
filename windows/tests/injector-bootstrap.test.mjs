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
  const observers = [];
  const timers = new Map();
  let nextTimer = 1;
  const markers = { shell: false, header: false, sidebar: false };
  const context = {
    window: { installs: [] },
    document: {
      documentElement: {},
      body: {},
      querySelector(selector) {
        if (selector === "main.main-surface") return markers.shell ? {} : null;
        if (selector === "main.main-surface > header.app-header-tint") return markers.header ? {} : null;
        if (selector === "aside.app-shell-left-panel") return markers.sidebar ? {} : null;
        return null;
      },
    },
    MutationObserver: class {
      constructor(callback) {
        this.callback = callback;
        this.connected = true;
        observers.push(this);
      }
      observe() {}
      disconnect() { this.connected = false; }
    },
    setTimeout(callback) {
      const id = nextTimer++;
      timers.set(id, callback);
      return id;
    },
    clearTimeout(id) { timers.delete(id); },
  };
  return { context, markers, observers };
}

const guarded = createFixture();
vm.runInNewContext(earlyPayloadFor('window.installs.push("guarded")', "guarded"), guarded.context);
assert.deepEqual(guarded.context.window.installs, [], "Auxiliary app targets must remain untouched.");
guarded.markers.shell = true;
guarded.observers[0].callback([]);
assert.deepEqual(guarded.context.window.installs, [], "A main surface without the native app header is not sufficient.");
guarded.markers.header = true;
guarded.observers[0].callback([]);
assert.deepEqual(guarded.context.window.installs, ["guarded"], "The guarded payload should support the verified shell while its sidebar is collapsed.");

const generations = createFixture();
vm.runInNewContext(earlyPayloadFor('window.installs.push("old")', "old"), generations.context);
vm.runInNewContext(earlyPayloadFor('window.installs.push("new")', "new"), generations.context);
generations.markers.shell = true;
generations.markers.header = true;
for (const observer of generations.observers) observer.callback([]);
assert.deepEqual(
  generations.context.window.installs,
  ["new"],
  "A stale early script must yield to the newest watcher generation.",
);
assert.equal(generations.context.window.__CODEX_DREAM_SKIN_EARLY_APPLIED__, "new");

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
assert.match(source, /markers\.shell && markers\.header && \(markers\.composer \|\| markers\.main\)/,
  "Collapsed-sidebar renderers must remain valid only when the native header identifies the main app shell.");
assert.match(source, /Boolean\(result\.composer\) && Boolean\(result\.header\)/,
  "Post-install verification must not reject a renderer solely because its left sidebar is collapsed.");
assert.doesNotMatch(source, /markers\.shell && markers\.sidebar|Boolean\(result\.composer\) && Boolean\(result\.sidebar\)/,
  "Sidebar presence must remain diagnostic-only throughout renderer detection and verification.");

console.log("PASS: Windows early injection is shell-guarded, generation-safe, ordered before probing, and reload-resilient.");

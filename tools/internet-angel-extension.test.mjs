import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

import {
  loadPayload as loadWindowsPayload,
  usesInternetAngelExtension as usesWindowsExtension,
} from "../windows/scripts/injector.mjs";
import {
  loadPayload as loadMacosPayload,
  usesInternetAngelExtension as usesMacosExtension,
} from "../macos/scripts/injector.mjs";
import {
  loadPayload as loadLinuxPayload,
  usesInternetAngelExtension as usesLinuxExtension,
} from "../linux/scripts/injector.mjs";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourceCss = await fs.readFile(
  path.join(projectRoot, "runtime", "internet-angel-extension.css"),
  "utf8",
);
const sourceScript = await fs.readFile(
  path.join(projectRoot, "runtime", "internet-angel-extension.js"),
  "utf8",
);
const gitAttributes = await fs.readFile(path.join(projectRoot, ".gitattributes"), "utf8");

function extractRendererCss(payload) {
  const marker = "((cssText, artDataUrl,";
  const overlayBoundary = payload.lastIndexOf(";\n(() => {");
  assert.notEqual(overlayBoundary, -1, "payload must include the Internet Angel extension boundary");
  const rendererPayload = payload.slice(0, overlayBoundary);
  const at = rendererPayload.indexOf(marker);
  assert.notEqual(at, -1, "payload must keep the canonical renderer IIFE signature");
  const bodyAt = rendererPayload.indexOf("=> {", at);
  assert.notEqual(bodyAt, -1, "renderer IIFE must keep a block body");
  const bodyStart = bodyAt + "=> {".length;
  const probe = `${rendererPayload.slice(0, bodyStart)}\nreturn cssText;\n${rendererPayload.slice(bodyStart)}`;
  return vm.runInNewContext(probe, Object.create(null), { timeout: 10_000 });
}

assert.match(sourceCss, /data-angel-component/);
assert.match(sourceCss, /prefers-reduced-motion:\s*reduce/);
assert.match(sourceScript, /__INTERNET_ANGEL_EXTENSION_ENABLED_JSON__/);
assert.match(sourceScript, /__CODEX_INTERNET_ANGEL_EXTENSION_STATE__/);
assert.doesNotMatch(
  sourceScript,
  /addListener\(window,\s*["']transitionend["']/,
  "visual transitions must not trigger a full-document reclassification",
);
assert.doesNotMatch(
  sourceScript,
  /const classify = \(\) => \{\s*clearMarks\(\);/,
  "classification must reconcile markers instead of clearing and rebuilding them",
);
assert.match(
  sourceScript,
  /node\.getAttribute\?\.\(componentAttribute\) !== component/,
  "classification must avoid unchanged marker writes",
);
assert.match(sourceScript, /compositionstart/);
assert.match(sourceScript, /compositionend/);

for (const platform of ["windows", "macos", "linux"]) {
  assert.match(
    gitAttributes,
    new RegExp(`^${platform}/assets/\\*\\* text eol=lf$`, "m"),
    `${platform} generated assets must stay LF on every checkout`,
  );
  assert.equal(
    await fs.readFile(
      path.join(projectRoot, platform, "assets", "internet-angel-extension.css"),
      "utf8",
    ),
    sourceCss,
    `${platform} CSS must be generated from the shared extension source`,
  );
  assert.equal(
    await fs.readFile(
      path.join(projectRoot, platform, "assets", "internet-angel-extension.js"),
      "utf8",
    ),
    sourceScript,
    `${platform} classifier must be generated from the shared extension source`,
  );
}

for (const platform of ["windows", "linux"]) {
  const [renderer, platformCss] = await Promise.all([
    fs.readFile(path.join(projectRoot, platform, "assets", "renderer-inject.js"), "utf8"),
    fs.readFile(path.join(projectRoot, platform, "assets", "dream-skin.css"), "utf8"),
  ]);
  assert.match(renderer, /"preset-internet-angel"[\s\S]{0,120}"preset-internet-angel-default"/,
    `${platform} renderer must use the same exact bundled theme IDs as its injector`);
  assert.match(renderer, /setAttribute\("data-dream-theme", isInternetAngelTheme \? "internet-angel" : "standard"\)/,
    `${platform} renderer must satisfy the shared extension CSS theme gate`);
  assert.match(renderer, /removeAttribute\("data-dream-theme"\)/,
    `${platform} renderer cleanup must remove the shared extension CSS theme gate`);
  const sidebarParents = ':is(aside.app-shell-left-panel, [data-testid="app-shell-floating-left-panel"])';
  for (const suffix of [
    "nav",
    "button",
    "button:hover",
    ':is(.dream-new-task-button, [data-angel-component="sidebar-new-task"])',
    'button[class~="group/section-toggle"]',
    '[role="list"] > [role="listitem"]',
  ]) {
    assert.ok(
      platformCss.includes(`html.codex-dream-skin ${sidebarParents} ${suffix}`),
      `${platform} must share its existing fixed-sidebar ${suffix} presentation with the floating sidebar`,
    );
  }
  assert.doesNotMatch(
    platformCss,
    /html\.codex-dream-skin aside\.app-shell-left-panel (?:nav|button|svg|\[class|\[role)/,
    `${platform} must not leave visual descendant rules scoped only to the fixed sidebar`,
  );
}

for (const predicate of [usesWindowsExtension, usesMacosExtension, usesLinuxExtension]) {
  assert.equal(predicate({ id: "preset-internet-angel" }), true);
  assert.equal(predicate({ id: "preset-internet-angel-default" }), true);
  assert.equal(predicate({ id: "custom-internet-angel-copy" }), false);
}

for (const [platform, loadPayload] of [
  ["windows", loadWindowsPayload],
  ["macos", loadMacosPayload],
  ["linux", loadLinuxPayload],
]) {
  const loaded = await loadPayload(
    path.join(projectRoot, "macos", "presets", "preset-internet-angel"),
  );
  assert.equal(loaded.internetAngelExtension, true, `${platform} must enable the shared extension`);
  assert.ok(
    extractRendererCss(loaded.payload).includes(sourceCss),
    `${platform} must pass the shared extension CSS to the renderer style IIFE`,
  );
  assert.match(loaded.payload, /__CODEX_INTERNET_ANGEL_EXTENSION_STATE__/);
  assert.doesNotMatch(loaded.payload, /__INTERNET_ANGEL_EXTENSION_ENABLED_JSON__/);
}

const windowsPreset = path.join(
  projectRoot,
  "macos",
  "presets",
  "preset-internet-angel",
);
const windowsSystem = await loadWindowsPayload(windowsPreset, null, "system");
assert.equal(
  windowsSystem.internetAngelClassifier,
  true,
  "Windows System material must retain the legacy classifier for its extension CSS",
);
assert.match(windowsSystem.payload, /const enabled = true;/);

const windowsAcrylic = await loadWindowsPayload(windowsPreset, null, "acrylic");
assert.equal(windowsAcrylic.internetAngelExtension, true);
assert.equal(
  windowsAcrylic.internetAngelClassifier,
  false,
  "Windows Acrylic must use durable renderer classes without rescanning the full document",
);
assert.equal(windowsAcrylic.acrylicOverlay, true);
assert.match(windowsAcrylic.payload, /const enabled = false;/);
const acrylicCss = await fs.readFile(
  path.join(projectRoot, "windows", "assets", "internet-angel-acrylic.css"),
  "utf8",
);
assert.doesNotMatch(
  acrylicCss,
  /data-angel-component/,
  "Acrylic must not depend on markers from the disabled legacy classifier",
);
for (const durableClass of [
  "dream-settings-sidebar",
  "composer-surface-chrome",
  "dream-composer-context-strip",
  "dream-side-workspace",
  "dream-terminal-panel",
]) {
  assert.match(
    acrylicCss,
    new RegExp(`\\.${durableClass}(?:[\\s,):]|$)`),
    `Acrylic must consume the renderer's durable .${durableClass} class`,
  );
}
assert.match(
  acrylicCss,
  /:not\(#codex-dream-skin-web-blur\)\s+:is\([^)]*\[data-composer-surface-variant\][^)]*\)\s*\{[^}]*backdrop-filter:\s*none\s*!important/s,
  "Acrylic must disable Chromium blur on a modern-only Codex 26.730 composer.",
);
assert.match(
  acrylicCss,
  /:is\(\s*\[data-composer-footer-responsive\],[^)]*\)\s*\{[^}]*background:\s*transparent\s*!important[^}]*backdrop-filter:\s*none\s*!important/s,
  "Acrylic must keep the responsive composer footer transparent and free of nested blur.",
);

console.log("PASS: Internet Angel overlays and animations share one three-platform runtime.");

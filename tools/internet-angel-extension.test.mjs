import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

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

assert.match(sourceCss, /data-angel-component/);
assert.match(sourceCss, /prefers-reduced-motion:\s*reduce/);
assert.match(sourceScript, /__INTERNET_ANGEL_EXTENSION_ENABLED_JSON__/);
assert.match(sourceScript, /__CODEX_INTERNET_ANGEL_EXTENSION_STATE__/);

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
  const renderer = await fs.readFile(
    path.join(projectRoot, platform, "assets", "renderer-inject.js"),
    "utf8",
  );
  assert.match(renderer, /"preset-internet-angel"[\s\S]{0,120}"preset-internet-angel-default"/,
    `${platform} renderer must use the same exact bundled theme IDs as its injector`);
  assert.match(renderer, /setAttribute\("data-dream-theme", isInternetAngelTheme \? "internet-angel" : "standard"\)/,
    `${platform} renderer must satisfy the shared extension CSS theme gate`);
  assert.match(renderer, /removeAttribute\("data-dream-theme"\)/,
    `${platform} renderer cleanup must remove the shared extension CSS theme gate`);
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
  assert.match(loaded.payload, /__CODEX_INTERNET_ANGEL_EXTENSION_STATE__/);
  assert.doesNotMatch(loaded.payload, /__INTERNET_ANGEL_EXTENSION_ENABLED_JSON__/);
}

console.log("PASS: Internet Angel overlays and animations share one three-platform runtime.");

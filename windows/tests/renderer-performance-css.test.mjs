import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const css = fs.readFileSync(path.join(testDirectory, "../assets/dream-skin.css"), "utf8");
const marker = "/* Persistent compositor surfaces:";
const start = css.indexOf(marker);

assert.notEqual(start, -1, "persistent compositor performance guard is missing");
const guard = css.slice(start);
for (const selector of [
  "#codex-dream-skin-chrome *",
  "aside.app-shell-left-panel",
  "main.main-surface > header.app-header-tint",
  ".composer-surface-chrome",
  ".dream-task::after",
]) {
  assert.ok(guard.includes(selector), `${selector} must stay out of persistent backdrop compositing`);
}
assert.match(guard, /backdrop-filter:\s*none\s*!important/);
assert.doesNotMatch(guard, /\[role=["'](?:dialog|menu|listbox)["']\]/,
  "short-lived overlay blur must remain outside the persistent-surface override");

console.log("PASS: persistent renderer surfaces avoid full-window backdrop compositing.");

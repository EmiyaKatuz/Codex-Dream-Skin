import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { loadPayload } from "../scripts/injector.mjs";

const testsRoot = path.dirname(fileURLToPath(import.meta.url));
const assetsRoot = path.resolve(testsRoot, "../assets");

test("theme text containing replacement tokens is inserted literally", async () => {
  const temporaryRoot = await fs.mkdtemp(path.join(os.tmpdir(), "dream-skin-payload-"));
  try {
    const sourceTheme = JSON.parse(await fs.readFile(path.join(assetsRoot, "theme.json"), "utf8"));
    await fs.copyFile(
      path.join(assetsRoot, sourceTheme.image),
      path.join(temporaryRoot, sourceTheme.image),
    );

    for (const name of ["Dollar $$", "Whole match $&", "Prefix $`", "Suffix $'"]) {
      await fs.writeFile(
        path.join(temporaryRoot, "theme.json"),
        `${JSON.stringify({ ...sourceTheme, name }, null, 2)}\n`,
        "utf8",
      );
      const loaded = await loadPayload(temporaryRoot);
      assert.doesNotMatch(loaded.payload, /__DREAM(?:_SKIN)?_[A-Z0-9_]+_JSON__/);
      assert.doesNotThrow(() => new Function(loaded.payload));
      assert.ok(
        loaded.payload.includes(`"name":${JSON.stringify(name)}`),
        `payload must preserve ${JSON.stringify(name)} exactly`,
      );
    }
  } finally {
    await fs.rm(temporaryRoot, { recursive: true, force: true });
  }
});

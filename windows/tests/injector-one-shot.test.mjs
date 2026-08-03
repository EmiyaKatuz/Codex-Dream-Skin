import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const injectorPath = path.resolve(here, "../scripts/injector.mjs");
let versionRequests = 0;
let port = 0;

const server = http.createServer((request, response) => {
  response.setHeader("content-type", "application/json");
  if (request.url === "/json/list") {
    response.end("[]");
    return;
  }
  if (request.url === "/json/version") {
    versionRequests += 1;
    response.end(JSON.stringify({
      webSocketDebuggerUrl: `ws://127.0.0.1:${port}/devtools/browser/test-browser`,
    }));
    return;
  }
  response.statusCode = 404;
  response.end("{}");
});

await new Promise((resolve, reject) => {
  server.once("error", reject);
  server.listen(0, "127.0.0.1", resolve);
});
port = server.address().port;

const runMode = (mode, extraArgs = []) => new Promise((resolve, reject) => {
  const child = spawn(process.execPath, [
    injectorPath,
    mode,
    "--port", String(port),
    "--browser-id", "test-browser",
    "--timeout-ms", "250",
    ...extraArgs,
  ], { stdio: ["ignore", "pipe", "pipe"] });
  let stdout = "";
  let stderr = "";
  child.stdout.setEncoding("utf8");
  child.stderr.setEncoding("utf8");
  child.stdout.on("data", (chunk) => { stdout += chunk; });
  child.stderr.on("data", (chunk) => { stderr += chunk; });
  child.once("error", reject);
  child.once("close", (code) => resolve({ code, stdout, stderr }));
});

try {
  for (const mode of ["--verify", "--once", "--remove"]) {
    const requestsBefore = versionRequests;
    const result = await runMode(mode);
    assert.notEqual(result.code, 0, `${mode} should time out because the fixture exposes no page targets.`);
    assert.ok(versionRequests > requestsBefore,
      `${mode} must pass its expected Browser ID into one-shot target discovery.`);
    assert.doesNotMatch(`${result.stdout}\n${result.stderr}`, /options is not defined/,
      `${mode} must not reference a CLI options binding outside its lexical scope.`);
  }

  const missingEvidence = await runMode("--verify", ["--allow-hidden-document"]);
  assert.notEqual(missingEvidence.code, 0);
  assert.match(`${missingEvidence.stdout}\n${missingEvidence.stderr}`,
    /--allow-hidden-document requires complete Win32 window evidence/);

  const requestsBeforeHiddenVerify = versionRequests;
  const hiddenVerify = await runMode("--verify", [
    "--allow-hidden-document",
    "--win32-window-pid", "4120",
    "--win32-window-hwnd", "918273645",
    "--win32-window-width", "1280",
    "--win32-window-height", "800",
  ]);
  assert.notEqual(hiddenVerify.code, 0,
    "The complete hidden-document verify fixture still has no page target.");
  assert.ok(versionRequests > requestsBeforeHiddenVerify,
    "Complete Win32 evidence must pass argument validation and reach target discovery.");

  const wrongMode = await runMode("--once", [
    "--allow-hidden-document",
    "--win32-window-pid", "4120",
    "--win32-window-hwnd", "918273645",
    "--win32-window-width", "1280",
    "--win32-window-height", "800",
  ]);
  assert.notEqual(wrongMode.code, 0);
  assert.match(`${wrongMode.stdout}\n${wrongMode.stderr}`,
    /--allow-hidden-document is only valid in verify mode/);
} finally {
  await new Promise((resolve) => server.close(resolve));
}

console.log("PASS: Windows verify, once, and remove pass Browser ID explicitly into one-shot discovery.");

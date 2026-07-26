import assert from "node:assert/strict";
import fs from "node:fs/promises";

class MockWebSocket {
  static instances = [];

  constructor(url) {
    this.url = url;
    this.listeners = new Map();
    this.sent = [];
    this.closeCalls = 0;
    this.onSend = null;
    MockWebSocket.instances.push(this);
  }

  addEventListener(type, listener, options = {}) {
    const listeners = this.listeners.get(type) ?? [];
    listeners.push({ listener, once: Boolean(options?.once) });
    this.listeners.set(type, listeners);
  }

  removeEventListener(type, listener) {
    const listeners = this.listeners.get(type) ?? [];
    const next = listeners.filter((entry) => entry.listener !== listener);
    if (next.length) this.listeners.set(type, next);
    else this.listeners.delete(type);
  }

  emit(type, event = {}) {
    for (const entry of [...(this.listeners.get(type) ?? [])]) {
      if (entry.once) this.removeEventListener(type, entry.listener);
      entry.listener(event);
    }
  }

  send(payload) {
    const message = JSON.parse(payload);
    this.sent.push(message);
    this.onSend?.(message);
  }

  close() {
    this.closeCalls += 1;
    this.emit("close");
  }
}

const originalWebSocket = globalThis.WebSocket;
const originalFetch = globalThis.fetch;
globalThis.WebSocket = MockWebSocket;

try {
  const { connectBrowserDiscovery } = await import("../scripts/injector.mjs");
  const port = 9335;
  globalThis.fetch = async (url) => {
    assert.equal(String(url), `http://127.0.0.1:${port}/json/version`);
    return {
      ok: true,
      async json() {
        return {
          webSocketDebuggerUrl: `ws://127.0.0.1:${port}/devtools/browser/browser-test`,
        };
      },
    };
  };

  const targetChanges = [];
  const connecting = connectBrowserDiscovery(port, (targetInfo) => targetChanges.push(targetInfo));
  for (let attempt = 0; attempt < 5 && MockWebSocket.instances.length < 1; attempt += 1) {
    await Promise.resolve();
  }
  const browserSocket = MockWebSocket.instances.at(-1);
  browserSocket.onSend = (message) => {
    queueMicrotask(() => browserSocket.emit("message", {
      data: JSON.stringify({ id: message.id, result: {} }),
    }));
  };
  browserSocket.emit("open");
  const browserSession = await connecting;

  assert.deepEqual(
    browserSocket.sent.map(({ method }) => method),
    ["Target.setDiscoverTargets"],
    "Browser discovery must not enable renderer-only Runtime or Page domains.",
  );
  assert.deepEqual(browserSocket.sent[0].params, { discover: true });

  const pageTarget = { targetId: "page-new", type: "page", url: "app://codex" };
  browserSocket.emit("message", {
    data: JSON.stringify({ method: "Target.targetCreated", params: { targetInfo: pageTarget } }),
  });
  const updatedPageTarget = { ...pageTarget, title: "Codex" };
  browserSocket.emit("message", {
    data: JSON.stringify({ method: "Target.targetInfoChanged", params: { targetInfo: updatedPageTarget } }),
  });
  browserSocket.emit("message", {
    data: JSON.stringify({ method: "Target.targetDestroyed", params: { targetId: pageTarget.targetId } }),
  });
  assert.deepEqual(targetChanges, [pageTarget, updatedPageTarget, null],
    "Page target lifecycle events must wake target discovery immediately.");

  browserSession.close();
  assert.equal(browserSession.listeners.size, 0,
    "Browser discovery cleanup must release target event listeners.");
  assert.equal(browserSocket.closeCalls, 1,
    "Browser discovery cleanup must close its WebSocket exactly once.");

  const socketCountBeforeRejection = MockWebSocket.instances.length;
  const rejectedConnecting = connectBrowserDiscovery(port, () => {});
  for (let attempt = 0;
    attempt < 5 && MockWebSocket.instances.length === socketCountBeforeRejection;
    attempt += 1) await Promise.resolve();
  const rejectedSocket = MockWebSocket.instances.at(-1);
  rejectedSocket.onSend = (message) => {
    queueMicrotask(() => rejectedSocket.emit("message", {
      data: JSON.stringify({
        id: message.id,
        error: { code: -32601, message: "Method not found" },
      }),
    }));
  };
  rejectedSocket.emit("open");
  await assert.rejects(rejectedConnecting, /Method not found/);
  assert.equal(rejectedSocket.closeCalls, 1,
    "Rejected target discovery must close its browser session before polling resumes.");

  const source = await fs.readFile(new URL("../scripts/injector.mjs", import.meta.url), "utf8");
  assert.match(source, /const pollDelay = sessions\.size \? 800 : \(targets\.length \? 250 : 100\);\s*await waitForDiscovery\(pollDelay\)/,
    "macOS must retain its existing adaptive polling fallback.");
  assert.match(source, /for \(const record of sessions\.values\(\)\) record\.session\.close\(\);\s*browserDiscovery\?\.close\(\)/,
    "Watcher shutdown must close renderer and browser discovery sessions.");
  assert.match(source, /CDP target events unavailable; polling fallback active/,
    "Rejected target discovery must preserve and report the polling fallback.");
} finally {
  globalThis.WebSocket = originalWebSocket;
  globalThis.fetch = originalFetch;
}

console.log("PASS: macOS browser target discovery is event-driven, domain-safe, and cleanly released.");

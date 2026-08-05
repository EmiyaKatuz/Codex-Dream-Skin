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
  const {
    CdpSession,
    connectBrowserIdentityAnchor,
    connectBrowserIdentityAnchorWithRetry,
  } = await import("../scripts/injector.mjs");
  const port = 9335;
  const target = {
    id: "page-test",
    webSocketDebuggerUrl: `ws://127.0.0.1:${port}/devtools/page/page-test`,
  };

  const failedSession = new CdpSession(target, port);
  failedSession.ws.onSend = (message) => {
    queueMicrotask(() => failedSession.ws.emit("message", {
      data: JSON.stringify({
        id: message.id,
        error: { code: -32000, message: "Runtime unavailable" },
      }),
    }));
  };
  const failedOpen = failedSession.open();
  failedSession.ws.emit("open");
  await assert.rejects(failedOpen, /Runtime unavailable/);
  assert.equal(failedSession.closed, true,
    "A CDP domain-enable failure must close the half-open session.");
  assert.equal(failedSession.ws.closeCalls, 1,
    "A failed open must release its WebSocket exactly once.");
  assert.equal(failedSession.pending.size, 0,
    "A failed open must reject and clear every pending CDP command.");

  const listenerSession = new CdpSession(target, port);
  let healthyListenerCalls = 0;
  let removedListenerCalls = 0;
  const errors = [];
  const originalConsoleError = console.error;
  console.error = (message) => { errors.push(String(message)); };
  try {
    listenerSession.on("Page.loadEventFired", () => { throw new Error("sync listener failure"); });
    listenerSession.on("Page.loadEventFired", async () => { throw new Error("async listener failure"); });
    listenerSession.on("Page.loadEventFired", () => { healthyListenerCalls += 1; });
    const removeListener = listenerSession.on("Page.loadEventFired", () => { removedListenerCalls += 1; });
    removeListener();
    assert.doesNotThrow(() => listenerSession.onMessage({
      data: JSON.stringify({ method: "Page.loadEventFired", params: {} }),
    }));
    await Promise.resolve();
  } finally {
    console.error = originalConsoleError;
  }
  assert.equal(healthyListenerCalls, 1,
    "One broken CDP event consumer must not prevent later listeners from running.");
  assert.equal(removedListenerCalls, 0,
    "Unsubscribed CDP listeners must not run.");
  assert.equal(errors.length, 2,
    "Synchronous and asynchronous listener failures must be contained and reported.");

  let forwardedTimeout = null;
  listenerSession.send = async (_method, _params, timeoutMs) => {
    forwardedTimeout = timeoutMs;
    return { result: { value: true } };
  };
  assert.equal(await listenerSession.evaluate("true", 275), true);
  assert.equal(forwardedTimeout, 275,
    "Operation UI and probe timeouts must reach the underlying CDP command.");

  listenerSession.close();
  listenerSession.close();
  assert.equal(listenerSession.ws.closeCalls, 1,
    "Session cleanup must be idempotent.");
  assert.equal(listenerSession.listeners.size, 0,
    "Session cleanup must release listener closures.");

  const browserId = "browser-test";
  globalThis.fetch = async (url) => {
    assert.equal(String(url), `http://127.0.0.1:${port}/json/version`);
    return {
      ok: true,
      async json() {
        return {
          webSocketDebuggerUrl: `ws://127.0.0.1:${port}/devtools/browser/${browserId}`,
        };
      },
    };
  };
  const targetChanges = [];
  const connecting = connectBrowserIdentityAnchor(
    port,
    browserId,
    (targetInfo) => targetChanges.push(targetInfo),
  );
  for (let attempt = 0; attempt < 5 && MockWebSocket.instances.length < 3; attempt += 1) {
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

  const avatarOverlayTarget = {
    targetId: "avatar-overlay",
    type: "page",
    url: "app://-/index.html?initialRoute=%2Favatar-overlay",
  };
  browserSocket.emit("message", {
    data: JSON.stringify({
      method: "Target.targetCreated",
      params: { targetInfo: avatarOverlayTarget },
    }),
  });
  assert.deepEqual(targetChanges, [],
    "The compact avatar overlay must not wake main Codex target discovery.");

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

  const socketCountBeforeFallback = MockWebSocket.instances.length;
  const fallbackErrors = [];
  const fallbackOriginalConsoleError = console.error;
  console.error = (message) => { fallbackErrors.push(String(message)); };
  try {
    const fallbackConnecting = connectBrowserIdentityAnchor(port, browserId, () => {});
    for (let attempt = 0;
      attempt < 5 && MockWebSocket.instances.length === socketCountBeforeFallback;
      attempt += 1) await Promise.resolve();
    const rejectedDiscoverySocket = MockWebSocket.instances.at(-1);
    rejectedDiscoverySocket.onSend = (message) => {
      queueMicrotask(() => rejectedDiscoverySocket.emit("message", {
        data: JSON.stringify({
          id: message.id,
          error: { code: -32601, message: "Method not found" },
        }),
      }));
    };
    rejectedDiscoverySocket.emit("open");
    for (let attempt = 0;
      attempt < 10 && MockWebSocket.instances.length < socketCountBeforeFallback + 2;
      attempt += 1) await Promise.resolve();
    const pollingAnchorSocket = MockWebSocket.instances.at(-1);
    assert.notEqual(pollingAnchorSocket, rejectedDiscoverySocket,
      "Rejected target discovery must create a plain browser identity anchor.");
    pollingAnchorSocket.emit("open");
    const pollingAnchor = await fallbackConnecting;
    assert.deepEqual(
      rejectedDiscoverySocket.sent.map(({ method }) => method),
      ["Target.setDiscoverTargets"],
    );
    assert.deepEqual(pollingAnchorSocket.sent, [],
      "The polling fallback anchor must not enable CDP domains or send commands.");
    assert.equal(fallbackErrors.some((message) => message.includes("polling fallback active")), true,
      "Target discovery rejection must report that polling remains active.");
    pollingAnchor.close();
  } finally {
    console.error = fallbackOriginalConsoleError;
  }

  let retryFetchAttempts = 0;
  globalThis.fetch = async (url) => {
    assert.equal(String(url), `http://127.0.0.1:${port}/json/version`);
    retryFetchAttempts += 1;
    if (retryFetchAttempts === 1) {
      throw new DOMException("transient CDP version stall", "AbortError");
    }
    return {
      ok: true,
      async json() {
        return {
          webSocketDebuggerUrl: `ws://127.0.0.1:${port}/devtools/browser/${browserId}`,
        };
      },
    };
  };
  const socketCountBeforeRetry = MockWebSocket.instances.length;
  const retryConnecting = connectBrowserIdentityAnchorWithRetry(
    port,
    browserId,
    () => {},
    { attempts: 2, delayMs: 0 },
  );
  for (let attempt = 0;
    attempt < 10 && MockWebSocket.instances.length === socketCountBeforeRetry;
    attempt += 1) await Promise.resolve();
  const retryAnchorSocket = MockWebSocket.instances.at(-1);
  assert.notEqual(retryAnchorSocket, MockWebSocket.instances[socketCountBeforeRetry - 1],
    "A transient version fetch failure must retry and create the pinned browser anchor.");
  retryAnchorSocket.onSend = (message) => {
    queueMicrotask(() => retryAnchorSocket.emit("message", {
      data: JSON.stringify({ id: message.id, result: {} }),
    }));
  };
  retryAnchorSocket.emit("open");
  const retryAnchor = await retryConnecting;
  assert.equal(retryFetchAttempts, 2,
    "The watcher anchor must retry a transient CDP version failure.");
  retryAnchor.close();

  let exhaustedFetchAttempts = 0;
  globalThis.fetch = async () => {
    exhaustedFetchAttempts += 1;
    throw new DOMException("CDP remains stalled", "AbortError");
  };
  const socketCountBeforeExhaustion = MockWebSocket.instances.length;
  await assert.rejects(
    connectBrowserIdentityAnchorWithRetry(
      port,
      browserId,
      () => {},
      { attempts: 3, delayMs: 0 },
    ),
    /CDP remains stalled/,
  );
  assert.equal(exhaustedFetchAttempts, 3,
    "The watcher anchor must stop after its bounded transient retry budget.");
  assert.equal(MockWebSocket.instances.length, socketCountBeforeExhaustion,
    "Exhausted version retries must not connect to or inject any page target.");

  let mismatchFetchAttempts = 0;
  globalThis.fetch = async () => {
    mismatchFetchAttempts += 1;
    if (mismatchFetchAttempts === 1) {
      throw new DOMException("first identity probe stalled", "AbortError");
    }
    return {
      ok: true,
      async json() {
        return {
          webSocketDebuggerUrl: `ws://127.0.0.1:${port}/devtools/browser/replaced-browser`,
        };
      },
    };
  };
  await assert.rejects(
    connectBrowserIdentityAnchorWithRetry(
      port,
      browserId,
      null,
      { attempts: 3, delayMs: 0 },
    ),
    /CDP browser identity changed/,
  );
  assert.equal(mismatchFetchAttempts, 2,
    "A browser identity mismatch after a transient retry must fail closed immediately.");

  const source = await fs.readFile(new URL("../scripts/injector.mjs", import.meta.url), "utf8");
  assert.match(source, /await waitForDiscovery\(1200\)/,
    "Windows must retain its previous 1200 ms polling fallback.");
  assert.match(source, /process\.off\("SIGTERM", stop\);\s*identityAnchor\.close\(\)/,
    "Watcher shutdown must close browser discovery and release process listeners.");
} finally {
  globalThis.WebSocket = originalWebSocket;
  globalThis.fetch = originalFetch;
}

console.log("PASS: Windows CDP sessions handle renderer commands and browser target discovery safely.");

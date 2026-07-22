import assert from "node:assert/strict";

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
globalThis.WebSocket = MockWebSocket;

try {
  const { CdpSession } = await import("../scripts/injector.mjs");
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
} finally {
  globalThis.WebSocket = originalWebSocket;
}

console.log("PASS: Windows CDP sessions close failed startups, isolate listeners, honor timeouts, and clean up idempotently.");

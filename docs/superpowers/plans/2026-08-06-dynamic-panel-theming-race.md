# 动态面板主题竞态修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Internet Angel 导航行在首次绘制时立即获得主题外观，在其他动态表面的结构证据挂载后最迟于下一动画帧完成分类，并让右侧工作区在分隔条拖动后保持主题标记，同时不因普通流式文本重新分类。

**Architecture:** 保持 `runtime/internet-angel-extension.js` 和 `.css` 为仅有的可编辑共享源。只为稳定的对话导航 DOM 增加结构 CSS 选择器；将多个浅层观察器替换为一个带过滤器的 `document.body` 子树观察器；相关 mutation、窗口缩放和输入法组合结束共用一个合并的动画帧刷新，同时保留 120 ms 交互兜底。右侧工作区优先使用非左栏 `aside` 的稳定结构归属，旧版非 `aside` DOM 继续使用现有几何条件。

**Tech Stack:** 浏览器 DOM API、限定作用域的 CSS、Node.js `vm` fixture、仓库运行时资源同步、macOS shell/Swift 回归、Windows 和 Linux payload 检查。

---

### 任务 1：增加对话导航结构 CSS 兜底

**文件：**
- 修改：`macos/tests/internet-angel-macos.test.mjs:24-313`
- 修改：`runtime/internet-angel-extension.css:526-564`
- 生成：`macos/assets/internet-angel-extension.css`
- 生成：`windows/assets/internet-angel-extension.css`
- 生成：`linux/assets/internet-angel-extension.css`

- [ ] **步骤 1：增加会失败的结构 CSS 断言**

  在 `macos/tests/internet-angel-macos.test.mjs` 的现有 CSS 断言旁增加以下 helper：

  ```js
  function assertCssRule(selectorFragments, declarationPattern, message) {
    const rules = overlayCss.match(/[^{}]+\{[^{}]*\}/g) || [];
    assert.ok(rules.some((rule) => {
      const boundary = rule.indexOf("{");
      const selector = rule.slice(0, boundary);
      const declarations = rule.slice(boundary + 1);
      return selectorFragments.every((fragment) => selector.includes(fragment))
        && declarationPattern.test(declarations);
    }), message);
  }

  assertCssRule(
    ['button[class*="navigation-row"]'],
    /background:\s*transparent\s*!important/,
    "Turn rows must have a first-paint structural fallback.",
  );
  assertCssRule(
    ['button[class*="navigation-row"]', '[class*="_marker_"]'],
    /width:\s*10px\s*!important/,
    "Turn markers must use the themed idle width before JavaScript classification.",
  );
  assertCssRule(
    ['button[class*="navigation-row"]', '[class*="_marker_"]', ":hover", ":focus-visible"],
    /width:\s*28px\s*!important/,
    "Structural turn markers must retain the themed hover and focus state.",
  );
  assertCssRule(
    ['button[class*="navigation-row"]', '[class*="_marker_"].opacity-60', '[aria-current="true"]'],
    /width:\s*18px\s*!important/,
    "Structural turn markers must retain both existing active-state signals.",
  );
  ```

  保留 `turn-nav-rail`、`turn-nav-row` 和 `turn-nav-marker` 的现有 `windowsToMacosParity` 断言；这些断言用于证明语义化 `data-angel-component` 选择器仍然存在。

- [ ] **步骤 2：运行聚焦测试并确认 RED**

  运行：

  ```bash
  node macos/tests/internet-angel-macos.test.mjs
  ```

  预期：第一个新增断言 `FAIL`，因为当前 CSS 只设置 `data-angel-component` 属性样式，没有 `button[class*="navigation-row"]` 兜底。

- [ ] **步骤 3：只扩展现有对话导航选择器**

  用以下内容替换 `runtime/internet-angel-extension.css` 中的对话导航规则块。所有声明保持不变，只为选择器增加结构替代项：

  ```css
  /* Turn rail, preview and footer action preserve native target geometry. */
  html[data-dream-skin="active"][data-dream-theme="internet-angel"] :is(
    [data-angel-component="turn-nav-rail"],
    :has(> button[class*="navigation-row"])
  ) {
    filter: drop-shadow(0 0 4px rgb(32 84 255 / .34));
  }

  html[data-dream-skin="active"][data-dream-theme="internet-angel"] :is(
    [data-angel-component="turn-nav-row"],
    button[class*="navigation-row"]
  ) {
    border-radius: 4px !important;
    background: transparent !important;
    box-shadow: none !important;
  }

  html[data-dream-skin="active"][data-dream-theme="internet-angel"] :is(
    [data-angel-component="turn-nav-marker"],
    [data-angel-component="turn-nav-marker-active"],
    button[class*="navigation-row"] [class*="_marker_"]
  ) {
    width: 10px !important;
    height: 2px !important;
    border-radius: 999px !important;
    background: linear-gradient(90deg, var(--angel-cyan), var(--angel-blue) 58%, var(--angel-violet)) !important;
    box-shadow: 0 0 5px rgb(99 244 255 / .38) !important;
    opacity: .68 !important;
    transition: width 110ms ease, opacity 110ms ease, filter 110ms ease !important;
  }

  html[data-dream-skin="active"][data-dream-theme="internet-angel"] :is(
    [data-angel-component="turn-nav-row"],
    button[class*="navigation-row"]
  ):is(:hover, :focus-visible) :is(
    [data-angel-component="turn-nav-marker"],
    [data-angel-component="turn-nav-marker-active"],
    [class*="_marker_"]
  ) {
    width: 28px !important;
    background: linear-gradient(90deg, var(--angel-cyan), var(--angel-pink)) !important;
    box-shadow: 0 0 7px rgb(255 69 200 / .52) !important;
    opacity: 1 !important;
  }

  html[data-dream-skin="active"][data-dream-theme="internet-angel"] :is(
    [data-angel-component="turn-nav-marker-active"],
    button[class*="navigation-row"] [class*="_marker_"].opacity-60,
    button[class*="navigation-row"] [class*="_marker_"][aria-current="true"]
  ) {
    width: 18px !important;
    background: linear-gradient(90deg, var(--angel-pink), var(--angel-violet) 46%, var(--angel-cyan)) !important;
    box-shadow: 0 0 7px rgb(255 69 200 / .56) !important;
    opacity: .95 !important;
  }
  ```

  不增加行级 `aria-current` 规则：当前分类器只把 marker 的 `.opacity-60` 或 marker 的 `aria-current="true"` 视为激活态，因此 CSS 兜底必须保留这一精确合同。

- [ ] **步骤 4：同步 CSS 并确认 GREEN**

  运行：

  ```bash
  node tools/sync-runtime-assets.mjs
  node macos/tests/internet-angel-macos.test.mjs
  node tools/internet-angel-extension.test.mjs
  node tools/sync-runtime-assets.mjs --check
  ```

  预期：两个测试都输出各自现有的 `PASS:` 行；同步检查以 `0` 退出且没有 `out-of-date=` 输出。

- [ ] **步骤 5：提交 CSS 兜底**

  ```bash
  git add runtime/internet-angel-extension.css \
    macos/assets/internet-angel-extension.css \
    windows/assets/internet-angel-extension.css \
    linux/assets/internet-angel-extension.css \
    macos/tests/internet-angel-macos.test.mjs
  git commit -m "fix: theme turn navigation on first paint"
  ```

### 任务 2：锁定过滤式深层观察行为

**文件：**
- 修改：`tools/internet-angel-extension.test.mjs:45-66`
- 修改：`macos/tests/internet-angel-macos.test.mjs:312-313`
- 修改：`macos/tests/internet-angel-macos.test.mjs:372-406`
- 修改：`macos/tests/internet-angel-macos.test.mjs:408-863`
- 修改：`macos/tests/internet-angel-macos.test.mjs:936-1027`

- [ ] **步骤 1：用过滤式观察护栏替换旧的无子树合同**

  删除 macOS 测试当前的 `assert.doesNotMatch(overlayScript, /subtree\\s*:\\s*true/)` 断言。在 `tools/internet-angel-extension.test.mjs` 的现有 composition 断言后增加以下共享源护栏：

  ```js
  assert.match(
    sourceScript,
    /const mutationHintSelector = \[/,
    "deep observation must be gated by an explicit structural hint list",
  );
  assert.match(sourceScript, /subtree\s*:\s*true/);
  assert.match(sourceScript, /new MutationObserver\(refreshAfterMutation\)/);
  assert.doesNotMatch(
    sourceScript,
    /new MutationObserver\(\s*scheduleRefresh\s*\)/,
    "subtree mutations must not directly schedule unfiltered full classification",
  );
  assert.doesNotMatch(sourceScript, /characterData\s*:\s*true/);
  assert.doesNotMatch(sourceScript, /attributes\s*:\s*true/);
  ```

- [ ] **步骤 2：为现有 fixture 增加元素和动画帧语义**

  在 `FixtureNode` 上方增加 registry 和 workspace 选择器常量，然后按以下内容更新该类，并保留现有方法与字段：

  ```js
  const registryKey = "__CODEX_INTERNET_ANGEL_EXTENSION_STATE__";
  const workspaceEvidenceSelector =
    '[role="tablist"], [role="tabpanel"], .xterm, .thread-scroll-container';

  class FixtureNode {
    constructor({ className = "", rect = {}, text = "", matchingSelectors = [] } = {}) {
      this.nodeType = 1;
      this.matchingSelectors = new Set(matchingSelectors);
      this.attributes = new Map();
      this.className = className;
      this.isConnected = true;
      this.parentElement = null;
      this.queries = new Map();
      this.closestNodes = new Map();
      this.rect = { left: 0, top: 0, width: 0, height: 0, ...rect };
      this.textContent = text;
    }

    addQuery(selector, nodes) {
      const values = Array.isArray(nodes) ? nodes : [nodes];
      this.queries.set(selector, values);
      for (const node of values) {
        if (!node.parentElement) node.parentElement = this;
      }
      return this;
    }

    getAttribute(name) { return this.attributes.get(name) ?? null; }
    setAttribute(name, value) { this.attributes.set(name, String(value)); }
    removeAttribute(name) { this.attributes.delete(name); }
    matches(selector) {
      return [...this.matchingSelectors].some((candidate) => selector.includes(candidate));
    }
    querySelector(selector) { return this.querySelectorAll(selector)[0] || null; }
    querySelectorAll(selector) {
      const exact = this.queries.get(selector);
      if (exact) return exact;
      return selector.split(",").flatMap((part) => this.queries.get(part.trim()) || []);
    }
    closest(selector) { return this.closestNodes.get(selector) || null; }
    getBoundingClientRect() {
      return {
        ...this.rect,
        right: this.rect.left + this.rect.width,
        bottom: this.rect.top + this.rect.height,
      };
    }
  }
  ```

  将 fixture 签名改为：

  ```js
  function makeOverlayFixture({
    modernComposer = false,
    deferWorkspaceEvidence = false,
  } = {}) {
  ```

- [ ] **步骤 3：增加延迟 workspace 证据且不放宽现有选择器 stub**

  用以下内容替换 workspace 证据设置：

  ```js
  const workspaceEvidence = makeNode({ matchingSelectors: ['[role="tabpanel"]'] });
  const workspaceMutationRoot = makeNode();
  workspaceMutationRoot.addQuery('[role="tabpanel"]', workspaceEvidence);
  if (!deferWorkspaceEvidence) {
    workspaceOuter.addQuery(workspaceEvidenceSelector, workspaceEvidence);
    workspace.addQuery(workspaceEvidenceSelector, workspaceEvidence);
  }
  workspace.parentElement = workspaceOuter;
  ```

  先把现有 `sidebarSelector` 声明移到构造器上方，再使用 `matchingSelectors: [sidebarSelector]` 构造 `sidebar` 和 `floatingSidebar`。这样现有浮动侧栏 mutation 回归在过滤后仍会命中。

  在当前 timer 队列旁增加可控的 frame 队列，并通过现有 `window` fixture 暴露：

  ```js
  let nextFrame = 0;
  const frames = new Map();
  const window = {
    navigation,
    addEventListener(type, callback) { listeners.set(type, callback); },
    removeEventListener(type) { listeners.delete(type); },
    requestAnimationFrame(callback) {
      const id = ++nextFrame;
      frames.set(id, callback);
      return id;
    },
    cancelAnimationFrame(id) { frames.delete(id); },
  };
  ```

  从 fixture 返回 `frames`、`notifyBodyMutation` 和以下 helper：

  ```js
  flushAnimationFrames() {
    const queued = [...frames.values()];
    frames.clear();
    for (const callback of queued) callback();
  },
  mountWorkspaceEvidence() {
    workspaceOuter.addQuery(workspaceEvidenceSelector, workspaceEvidence);
    workspace.addQuery(workspaceEvidenceSelector, workspaceEvidence);
    notifyBodyMutation({
      type: "childList",
      target: workspace,
      addedNodes: [workspaceMutationRoot],
      removedNodes: [],
    });
  },
  removeWorkspaceEvidence() {
    workspaceOuter.queries.delete(workspaceEvidenceSelector);
    workspace.queries.delete(workspaceEvidenceSelector);
    notifyBodyMutation({
      type: "childList",
      target: workspace,
      addedNodes: [],
      removedNodes: [workspaceMutationRoot],
    });
  },
  notifyBodyMutation,
  ```

- [ ] **步骤 4：增加启动覆盖层和模拟交互的精确 helper**

  在创建第一个 fixture 前立即增加以下 helper：

  ```js
  const runOverlay = (fixture, enabled = true) => vm.runInNewContext(
    overlayScript.replace(
      "__INTERNET_ANGEL_EXTENSION_ENABLED_JSON__",
      enabled ? "true" : "false",
    ),
    fixture.context,
  );
  const fireClick = (fixture) => fixture.listeners.get("click")({
    target: { closest: () => ({}) },
  });
  ```

  将测试中重复的 `vm.runInNewContext(...true...)` 调用替换为 `runOverlay(fixture)`，使后续 cleanup 用例使用同一入口。这只是局部测试 helper，不是运行时抽象。

- [ ] **步骤 5：增加延迟挂载、合并、过滤、timer、移除和输入法组合回归**

  在现有组件断言之后、cleanup 之前插入以下代码：

  ```js
  const delayed = makeOverlayFixture({ deferWorkspaceEvidence: true });
  runOverlay(delayed);
  const delayedState = delayed.window[registryKey];
  assert.equal(delayedState.metrics.classifyRuns, 1);
  assert.equal(component(delayed.workspace), null);

  fireClick(delayed);
  delayed.flushTimers();
  assert.equal(delayedState.metrics.classifyRuns, 2);
  assert.equal(component(delayed.workspace), null);

  delayed.mountWorkspaceEvidence();
  delayed.notifyBodyMutation({
    type: "childList",
    target: delayed.workspace,
    addedNodes: [delayed.workspaceEvidence],
    removedNodes: [],
  });
  assert.equal(delayed.frames.size, 1);
  assert.equal(component(delayed.workspace), null);
  delayed.flushAnimationFrames();
  assert.equal(component(delayed.workspace), "side-workspace");
  assert.equal(delayedState.metrics.classifyRuns, 3);

  const runsAfterMount = delayedState.metrics.classifyRuns;
  delayed.flushTimers();
  assert.equal(delayedState.metrics.classifyRuns, runsAfterMount);
  delayed.notifyBodyMutation({
    type: "childList",
    target: delayed.streamingActivity,
    addedNodes: [{ nodeType: 3, textContent: "token" }],
    removedNodes: [],
  });
  delayed.notifyBodyMutation({
    type: "childList",
    target: delayed.assistantMessage,
    addedNodes: [new FixtureNode({ className: "whitespace-pre-wrap" })],
    removedNodes: [],
  });
  assert.equal(delayed.frames.size, 0);
  assert.equal(delayed.timers.size, 0);
  assert.equal(delayedState.metrics.classifyRuns, runsAfterMount);

  delayed.removeWorkspaceEvidence();
  assert.equal(component(delayed.workspace), "side-workspace");
  assert.equal(delayed.frames.size, 1);
  delayed.flushAnimationFrames();
  assert.equal(component(delayed.workspace), null);
  assert.equal(delayedState.metrics.classifyRuns, runsAfterMount + 1);

  const fast = makeOverlayFixture({ deferWorkspaceEvidence: true });
  runOverlay(fast);
  fireClick(fast);
  assert.equal(fast.timers.size, 1);
  fast.mountWorkspaceEvidence();
  assert.equal(fast.timers.size, 0);
  assert.equal(fast.frames.size, 1);
  fast.flushAnimationFrames();
  const fastRuns = fast.window[registryKey].metrics.classifyRuns;
  fast.flushTimers();
  assert.equal(fast.window[registryKey].metrics.classifyRuns, fastRuns);

  const composition = makeOverlayFixture({ deferWorkspaceEvidence: true });
  runOverlay(composition);
  composition.listeners.get("compositionstart")();
  composition.mountWorkspaceEvidence();
  assert.equal(composition.frames.size, 0);
  assert.equal(component(composition.workspace), null);
  composition.listeners.get("compositionend")();
  assert.equal(composition.timers.size, 0);
  assert.equal(composition.frames.size, 1);
  composition.flushAnimationFrames();
  assert.equal(component(composition.workspace), "side-workspace");
  ```

  从 fixture 返回 `workspaceEvidence`，使第二条相关记录可用。第二次通知发生在 frame flush 之前，用于证明多条相关记录仍然只生成一个 frame，并且 `classifyRuns` 只增加一次。

- [ ] **步骤 6：按新调度合同更新现有侧栏和观察器断言**

  在两条浮动侧栏挂载路径的相关 mutation 后调用 `flushAnimationFrames()`，替代 `flushTimers()`。用以下内容替换旧的观察器数量断言：

  ```js
  assert.equal(fixture.observers.length, 1);
  assert.equal(fixture.observers[0].target, fixture.context.document.body);
  assert.equal(fixture.observers[0].options?.childList, true);
  assert.equal(fixture.observers[0].options?.subtree, true);
  assert.equal(fixture.observers[0].options?.characterData, undefined);
  assert.equal(fixture.observers[0].options?.attributes, undefined);
  ```

  保留现有 `transitionend === false` 断言。它仍是必需的性能边界。

- [ ] **步骤 7：扩展两种待执行机制的 cleanup 覆盖**

  禁用主 fixture 前先安排 resize frame，并断言 cleanup 会移除它：

  ```js
  fixture.listeners.get("resize")();
  assert.equal(fixture.frames.size, 1);
  runOverlay(fixture, false);
  assert.equal(fixture.frames.size, 0);
  ```

  由于 frame 调度器会有意取代 timeout，增加独立的待执行 timeout fixture：

  ```js
  const pendingTimeout = makeOverlayFixture();
  runOverlay(pendingTimeout);
  fireClick(pendingTimeout);
  assert.equal(pendingTimeout.timers.size, 1);
  runOverlay(pendingTimeout, false);
  assert.equal(pendingTimeout.timers.size, 0);
  assert.ok(pendingTimeout.observers.every((observer) => observer.disconnected === true));
  ```

  保留现有断言，继续验证 marks、observers、listeners 和 registry 状态均被移除。

- [ ] **步骤 8：运行两个聚焦测试并确认 RED**

  运行：

  ```bash
  node tools/internet-angel-extension.test.mjs
  node macos/tests/internet-angel-macos.test.mjs
  ```

  预期：共享测试因不存在 `mutationHintSelector` 和 `subtree: true` 而失败；单独运行 macOS 测试时，当前运行时会因安装多个浅层 observers、安排 120 ms timeout 而不是一个过滤后的动画帧而失败。

### 任务 3：实现一个过滤式深层观察器和一个 frame 刷新槽

**文件：**
- 修改：`runtime/internet-angel-extension.js:5-23`
- 修改：`runtime/internet-angel-extension.js:36-44`
- 修改：`runtime/internet-angel-extension.js:584-648`
- 修改：`runtime/internet-angel-extension.js:656-683`
- 生成：`macos/assets/internet-angel-extension.js`
- 生成：`windows/assets/internet-angel-extension.js`
- 生成：`linux/assets/internet-angel-extension.js`
- 测试：`tools/internet-angel-extension.test.mjs`
- 测试：`macos/tests/internet-angel-macos.test.mjs`

- [ ] **步骤 1：定义只包含证据的 mutation 选择器**

  在 `selectors` 后立即增加以下常量。它有意排除空的 shell、environment panel 和 workspace 容器，避免外层过早挂载在可用证据出现前取消 120 ms 兜底：

  ```js
  const mutationHintSelector = [
    selectors.composer,
    selectors.composerFooter,
    selectors.contextStrip,
    `${selectors.environmentPanel} button`,
    selectors.environmentGit,
    selectors.workspaceEvidence,
    selectors.sidebar,
    ':is(aside.app-shell-left-panel, [data-testid="app-shell-floating-left-panel"]) :is(button, [role="button"])',
    selectors.paletteScroll,
    selectors.paletteHeading,
    selectors.paletteItem,
    selectors.turnRow,
    '[class*="_marker_"]',
    '[role="tooltip"] div[class~="w-80"][class*="bg-token-dropdown-background"]',
    '[class*="_preview_"]',
    'button[class*="absolute"][class~="z-30"][class~="h-8"][class~="w-8"][class~="rounded-full"]',
    selectors.settingsNav,
    selectors.settingsContent,
    `${selectors.settingsContent} :is(button, input, textarea, [contenteditable="true"], [role="radiogroup"], [role="slider"])`,
    '[role="menu"]',
    '[role="listbox"]',
    '[data-testid*="permission"]',
    '[data-testid*="approval"]',
    ':is([data-testid*="permission"], [data-testid*="approval"], [role="alert"]) button',
    '[data-user-message-bubble="true"]',
    '[data-content-search-unit-key]',
    '[data-response-annotation-target]',
    '[class*="group/activity-header"]',
    '[class*="group/command"]',
    '[class*="group/output"]',
    '[class*="git-decoration-added"]',
    '[class*="git-decoration-deleted"]',
    '.xterm',
    '[class~="h-toolbar-pane"]',
    '[class*="group/summary-panel-item"]',
    '.thread-scroll-container',
    'input[placeholder*="optional comment" i]',
    'textarea[placeholder*="optional comment" i]',
    '[contenteditable="true"][data-placeholder*="optional comment" i]',
    '[class*="group/turn-diff-header"]',
    '.turn-diff-default-subtitle',
    '.thread-diff-virtualized',
    '[role="tabpanel"] > [class~="h-full"][class~="min-h-0"][class~="overflow-y-auto"][class~="px-3"][class~="py-5"]',
    '[class~="relative"][class~="z-10"] > button[class~="items-start"][class~="w-full"]',
    `[${componentAttribute}]`,
  ].join(", ");
  ```

  不增加通用 `span`、`div`、文本或 `.xterm` 后代选择器。`.xterm` 根节点是一次性结构提示；终端输出子节点必须继续被视为无关变化。

- [ ] **步骤 2：用共享槽替换 resize 专用 frame 变量**

  为生命周期状态和测试保留 `observers = []`，删除 `observedTargets`，并将 `let resizeFrame = null` 替换为：

  ```js
  let refreshFrame = null;
  ```

  所有 `classify*` 函数和完整 `classify()` 对账逻辑保持不变。

- [ ] **步骤 3：替换调度和观察器代码块**

  用以下代码替换 `scheduleRefresh`、`compositionStarted`、`compositionEnded`、`refreshAfterResize`、`observeTarget` 和 `installObservers`：

  ```js
  const scheduleRefresh = () => {
    metrics.scheduleRequests += 1;
    if (compositionDepth > 0) {
      refreshPendingAfterComposition = true;
      metrics.suppressedDuringComposition += 1;
      return;
    }
    if (refreshTimer !== null || refreshFrame !== null) return;
    refreshTimer = setTimeout(() => {
      refreshTimer = null;
      classify();
    }, 120);
  };

  const scheduleFrameRefresh = () => {
    metrics.scheduleRequests += 1;
    if (refreshTimer !== null) {
      clearTimeout(refreshTimer);
      refreshTimer = null;
    }
    if (compositionDepth > 0) {
      refreshPendingAfterComposition = true;
      metrics.suppressedDuringComposition += 1;
      return;
    }
    if (refreshFrame !== null) return;
    if (typeof window.requestAnimationFrame !== "function") {
      classify();
      return;
    }
    refreshFrame = window.requestAnimationFrame(() => {
      refreshFrame = null;
      classify();
    });
  };

  const compositionStarted = () => {
    compositionDepth += 1;
    let canceledRefresh = false;
    if (refreshTimer !== null) {
      clearTimeout(refreshTimer);
      refreshTimer = null;
      canceledRefresh = true;
    }
    if (refreshFrame !== null) {
      window.cancelAnimationFrame?.(refreshFrame);
      refreshFrame = null;
      canceledRefresh = true;
    }
    if (canceledRefresh) refreshPendingAfterComposition = true;
  };

  const compositionEnded = () => {
    compositionDepth = Math.max(0, compositionDepth - 1);
    if (compositionDepth !== 0 || !refreshPendingAfterComposition) return;
    refreshPendingAfterComposition = false;
    scheduleFrameRefresh();
  };

  const hasMutationHint = (node) => node?.nodeType === 1 && (
    node.matches?.(mutationHintSelector) || node.querySelector?.(mutationHintSelector)
  );

  const refreshAfterMutation = (records) => {
    const relevant = records.some((record) => [
      ...(record.addedNodes || []),
      ...(record.removedNodes || []),
    ].some(hasMutationHint));
    if (relevant) scheduleFrameRefresh();
  };

  function installObservers() {
    if (!document.body || observers.length) return;
    const observer = new MutationObserver(refreshAfterMutation);
    observer.observe(document.body, { childList: true, subtree: true });
    observers.push(observer);
  }
  ```

  保持 `refreshAfterClick` 不变。它和 navigation 事件继续调用 120 ms 的 `scheduleRefresh()` 兜底。

- [ ] **步骤 4：完成生命周期接线和 cleanup**

  在 `cleanup()` 中替换 `resizeFrame` 代码块，并删除 `observedTargets.clear()`：

  ```js
  if (refreshFrame !== null) window.cancelAnimationFrame?.(refreshFrame);
  refreshFrame = null;
  ```

  timeout 清理、composition 重置、observer 断开、listener 移除、mark 移除和 registry 删除保持不变。将 resize 绑定到共享快速刷新槽：

  ```js
  addListener(window, "resize", scheduleFrameRefresh);
  ```

  初次安装时保留 `classify(); installObservers();`。两个刷新回调都不再调用 `installObservers()`，因为唯一的 body observer 会持续存在直至 cleanup。

- [ ] **步骤 5：同步生成的 JavaScript 并确认 GREEN**

  运行：

  ```bash
  node tools/sync-runtime-assets.mjs
  node tools/internet-angel-extension.test.mjs
  node macos/tests/internet-angel-macos.test.mjs
  node tools/sync-runtime-assets.mjs --check
  ```

  预期：两个测试都输出各自现有的 `PASS:` 行；同步检查以 `0` 退出且没有 mismatch。延迟 fixture 对多条相关记录必须只增加一次 `classifyRuns`，文本和普通消息 mutation 不得增加该计数。

- [ ] **步骤 6：提交共享 observer 修复**

  ```bash
  git add runtime/internet-angel-extension.js \
    macos/assets/internet-angel-extension.js \
    windows/assets/internet-angel-extension.js \
    linux/assets/internet-angel-extension.js \
    tools/internet-angel-extension.test.mjs \
    macos/tests/internet-angel-macos.test.mjs
  git commit -m "fix: classify delayed dynamic theme surfaces"
  ```

### 任务 4：运行跨平台回归和 payload 检查

**文件：**
- 验证：`runtime/internet-angel-extension.js`
- 验证：`runtime/internet-angel-extension.css`
- 验证：`macos/assets/internet-angel-extension.js`
- 验证：`macos/assets/internet-angel-extension.css`
- 验证：`windows/assets/internet-angel-extension.js`
- 验证：`windows/assets/internet-angel-extension.css`
- 验证：`linux/assets/internet-angel-extension.js`
- 验证：`linux/assets/internet-angel-extension.css`

- [ ] **步骤 1：运行共享和 macOS 聚焦测试**

  ```bash
  node tools/internet-angel-extension.test.mjs
  node tools/sync-runtime-assets.mjs --check
  node macos/tests/internet-angel-macos.test.mjs
  ```

  预期：两个测试命令都输出 `PASS:`，同步检查静默地以 `0` 退出。

- [ ] **步骤 2：运行完整 macOS 回归套件**

  ```bash
  ./macos/tests/run-tests.sh
  ```

  预期：以 `0` 退出，套件中的所有 Node、shell 和 Swift 检查通过。不得为获得绿色结果而抑制 selector doctor 或原生测试失败。

- [ ] **步骤 3：验证 Windows 和 Linux 注入 payload**

  ```bash
  node windows/scripts/injector.mjs --check-payload
  node linux/scripts/injector.mjs --check-payload
  ```

  预期：两个命令都以 `0` 退出，并确认其 payload 包含同步后的共享扩展。此 macOS 主机无法执行的 Windows 原生冒烟测试继续交给 CI。

- [ ] **步骤 4：检查精确 diff**

  ```bash
  git diff --check
  git status --short
  git diff --stat
  git diff -- runtime/internet-angel-extension.js runtime/internet-angel-extension.css \
    tools/internet-angel-extension.test.mjs macos/tests/internet-angel-macos.test.mjs
  ```

  预期：没有空白错误；本任务只涉及两个规范源、六个生成副本、两个测试、本计划和 `TASK_PROGRESS.md`。除非用户另外要求提交，否则保留任务开始前已存在且未跟踪的诊断文档。

### 任务 5：验证真实 Codex renderer 并记录结果

**文件：**
- 修改：`TASK_PROGRESS.md`
- 只读验证：`docs/macos-dynamic-panel-theming-race.md`

- [ ] **步骤 1：将构建后的共享运行时应用到活动 Dream Skin 测试安装**

  对当前已保存的 Internet Angel 主题使用仓库正常的 macOS 应用/重新应用流程。不得修改 Codex 的 `app.asar`、签名、ACL 或受保护安装目录。记录精确的 Codex Desktop 版本、Dream Skin 运行时版本、扩展 revision，以及活动 renderer 字节是否与工作树共享源一致。

- [ ] **步骤 2：操作目标动态表面**

  在可见 Codex 窗口中完成以下全部可逆检查：

  1. 切换会话 20 次，要求每个挂载后的对话导航 marker 立即显示 Internet Angel 外观。
  2. 打开和关闭右侧文档/workspace 预览 20 次。
  3. 分别打开和关闭 Environment 与 summary 表面各 20 次。
  4. 快速交替切换会话和右侧标签，要求每次挂载后预期的 `data-angel-component` mark 都保持存在。

  检查完成后恢复到原任务和 UI 状态。

- [ ] **步骤 3：检查性能边界**

  在滚动长对话并观察普通流式输出前后读取 `window.__CODEX_INTERNET_ANGEL_EXTENSION_STATE__.metrics`。要求仅文本和未识别消息子节点 mutation 不增加 `classifyRuns`；相关结构挂载每个动画帧最多增加一次。记录 `lastClassifyMs`，并与此前实测的 3.5-3.7 ms 范围比较；如有明显回退必须如实记录。

- [ ] **步骤 4：保持 Shadow DOM 和状态误报问题独立**

  不把黑色 `diffs-container` Shadow DOM 源码查看器视为本计划失败。不要修改 `status-dream-skin-macos.sh`；它的本地化星期字符串比较错误是独立的生命周期/状态问题。

- [ ] **步骤 5：更新连续性证据**

  将精确的自动化命令/结果、实机迭代次数、版本、分类次数/耗时，以及无法执行的平台原生检查加入 `TASK_PROGRESS.md` 当前章节。严格区分本地实现、已测试、已提交、已推送、PR、已合并和已发布状态。

- [ ] **步骤 6：提交计划和已验证进度记录**

  ```bash
  git add docs/superpowers/plans/2026-08-06-dynamic-panel-theming-race.md TASK_PROGRESS.md
  git commit -m "docs: record dynamic theming race verification"
  ```

  此命令不要暂存 `docs/macos-dynamic-panel-theming-race.md`，因为它早于本计划，仍是未跟踪的用户/诊断文件。

### 任务 6：稳定分隔条拖动后的右侧工作区分类

**文件：**
- 修改：`macos/tests/internet-angel-macos.test.mjs:593-609`
- 修改：`macos/tests/internet-angel-macos.test.mjs:784-818`
- 修改：`macos/tests/internet-angel-macos.test.mjs:1080-1110`
- 修改：`runtime/internet-angel-extension.js:365-379`
- 生成：`macos/assets/internet-angel-extension.js`
- 生成：`windows/assets/internet-angel-extension.js`
- 生成：`linux/assets/internet-angel-extension.js`
- 修改：`TASK_PROGRESS.md`

- [x] **步骤 1：让 fixture 表达右侧 `aside` 归属和左栏排除**

  在现有 workspace fixture 中增加一个右侧 `aside` 宿主，并让外层、内层工作区都能通过 `closest("aside")` 找到它：

  ```js
  const workspaceAside = makeNode({ matches: ["aside"] });
  workspaceOuter.closestNodes.set("aside", workspaceAside);
  workspace.closestNodes.set("aside", workspaceAside);
  ```

  再增加一个带 `workspaceEvidence`、宽度小于 `260px` 的左栏伪候选。创建 `sidebar` 后，将它同时登记为该候选的 `aside` 和 `selectors.sidebar` 最近祖先：

  ```js
  const leftWorkspace = makeNode({
    className: "bg-token-main-surface-primary",
    rect: { left: 0, top: 48, width: 220, height: 820 },
  });
  leftWorkspace.addQuery(workspaceEvidenceSelector, workspaceEvidence);

  leftWorkspace.closestNodes.set("aside", sidebar);
  leftWorkspace.closestNodes.set(sidebarSelector, sidebar);
  ```

  将 `leftWorkspace` 加入 workspace 的 `documentQueries` 候选并从 fixture 返回。现有初始断言旁增加：

  ```js
  assert.equal(
    component(fixture.leftWorkspace),
    null,
    "A workspace-like surface inside the left sidebar must stay unmarked.",
  );
  ```

- [x] **步骤 2：增加分隔条拖窄、拖宽的回归并确认 RED**

  在现有 resize 合并测试前增加一个独立 fixture。每次改变外层和内层矩形后，通过现有 resize 监听器执行一次完整重新分类：

  ```js
  const dividerDrag = activateOverlayFixture();
  dividerDrag.workspaceOuter.rect = { left: 1438, top: 28, width: 240, height: 840 };
  dividerDrag.workspace.rect = { left: 1458, top: 48, width: 220, height: 820 };
  dividerDrag.listeners.get("resize")();
  dividerDrag.flushFrames();
  assert.equal(
    component(dividerDrag.workspace),
    "side-workspace",
    "A right-aside workspace must stay themed below the legacy 260px threshold.",
  );

  dividerDrag.workspaceOuter.rect = { left: 678, top: 28, width: 1000, height: 840 };
  dividerDrag.workspace.rect = { left: 698, top: 48, width: 980, height: 820 };
  dividerDrag.listeners.get("resize")();
  dividerDrag.flushFrames();
  assert.equal(
    component(dividerDrag.workspace),
    "side-workspace",
    "A right-aside workspace must stay themed left of the legacy 45% threshold.",
  );
  assert.equal(component(dividerDrag.workspaceOuter), null);
  assert.equal(component(dividerDrag.leftWorkspace), null);
  ```

  运行：

  ```bash
  node macos/tests/internet-angel-macos.test.mjs
  ```

  预期：第一个新增拖窄断言失败，实际值为 `null`。这证明测试命中旧的 `260px` 几何条件，而不是测试搭建错误。

- [x] **步骤 3：为右侧 `aside` 增加最小结构路径**

  在 `classifyWorkspaces()` 保留 `workspaceEvidence` 必要条件。证据存在后，先接受位于 `aside` 且不属于 `selectors.sidebar` 的候选；其他候选继续执行原有几何条件：

  ```js
  const inRightAside = candidate.closest?.("aside")
    && !candidate.closest?.(selectors.sidebar);
  if (inRightAside) return true;
  ```

  候选排序和 `mark(candidates[0], "side-workspace")` 保持不变，因此嵌套候选仍只标记面积最小的有效表面。不增加新 helper、配置或 CSS。

- [x] **步骤 4：同步三平台副本并确认 GREEN**

  运行：

  ```bash
  node tools/sync-runtime-assets.mjs
  node macos/tests/internet-angel-macos.test.mjs
  node tools/internet-angel-extension.test.mjs
  node tools/sync-runtime-assets.mjs --check
  ```

  预期：两个测试输出各自现有的 `PASS:` 行；同步检查静默以 `0` 退出。窄、宽、左栏排除和最小表面断言全部通过。

- [x] **步骤 5：运行跨平台 payload 和完整 macOS 回归**

  运行：

  ```bash
  node windows/scripts/injector.mjs --check-payload
  node linux/scripts/injector.mjs --check-payload
  ./macos/tests/run-tests.sh
  git diff --check
  ```

  预期：payload 检查和完整 macOS 回归均以 `0` 退出；没有空白错误。Windows/Linux 原生视觉验收仍由 CI 或对应平台完成，不把共享副本一致误述为原生验证。

- [x] **步骤 6：提交共享修复并记录验证状态**

  在 `TASK_PROGRESS.md` 记录 RED、GREEN、同步、payload、完整回归和实机拖动缺口。然后只提交本任务涉及的共享源、三个生成副本、测试、计划和进度记录：

  ```bash
  git add runtime/internet-angel-extension.js \
    macos/assets/internet-angel-extension.js \
    windows/assets/internet-angel-extension.js \
    linux/assets/internet-angel-extension.js \
    macos/tests/internet-angel-macos.test.mjs \
    docs/superpowers/plans/2026-08-06-dynamic-panel-theming-race.md \
    TASK_PROGRESS.md
  git commit -m "fix: stabilize side workspace classification"
  ```

  不修改或暂存右侧内部黑色子层、快捷键搜索带、`diffs-container` Shadow DOM 以及用户的未跟踪诊断报告。

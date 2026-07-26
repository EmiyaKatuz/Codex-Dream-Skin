(() => {
  const enabled = __INTERNET_ANGEL_MACOS_ENABLED_JSON__;
  const registryKey = "__CODEX_INTERNET_ANGEL_MACOS_STATE__";
  const componentAttribute = "data-angel-component";
  const selectors = {
    composer: ".composer-surface-chrome",
    stickyComposer: 'main.main-surface [class~="sticky"][class~="bottom-0"]',
    contextStrip: 'div[class~="relative"][class~="min-w-0"][class~="overflow-clip"][class~="border-x"][class~="border-t"]',
    environmentPanel: 'div[class*="bg-token-dropdown-background"][class~="rounded-3xl"]',
    environmentToggle: 'button[class~="group/section-toggle"]',
    environmentGit: '[data-testid*="git"], [aria-label*="git" i], [class*="git-"]',
    workspace: '[class*="contain:layout_paint"], [class~="bg-token-main-surface-primary"]',
    workspaceEvidence: '[role="tablist"], [role="tabpanel"], .xterm, .thread-scroll-container',
    sidebar: "aside.app-shell-left-panel",
    paletteScroll: 'div.vertical-scroll-fade-mask[class~="overflow-y-auto"]',
    paletteHeading: '[class~="sticky"][class~="top-0"][class~="z-10"]',
    paletteItem: 'button[class~="w-full"][class~="shrink-0"][class~="rounded-lg"][class~="text-left"]',
    turnRow: 'button[class*="navigation-row"]',
    settingsNav: 'nav:has([data-settings-panel-slug])',
    settingsContent: 'div.main-surface:has(> [class~="scrollbar-stable"][class~="flex-1"][class~="overflow-y-auto"][class~="p-panel"])',
  };
  const previous = window[registryKey];
  previous?.cleanup?.();

  const clearMarks = () => {
    for (const node of document.querySelectorAll(`[${componentAttribute}]`)) {
      node.removeAttribute(componentAttribute);
    }
  };
  clearMarks();
  delete window[registryKey];
  if (!enabled) return;

  const observers = [];
  const observedTargets = new Set();
  const listeners = [];
  let refreshTimer = null;
  let state = null;

  const mark = (node, component) => {
    if (node?.setAttribute) node.setAttribute(componentAttribute, component);
    return node;
  };

  const classText = (node) => typeof node?.className === "string"
    ? node.className
    : node?.getAttribute?.("class") || "";
  const textOf = (node) => (node?.textContent || "").trim();
  const labelOf = (node) => [
    node?.getAttribute?.("aria-label"),
    node?.getAttribute?.("title"),
    textOf(node),
  ].filter(Boolean).join(" ");
  const commonAncestor = (left, right, boundary) => {
    if (!left || !right) return null;
    if (left.parentElement && left.parentElement === right.parentElement) return left.parentElement;
    let candidate = left.parentElement;
    while (candidate && candidate !== boundary) {
      if (candidate.contains?.(right)) return candidate;
      candidate = candidate.parentElement;
    }
    return null;
  };

  const classifySidebar = () => {
    const sidebar = document.querySelector(selectors.sidebar);
    if (!sidebar) return;
    mark(sidebar, "sidebar");
    const controls = [...(sidebar.querySelectorAll?.("button, [role=button]") || [])];
    const profile = controls.find((node) => /open profile menu|profile menu|account menu|\u4e2a\u4eba\u8d44\u6599|\u8d26\u6237\u83dc\u5355/i.test(labelOf(node)));
    const help = controls.find((node) => /open help menu|help menu|\u5e2e\u52a9\u83dc\u5355/i.test(labelOf(node)));
    const footer = commonAncestor(profile, help, sidebar);
    if (footer && footer !== sidebar) mark(footer, "sidebar-footer");
    for (const control of controls) {
      const label = labelOf(control);
      const classes = classText(control);
      if (control === profile) mark(control, "sidebar-profile");
      else if (control === help) mark(control, "sidebar-help");
      else if (classes.includes("group/section-toggle")) mark(control, "sidebar-section");
      else if (/^(?:new (?:chat|task)|\u65b0\u5efa(?:\u804a\u5929|\u4efb\u52a1))$/i.test(textOf(control))) {
        mark(control, "sidebar-new-task");
      } else if (/switch mode|current mode|search|\u5207\u6362\u6a21\u5f0f|\u641c\u7d22/i.test(label)) {
        mark(control, "sidebar-control");
      } else {
        mark(control, "sidebar-row");
      }
    }
  };

  const classifyComposerPalette = () => {
    for (const scroll of document.querySelectorAll(selectors.paletteScroll)) {
      const palette = scroll.parentElement;
      const classes = classText(palette);
      if (!palette || !classes.includes("border-token-border")
        || !classes.includes("bg-token-dropdown-background")
        || !classes.includes("overflow-hidden") || !classes.includes("rounded-2xl")) continue;
      mark(palette, "composer-palette");
      mark(scroll, "composer-palette-scroll");
      for (const heading of scroll.querySelectorAll?.(selectors.paletteHeading) || []) {
        mark(heading, "composer-palette-heading");
      }
      for (const item of scroll.querySelectorAll?.(selectors.paletteItem) || []) {
        mark(item, "composer-palette-item");
      }
    }
  };

  const classifyTurnNavigation = () => {
    for (const row of document.querySelectorAll(selectors.turnRow)) {
      mark(row.parentElement, "turn-nav-rail");
      mark(row, "turn-nav-row");
      const marker = row.querySelector?.('[class*="_marker_"]')
        || row.firstElementChild?.firstElementChild
        || row.firstElementChild;
      if (!marker) continue;
      const active = classText(marker).split(/\s+/).includes("opacity-60")
        || marker.getAttribute?.("aria-current") === "true";
      mark(marker, active ? "turn-nav-marker-active" : "turn-nav-marker");
    }
    for (const previewSurface of document.querySelectorAll(
      '[role="tooltip"] div[class~="w-80"][class*="bg-token-dropdown-background"]',
    )) {
      mark(previewSurface.closest?.('[role="tooltip"]'), "turn-preview");
      mark(previewSurface, "turn-preview-surface");
      mark(previewSurface.querySelector?.('[class~="font-medium"]'), "turn-preview-title");
      mark(previewSurface.querySelector?.('[class*="_preview_"]'), "turn-preview-excerpt");
    }
    for (const button of document.querySelectorAll(
      'button[aria-label], button[class*="absolute"][class~="rounded-full"]',
    )) {
      const label = labelOf(button);
      const classes = classText(button);
      const semantic = /scroll.*bottom|bottom.*scroll|latest message|\u6eda\u52a8\u5230\u5e95\u90e8|\u6700\u65b0\u6d88\u606f/i.test(label);
      const structural = classes.includes("absolute") && classes.includes("z-30")
        && classes.includes("h-8") && classes.includes("w-8") && classes.includes("rounded-full");
      if (semantic || structural) mark(button, "scroll-bottom");
    }
  };

  const classifySettings = () => {
    const nav = document.querySelector(selectors.settingsNav);
    if (!nav) return;
    const sidebar = nav.closest?.(selectors.sidebar) || nav.parentElement;
    const content = document.querySelector(selectors.settingsContent);
    mark(sidebar, "settings-sidebar");
    mark(nav, "settings-nav");
    const search = nav.querySelector?.('[role="searchbox"]');
    mark(search?.closest?.('div[class~="rounded-lg"]') || search, "settings-search");
    mark(content, "settings-content");
    const surfaces = [...(content?.querySelectorAll?.(
      'div[class~="flex"][class~="flex-col"][class~="overflow-hidden"][class~="rounded-2xl"]',
    ) || [])].filter((surface) => {
      const box = surface.getBoundingClientRect?.() || { width: 0, height: 0 };
      return box.width >= 320 && box.height >= 44 && (surface.childElementCount || 0) > 0;
    });
    for (const surface of surfaces) {
      mark(surface, "settings-surface");
      for (const row of surface.children || []) {
        const box = row.getBoundingClientRect?.() || { width: 0, height: 0 };
        if ((row.tagName === "DIV" || !row.tagName) && box.width >= 260 && box.height >= 36) {
          mark(row, "settings-row");
        }
      }
      const appSelector = 'button[class~="appearance-none"][class~="bg-transparent"][class~="p-0"][class~="text-left"]';
      if (surface.querySelector?.(appSelector)) {
        for (const row of surface.children || []) {
          if (row.querySelector?.(appSelector)) mark(row, "settings-app-row");
        }
      }
    }
    for (const control of content?.querySelectorAll?.(
      'button, input, textarea, [contenteditable="true"], [role="radiogroup"], [role="slider"]',
    ) || []) {
      if (control.matches?.('input, textarea, [contenteditable="true"]')) mark(control, "settings-input");
      else if (control.matches?.('[role="radiogroup"]')) {
        mark(control, "settings-segment-group");
        for (const segment of control.querySelectorAll?.('button, [role="radio"]') || []) {
          mark(segment, "settings-segment");
        }
      } else mark(control, "settings-control");
    }
    for (const group of content?.querySelectorAll?.(
      'div[class~="rounded-lg"]:has(> button + button), div[class~="rounded-xl"]:has(> button + button)',
    ) || []) {
      const box = group.getBoundingClientRect?.() || { width: 0, height: 0 };
      if (box.width <= 52 || box.width >= 520 || box.height < 24 || box.height > 64) continue;
      mark(group, "settings-segment-group");
      for (const segment of group.querySelectorAll?.(':scope > button') || []) mark(segment, "settings-segment");
    }
    for (const trigger of content?.querySelectorAll?.('button[aria-haspopup][aria-controls]') || []) {
      const menu = document.getElementById?.(trigger.getAttribute?.("aria-controls"));
      mark(menu, "settings-menu");
    }
    for (const menu of document.querySelectorAll('[role="menu"], [role="listbox"]')) {
      mark(menu, "settings-menu");
    }
  };

  const classifyComposer = () => {
    for (const composer of document.querySelectorAll(selectors.composer)) {
      mark(composer, "composer");
      mark(composer.querySelector?.('[contenteditable="true"]'), "composer-input");
      for (const button of composer.querySelectorAll?.("button") || []) {
        mark(button, "composer-action");
      }
    }
  };

  const classifyComposerContext = () => {
    const goalStepPattern = /^(?:\u7b2c\s*\d+\s*\/\s*\d+\s*\u6b65|step\s*\d+\s*\/\s*\d+)$/i;
    const activeGoalPattern = /^(?:\u8fdb\u884c\u4e2d\u7684\u76ee\u6807|active goal)$/i;
    for (const sticky of document.querySelectorAll(selectors.stickyComposer)) {
      for (const strip of sticky.querySelectorAll?.(selectors.contextStrip) || []) {
        mark(strip, "context-strip");
      }
      const labels = [...(sticky.querySelectorAll?.("span") || [])];
      const activeGoalLabel = labels.find((node) => activeGoalPattern.test((node.textContent || "").trim()));
      const activeGoalStrip = activeGoalLabel?.closest?.(`[${componentAttribute}="context-strip"]`);
      if (activeGoalStrip) mark(activeGoalStrip, "active-goal-strip");
      const stepLabel = labels.find((node) => goalStepPattern.test((node.textContent || "").trim()));
      const step = stepLabel?.closest?.('span[class~="inline-flex"]') || stepLabel?.parentElement || null;
      const progress = step?.closest?.('div[class~="rounded-3xl"][class~="items-center"]') || null;
      mark(step, "goal-step");
      mark(progress, "goal-progress");
    }
  };

  const classifyEnvironment = () => {
    for (const panel of document.querySelectorAll(selectors.environmentPanel)) {
      const toggle = panel.querySelector?.(selectors.environmentToggle);
      const buttons = [...(panel.querySelectorAll?.("button") || [])];
      const host = panel.closest?.('[class~="absolute"][class~="z-40"]');
      const box = panel.getBoundingClientRect?.() || { left: 0, width: 0, height: 0, right: 0 };
      const right = Number.isFinite(box.right) ? box.right : box.left + box.width;
      const rightFloating = box.width >= 240 && box.width <= 520 && box.height >= 96
        && box.height <= 760 && right >= innerWidth - 64 && right <= innerWidth + 16;
      const structuralGitSignal = Boolean(panel.querySelector?.(selectors.environmentGit));
      const text = (panel.textContent || "").trim().slice(0, 1200);
      const semanticSignals = [
        /environment|\u73af\u5883/i,
        /changes?|\u66f4\u6539/i,
        /local|branch|commit|compare|\u5206\u652f|\u63d0\u4ea4|\u6bd4\u8f83/i,
      ].filter((pattern) => pattern.test(text)).length;
      if (!host || !toggle || buttons.length < 2 || !rightFloating
        || (!structuralGitSignal && semanticSignals < 2)) continue;
      mark(panel, "environment");
      mark(toggle, "environment-header");
      if (toggle.parentElement && toggle.parentElement !== panel) {
        mark(toggle.parentElement, "environment-section");
      }
      for (const button of buttons) {
        if (button !== toggle) mark(button, "environment-action");
      }
    }
  };

  const classifyWorkspaces = () => {
    for (const candidate of document.querySelectorAll(selectors.workspace)) {
      const evidence = candidate.querySelector?.(selectors.workspaceEvidence);
      if (!evidence) continue;
      const box = candidate.getBoundingClientRect?.() || { left: 0, width: 0, height: 0, right: 0 };
      const right = Number.isFinite(box.right) ? box.right : box.left + box.width;
      const rightDocked = box.width >= 260 && box.height >= 180
        && box.left >= innerWidth * .45 && right >= innerWidth - 48 && right <= innerWidth + 16;
      if (rightDocked) mark(candidate, "side-workspace");
    }
  };

  const classifyPermissions = () => {
    for (const candidate of document.querySelectorAll(
      '[data-testid*="permission"], [data-testid*="approval"], [role="alert"]',
    )) {
      const text = (candidate.textContent || "").trim();
      const actions = candidate.querySelectorAll?.("button") || [];
      if (actions.length && /access|permission|approval|\u8bbf\u95ee|\u6743\u9650|\u6279\u51c6/i.test(text)) {
        mark(candidate, "permission");
      }
    }
  };

  const classifyAuxiliarySurfaces = () => {
    const terminal = document.querySelector(".xterm");
    const terminalPanel = terminal?.closest?.('[class*="contain:layout_paint"]')
      || terminal?.closest?.('[role="tabpanel"]')
      || document.querySelector(
        '[class*="contain:layout_paint"]:has(> [class~="h-toolbar-pane"] [role="tablist"])',
      );
    mark(terminalPanel, "terminal-panel");
    const terminalToolbar = terminalPanel?.querySelector?.('[class~="h-toolbar-pane"]')
      || terminalPanel?.querySelector?.('[role="tablist"]')?.parentElement;
    mark(terminalToolbar, "terminal-toolbar");
    for (const tab of terminalPanel?.querySelectorAll?.('[role="tab"]') || []) mark(tab, "terminal-tab");

    for (const summary of document.querySelectorAll(
      '[class*="rounded-3xl"][class*="bg-token-dropdown-background"]:has(> [class*="overflow-y-auto"] [class*="group/summary-panel-item"])',
    )) {
      if (summary.getAttribute?.(componentAttribute) === "environment") continue;
      mark(summary, "summary-panel");
    }

    for (const aside of document.querySelectorAll("main.main-surface aside")) {
      if (!aside.querySelector?.(".thread-scroll-container") || !aside.querySelector?.(".composer-surface-chrome")) continue;
      mark(aside.querySelector?.(':scope > [class*="contain:layout_paint"]')
        || aside.querySelector?.('[class*="contain:layout_paint"]')
        || aside.firstElementChild, "side-chat");
    }
  };

  const classifySelectionAndDiffs = () => {
    const selectionPattern = /^(?:\u6dfb\u52a0\u5230\u4efb\u52a1|add to task|\u66f4\u591a\u8be6\u60c5|more details|\u5728\u4fa7\u8fb9\u804a\u5929\u4e2d\u63d0\u95ee|ask in sidebar chat)$/i;
    const selectionButtons = [...document.querySelectorAll("button, [role=button]")]
      .filter((button) => selectionPattern.test(textOf(button)));
    for (const button of selectionButtons) mark(button, "selection-action");
    if (selectionButtons.length) {
      let actions = selectionButtons[0].parentElement;
      while (actions && actions !== document.body
        && !selectionButtons.every((button) => actions.contains?.(button))) {
        actions = actions.parentElement;
      }
      if (actions && actions !== document.body) mark(actions, "selection-actions");
    }

    const selectedPattern = /^\d+\s*(?:\u4e2a)?\s*(?:\u5df2\u9009\u6587\u672c\u7247\u6bb5|selected text (?:fragment|snippet)s?)$/i;
    const selectedLabel = [...document.querySelectorAll("button, div, span")]
      .find((node) => selectedPattern.test(textOf(node)));
    mark(selectedLabel?.closest?.("button") || selectedLabel?.closest?.('[class*="rounded"]') || selectedLabel,
      "selected-fragment");

    const optionalInput = [...document.querySelectorAll('input, textarea, [contenteditable="true"]')]
      .find((node) => /\u6dfb\u52a0\u53ef\u9009\u8bc4\u8bba|optional comment/i.test(
        node.getAttribute?.("placeholder") || node.getAttribute?.("data-placeholder") || "",
      ));
    mark(optionalInput, "optional-comment-input");
    if (optionalInput) {
      let frame = optionalInput.parentElement;
      while (frame && frame !== document.body) {
        const box = frame.getBoundingClientRect?.() || { width: 0, height: 0 };
        if (box.width >= 120 && box.width < 720 && box.height >= 32 && box.height < 104) break;
        frame = frame.parentElement;
      }
      if (frame && frame !== document.body) mark(frame, "optional-comment");
    }

    const editedTitlePattern = /^(?:\u5df2\u7f16\u8f91|edited)(?:\s+|[:\uff1a]\s*)\S/i;
    const undoPattern = /^(?:\u64a4\u9500|undo)$/i;
    const reviewPattern = /^(?:\u5ba1\u6838|review)$/i;
    for (const header of document.querySelectorAll('[class*="group/turn-diff-header"]')) {
      const title = [...(header.querySelectorAll?.('span[class~="font-medium"][class*="text-token-foreground"]') || [])]
        .find((node) => editedTitlePattern.test(textOf(node)));
      const card = header.parentElement?.matches?.('[class*="--thread-resource-card-row-padding-x:"]')
        ? header.parentElement
        : header.closest?.('[class*="rounded-lg"][class*="bg-token-dropdown-background"]');
      const stats = card?.querySelector?.(".turn-diff-default-subtitle");
      const buttons = [...(card?.querySelectorAll?.("button, [role=button]") || [])];
      const undo = buttons.find((button) => undoPattern.test(textOf(button)));
      const review = buttons.find((button) => reviewPattern.test(textOf(button)));
      if (!title || !card || !stats || !undo || !review) continue;
      mark(card, "edited-card");
      mark(header, "edited-card-header");
      mark(title, "edited-card-title");
      mark(stats, "edited-card-stats");
      mark(undo, "edited-card-action");
      mark(review, "edited-card-action");
    }
  };

  const classifySubagents = () => {
    const scroller = [...document.querySelectorAll(
      '[role="tabpanel"] > [class~="h-full"][class~="min-h-0"][class~="overflow-y-auto"][class~="px-3"][class~="py-5"]',
    )].find((candidate) => [...(candidate.querySelectorAll?.(':scope > section') || [])]
      .some((section) => section.querySelector?.(
        ':scope > [class~="relative"][class~="z-10"] > button[class~="items-start"][class~="w-full"]',
      )));
    if (!scroller) return;
    const panel = scroller.parentElement?.matches?.('[role="tabpanel"]') ? scroller.parentElement : null;
    const shell = panel?.parentElement;
    const toolbar = panel?.previousElementSibling?.matches?.('[class~="h-toolbar"]')
      ? panel.previousElementSibling : null;
    const frame = shell?.closest?.('[class~="border-l"][class~="bg-token-main-surface-primary"]');
    mark(frame || shell, "subagent-frame");
    mark(toolbar, "subagent-toolbar");
    mark(panel, "subagent-panel");
    mark(scroller, "subagent-scroller");
    const sections = [...(scroller.querySelectorAll?.(':scope > section') || [])];
    sections.forEach((section, index) => {
      const archived = classText(section).split(/\s+/).includes("mt-6") || index > 0;
      mark(section, archived ? "subagent-section-archive" : "subagent-section");
      const list = section.querySelector?.(':scope > [class~="relative"][class~="z-10"]');
      mark(list, "subagent-list");
      for (const row of list?.querySelectorAll?.(':scope > button[class~="items-start"][class~="w-full"]') || []) {
        mark(row, archived ? "subagent-row-archive" : "subagent-row");
      }
      for (const more of section.querySelectorAll?.(':scope > button:not([class~="items-start"])') || []) {
        mark(more, "subagent-more");
      }
    });
  };

  const classifySystemToasts = () => {
    const toastPattern = /\u901f\u7387\u9650\u5236\u91cd\u7f6e\u673a\u4f1a|rate limit reset opportunity/i;
    const actionPattern = /\u67e5\u770b\u91cd\u7f6e\u6b21\u6570|view (?:reset|redemption)/i;
    for (const candidate of document.querySelectorAll("body div, body section, body aside")) {
      if (!toastPattern.test(textOf(candidate))) continue;
      const action = [...(candidate.querySelectorAll?.("button") || [])]
        .some((button) => actionPattern.test(textOf(button)));
      if (!action) continue;
      mark(candidate.matches?.('aside[class~="rounded-2xl"]')
        ? candidate
        : candidate.querySelector?.('aside[class~="rounded-2xl"]') || candidate, "system-toast");
      break;
    }
  };

  const classify = () => {
    clearMarks();
    classifySidebar();
    classifyComposer();
    classifyComposerPalette();
    classifyComposerContext();
    classifyEnvironment();
    classifyWorkspaces();
    classifyPermissions();
    classifyTurnNavigation();
    classifySettings();
    classifyAuxiliarySurfaces();
    classifySelectionAndDiffs();
    classifySubagents();
    classifySystemToasts();
  };

  const scheduleRefresh = () => {
    if (refreshTimer !== null) return;
    refreshTimer = setTimeout(() => {
      refreshTimer = null;
      classify();
      installObservers();
    }, 60);
  };

  const observeTarget = (target) => {
    if (!target || observedTargets.has(target)) return;
    const observer = new MutationObserver(scheduleRefresh);
    observer.observe(target, { childList: true });
    observers.push(observer);
    observedTargets.add(target);
  };

  function installObservers() {
    observeTarget(document.body);
    observeTarget(document.querySelector("main.main-surface"));
    for (const sticky of document.querySelectorAll(selectors.stickyComposer)) observeTarget(sticky);
  }

  const addListener = (target, type) => {
    if (!target?.addEventListener) return;
    target.addEventListener(type, scheduleRefresh);
    listeners.push([target, type]);
  };

  const cleanup = () => {
    if (refreshTimer !== null) clearTimeout(refreshTimer);
    refreshTimer = null;
    for (const observer of observers) observer.disconnect();
    observers.length = 0;
    observedTargets.clear();
    for (const [target, type] of listeners) target.removeEventListener?.(type, scheduleRefresh);
    listeners.length = 0;
    clearMarks();
    if (window[registryKey] === state) delete window[registryKey];
  };

  state = { cleanup, observers, refresh: classify };
  window[registryKey] = state;
  classify();
  installObservers();
  addListener(window.navigation, "navigate");
  addListener(window, "popstate");
  addListener(window, "hashchange");
  addListener(window, "click");
  addListener(window, "transitionend");
})();

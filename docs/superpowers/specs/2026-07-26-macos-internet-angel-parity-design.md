# macOS Internet Angel Visual Parity Design

## Context

The active macOS `preset-internet-angel` session passes the existing structural
verifier, but its task composer and floating Environment surface retain native
gray Codex styling. Live CDP inspection on Codex `26.721.41059` showed:

- the root correctly carries `data-dream-theme="internet-angel"`;
- the composer is visible but resolves to a flat `rgb(48, 47, 50)` surface with
  no Internet Angel cyan/pink border treatment;
- the Environment card resolves to native `rgb(45, 45, 45)` styling;
- goal progress, access mode, model, and reasoning controls remain native gray;
- the current macOS CSS contains an Internet Angel home block that is not fully
  gated by `data-dream-theme`, so it can affect Gothic and custom themes.

Windows is the visual reference. macOS keeps its own application discovery,
signature validation, CDP lifecycle, and native layout behavior.

## Goal

Bring both bundled Internet Angel themes on macOS to Windows visual parity
across home, thread, composer, Environment/Changes, workspace, overlay, and
responsive states without changing native interaction behavior or affecting
Gothic and custom themes.

The supported theme IDs are exactly:

- `preset-internet-angel`
- `preset-internet-angel-default`

Theme display names are not activation signals.

## Non-Goals

- Do not replace the macOS renderer with the Windows renderer.
- Do not modify the official ChatGPT/Codex application or `app.asar`.
- Do not change Gothic, custom, or future unrelated themes.
- Do not copy Windows-only process, tray, installer, or layout assumptions.
- Do not rasterize native controls or block pointer/keyboard interaction.

## Architecture

The generic macOS runtime remains the base. A macOS-only Internet Angel layer
is packaged beside it:

- `macos/assets/internet-angel-macos.css` contains the visual system and all
  component rules.
- `macos/assets/internet-angel-macos.js` classifies dynamic native surfaces
  with removable `data-angel-component` attributes.
- `macos/scripts/injector.mjs` composes the extra CSS only for the two exact
  Internet Angel IDs and always executes the small overlay lifecycle script so
  switching away can clean an earlier Internet Angel session.

Existing home/side ornament behavior in the canonical renderer remains in
place. Existing Internet Angel home CSS is gated by the root theme attribute so
generic themes cannot inherit its layout.

## Component Coverage

The overlay maps the Windows Internet Angel visual language to stable macOS DOM
signals:

| Area | macOS target | Treatment |
| --- | --- | --- |
| Composer | `.composer-surface-chrome` | cyan/blue/pink frame, angular corners, focus glow, themed controls |
| Goal progress | centered rounded progress surface above composer | compact broadcast/status chip |
| Access/model/reasoning | native composer buttons | readable Angel pills with preserved labels and hit areas |
| Environment | right floating task surface containing section toggles | broadcast panel, themed header, rows, separators |
| Changes | Environment section and change counters/actions | cyan/pink state accents without changing Git semantics |
| Context strips | sticky composer attachments/goal strips | linked-context rail consistent with Windows |
| Side workspace | right browser/terminal/task panel | Angel workspace shell and restrained branding |
| Messages/cards | task message and resource surfaces | high-contrast translucent panels over artwork |
| Menus/dialogs | native role-based overlay surfaces | angular Angel frame, blur, focus/selection states |
| Header/sidebar/home | existing macOS Internet Angel surfaces | retain behavior, add strict theme isolation |

### Completion Pass: Windows-Only Component Delta

The first parity pass covered the always-visible task shell but did not carry
over every Windows classifier. The completion pass extends the same macOS-only
overlay contract to the remaining functional surfaces:

| Area | Components | Acceptance |
| --- | --- | --- |
| Left navigation | mode/search controls, new chat, utility rows, section toggles, project/thread rows | Windows pixel-console hover, selected, and section states without moving native navigation |
| Sidebar footer | profile trigger and help action | visually joined footer rail with intact native menus and hit areas |
| Composer palettes | Add/slash surface, scroll frame, headings, items | bespoke cyan/blue/pink palette replaces the native gray rounded surface |
| Thread navigation | turn rail, rows, markers, preview tooltip, scroll-to-bottom control | themed navigation and preview states without changing scrolling behavior |
| Settings | navigation, search, content surfaces, rows, controls, inputs, segments, app rows, menus | complete Windows settings grammar while preserving macOS control geometry |
| Bottom/right workspaces | terminal frame and tabs, output summary, side chat, collaboration | distinct broadcast frames and selected tab/status states |
| Selection and changes | selection actions, selected fragment, optional comment, edited file card/actions | semantic cyan/pink action hierarchy and readable diff states |
| System overlays | permissions, reset toast, tooltip, renderer menus/dialogs | consistent Angel portal treatment with native focus ownership |
| Subagents | frame, toolbar, sections, live/archive rows, more action | Windows collaboration status grammar and bounded scrolling |

Windows-only operating-system surfaces (tray menu, installer, native title-bar
buttons, window process handling) remain outside renderer parity. Existing
macOS Angel home/sidebar decoration is retained instead of mounting a second
copy of the Windows decorative broadcast layer; the completion criterion is
functional and visual parity, not duplicate DOM ornamentation.

## Dynamic Classification

The overlay classifier uses stable semantic attributes and bounded structure:

- stable roles/test IDs and existing selector-contract entries first;
- CSS module prefixes and durable utility-class combinations second;
- geometry only to distinguish right-docked/floating surfaces;
- localized visible text only as a last-resort corroborating signal, never as
  the sole selector.

Native nodes receive only `data-angel-component="..."` attributes. Decoration
nodes are renderer-owned, `aria-hidden`, and `pointer-events: none`.

The overlay watches route changes and bounded shell/portal mount points. It
must not observe streamed transcript descendants or perform continuous layout
reads. Refreshes are coalesced, and cleanup disconnects every observer and
timer before removing attributes and owned decoration.

The completion pass keeps one component attribute per node. Classifiers run in
specific-to-general order so a terminal, settings surface, or subagent panel is
not overwritten by the generic side-workspace marker. Portal classification is
also performed immediately after click/transition events, with the existing
coalesced refresh as the fallback.

## Styling Rules

Every overlay selector starts with both:

```css
html[data-dream-skin="active"][data-dream-theme="internet-angel"]
```

The palette follows the Windows reference: cyan `#63f4ff`, blue `#2054ff`,
pink `#ff45c8`, violet `#8258ff`, ink `#17132d`, and paper `#fff7ff`.
Geometry remains macOS-native unless a purely visual radius, border, shadow,
or internal spacing adjustment is required. Font sizes, hit areas, fixed header
position, composer width, scrolling, and z-index ownership remain native.

Reduced-motion mode removes decorative animation. Narrow-window rules reduce
ornamentation before compressing controls and never hide composer actions.

## Lifecycle And Failure Behavior

- Missing overlay assets fail payload construction before injection.
- A non-Internet-Angel theme never receives overlay CSS.
- Every payload executes overlay cleanup before deciding whether to install.
- Pause, theme switch, renderer replacement, and watcher exit remove all
  `data-angel-*` attributes, observers, timers, and owned nodes.
- A classifier miss leaves the native component untouched instead of applying
  a broad selector to an uncertain surface.

## Verification

Automated coverage must prove:

- exact allowlist activation for both Internet Angel IDs;
- no activation for Gothic, custom themes, or misleading display names;
- overlay assets are packaged and watched for live reload;
- existing Internet Angel home rules are theme-gated;
- composer and Environment fixture surfaces receive classifications;
- sidebar controls/footer, composer palette, turn navigation, settings,
  terminal/summary, selection, edited-card, and subagent fixtures receive their
  exact component classifications;
- cleanup removes all attributes and observers;
- no nested `:has()`, unsafe class pollution, broad transcript observer, or
  pointer-intercepting decoration is introduced;
- the existing macOS suite, Swift tests, payload checks, and release asset
  checks remain green.

Live acceptance uses the real Codex renderer at normal and narrow widths. A
passing screenshot must show the themed composer, goal chip, Environment card,
header/sidebar, and readable task content with no overlap or horizontal
overflow. Computed-style probes must confirm the native gray composer and
Environment backgrounds have been replaced only for Internet Angel.

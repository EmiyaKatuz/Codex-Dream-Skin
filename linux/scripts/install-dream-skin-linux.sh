#!/usr/bin/env bash

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-linux.sh"

PORT=9341
LAUNCH=true
while [ "$#" -gt 0 ]; do
  case "$1" in
    --port) PORT="${2:-}"; shift 2 ;;
    --no-launch) LAUNCH=false; shift ;;
    *) fail "Unknown argument: $1" ;;
  esac
done
case "$PORT" in ''|*[!0-9]*) fail 'Port must be numeric.' ;; esac
[ "$PORT" -ge 1024 ] && [ "$PORT" -le 65535 ] || fail 'Port must be between 1024 and 65535.'

require_node
discover_codex
codex_is_running && fail 'Close Codex before installation, then run this command again.'
ensure_state_root

temporary="$INSTALL_ROOT.installing.$$"
previous="$INSTALL_ROOT.previous.$$"
rm -rf "$temporary"
mkdir -p "$temporary"
cp -a "$PROJECT_ROOT/." "$temporary/"
rm -rf "$temporary/.git" "$temporary/release"
chmod 700 "$temporary/scripts/"*.sh
rm -rf "$previous"
[ ! -e "$INSTALL_ROOT" ] || mv "$INSTALL_ROOT" "$previous"
if ! mv "$temporary" "$INSTALL_ROOT"; then
  [ ! -e "$previous" ] || mv "$previous" "$INSTALL_ROOT"
  fail "Could not install the engine at $INSTALL_ROOT"
fi
rm -rf "$previous"

replace_legacy_default="$($NODE -e '
  try {
    const theme = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    process.stdout.write(String(theme.id === "custom-1784123441349" && theme.name === "Dream Skin"));
  } catch { process.stdout.write("false"); }
' "$THEME_DIR/theme.json")"
if [ ! -f "$THEME_DIR/theme.json" ] || [ "$replace_legacy_default" = true ]; then
  rm -f "$THEME_DIR/portal-hero.png"
  cp "$INSTALL_ROOT/assets/theme.json" "$THEME_DIR/theme.json"
  cp "$INSTALL_ROOT/assets/dream-reference.jpg" "$THEME_DIR/dream-reference.jpg"
  chmod 600 "$THEME_DIR/"*
fi
"$NODE" "$INSTALL_ROOT/scripts/injector.mjs" --check-payload --theme-dir "$THEME_DIR" >/dev/null
printf 'Codex Dream Skin %s installed at %s.\n' "$SKIN_VERSION" "$INSTALL_ROOT"
[ "$LAUNCH" = true ] && exec "$INSTALL_ROOT/scripts/start-dream-skin-linux.sh" --port "$PORT"

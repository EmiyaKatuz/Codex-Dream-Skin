#!/usr/bin/env bash

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-linux.sh"

require_node
ensure_state_root
PORT="$(state_port || true)"
stop_injector || fail 'Could not stop the recorded injector.'
if [ -n "$PORT" ] && cdp_ready "$PORT"; then
  "$NODE" "$INJECTOR" --remove --port "$PORT" --theme-dir "$THEME_DIR" --timeout-ms 8000 >/dev/null
fi
rm -f "$STATE_PATH"
desktop_file="${XDG_DATA_HOME:-$HOME/.local/share}/applications/Codex.desktop"
if [ -f "$desktop_file" ] && grep -Fqx 'X-Codex-Dream-Skin=true' "$desktop_file"; then
  rm -f "$desktop_file"
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$(dirname "$desktop_file")" || printf 'Warning: could not refresh the desktop entry cache.\n' >&2
  fi
fi
printf 'Codex Dream Skin was removed from the current Codex window.\n'

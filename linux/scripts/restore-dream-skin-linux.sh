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
printf 'Codex Dream Skin was removed from the current Codex window.\n'

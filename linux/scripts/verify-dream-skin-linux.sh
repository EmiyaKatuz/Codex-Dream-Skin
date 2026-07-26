#!/usr/bin/env bash

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-linux.sh"

require_node
ensure_state_root
PORT="$(state_port || true)"
[ -n "$PORT" ] || fail 'No active Dream Skin state was found.'
cdp_ready "$PORT" || fail "Codex CDP is unavailable on port $PORT."
exec "${INJECTOR_ENV[@]}" "$NODE" "$INJECTOR" --verify --port "$PORT" --theme-dir "$THEME_DIR" --timeout-ms 30000

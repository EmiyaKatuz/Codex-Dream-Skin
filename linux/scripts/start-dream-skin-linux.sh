#!/usr/bin/env bash

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-linux.sh"

PORT=9341
while [ "$#" -gt 0 ]; do
  case "$1" in
    --port) PORT="${2:-}"; shift 2 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done
case "$PORT" in ''|*[!0-9]*) fail 'Port must be numeric.' ;; esac
require_node
discover_codex
ensure_state_root
# An upgraded engine must not race a watcher that has an older renderer
# template in memory. Stop it before the first payload is built.
stop_injector || fail 'Could not stop the previous injector.'

if ! cdp_ready "$PORT"; then
  codex_is_running && fail 'Codex is already running without the Dream Skin CDP port. Close it, then run start again.'
  nohup "$CODEX_EXE" --remote-debugging-address=127.0.0.1 --remote-debugging-port="$PORT" \
    >>"$STATE_ROOT/codex-launch.log" 2>>"$STATE_ROOT/codex-launch-error.log" &
  wait_for_cdp "$PORT" || fail "Codex did not expose CDP on 127.0.0.1:$PORT within 45 seconds."
fi

"$NODE" "$INJECTOR" --once --reload --port "$PORT" --theme-dir "$THEME_DIR" --timeout-ms 30000 >/dev/null
nohup "$NODE" "$INJECTOR" --watch --port "$PORT" --theme-dir "$THEME_DIR" \
  >>"$LOG_PATH" 2>>"$ERROR_LOG" &
pid=$!
sleep 0.2
kill -0 "$pid" 2>/dev/null || fail "Injector failed to start; see $ERROR_LOG"
write_state "$PORT" "$pid"
printf 'Codex Dream Skin applied on loopback CDP port %s.\n' "$PORT"

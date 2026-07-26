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
launcher_started_ms="$(date +%s%3N)"
codex_gpu_args=()
# Chromium's Vulkan surface path is incompatible with native Wayland in the
# current Electron runtime. Keep GPU compositing on the OpenGL/ANGLE fallback.
if [ "${XDG_SESSION_TYPE:-}" = wayland ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
  codex_gpu_args+=(--disable-features=Vulkan)
fi
printf '[dream-skin] timing %s launcher-start {"pid":%s}\n' \
  "$(date '+%Y-%m-%dT%H:%M:%S.%3N%:z')" "$$" >>"$LOG_PATH"
# An upgraded engine must not race a watcher that has an older renderer
# template in memory. Stop it before the first payload is built.
stop_injector || fail 'Could not stop the previous injector.'
printf '[dream-skin] timing %s launcher-cleanup-finished {"elapsedMs":%s}\n' \
  "$(date '+%Y-%m-%dT%H:%M:%S.%3N%:z')" "$(( $(date +%s%3N) - launcher_started_ms ))" >>"$LOG_PATH"

if ! cdp_ready "$PORT"; then
  codex_is_running && fail 'Codex is already running without the Dream Skin CDP port. Close it, then run start again.'
  nohup "$CODEX_EXE" "${codex_gpu_args[@]}" \
    --remote-debugging-address=127.0.0.1 --remote-debugging-port="$PORT" \
    >>"$STATE_ROOT/codex-launch.log" 2>>"$STATE_ROOT/codex-launch-error.log" &
  printf '[dream-skin] timing %s codex-launch-requested {"elapsedMs":%s,"vulkanDisabled":%s}\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S.%3N%:z')" "$(( $(date +%s%3N) - launcher_started_ms ))" \
    "$([ "${#codex_gpu_args[@]}" -gt 0 ] && printf true || printf false)" >>"$LOG_PATH"
fi

nohup "${INJECTOR_ENV[@]}" "$NODE" "$INJECTOR" --watch --port "$PORT" --theme-dir "$THEME_DIR" \
  >>"$LOG_PATH" 2>>"$ERROR_LOG" &
pid=$!
printf '[dream-skin] timing %s watcher-launch-requested {"elapsedMs":%s,"pid":%s}\n' \
  "$(date '+%Y-%m-%dT%H:%M:%S.%3N%:z')" "$(( $(date +%s%3N) - launcher_started_ms ))" "$pid" >>"$LOG_PATH"
sleep 0.2
kill -0 "$pid" 2>/dev/null || fail "Injector failed to start; see $ERROR_LOG"
write_state "$PORT" "$pid"
printf 'Codex Dream Skin is waiting for the verified Codex shell on loopback CDP port %s.\n' "$PORT"

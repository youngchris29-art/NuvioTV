#!/bin/bash
# NuvioTV device rig: launch the Debug device build with its console streamed to a log file.
#   console.sh start [log-path] [-- app args…]   # launches com.youngchris29.NuvioTV with --console
#   console.sh stop                              # ends the stream AND THE APP (SIGTERM to the devicectl
#                                                # stream ends the launched process: "App terminated due to signal 15")
#   console.sh tail [n]                          # last n lines of the current log
#   console.sh grep <pattern>                    # grep the current log
# Recipe from the 09-30 device walks: devicectl process launch --terminate-existing --console
# keeps stdout/NSLog lines UNTRUNCATED (the About pane's lineLimit(1) loses them). App args
# go after `--` (e.g. -- -debug.homeScrollProbe YES). The stream dies when the app exits.
set -euo pipefail
CONF="${NUVIOTV_DEVICE_CONF:-$HOME/.config/nuviotv-device}"
# shellcheck disable=SC1091
source "$CONF/atv.env"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE="${NUVIOTV_BUNDLE:-com.youngchris29.NuvioTV}"
PIDFILE="$CONF/console.pid"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 2026-11-09: start relaunches the app and stop kills it, so both respect the box lock (lock.sh).
case "${1:-}" in
  start|stop) "$HERE/lock.sh" check box || { echo "console.sh: refusing '$1' while another project holds the box (scripts/device/lock.sh who)" >&2; exit 75; } ;;
esac
cmd="${1:-}"; shift || true
case "$cmd" in
  start)
    log=""; if [[ "${1:-}" != "--" && -n "${1:-}" ]]; then log="$1"; shift; fi
    [[ "${1:-}" == "--" ]] && shift
    if [[ -z "$log" ]]; then d="$ROOT/docs/research/device-rig-$(date +%F)"; mkdir -p "$d"; log="$d/console-$(date +%H%M%S).log"; fi
    mkdir -p "$(dirname "$log")"; echo "$log" > "$PIDFILE.path"
    # devicectl needs `--` before the app's own arguments (otherwise it parses them as its own flags)
    nohup xcrun devicectl device process launch --device "$ATV_UDID" --terminate-existing --console "$BUNDLE" ${1:+--} "$@" > "$log" 2>&1 &
    echo $! > "$PIDFILE"; echo "console → $log (pid $(cat "$PIDFILE"))" ;;
  stop)
    # Wait for the stream process to exit: a devicectl stream killed mid-write prints its last
    # "App terminated due to signal 15" lines at its OLD offset, which punches NULs into a log
    # that a following `start` has already truncated and reused (seen 2026-10-16).
    [[ -f "$PIDFILE" ]] && { p="$(cat "$PIDFILE")"; kill "$p" 2>/dev/null || true; for _ in $(seq 1 40); do kill -0 "$p" 2>/dev/null || break; sleep 0.25; done; rm -f "$PIDFILE"; }
    [[ -f "$PIDFILE.path" ]] && { cat "$PIDFILE.path"; rm -f "$PIDFILE.path"; } ;;
  tail) tail -n "${1:-40}" "$(cat "$PIDFILE.path")" ;;
  grep) grep -n -E "${1:?pattern}" "$(cat "$PIDFILE.path")" ;;
  *) sed -n 2,9p "$0"; exit 64 ;;
esac

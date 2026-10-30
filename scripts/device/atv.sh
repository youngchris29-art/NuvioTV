#!/bin/bash
# NuvioTV device rig: drive the Living Room Apple TV through pyatv's Companion protocol.
#
#   atv.sh press up|down|left|right|select|menu|home|play_pause [repeat] [gap_s]
#   atv.sh hold  <button> [seconds]         # press-and-hold for N seconds (FF/RW scan, hold menus)
#   atv.sh seq   <step>…                    # several inputs over one connection, see atvctl.py
#                                            # e.g. seq 'waitlog=[UpNext] search begin|<log>|600' menu
#   atv.sh swipe x0 y0 x1 y1 [ms]           # Siri Remote swipe on the 0..1000 touch surface
#   atv.sh click [0|1|2]                    # touch click: single / double / hold
#   atv.sh touch x y 1|3|4                  # raw touch press / hold / release at x,y
#   atv.sh wake | sleep | features | app | apps | launch <bundle-id> | raw <atvremote args…>
#
# Credentials and addresses live outside the repo in ~/.config/nuviotv-device/
# (atv.env + atv-credentials, written by pair.py). The Companion port is re-resolved
# from Bonjour on every call because tvOS picks a new one after a reboot.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${NUVIOTV_DEVICE_CONF:-$HOME/.config/nuviotv-device}"
# shellcheck disable=SC1091
source "$CONF/atv.env"
CREDS="$(cat "$ATV_CREDENTIALS_FILE")"
ATVREMOTE="$HERE/.venv/bin/atvremote"

# 2026-10-30: the box drops its IPv4 path (ping 100% loss, ARP incomplete) while IPv6 can stay up
# (rig lessons 2026-10-21). atvctl.py already fell back to the link-local IPv6 on its own; this
# gives the atvremote paths (`run`, ready.sh's Companion check) the same fallback. Fast path: one
# 1 s TCP probe of the configured address; only when it fails is atvctl.reachable_address asked
# (it prints "[atvctl] IPv4 … unreachable; using IPv6 …" on stderr, and returns the configured
# address unchanged when no IPv6 path works either).
pick_address() {
  local probe_port="$1" addr
  if nc -z -G 1 "$ATV_ADDRESS" "$probe_port" >/dev/null 2>&1; then
    echo "$ATV_ADDRESS"; return
  fi
  addr="$("$HERE/.venv/bin/python" -c '
import sys
sys.path.insert(0, sys.argv[1])
import atvctl
print(atvctl.reachable_address(sys.argv[2], int(sys.argv[3]), sys.argv[4]))' \
    "$HERE" "$ATV_ADDRESS" "$probe_port" "${ATV_HOST:-}" || true)"
  echo "${addr:-$ATV_ADDRESS}"
}

# The Companion port Bonjour advertises (empty when mDNS has no answer).
advertised_port() {
  local line
  line="$(timeout 3 dns-sd -L "$ATV_NAME" _companion-link._tcp local. 2>/dev/null | grep -m1 'can be reached at' || true)"
  if [[ "$line" =~ :([0-9]+)\ \(interface ]]; then echo "${BASH_REMATCH[1]}"; fi
}
ADV="$(advertised_port)"
ADDR="$(pick_address "${ADV:-$ATV_COMPANION_PORT}")"
# mDNS can keep serving the pre-restart port (2026-10-19: 61193 refused, the box listened on
# 49153), so use the advertised port only if it accepts a connection.
if [[ -n "$ADV" ]] && nc -z -G 2 "$ADDR" "$ADV" >/dev/null 2>&1; then
  PORT="$ADV"
else
  PORT="$ATV_COMPANION_PORT"
fi

run() {
  "$ATVREMOTE" --manual --address "$ADDR" --port "$PORT" --protocol companion \
    --id "$ATV_ID" --companion-credentials "$CREDS" "$@"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  press)
    # timed presses (PRESS_MS, default 100 ms) over one connection; see atvctl.py for why not atvremote's 0 ms press
    btn="${1:?button}"; n="${2:-1}"; gap="${3:-0.4}"; steps=()
    for ((i = 0; i < n; i++)); do steps+=("$btn"); (( i + 1 < n )) && steps+=("sleep=$gap"); done
    ATV_PORT_OVERRIDE="$PORT" "$HERE/.venv/bin/python" "$HERE/atvctl.py" "${steps[@]}" ;;
  hold)
    btn="${1:?button}"; secs="${2:-1}"
    ATV_PORT_OVERRIDE="$PORT" "$HERE/.venv/bin/python" "$HERE/atvctl.py" "hold=$btn,$secs" ;;
  seq)
    ATV_PORT_OVERRIDE="$PORT" "$HERE/.venv/bin/python" "$HERE/atvctl.py" "$@" ;;
  swipe)
    x0="${1:?x0}"; y0="${2:?y0}"; x1="${3:?x1}"; y1="${4:?y1}"; ms="${5:-200}"
    run "swipe=$x0,$y0,$x1,$y1,$ms" ;;
  click)
    mode="${1:-0}"   # 0 single tap, 1 double tap, 2 hold
    run "touch_click=$mode" ;;
  touch)
    x="${1:?x}"; y="${2:?y}"; mode="${3:?mode 1 press|3 hold|4 release}"
    run "touch_action=$x,$y,$mode" ;;
  wake)   run turn_on ;;
  sleep)  run turn_off ;;
  features) run features ;;
  app)    run app ;;
  apps)   run app_list ;;
  launch) run "launch_app=${1:?bundle-id}" ;;
  raw)    run "$@" ;;
  *) sed -n 2,11p "$0"; exit 64 ;;
esac

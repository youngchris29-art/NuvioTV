#!/bin/bash
# NuvioTV device rig: is the Living Room Apple TV ready for a device pass?
#
#   scripts/device/ready.sh --project <name> [--eta <text>] [--no-wake] [--walk] [--no-launch] [--timeout <s>]
#
# Run this ONCE before any device pass, install or walk. It wakes the TV if it is asleep,
# waits a bounded time for the devicectl tunnel, confirms Companion pairing, reports the
# installed build and the signing-profile expiry, and prints one READY or one REFUSED line.
# It never loops beyond --timeout. If it refuses, say so once and stop; do not retry on a loop.
#
#   exit 0  READY
#   exit 1  REFUSED (TV unreachable, not paired, tunnel down, Companion broken)
#   exit 2  rig config missing (~/.config/nuviotv-device) or no --project
#   exit 3  BUSY: another project holds the box lock (lock.sh who / lock.sh wait)
#
#   --no-wake    only check; never send the wake command (the TV screen may turn on with it)
#   --project N  the batch or clone name that will hold the box lock (or NUVIO_PROJECT); required
#   --eta T      when you expect to release the box (free text, shown to whoever waits)
#   --walk       after READY: launch the app with its console if it is not running, take a
#                "pre" settings snapshot, then run preflight.sh (app pid, console, Test profile)
#   --no-launch  with --walk, keep the old behaviour: refuse instead of launching
#   --timeout N  seconds to wait for the tunnel after waking (default 60)
#
# Pairs with scripts/device/preflight.sh, which gates a WALK (app pid, console log, profile).
# This script gates the DEVICE. Credentials stay in ~/.config/nuviotv-device/, never printed.
# 2026-11-09: takes the box lock for --project (lock.sh; BUSY = exit 3, never pkill the holder),
# starts keep-awake.sh for 4 h, and with --walk launches instead of refusing. End the pass
# with scripts/device/done.sh <project> (settings diff, Home, lock release).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${NUVIOTV_DEVICE_CONF:-$HOME/.config/nuviotv-device}"
BUNDLE="${NUVIOTV_BUNDLE:-com.youngchris29.NuvioTV}"
WAIT=60; WAKE=1; WALK=0; LAUNCH=1; PROJECT="${NUVIO_PROJECT:-}"; ETA=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-wake) WAKE=0 ;;
    --walk) WALK=1 ;;
    --no-launch) LAUNCH=0 ;;
    --project) PROJECT="${2:?name}"; shift ;;
    --eta) ETA="${2:?text}"; shift ;;
    --timeout) WAIT="${2:?seconds}"; shift ;;
    -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
    *) echo "ready.sh: unknown flag $1" >&2; exit 2 ;;
  esac
  shift
done

refuse() { echo "DEVICE REFUSED: $*"; exit 1; }
note()   { echo "  - $*"; }
T() { if command -v timeout >/dev/null 2>&1; then timeout "$@"; else shift; "$@"; fi; }

# 1. Rig config present (names only; values are never echoed).
[[ -f "$CONF/atv.env" ]] || { echo "DEVICE CONFIG MISSING: $CONF/atv.env (see docs/device-rig-2026-10-15.md, Pairing)"; exit 2; }
# shellcheck disable=SC1091
source "$CONF/atv.env"
for v in ATV_NAME ATV_UDID ATV_CREDENTIALS_FILE; do
  [[ -n "${!v:-}" ]] || { echo "DEVICE CONFIG MISSING: $v is not set in $CONF/atv.env"; exit 2; }
done
[[ -f "$ATV_CREDENTIALS_FILE" ]] || { echo "DEVICE CONFIG MISSING: Companion credentials file (run scripts/device/pair.py)"; exit 2; }

# 1b. Box ownership. One project at a time; everyone else waits on the lock, not on Christian.
[[ -n "$PROJECT" ]] || { echo "DEVICE REFUSED: name the project that will hold the box: ready.sh --project <batch-or-clone-name> (or NUVIO_PROJECT)"; exit 2; }
if ! "$HERE/lock.sh" take box "$PROJECT" ${ETA:+--eta "$ETA"}; then
  echo "DEVICE BUSY: say so once in the thread and wait (scripts/device/lock.sh wait box $PROJECT --timeout 1800); never kill the holder's processes"; exit 3
fi
export NUVIO_PROJECT="$PROJECT"
"$HERE/keep-awake.sh" start 4 >/dev/null 2>&1 && note "keep-awake: Mac held awake for 4 h (scripts/device/keep-awake.sh status)"

# 2. Is devicectl connected to the box? Wake once and wait a bounded time if not.
state() {
  T 30 xcrun devicectl list devices 2>/dev/null | awk -v id="$ATV_UDID" '
    index($0, id) { s = $0; sub(/.*\(UDID\)[ \t]+/, "", s); split(s, f, /[ \t][ \t]+/); print f[1]; exit }'
}
st="$(state)"
# "available (paired)" is devicectl's idle state: the box is on the network but the tunnel
# opens only on demand. One call that needs the tunnel brings it up (2026-10-19: list alone never did).
if [[ "$st" == "available (paired)" ]]; then
  T 60 xcrun devicectl device info apps --device "$ATV_UDID" >/dev/null 2>&1 || true
  st="$(state)"
fi
if [[ "$st" != "connected" ]]; then
  if (( WAKE )); then
    echo "Apple TV '$ATV_NAME' is ${st:-not listed}; sending wake over Companion and waiting up to ${WAIT}s"
    T 25 "$HERE/atv.sh" wake >/dev/null 2>&1 || note "wake command did not get an acknowledgement (the box may still be coming up)"
    deadline=$(( SECONDS + WAIT ))
    while (( SECONDS < deadline )); do
      sleep 5
      st="$(state)"
      [[ "$st" == "connected" ]] && break
    done
  fi
  if (( WAKE )); then waited="after a wake and ${WAIT}s"; else waited="(wake disabled by --no-wake)"; fi
  [[ "$st" == "connected" ]] || refuse "Apple TV '$ATV_NAME' is ${st:-not listed} $waited: asleep, off the network, or unplugged. Ask Christian to wake it; do not retry on a loop."
fi

# 3. devicectl pairing and tunnel.
details="$(T 40 xcrun devicectl device info details --device "$ATV_UDID" 2>/dev/null)"
grep -q "Pairing State: paired" <<<"$details" || refuse "devicectl reports the box as not paired (Settings > Remotes and Devices > Remote App and Devices)"
tunnel="$(grep -o 'Tunnel IP Address: .*' <<<"$details" | head -1 | awk '{print $NF}')"
[[ -n "$tunnel" ]] || refuse "devicectl tunnel is down although the box is connected; wait ~20 s and run ready.sh once more, then stop"
os="$(grep -o 'OS Version: .*' <<<"$details" | head -1 | awk '{print $NF}')"

# 4. Companion pairing (pyatv), the input path for walks.
if ! T 25 "$HERE/atv.sh" features 2>/dev/null | grep -q "Feature list:"; then
  refuse "Companion pairing is broken (atv.sh features failed). Re-pair with scripts/device/pair.py; the PIN is readable off a screenshot."
fi

# 5. Installed build (informational; a fresh install may follow).
app="$(T 40 xcrun devicectl device info apps --device "$ATV_UDID" 2>/dev/null | awk -v b="$BUNDLE" '$2 == b {print "version " $3 " build " $4; exit}')"
# 6. Signing profile expiry (7-day free-team profile), informational.
expiry=""
for dir in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" "$HOME/Library/MobileDevice/Provisioning Profiles"; do
  [[ -d "$dir" ]] || continue
  for p in "$dir"/*.mobileprovision; do
    [[ -f "$p" ]] || continue
    plist="$(security cms -D -i "$p" 2>/dev/null)" || continue
    grep -q "$BUNDLE" <<<"$plist" || continue
    e="$(plutil -extract ExpirationDate raw - <<<"$plist" 2>/dev/null)"
    [[ -n "$e" && ( -z "$expiry" || "$e" > "$expiry" ) ]] && expiry="$e"
  done
done

echo "DEVICE READY: '$ATV_NAME' connected, paired, tunnel up, Companion ok${os:+, tvOS $os}"
note "app: ${app:-$BUNDLE not installed (device build + devicectl install comes next)}"
if [[ -n "$expiry" ]]; then
  if [[ "$(date -u -v+1d +%Y-%m-%dT%H:%M:%SZ)" > "$expiry" ]]; then
    note "signing profile for $BUNDLE expires $expiry (<24 h): build with -allowProvisioningUpdates and delete stale youngchris29 profiles if it fails"
  else
    note "signing profile ok until $expiry"
  fi
else
  note "no signing profile for $BUNDLE found locally; the device build will create one (-allowProvisioningUpdates)"
fi
note "profile for every device step: the Test profile (\"Test 2\" on this box, TEST_PROFILE_INDEX=${TEST_PROFILE_INDEX:-3}); never \"Chris\""

if (( WALK )); then
  # Launch instead of refusing (2026-11-09): the old gate stopped on "app not running" and
  # waited for a go that only ever said "launch it". A dead console stream is launched too,
  # since the walk needs the stream and console.sh start relaunches the app anyway.
  pid="$(T 40 xcrun devicectl device info processes --device "$ATV_UDID" 2>/dev/null | awk '$2 ~ /NuvioTV\.app\/NuvioTV$/ {print $1}')"
  stream_ok=0; [[ -f "$CONF/console.pid" ]] && kill -0 "$(cat "$CONF/console.pid")" 2>/dev/null && stream_ok=1
  if [[ -z "$pid" || $stream_ok -eq 0 ]]; then
    if (( LAUNCH )); then
      echo "launching $BUNDLE with its console (app ${pid:+running without a stream}${pid:-not running})"
      "$HERE/console.sh" start >/dev/null || note "console.sh start failed; preflight will say why"
      for _ in $(seq 1 10); do
        sleep 2
        pid="$(T 40 xcrun devicectl device info processes --device "$ATV_UDID" 2>/dev/null | awk '$2 ~ /NuvioTV\.app\/NuvioTV$/ {print $1}')"
        [[ -n "$pid" ]] && break
      done
      [[ -n "$pid" ]] && note "app launched (pid $pid); if the profile picker is showing, select the Test profile (\"Test 2\") before the first step" || note "app did not come up within 20 s"
    else
      note "--no-launch: app or console stream missing; preflight will refuse"
    fi
  fi
  snap="$("$HERE/settings-snapshot.sh" take pre 2>&1)" && note "$snap (done.sh diffs against it)" || note "${snap#SNAPSHOT FAILED: }"
  echo "running preflight.sh (walk gate)"
  exec "$HERE/preflight.sh"
fi
exit 0

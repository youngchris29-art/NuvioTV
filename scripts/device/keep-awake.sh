#!/bin/bash
# NuvioTV rig: keep the Mac awake while a remote session drives a long build, review loop or
# device pass (the Mac dropped offline four times on 2026-11-08, once right after the box
# was freed). One caffeinate per Mac, with a pid file, so sessions renew rather than stack.
#
#   keep-awake.sh start [hours]    # default 4 h; renews (restarts the timer) if already running
#   keep-awake.sh stop
#   keep-awake.sh status
#
# caffeinate -d (display) -i (idle sleep) -m (disk) -s (system, on AC) -t <seconds>. This does
# not change any System Settings; for unattended runs Christian also turns on
# System Settings › Battery › Options › "Prevent automatic sleeping on power adapter when the
# display is off" once, by hand.
set -uo pipefail
CONF="${NUVIOTV_DEVICE_CONF:-$HOME/.config/nuviotv-device}"; mkdir -p "$CONF"
PIDFILE="$CONF/caffeinate.pid"
alive() { [[ -f "$PIDFILE" ]] && kill -0 "$(cut -d' ' -f1 "$PIDFILE")" 2>/dev/null; }
case "${1:-status}" in
  start)
    hours="${2:-4}"; secs=$(( hours * 3600 ))
    if alive; then kill "$(cut -d' ' -f1 "$PIDFILE")" 2>/dev/null; sleep 0.2; fi   # our own pid, from our pid file
    nohup caffeinate -dims -t "$secs" >/dev/null 2>&1 &
    echo "$! $(date -u -v+"${secs}"S +%Y-%m-%dT%H:%M:%SZ)" > "$PIDFILE"
    echo "keep-awake: caffeinate pid $! for ${hours} h (until $(cut -d' ' -f2 "$PIDFILE"))" ;;
  stop)
    if alive; then kill "$(cut -d' ' -f1 "$PIDFILE")" 2>/dev/null; echo "keep-awake: stopped"; else echo "keep-awake: not running"; fi
    rm -f "$PIDFILE" ;;
  status)
    if alive; then echo "keep-awake: running (pid $(cut -d' ' -f1 "$PIDFILE"), until $(cut -d' ' -f2 "$PIDFILE"))"; else echo "keep-awake: not running"; exit 1; fi ;;
  *) sed -n '2,8p' "$0"; exit 2 ;;
esac

#!/bin/bash
# NuvioTV rig: who owns the Living Room box, the FA87 fixture simulator and the build slot.
#
#   lock.sh take    box <project> [--eta <text>] [--ttl <hours>] [--force]
#   lock.sh release box <project> [--force]
#   lock.sh wait    box <project> [--timeout <s>] [--eta <text>]   # bounded poll, then take
#   lock.sh check   box                                            # 0 free or ours, 1 held by another
#   lock.sh who     [box|sim|build]                                # print every holder
#
# The BOX lock is a lease: one file under ~/Claude/Projects that names the project holding the
# Living Room Apple TV, when it took it and when it expects to be done. It spans a whole device
# pass (many commands), so it is take/release, not wrap-one-command. ready.sh takes it,
# done.sh releases it, and atv.sh / console.sh refuse to act while another project holds it.
# A lease older than --ttl (default 6 h) counts as abandoned and may be taken over; the
# takeover is printed so the previous holder sees it in its own next call.
#
# The SIM and BUILD locks are the existing flocks (scripts/build/with-sim-lock.sh and
# with-lock.sh). `who` reads their holder line and whether that pid is still alive; take and
# release do not apply to them (wrap the command instead).
#
# Project names: the batch or clone name ("hub-v2c", "picker-25", "chris"). NUVIO_PROJECT in
# the environment is the default for every subcommand. Rules: kill only PIDs you started; a
# lock held by another project is a reason to wait or ask in the thread, never to pkill.
set -uo pipefail

LOCKDIR="${NUVIO_LOCK_DIR:-$HOME/Claude/Projects}"
BOX_LOCK="$LOCKDIR/.box.lock"
SIM_LOCK="${SIM_LOCK:-$LOCKDIR/.sim-FA87.lock}"
BUILD_LOCK="${BUILD_LOCK:-$LOCKDIR/.build.lock}"
TTL_H=6

cmd="${1:-}"; shift || true
res="${1:-}"; [[ -n "$res" && "$res" != --* ]] && shift
project="${1:-}"; [[ -n "$project" && "$project" != --* ]] && shift
project="${project:-${NUVIO_PROJECT:-}}"
eta="" ; force=0; timeout_s=1800
while [[ $# -gt 0 ]]; do
  case "$1" in
    --eta) eta="${2:?text}"; shift ;;
    --ttl) TTL_H="${2:?hours}"; shift ;;
    --timeout) timeout_s="${2:?seconds}"; shift ;;
    --force) force=1 ;;
    *) echo "lock.sh: unknown flag $1" >&2; exit 2 ;;
  esac
  shift
done

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }
age_s() {  # seconds since the lease's taken= stamp
  local t; t="$(sed -n 's/^taken=//p' "$BOX_LOCK" 2>/dev/null)"
  [[ -n "$t" ]] || { echo 0; return; }
  local then; then="$(date -j -u -f %Y-%m-%dT%H:%M:%SZ "$t" +%s 2>/dev/null || echo 0)"
  echo $(( $(date -u +%s) - then ))
}
hm() { printf '%dh%02dm' $(( $1 / 3600 )) $(( ($1 % 3600) / 60 )); }
field() { sed -n "s/^$1=//p" "$BOX_LOCK" 2>/dev/null; }
box_state() {
  if [[ ! -f "$BOX_LOCK" ]]; then echo "box: free"; return; fi
  local o a; o="$(field owner)"; a="$(age_s)"
  local stale=""; (( a > TTL_H * 3600 )) && stale=" (STALE: over ${TTL_H} h, may be taken over)"
  echo "box: held by '$o' since $(field taken) ($(hm "$a") ago), eta: $(field eta)$stale"
}
flock_state() {  # <label> <file>: the holder line is "<pid> <command>", written by the wrapper
  local label="$1" f="$2" line pid
  [[ -s "$f" ]] || { echo "$label: free"; return; }
  line="$(head -1 "$f")"; pid="${line%% *}"
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    echo "$label: held by pid $pid: ${line#* }"
  else
    echo "$label: free (last holder pid ${pid:-?} has exited)"
  fi
}
write_lease() {
  umask 022
  printf 'owner=%s\ntaken=%s\neta=%s\nhost=%s\n' "$project" "$(now_iso)" "${eta:-unknown}" "$(hostname -s)" > "$BOX_LOCK.$$" \
    && mv -f "$BOX_LOCK.$$" "$BOX_LOCK"
}
need_project() { [[ -n "$project" ]] || { echo "lock.sh: name the project (argument or NUVIO_PROJECT)" >&2; exit 2; }; }
need_box() { [[ "$res" == "box" ]] || { echo "lock.sh: only the box lock is take/release; the sim and build locks wrap a command (scripts/build/with-sim-lock.sh, with-lock.sh)" >&2; exit 2; }; }

take_box() {
  if [[ -f "$BOX_LOCK" ]]; then
    local o; o="$(field owner)"
    if [[ "$o" == "$project" ]]; then
      write_lease; echo "box: renewed by '$project' (eta ${eta:-unknown})"; return 0
    fi
    local a; a="$(age_s)"
    if (( a > TTL_H * 3600 )) || (( force )); then
      local why="stale $(hm "$a")"; (( force )) && why="--force"
      write_lease; echo "box: TAKEN OVER from '$o' ($why) by '$project' (eta ${eta:-unknown}); tell the thread"; return 0
    fi
    echo "BOX BUSY: $(box_state)"
    echo "  wait with: scripts/device/lock.sh wait box $project --timeout 1800, or ask in the thread; never kill their processes"
    return 1
  fi
  write_lease; echo "box: taken by '$project' at $(field taken) (eta ${eta:-unknown})"
}

case "$cmd" in
  take)
    need_box; need_project; take_box ;;
  release)
    need_box; need_project
    if [[ ! -f "$BOX_LOCK" ]]; then echo "box: already free"; exit 0; fi
    o="$(field owner)"
    if [[ "$o" != "$project" && $force -eq 0 ]]; then
      echo "box: held by '$o', not '$project'; not released (use --force only if you know they are done)"; exit 1
    fi
    rm -f "$BOX_LOCK"; echo "box: released by '$project'${o:+ (was '$o')}" ;;
  wait)
    need_box; need_project
    deadline=$(( SECONDS + timeout_s ))
    while :; do
      if take_box >/dev/null 2>&1; then echo "box: taken by '$project' (eta ${eta:-unknown})"; exit 0; fi
      (( SECONDS < deadline )) || { echo "BOX BUSY after ${timeout_s}s: $(box_state)"; echo "  stop here and say so once; do not retry on a loop"; exit 1; }
      sleep 30
    done ;;
  check)
    need_box
    [[ -f "$BOX_LOCK" ]] || exit 0
    o="$(field owner)"
    [[ -n "$project" && "$o" == "$project" ]] && exit 0
    [[ "${NUVIO_LOCK_BYPASS:-0}" == "1" ]] && exit 0
    echo "BOX BUSY: $(box_state)"
    if [[ -z "$project" ]]; then echo "  set NUVIO_PROJECT=<your project> after taking the lock (scripts/device/ready.sh --project <name>)"; fi
    exit 1 ;;
  who|"")
    case "${res:-all}" in
      box) box_state ;;
      sim) flock_state "sim FA87" "$SIM_LOCK" ;;
      build) flock_state "build" "$BUILD_LOCK" ;;
      all) box_state; flock_state "sim FA87" "$SIM_LOCK"; flock_state "build" "$BUILD_LOCK" ;;
      *) echo "lock.sh: unknown resource '$res' (box|sim|build)" >&2; exit 2 ;;
    esac ;;
  -h|--help) sed -n '2,26p' "$0" ;;
  *) echo "lock.sh: unknown command '$cmd'" >&2; sed -n '2,8p' "$0" >&2; exit 2 ;;
esac

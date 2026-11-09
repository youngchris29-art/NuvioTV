#!/bin/bash
# NuvioTV rig: end a device pass the same way every time.
#
#   done.sh <project> [--keep-app]
#
# 1. Diffs the Test-profile settings against the pre-pass snapshot (settings-snapshot.sh) and
#    prints every key that changed, so a toggle the walk flipped can be restored before the box
#    goes back to daily use. The diff is printed, not fixed: restore by hand or by atv.sh steps,
#    then run it again until "no differences".
# 2. Sends Home so the box rests on the tvOS home screen (the app stays installed and in the
#    background; --keep-app skips the Home press). Picking Christian's tvOS user back is a
#    remote-only step on this box, so the pass note says if the user picker was left showing.
# 3. Releases the box lock for the project (lock.sh release).
# The console stream is left running: console.sh stop also kills the app.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project="${1:-${NUVIO_PROJECT:-}}"; [[ -n "$project" && "$project" != --* ]] && shift
[[ -n "$project" ]] || { echo "done.sh: name the project (argument or NUVIO_PROJECT)" >&2; exit 2; }
keep=0; [[ "${1:-}" == "--keep-app" ]] && keep=1
export NUVIO_PROJECT="$project"
rc=0
echo "== settings"
"$HERE/settings-snapshot.sh" diff || { r=$?; (( r == 1 )) && rc=1; (( r == 2 )) && echo "  (no pre-pass snapshot or copy failed; nothing to compare)"; }
if (( ! keep )); then
  echo "== home"
  if "$HERE/atv.sh" press home >/dev/null 2>&1; then echo "  Home sent; the box rests on the tvOS home screen"; else echo "  Home press failed (box asleep or Companion down); say so in the pass note"; fi
fi
echo "== lock"
"$HERE/lock.sh" release box "$project"
(( rc )) && echo "DONE WITH DIFFERENCES: restore the Test profile settings listed above, then run settings-snapshot.sh diff again"
exit $rc

#!/bin/bash
# NuvioTV rig: one tvOS simulator per project, so UI legs from two sessions never collide.
#
#   sim.sh clone  <project> [--from <udid>]   # "NuvioTV <project>" cloned from the template
#   sim.sh list                                # every NuvioTV sim with state and udid
#   sim.sh udid   <project>                    # the udid, for -destination 'platform=tvOS Simulator,id=…'
#   sim.sh boot   <project>                    # boot your own clone (never someone else's)
#   sim.sh delete <project>                    # delete your clone when the batch lands
#   sim.sh template                            # (re)create the shut-down template from FA87
#
# FA87E9B6-… stays the fixture for the FINAL gate; every other run goes on a clone. simctl
# refuses to clone a booted device (seen 2026-11-09), and FA87 is booted most of the day by
# whoever holds the sim lock, so clones come from a shut-down TEMPLATE ("NuvioTV template")
# that is itself a clone of FA87. The template is made once while FA87 is shut down (or from a
# shut-down clone with --from); it is never booted. A clone is still a concrete arm64
# destination, so Release builds link (the generic destination does not; CLAUDE.md).
#
# Never shuts down or deletes a sim it did not create in this call: boot/delete act only on
# "NuvioTV <project>" sims, and FA87 and the template are refused.
set -uo pipefail

FIXTURE="${NUVIO_FIXTURE_SIM:-FA87E9B6-F28D-4DF9-84E4-A5A4C5DBFC4E}"
TEMPLATE_NAME="NuvioTV template"

cmd="${1:-}"; shift || true
project="${1:-}"; [[ -n "$project" && "$project" != --* ]] && shift
from=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) from="${2:?udid}"; shift ;;
    *) echo "sim.sh: unknown flag $1" >&2; exit 2 ;;
  esac; shift
done

devices_json() { xcrun simctl list devices -j; }
# python3 reads the JSON once; prints "name<TAB>udid<TAB>state" for every device
rows() { devices_json | python3 -c '
import json, sys
d = json.load(sys.stdin)["devices"]
for rt, devs in d.items():
    for x in devs:
        print(x["name"] + "\t" + x["udid"] + "\t" + x["state"])'; }
udid_of_name() { rows | awk -F'\t' -v n="$1" '$1==n {print $2; exit}'; }
state_of_udid() { rows | awk -F'\t' -v u="$1" '$2==u {print $3; exit}'; }
name_of_udid() { rows | awk -F'\t' -v u="$1" '$2==u {print $1; exit}'; }
need_project() { [[ -n "$project" ]] || { echo "sim.sh: name the project" >&2; exit 2; }; }
is_clone_name() { [[ "$1" == NuvioTV\ * && "$1" != "$TEMPLATE_NAME" ]]; }

make_template() {
  local src="${1:-$FIXTURE}" st
  if [[ -n "$(udid_of_name "$TEMPLATE_NAME")" ]]; then echo "template exists: $(udid_of_name "$TEMPLATE_NAME")"; return 0; fi
  st="$(state_of_udid "$src")"
  if [[ "$st" != "Shutdown" ]]; then
    echo "SIM REFUSED: cannot clone $src ($(name_of_udid "$src")) while it is $st, and shutting down a sim another session booted is not allowed."
    echo "  wait until it is shut down, or clone from a shut-down clone: sim.sh template --from <udid> (sim.sh list)"
    return 1
  fi
  local u; u="$(xcrun simctl clone "$src" "$TEMPLATE_NAME" 2>&1)" || { echo "SIM REFUSED: clone failed: $u"; return 1; }
  echo "template created from $(name_of_udid "$src"): $u (keep it shut down)"
}

case "$cmd" in
  template) make_template "${from:-$FIXTURE}" ;;
  clone)
    need_project
    name="NuvioTV $project"
    if u="$(udid_of_name "$name")" && [[ -n "$u" ]]; then echo "exists: $name $u ($(state_of_udid "$u"))"; echo "$u"; exit 0; fi
    if [[ -n "$from" ]]; then src="$from"; else make_template "$FIXTURE" >/dev/null || { make_template "$FIXTURE"; exit 1; }; src="$(udid_of_name "$TEMPLATE_NAME")"; fi
    [[ "$(state_of_udid "$src")" == "Shutdown" ]] || { echo "SIM REFUSED: source $src is $(state_of_udid "$src"), not Shutdown"; exit 1; }
    u="$(xcrun simctl clone "$src" "$name" 2>&1)" || { echo "SIM REFUSED: clone failed: $u"; exit 1; }
    echo "cloned: $name $u (from $(name_of_udid "$src"))"
    echo "destination: -destination 'platform=tvOS Simulator,id=$u'"
    echo "$u" ;;
  udid)
    need_project; u="$(udid_of_name "NuvioTV $project")"; [[ -n "$u" ]] || { echo "no sim named 'NuvioTV $project' (sim.sh clone $project)" >&2; exit 1; }; echo "$u" ;;
  boot)
    need_project; name="NuvioTV $project"; u="$(udid_of_name "$name")"
    [[ -n "$u" ]] || { echo "no sim named '$name'" >&2; exit 1; }
    is_clone_name "$name" || { echo "SIM REFUSED: $name is not a project clone" >&2; exit 1; }
    st="$(state_of_udid "$u")"; [[ "$st" == "Booted" ]] && { echo "already booted: $name $u"; exit 0; }
    xcrun simctl boot "$u" && echo "booted: $name $u" ;;
  delete)
    need_project; name="NuvioTV $project"; u="$(udid_of_name "$name")"
    [[ -n "$u" ]] || { echo "no sim named '$name'; nothing to delete"; exit 0; }
    is_clone_name "$name" || { echo "SIM REFUSED: will not delete $name" >&2; exit 1; }
    [[ "$u" == "$FIXTURE" ]] && { echo "SIM REFUSED: that is the FA87 fixture" >&2; exit 1; }
    st="$(state_of_udid "$u")"
    if [[ "$st" == "Booted" ]]; then xcrun simctl shutdown "$u" >/dev/null 2>&1 || true; fi
    xcrun simctl delete "$u" && echo "deleted: $name $u" ;;
  list|"")
    printf '%-40s %-38s %s\n' NAME UDID STATE
    rows | awk -F'\t' -v f="$FIXTURE" '$1 ~ /^NuvioTV / || $2==f {printf "%-40s %-38s %s%s\n", $1, $2, $3, ($2==f ? "  (fixture, final gate only)" : "")}' ;;
  -h|--help) sed -n '2,20p' "$0" ;;
  *) echo "sim.sh: unknown command '$cmd'" >&2; sed -n '2,9p' "$0" >&2; exit 2 ;;
esac

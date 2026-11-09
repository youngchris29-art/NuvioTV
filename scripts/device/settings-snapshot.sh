#!/bin/bash
# NuvioTV rig: snapshot the app's settings on the box before a pass and diff them after, so a
# walk that flipped a toggle by mistake (Hide Spoilers 11-06, OpenSubtitles 11-08) is caught
# and restored before the box goes back to daily use.
#
#   settings-snapshot.sh take <label>           # copies the prefs plist to ~/.config/nuviotv-device/snapshots/
#   settings-snapshot.sh diff [<label-a> [<label-b>]]
#       no args:     newest "pre-*" snapshot against the box NOW (takes a "post-<stamp>" snapshot)
#       one label:   that snapshot against the box now
#       two labels:  those two snapshots
#   settings-snapshot.sh list
#
# The plist comes from the app's data container over devicectl (works on the Living Room box,
# 2026-11-09). It holds every profile's settings with a profile-index suffix (_3 = the Test
# profile on this box) AND secrets (debrid API keys, Trakt tokens), so snapshots stay in
# ~/.config (never the repo), nothing is echoed but key names, and the diff prints a value
# only for keys that look like plain settings. Keys that look like secrets or payload blobs
# print as "changed" with no value.
#
# exit 0 no differences (or snapshot taken) · 1 differences printed · 2 config / copy failure
set -uo pipefail
CONF="${NUVIOTV_DEVICE_CONF:-$HOME/.config/nuviotv-device}"
# shellcheck disable=SC1091
source "$CONF/atv.env" 2>/dev/null || { echo "SNAPSHOT: $CONF/atv.env missing"; exit 2; }
BUNDLE="${NUVIOTV_BUNDLE:-com.youngchris29.NuvioTV}"
DIR="$CONF/snapshots"; mkdir -p "$DIR"; chmod 700 "$DIR"
T() { if command -v timeout >/dev/null 2>&1; then timeout "$@"; else shift; "$@"; fi; }

take() {  # <label> -> path
  local label="$1" out="$DIR/$(date -u +%Y%m%dT%H%M%SZ)-$1.plist"
  if ! T 90 xcrun devicectl device copy from --device "$ATV_UDID" --domain-type appDataContainer \
        --domain-identifier "$BUNDLE" --source "Library/Preferences/$BUNDLE.plist" --destination "$out" >/dev/null 2>&1; then
    echo "SNAPSHOT FAILED: could not copy the prefs plist off the box (tunnel down, or the app has never written prefs)"; return 2
  fi
  chmod 600 "$out"; echo "$out"
}
newest() { ls -1t "$DIR"/*-"$1"*.plist 2>/dev/null | head -1; }
resolve() {  # label or path -> path
  [[ -f "$1" ]] && { echo "$1"; return; }
  local p; p="$(newest "$1")"; [[ -n "$p" ]] || { echo "SNAPSHOT: no snapshot labelled '$1' in $DIR" >&2; return 2; }; echo "$p"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  take)
    p="$(take "${1:?label}")" || { echo "$p"; exit 2; }; echo "snapshot: $p" ;;
  list)
    ls -1t "$DIR"/*.plist 2>/dev/null | sed 's#.*/##' || echo "no snapshots" ;;
  diff)
    a="${1:-}"; b="${2:-}"
    if [[ -z "$a" ]]; then a="$(newest pre)"; [[ -n "$a" ]] || { echo "SNAPSHOT: no pre-* snapshot to diff against (ready.sh --walk takes one)"; exit 2; }; fi
    a="$(resolve "$a")" || exit 2
    if [[ -z "$b" ]]; then b="$(take "post")" || { echo "$b"; exit 2; }; else b="$(resolve "$b")" || exit 2; fi
    python3 - "$a" "$b" "${TEST_PROFILE_INDEX:-3}" <<'PY'
import plistlib, re, sys
a, b, test_idx = sys.argv[1], sys.argv[2], sys.argv[3]
A = plistlib.load(open(a, "rb")); B = plistlib.load(open(b, "rb"))
secret = re.compile(r"(key|token|secret|password|passwd|auth|credential|cookie|session|payload|manifest|url)", re.I)
def show(k, v):
    if secret.search(k): return "changed"
    s = repr(v)
    return s if len(s) <= 80 else s[:77] + "..."
changed = []
for k in sorted(set(A) | set(B)):
    va, vb = A.get(k, "<absent>"), B.get(k, "<absent>")
    if va == vb: continue
    suffix = re.search(r"_(\d+)$", k)
    prof = f"profile {suffix.group(1)}" if suffix else "global"
    tag = " (TEST PROFILE)" if suffix and suffix.group(1) == test_idx else ""
    if secret.search(k):
        changed.append(f"  {k}  [{prof}{tag}]  changed")
    else:
        changed.append(f"  {k}  [{prof}{tag}]  {show(k, va)}  ->  {show(k, vb)}")
import os
print(f"settings diff: {os.path.basename(a)}  ->  {os.path.basename(b)}")
if not changed:
    print("  no differences"); sys.exit(0)
print(f"  {len(changed)} key(s) differ; restore anything in the Test profile that the pass did not mean to change:")
print("\n".join(changed)); sys.exit(1)
PY
    ;;
  -h|--help) sed -n '2,20p' "$0" ;;
  *) echo "settings-snapshot.sh: take <label> | diff [a [b]] | list" >&2; exit 2 ;;
esac

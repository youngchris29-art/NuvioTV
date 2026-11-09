#!/bin/bash
# Exercises the state.env helpers of refresh-ipad.sh in isolation: no config, no clone, no iPad.
# It extracts the block between the "state helpers" markers, points STATE at a temp file and
# checks that every value survives a write → read round trip (parentheses, quotes, a colon,
# command-substitution text, backslashes), that the file is also valid for a plain `.`, and
# that a pre-2026-11-09 bare-value file (the one that broke sourcing) still loads.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../refresh-ipad.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
HELPERS="$TMP/helpers.sh"
sed -n '/^# --- state helpers/,/^# --- end state helpers/p' "$SCRIPT" > "$HELPERS"
[ -s "$HELPERS" ] || { echo "FAIL: helper block not found in $SCRIPT"; exit 1; }

fails=0
check() {  # name expected actual
  if [ "$2" == "$3" ]; then echo "ok   $1"; else echo "FAIL $1"; printf '     want: %q\n     got:  %q\n' "$2" "$3"; fails=$((fails+1)); fi
}
reset_vars() { INSTALLED_TAG=""; PROFILE_EXPIRY=""; LAST_RUN_DATE=""; LAST_RESULT=""; LAST_CAUSE=""; LAST_SUCCESS=""; }

# shellcheck source=/dev/null
. "$HELPERS"
STATE="$TMP/state.env"; TODAY="2026-11-09"

# 1. The bare file the 11-08 run left behind: `.` rejects it, load_state reads it.
cat > "$TMP/old.env" <<'EOF'
INSTALLED_TAG=0.6.10-beta
PROFILE_EXPIRY=2026-11-14T15:02:11Z
LAST_RUN_DATE=2026-11-08
LAST_RESULT=failed
LAST_CAUSE=xcode-signed-out: Xcode has no Apple ID (an Xcode update signs it out). Fix: Xcode > Settings > Accounts, sign in, then rerun.
LAST_SUCCESS=2026-11-07T10:01:40Z
EOF
if ( . "$TMP/old.env" ) 2>/dev/null; then echo "FAIL old bare file sources cleanly (expected a syntax error)"; fails=$((fails+1)); else echo "ok   old bare file: plain . fails as on 11-09"; fi
reset_vars; load_state "$TMP/old.env"
check "old bare: INSTALLED_TAG" "0.6.10-beta" "$INSTALLED_TAG"
check "old bare: LAST_RUN_DATE (the once-a-day guard key)" "2026-11-08" "$LAST_RUN_DATE"
check "old bare: LAST_RESULT" "failed" "$LAST_RESULT"
check "old bare: LAST_CAUSE verbatim" "xcode-signed-out: Xcode has no Apple ID (an Xcode update signs it out). Fix: Xcode > Settings > Accounts, sign in, then rerun." "$LAST_CAUSE"
check "old bare: LAST_SUCCESS" "2026-11-07T10:01:40Z" "$LAST_SUCCESS"

# 2. Round trip of a hostile cause through save_state → load_state and through a plain `.`.
HOSTILE="xcode-signed-out: it's \"quoted\" (parens) \$(touch $TMP/pwned) \`id\` back\\slash 'single' ; && | <> *glob* ~"
reset_vars
INSTALLED_TAG="0.6.11-beta"; PROFILE_EXPIRY="2026-11-16T09:00:00Z"; LAST_SUCCESS="2026-11-09T09:00:00Z"
save_state failed "$HOSTILE"
echo "--- written file:"; cat "$STATE"
check "written: six lines" "6" "$(wc -l < "$STATE" | tr -d ' ')"
check "written: every line is KEY='...'" "6" "$(grep -c "^[A-Z_]*='.*'$" "$STATE")"
reset_vars; load_state "$STATE"
check "round trip: LAST_CAUSE" "$HOSTILE" "$LAST_CAUSE"
check "round trip: LAST_RESULT" "failed" "$LAST_RESULT"
check "round trip: LAST_RUN_DATE" "2026-11-09" "$LAST_RUN_DATE"
check "round trip: INSTALLED_TAG" "0.6.11-beta" "$INSTALLED_TAG"
check "round trip: PROFILE_EXPIRY" "2026-11-16T09:00:00Z" "$PROFILE_EXPIRY"
check "round trip: LAST_SUCCESS" "2026-11-09T09:00:00Z" "$LAST_SUCCESS"
[ -e "$TMP/pwned" ] && { echo "FAIL load_state executed the cause"; fails=$((fails+1)); }
sourced="$(reset_vars; . "$STATE" && printf '%s' "$LAST_CAUSE")"
check "new file is valid for a plain . too" "$HOSTILE" "$sourced"
[ -e "$TMP/pwned" ] && { echo "FAIL sourcing the new file executed the cause"; fails=$((fails+1)); }

# 3. Empty values and a cause with a newline (flattened to a space, file stays one line per key).
reset_vars; save_state nothing
reset_vars; INSTALLED_TAG=x; load_state "$STATE"
check "empty: INSTALLED_TAG reset to empty" "" "$INSTALLED_TAG"
check "empty: LAST_CAUSE empty" "" "$LAST_CAUSE"
check "empty: LAST_RESULT" "nothing" "$LAST_RESULT"
reset_vars; save_state failed $'gradle: line one\nline two'
check "newline: still six lines" "6" "$(wc -l < "$STATE" | tr -d ' ')"
reset_vars; load_state "$STATE"
check "newline: flattened to a space" "gradle: line one line two" "$LAST_CAUSE"

# 4. Unknown keys and comments are ignored, known keys from a mixed-form file all load.
printf '# comment\nFOO=bar\nLAST_RESULT=ok\nLAST_CAUSE=%s\nINSTALLED_TAG=%s\n' "'has (parens) and '\\''quote'\\'''" "bare (parens): ok" > "$TMP/mixed.env"
reset_vars; load_state "$TMP/mixed.env"
check "mixed: quoted value unescaped" "has (parens) and 'quote'" "$LAST_CAUSE"
check "mixed: bare value verbatim" "bare (parens): ok" "$INSTALLED_TAG"
check "mixed: FOO not set" "" "${FOO:-}"

echo; if [ "$fails" = 0 ]; then echo "ALL OK"; else echo "$fails FAILED"; exit 1; fi

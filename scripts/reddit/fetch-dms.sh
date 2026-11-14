#!/usr/bin/env bash
# fetch-dms.sh — run scripts/reddit/fetch-dms.mjs inside the ego-browser runtime.
#
#   scripts/reddit/fetch-dms.sh --since 2026-10-08T15:24:08Z --summary
#   scripts/reddit/fetch-dms.sh --since <ISO> > dms.json          # JSON
#   scripts/reddit/fetch-dms.sh --summary                          # full read, no watermark
#
# Options: --since <ISO>   emit only events strictly newer than this timestamp
#          --summary       human-readable digest instead of JSON
#          --limit <n>     max events fetched per chat room (default 200)
#          --space <name>  ego-browser task-space name to reuse (default "reddit dm sweep")
#          --timeout <s>   kill the runtime after this many seconds (default 150)
#          --log <path>    progress log (default: $TMPDIR/fetch-dms.log)
#
# Why a wrapper: ego-browser's `nodejs -e` takes ONE line (a multi-line script
# via "$(cat file)" hangs before its first statement), and resolving a task
# space BY NAME hangs intermittently while a numeric id is reliable. So this
# script resolves/creates the space once with a short timeout, flattens the
# .mjs (line comments stripped) to one line, prepends the config, and runs it
# under an alarm with stdin on /dev/null (ego's nodejs probes stdin for a piped
# script and hangs when it inherits an open pipe — the "silent wedge"). Note
# ego prints console.log output on STDERR; never `2>/dev/null` it. The chat token stays inside that process; nothing secret is
# written to disk. macOS has no `timeout` binary, hence perl's alarm.
#
# Exit codes: 0 ok · 3 no/expired chat token (sign in at reddit.com/chat in
# ego lite) · 4 ego-browser failure or timeout · 2 usage.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EGO="${EGO_BROWSER:-$HOME/.local/bin/ego-browser}"
SINCE=""; SUMMARY=false; LIMIT=200; SPACE_NAME="reddit dm sweep"; TIMEOUT=150
LOG="${TMPDIR:-/tmp}/fetch-dms.log"
while [ $# -gt 0 ]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --summary) SUMMARY=true; shift ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --space) SPACE_NAME="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
if [ -n "$SINCE" ] && command -v node >/dev/null 2>&1 && ! node -e 'process.exit(Number.isNaN(Date.parse(process.argv[1])) ? 1 : 0)' -- "$SINCE" 2>/dev/null; then echo "--since is not a parseable timestamp: $SINCE (use ISO, e.g. 2026-11-13T09:00:00Z)" >&2; exit 2; fi
if [ ! -x "$EGO" ]; then echo "ego-browser not found at $EGO (ego lite installed?)" >&2; exit 4; fi
: > "$LOG" 2>/dev/null || LOG=""

run_js() { # $1 = seconds, $2 = one-line JS. stdin MUST be /dev/null: ego's nodejs
  # probes stdin for a piped script and hangs for good when it inherits an open pipe.
  perl -e 'alarm shift; exec @ARGV' "$1" "$EGO" nodejs -e "$2" </dev/null
}

# 1. Resolve the task space by name → numeric id; create it if missing (retry twice).
find_space() {
  run_js 30 "const s = await listTaskSpaces(); const m = s.find(x => x.name === $(printf '%s' "$SPACE_NAME" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')); console.log(m ? m.id : \"\");" 2>&1 | grep -E '^[0-9]+$' | tail -1
}
SPACE_ID="$(find_space)"
attempt=0
while [ -z "$SPACE_ID" ] && [ $attempt -lt 2 ]; do
  attempt=$((attempt + 1))
  run_js 40 "const t = await taskSpace($(printf '%s' "$SPACE_NAME" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')); console.log(t.id);" >/dev/null 2>&1
  sleep 2
  SPACE_ID="$(find_space)"
done
if ! [[ "$SPACE_ID" =~ ^[0-9]+$ ]]; then
  echo "could not resolve or create ego-browser task space '$SPACE_NAME' (ego lite running? see memory reddit-chat-smash-fetch)" >&2
  exit 4
fi

# 2. Flatten the script to one line and prepend the config.
CFG="const CFG = {space: $SPACE_ID, since: $(printf '%s' "$SINCE" | python3 -c 'import json,sys; v=sys.stdin.read(); print(json.dumps(v) if v else "null")'), limit: $LIMIT, summary: $SUMMARY, log: $(printf '%s' "$LOG" | python3 -c 'import json,sys; v=sys.stdin.read(); print(json.dumps(v) if v else "null")')};"
BODY="$(grep -v '^[[:space:]]*//' "$HERE/fetch-dms.mjs" | tr '\n' ' ')"

# 3. Run it. ego-browser prints console.log output on STDERR, so fold it into
#    stdout for the caller. Alarm → exit 142 → 4.
run_js "$TIMEOUT" "$CFG $BODY" 2>&1
rc=$?
if [ $rc -eq 142 ] || [ $rc -gt 128 ]; then
  echo "fetch-dms timed out after ${TIMEOUT}s (ego-browser wedge?). Progress log: ${LOG:-none}" >&2
  exit 4
fi
exit $rc

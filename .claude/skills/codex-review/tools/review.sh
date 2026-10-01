#!/usr/bin/env bash
# Codex code review on the highest model this account can use.
#
#   tools/review.sh --base <sha>            # review <sha>..HEAD (landed commits)
#   tools/review.sh --commit <sha>          # review one commit
#   tools/review.sh                         # review the working tree (staged + unstaged + untracked)
#   tools/review.sh --models                # print the models the account lists, best first
#
# Options:
#   --repo <dir>       run from this repo (default: cwd; pass NuvioMobile for the submodule)
#   --focus "<text>"   extra instructions appended to the brief (what to look hardest at)
#   --model <slug>     override the resolved model (env: CODEX_REVIEW_MODEL)
#   --effort <level>   reasoning effort, default xhigh (env: CODEX_REVIEW_EFFORT); max / ultra are
#                      accepted on gpt-5.6-terra, ultra adds automatic task delegation
#   --native           use `codex review` (Codex's built-in reviewer) instead of the `exec` brief
#   --out <log>        full transcript path (default: $TMPDIR or /tmp, codex-review-<ts>.log)
#   --dry-run          print the resolved command and exit
#
# Rules this script bakes in (see the memory codex-review-workflow for the history):
#   - never pipe the codex invocation (SIGPIPE kills the job); it writes to --out and the answer
#     is extracted afterwards
#   - stdin is /dev/null, sandbox is read-only, no approvals
#   - run it from an UNSANDBOXED shell: sandboxed Bash makes the Codex CLI fail at init
#   - exit 0 = VERDICT: CLEAN, exit 3 = findings, exit 2 = Codex produced no verdict (read the log)
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CACHE="${CODEX_HOME:-$HOME/.codex}/models_cache.json"
FALLBACK_MODEL="gpt-5.6-terra"

MODE="uncommitted"; RANGE=""; COMMIT=""; REPO="."; FOCUS=""; NATIVE=0; DRY=0; OUT=""
MODEL="${CODEX_REVIEW_MODEL:-}"; EFFORT="${CODEX_REVIEW_EFFORT:-xhigh}"

list_models() {
  python3 - "$CACHE" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"(no models cache at {sys.argv[1]}: {e})", file=sys.stderr); sys.exit(1)
rows = [m for m in d.get("models", []) if m.get("visibility") == "list"]
rows.sort(key=lambda m: m.get("priority", 10**6))
print(f"fetched {d.get('fetched_at','?')} by codex {d.get('client_version','?')}")
for m in rows:
    efforts = ",".join(e.get("effort", "?") for e in m.get("supported_reasoning_levels", []))
    print(f"{m['slug']:<16} priority={m.get('priority'):<3} efforts={efforts:<38} {m.get('description','')}")
PY
}

resolve_model() {
  python3 - "$CACHE" "$FALLBACK_MODEL" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    rows = [m for m in d.get("models", []) if m.get("visibility") == "list" and m.get("supported_in_api", True)]
    rows.sort(key=lambda m: m.get("priority", 10**6))
    print(rows[0]["slug"] if rows else sys.argv[2])
except Exception:
    print(sys.argv[2])
PY
}

while [ $# -gt 0 ]; do
  case "$1" in
    --base)    MODE="range";  RANGE="$2"; shift 2 ;;
    --commit)  MODE="commit"; COMMIT="$2"; shift 2 ;;
    --uncommitted) MODE="uncommitted"; shift ;;
    --repo)    REPO="$2"; shift 2 ;;
    --focus)   FOCUS="$2"; shift 2 ;;
    --model)   MODEL="$2"; shift 2 ;;
    --effort)  EFFORT="$2"; shift 2 ;;
    --native)  NATIVE=1; shift ;;
    --out)     OUT="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --models)  list_models; exit $? ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "review: unknown argument $1" >&2; exit 64 ;;
  esac
done

command -v codex >/dev/null 2>&1 || { echo "review: codex CLI not found (npm i -g @openai/codex@latest)" >&2; exit 69; }
[ -n "$MODEL" ] || MODEL="$(resolve_model)"
[ -n "$OUT" ] || OUT="${TMPDIR:-/tmp}/codex-review-$(date +%Y%m%d-%H%M%S).log"
OUT="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"

cd "$REPO" || exit 66
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "review: $REPO is not a git checkout" >&2; exit 66; }

case "$MODE" in
  range)
    git rev-parse --verify "$RANGE^{commit}" >/dev/null 2>&1 || { echo "review: unknown base $RANGE" >&2; exit 66; }
    SCOPE="the commits in \`git log --oneline $RANGE..HEAD\`; the full change is \`git diff $RANGE..HEAD\`" ;;
  commit)
    git rev-parse --verify "$COMMIT^{commit}" >/dev/null 2>&1 || { echo "review: unknown commit $COMMIT" >&2; exit 66; }
    SCOPE="the single commit \`git show $COMMIT\`" ;;
  uncommitted)
    SCOPE="the working tree: \`git diff HEAD\` plus every untracked file in \`git status --porcelain\`" ;;
esac

BRIEF="You are a strict senior reviewer for this repository. Review ${SCOPE}.

Read the whole diff first, then the surrounding code it touches, and run any read-only probes you need (grep, git log, reading tests). Do not edit files.

Report only real defects: correctness, concurrency and races, data loss or corruption, crashes, security, behavioural regressions, broken invariants, and missing tests on a risky path. Skip style and naming.

For each finding give: severity (P1 breaks users or data, P2 wrong under a realistic condition, P3 latent or hygiene), file:line, what breaks, a concrete scenario that triggers it, and the smallest fix.

End your answer with exactly one line of the form
VERDICT: CLEAN
or
VERDICT: <n> findings (<a> P1 / <b> P2 / <c> P3)"
[ -n "$FOCUS" ] && BRIEF="$BRIEF

Focus: $FOCUS"

if [ "$NATIVE" -eq 1 ]; then
  CMD=(codex review -c "model=\"$MODEL\"" -c "model_reasoning_effort=\"$EFFORT\"")
  case "$MODE" in
    range)  CMD+=(--base "$RANGE") ;;
    commit) CMD+=(--commit "$COMMIT") ;;
    *)      CMD+=(--uncommitted) ;;
  esac
  [ -n "$FOCUS" ] && CMD+=("$FOCUS")
else
  CMD=(codex exec -s read-only -m "$MODEL" -c "model_reasoning_effort=\"$EFFORT\"" "$BRIEF")
fi

echo "review: model=$MODEL effort=$EFFORT mode=$MODE repo=$(pwd)"
echo "review: log=$OUT"
if [ "$DRY" -eq 1 ]; then printf '  %q' "${CMD[@]}"; echo; exit 0; fi

"${CMD[@]}" </dev/null >"$OUT" 2>&1
RC=$?

# The transcript wraps the answer in banners; the final answer is the last block that starts
# after a bare `codex` line and ends at `tokens used`.
BODY="$(awk '$0=="codex"{buf="";on=1;next} $0=="tokens used"{on=0;next} on{buf=buf $0 "\n"} END{printf "%s", buf}' "$OUT")"
if [ -z "$(printf '%s' "$BODY" | tr -d '[:space:]')" ]; then
  echo "review: no answer block in the transcript (codex exit $RC); tail of the log:" >&2
  tail -n 20 "$OUT" >&2
  exit 2
fi
printf '%s\n' "$BODY"
VERDICT="$(printf '%s\n' "$BODY" | grep -E '^VERDICT:' | tail -n 1)"
case "$VERDICT" in
  "VERDICT: CLEAN") exit 0 ;;
  VERDICT:*)        exit 3 ;;
  *) [ "$NATIVE" -eq 1 ] && exit 0; echo "review: answer has no VERDICT line (codex exit $RC)" >&2; exit 2 ;;
esac

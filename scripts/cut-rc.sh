#!/bin/bash
# Cut a NuvioTV beta release candidate, start to finish:
#
#   preflight  read-only checks; --preflight stops here
#   bump       Version.xcconfig build number +1, commit, tag tvos-v<version>-<label>
#   push       push tvos-shared-extraction and the tag to origin
#   pointer    commit the outer repo's NuvioMobile pointer (not pushed)
#   build      unsigned Release build for generic/platform=tvOS, stamped with the tag
#   stamp      the built Info.plist carries the tag, HEAD's SHA and the build number
#   package    Payload zip without PlugIns, copied to ~/Downloads
#   upload     litterbox (72 h); if it fails, filebin + gofile; every link size-checked
#
# The recipe the rc8..beta.19-rc1 cuts ran by hand, kept in one place. Catbox is
# never used: it has stored 0-byte objects and dedups every retry of the same file
# to that empty copy. Filebin's file URL reports a different size on HEAD, so its
# upload is checked against the bin's JSON instead.
#
# Usage:
#   scripts/cut-rc.sh <label> [--preflight] [--from build|upload] [--allow a,b] [--litterbox-tries N]
#   scripts/cut-rc.sh --simulate [--preflight]   canned marker sequence for the rc-cut mod, no side effects
#
#   <label>          beta.<n>-rc<m>, e.g. beta.19-rc2 (tag tvos-v0.3.0-beta.19-rc2)
#   --from build     the tag already exists at HEAD (an earlier run failed after the push)
#   --from upload    reuse the built product; repackage and upload only
#   --allow a,b      preflight checks that may be bad without stopping the cut (default: none)
#
# Lines starting with "::" are for the rc-cut mod:
#   ::meta k=v ...   ::check <name> ok|bad <detail>   ::preflight done
#   ::step <id> start|ok|skip [detail]   ::progress <id> <detail>
#   ::url <url> <host> <expiry>   ::fail <id> <reason>   ::done <tag>

set -uo pipefail

OUTER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUB="$OUTER/NuvioMobile"
BRANCH=tvos-shared-extraction
XCCONFIG="$SUB/iosApp/Configuration/Version.xcconfig"
DD="$SUB/iosApp/build/tvos-ipa"
PRODUCTS="$DD/Build/Products/Release-appletvos"
LOG_DIR="${CUT_LOG_DIR:-$HOME/Library/Logs/NuvioCut}"

CUR=preflight
mark()  { printf '::%s\n' "$*"; }
step()  { CUR="$1"; mark "step $*"; }
fail()  { mark "fail $CUR $*"; exit 1; }
check() { mark "check $*"; [[ "$2" == ok ]] || BAD_NAMES="$BAD_NAMES $1"; }
XPID=""
trap 'mark "fail $CUR killed by a signal"; [[ -n "$XPID" ]] && kill "$XPID" 2>/dev/null; exit 1' INT TERM HUP

simulate() {
  mark "meta tag=tvos-v0.3.0-beta.99-rc1 build=999 ipa=NuvioTV-beta99-rc1.ipa from=start simulated=1"
  for c in "branch ok tvos-shared-extraction" "clean ok no tracked changes" "synced ok HEAD 284fd764 = origin" \
           "tag ok tvos-v0.3.0-beta.99-rc1 is free" "outer ok nothing staged" "xcodebuild ok none running" \
           "sleep ok caffeinate holds an assertion" "disk ok 212 GB free" "build ok 998 → 999"; do
    check $c; sleep 0.3
  done
  mark "preflight done"
  [[ "${2:-}" == --preflight ]] && exit 0
  step bump start; sleep 1; mark "step bump ok 1a2b3c4d"
  step push start; sleep 1; mark "step push ok branch + tag on origin"
  step pointer start; sleep 1; mark "step pointer ok 5e6f7a8 (not pushed)"
  step build start
  for n in 120 480 910 1302; do sleep 2; mark "progress build $n compile steps · SwiftCompile HomeView.swift"; done
  mark "step build ok 7m 41s"
  step stamp start; sleep 1; mark "step stamp ok tag, sha 1a2b3c4d, build 999"
  step package start; sleep 1; mark "meta size=27601572 sha=2f47c7f0f6ad8535"; mark "step package ok 27601572 B"
  step upload start; echo "litterbox attempt 1: HTTP 500"; sleep 2
  mark "url https://example.com/NuvioTV-beta99-rc1.ipa simulated 72h"
  mark "step upload ok 1 link"
  mark "done tvos-v0.3.0-beta.99-rc1"
  exit 0
}

[[ "${1:-}" == --simulate ]] && simulate "$@"

LABEL="${1:-}"; shift || true
PREFLIGHT_ONLY=0; FROM=start; LB_TRIES=3; ALLOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --preflight) PREFLIGHT_ONLY=1; shift ;;
    --from) FROM="${2:-}"; shift 2 ;;
    --litterbox-tries) LB_TRIES="${2:-3}"; shift 2 ;;
    --allow) ALLOW="${2:-}"; shift 2 ;;
    *) fail "unknown option $1" ;;
  esac
done
[[ "$LABEL" =~ ^beta\.[0-9]+-rc[0-9]+$ ]] || fail "label must look like beta.19-rc2, got '$LABEL'"
[[ "$FROM" == start || "$FROM" == build || "$FROM" == upload ]] || fail "--from takes build or upload"

MV="$(sed -n 's/^MARKETING_VERSION=//p' "$XCCONFIG" | tr -d '[:space:]')"
CUR_BUILD="$(sed -n 's/^CURRENT_PROJECT_VERSION=//p' "$XCCONFIG" | tr -d '[:space:]')"
[[ -n "$MV" && "$CUR_BUILD" =~ ^[0-9]+$ ]] || fail "cannot read the version from $XCCONFIG"
TAG="tvos-v${MV}-${LABEL}"
IPA_NAME="NuvioTV-${LABEL/beta./beta}.ipa"
if [[ "$FROM" == start ]]; then BUILD=$((CUR_BUILD + 1)); else BUILD="$CUR_BUILD"; fi
mark "meta tag=$TAG build=$BUILD ipa=$IPA_NAME from=$FROM"

# ---------------------------------------------------------------- preflight
BAD_NAMES=""
git -C "$SUB" fetch -q origin "$BRANCH" --tags 2>/dev/null || true
HEAD8="$(git -C "$SUB" rev-parse --short=8 HEAD)"
ON="$(git -C "$SUB" symbolic-ref --short HEAD 2>/dev/null || echo detached)"
[[ "$ON" == "$BRANCH" ]] && check branch ok "$ON" || check branch bad "on $ON, not $BRANCH"

DIRTY="$(git -C "$SUB" status --porcelain --untracked-files=no | head -3 | tr '\n' ' ')"
[[ -z "$DIRTY" ]] && check clean ok "no tracked changes" || check clean bad "uncommitted: $DIRTY"

ORIGIN8="$(git -C "$SUB" rev-parse --short=8 "origin/$BRANCH" 2>/dev/null || echo none)"
TAG8="$(git -C "$SUB" rev-parse --short=8 "$TAG^{commit}" 2>/dev/null || echo none)"
REMOTE_TAG="$(git -C "$SUB" ls-remote --tags origin "refs/tags/$TAG" 2>/dev/null | cut -c1-8)"
if [[ "$FROM" == start ]]; then
  [[ "$HEAD8" == "$ORIGIN8" ]] && check synced ok "HEAD $HEAD8 = origin" || check synced bad "HEAD $HEAD8, origin/$BRANCH $ORIGIN8"
  [[ "$TAG8" == none && -z "$REMOTE_TAG" ]] && check tag ok "$TAG is free" || check tag bad "$TAG already exists (${TAG8}${REMOTE_TAG:+, on origin})"
else
  [[ "$TAG8" == "$HEAD8" ]] && check tag ok "$TAG is HEAD $HEAD8" || check tag bad "$TAG is at $TAG8, HEAD is $HEAD8"
  [[ -n "$REMOTE_TAG" ]] && check synced ok "tag is on origin" || check synced bad "tag not on origin"
fi

if git -C "$OUTER" diff --cached --quiet; then check outer ok "nothing staged"
else check outer bad "the outer repo has staged changes; the pointer commit must go alone"; fi

if [[ "$FROM" == upload ]]; then
  [[ -d "$PRODUCTS/NuvioTV.app" ]] && check product ok "built product present" || check product bad "no built product at $PRODUCTS"
else
  OTHER="$(pgrep -x xcodebuild | tr '\n' ' ')"
  [[ -z "$OTHER" ]] && check xcodebuild ok "none running" || check xcodebuild bad "xcodebuild already running (pid $OTHER)"
  if caffeinate -i -t 1 >/dev/null 2>&1; then check sleep ok "caffeinate holds an assertion"
  else check sleep bad "powerd refuses sleep assertions; run: sudo killall powerd"; fi
  FREE_GB="$(df -g "$SUB" | awk 'NR==2 {print $4}')"
  [[ "${FREE_GB:-0}" -ge 8 ]] && check disk ok "$FREE_GB GB free" || check disk bad "only ${FREE_GB:-?} GB free"
fi
if [[ "$FROM" == start ]]; then check build ok "$CUR_BUILD → $BUILD"; else check build ok "$BUILD (already bumped)"; fi
mark "preflight done"
[[ "$PREFLIGHT_ONLY" == 1 ]] && exit 0
BLOCK=""
for n in $BAD_NAMES; do [[ ",$ALLOW," == *",$n,"* ]] || BLOCK="$BLOCK $n"; done
[[ -z "$BLOCK" ]] || fail "preflight failed:$BLOCK (pass --allow to override)"

# ---------------------------------------------------------------- bump, push, pointer
if [[ "$FROM" == start ]]; then
  step bump start
  OLD8="$HEAD8"
  sed -i '' "s/^CURRENT_PROJECT_VERSION=$CUR_BUILD\$/CURRENT_PROJECT_VERSION=$BUILD/" "$XCCONFIG"
  grep -q "^CURRENT_PROJECT_VERSION=$BUILD\$" "$XCCONFIG" || fail "the build number did not change in Version.xcconfig"
  git -C "$SUB" commit -q -m "release: bump build number to $BUILD for $LABEL" -- iosApp/Configuration/Version.xcconfig || fail "git commit failed"
  git -C "$SUB" tag "$TAG" || fail "git tag failed"
  HEAD8="$(git -C "$SUB" rev-parse --short=8 HEAD)"
  step bump ok "$HEAD8"

  step push start
  git -C "$SUB" push -q origin "$BRANCH" "$TAG" 2>&1 | grep -v '^remote:' || true
  [[ "$(git -C "$SUB" ls-remote origin "refs/heads/$BRANCH" | cut -c1-8)" == "$HEAD8" ]] || fail "origin/$BRANCH is not at $HEAD8 after the push"
  [[ -n "$(git -C "$SUB" ls-remote --tags origin "refs/tags/$TAG")" ]] || fail "$TAG is not on origin after the push"
  step push ok "branch + tag on origin"

  step pointer start
  if git -C "$OUTER" diff --quiet -- NuvioMobile; then
    step pointer skip "pointer already at $HEAD8"
  else
    git -C "$OUTER" add NuvioMobile
    git -C "$OUTER" commit -q -m "submodule: $BRANCH $OLD8 → $HEAD8 (build $BUILD, tag $TAG)" -- NuvioMobile || fail "outer pointer commit failed"
    step pointer ok "$(git -C "$OUTER" rev-parse --short HEAD) (not pushed)"
  fi
else
  step bump skip "tag exists"; step push skip "already on origin"; step pointer skip "unchanged"
fi

# ---------------------------------------------------------------- build
mkdir -p "$LOG_DIR"
if [[ "$FROM" != upload ]]; then
  step build start
  BUILD_LOG="$LOG_DIR/$LABEL-xcodebuild.log"
  echo "xcodebuild log: $BUILD_LOG"
  T0=$SECONDS
  ( cd "$SUB" && xcodebuild -project iosApp/iosApp.xcodeproj -scheme NuvioTV -configuration Release \
      -destination "generic/platform=tvOS" -derivedDataPath "$DD" \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
      NUVIO_BETA_TAG="$TAG" ) >"$BUILD_LOG" 2>&1 &
  XPID=$!
  while kill -0 "$XPID" 2>/dev/null; do
    sleep 15
    N="$(grep -cE '^(SwiftCompile|CompileSwift|CompileC|Ld|> Task) ' "$BUILD_LOG" 2>/dev/null || echo 0)"
    LAST="$(grep -oE '(> Task :[^ ]+|[A-Za-z0-9_+]+\.(swift|mm?|c))' "$BUILD_LOG" 2>/dev/null | tail -1 | cut -c1-60)"
    mark "progress build $N compile steps${LAST:+ · $LAST}"
  done
  wait "$XPID"; XCODE_EXIT=$?
  grep -E '\*\* BUILD (SUCCEEDED|FAILED) \*\*|error:' "$BUILD_LOG" | tail -4
  [[ "$XCODE_EXIT" == 0 ]] && grep -q '\*\* BUILD SUCCEEDED \*\*' "$BUILD_LOG" || fail "xcodebuild exit $XCODE_EXIT; see $BUILD_LOG"
  E=$((SECONDS - T0)); step build ok "$((E / 60))m $((E % 60))s"
else
  step build skip "reusing the built product"
fi

# ---------------------------------------------------------------- stamp
step stamp start
P="$PRODUCTS/NuvioTV.app/Info.plist"
[[ -f "$P" ]] || fail "no Info.plist at $P"
pl() { /usr/libexec/PlistBuddy -c "Print :$1" "$P" 2>/dev/null; }
[[ "$(pl NuvioBetaTag)" == "$TAG" ]] || fail "NuvioBetaTag is '$(pl NuvioBetaTag)', expected $TAG"
[[ "$(pl NuvioCommitSHA)" == "$HEAD8" ]] || fail "NuvioCommitSHA is '$(pl NuvioCommitSHA)', HEAD is $HEAD8"
[[ "$(pl CFBundleVersion)" == "$BUILD" ]] || fail "CFBundleVersion is '$(pl CFBundleVersion)', expected $BUILD"
[[ "$(pl CFBundleShortVersionString)" == "$MV" ]] || fail "CFBundleShortVersionString is '$(pl CFBundleShortVersionString)', expected $MV"
step stamp ok "tag, sha $HEAD8, build $BUILD"

# ---------------------------------------------------------------- package
step package start
( cd "$PRODUCTS" && rm -rf Payload NuvioTV.ipa && mkdir Payload && cp -R NuvioTV.app Payload/ \
  && rm -rf Payload/NuvioTV.app/PlugIns && zip -qry NuvioTV.ipa Payload && rm -rf Payload ) || fail "packaging failed"
IPA="$HOME/Downloads/$IPA_NAME"
cp "$PRODUCTS/NuvioTV.ipa" "$IPA" || fail "copy to ~/Downloads failed"
SIZE="$(stat -f %z "$IPA")"
SHA="$(shasum -a 256 "$IPA" | cut -c1-16)"
mark "meta size=$SIZE sha=$SHA head=$HEAD8"
step package ok "$SIZE B"

# ---------------------------------------------------------------- upload
step upload start
LINKS=0
for ((i = 1; i <= LB_TRIES; i++)); do
  R="$(curl -s -m 300 -F reqtype=fileupload -F time=72h -F "fileToUpload=@$IPA" https://litterbox.catbox.moe/resources/internals/api.php || true)"
  if [[ "$R" == https://litter.catbox.moe/* ]]; then
    L="$(curl -sI -m 60 "$R" | grep -i '^content-length' | tr -dc '0-9')"
    if [[ "$L" == "$SIZE" ]]; then mark "url $R litterbox 72h"; LINKS=1; break; fi
    echo "litterbox attempt $i: $R reports $L bytes, expected $SIZE"
  else
    echo "litterbox attempt $i: $(echo "$R" | head -c 80 | tr -d '\n')"
  fi
  [[ $i -lt $LB_TRIES ]] && sleep 20
done

if [[ "$LINKS" == 0 ]]; then
  BIN="nuviotv-${LABEL//./}-$(openssl rand -hex 4)"
  F="https://filebin.net/$BIN/$IPA_NAME"
  curl -s -m 600 -X POST --data-binary "@$IPA" -H "Content-Type: application/octet-stream" "$F" >/dev/null || true
  J="$(curl -s -m 60 -H 'accept: application/json' "https://filebin.net/$BIN")"
  FB="$(echo "$J" | python3 -c 'import json,sys; d=json.load(sys.stdin); f=d.get("files") or [{}]; print(f[0].get("bytes",""), d.get("bin",{}).get("expired_at","")[:10])' 2>/dev/null)"
  if [[ "${FB%% *}" == "$SIZE" ]]; then mark "url $F filebin until-${FB#* }"; LINKS=$((LINKS + 1))
  else echo "filebin: bin reports '${FB%% *}' bytes, expected $SIZE"; fi

  SRV="$(curl -s -m 30 https://api.gofile.io/servers | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["servers"][0]["name"])' 2>/dev/null)"
  if [[ -n "$SRV" ]]; then
    G="$(curl -s -m 900 -F "file=@$IPA;filename=$IPA_NAME" "https://$SRV.gofile.io/contents/uploadfile" \
      | python3 -c 'import json,sys; d=json.load(sys.stdin).get("data",{}); print(d.get("size",""), d.get("downloadPage",""))' 2>/dev/null)"
    if [[ "${G%% *}" == "$SIZE" ]]; then mark "url ${G#* } gofile backup"; LINKS=$((LINKS + 1))
    else echo "gofile: reports '${G%% *}' bytes, expected $SIZE"; fi
  else
    echo "gofile: no upload server"
  fi
fi
[[ "$LINKS" -gt 0 ]] || fail "no host kept the full $SIZE bytes; the IPA is at $IPA"
step upload ok "$LINKS link(s)"
mark "done $TAG"

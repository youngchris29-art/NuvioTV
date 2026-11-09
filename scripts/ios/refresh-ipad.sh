#!/bin/bash
# Nuvio on the iPad: keep the sideloaded upstream iOS build current and signed.
#
#   scripts/ios/refresh-ipad.sh [--force] [--dry-run] [--no-release-check]
#
# Meant to run hourly 10:00–22:00 from ~/Library/LaunchAgents/com.youngchris29.nuvio-ipad.plist,
# but it does real work at most once a day. Each run:
#   1. runs scripts/ios/check-release.sh (new upstream release → notification + log)
#   2. decides whether to rebuild: a newer release tag than the installed one, or the
#      installed free-team profile has fewer than REFRESH_DAYS (default 2) days left
#   3. if so and the iPad is reachable: checks the side clone out at that tag, re-points the
#      app + widget to TEAM_ID / APP_BUNDLE_ID, deletes the old profiles so Xcode mints fresh
#      7-day ones, builds Release for iphoneos, installs with devicectl, records the state
#   4. notifies on success or failure; an unreachable iPad is retried by the next hourly slot
#
#   exit 0  done, or nothing to do today
#   exit 1  build or install failed (notified; no retry until tomorrow)
#   exit 2  config missing (~/.config/nuvio-ipad/config.env) or clone missing
#   exit 4  iPad unreachable (retried next slot; notified once after 21:00)
#
#   --force             rebuild and reinstall even if nothing changed
#   --dry-run           print the decision and stop before touching the clone or the iPad
#   --no-release-check  skip GitHub; use the installed tag
#
# State lives in ~/.config/nuvio-ipad/state.env; logs in ~/Library/Logs/nuvio-ipad/.
# Nothing here is pushed anywhere: the side clone is detached at a tag, never committed.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR="${NUVIO_IPAD_CONF:-$HOME/.config/nuvio-ipad}"
CONF="$CONF_DIR/config.env"
STATE="$CONF_DIR/state.env"
LOG_DIR="$HOME/Library/Logs/nuvio-ipad"
mkdir -p "$LOG_DIR"
TODAY="$(date +%F)"
LOG="$LOG_DIR/refresh-$TODAY.log"

FORCE=0; DRY=0; CHECK=1
for a in "$@"; do
  case "$a" in
    --force) FORCE=1 ;;
    --dry-run) DRY=1 ;;
    --no-release-check) CHECK=0 ;;
    -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
    *) echo "unknown flag: $a" >&2; exit 2 ;;
  esac
done

log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG"; }
notify() {  # title, body
  osascript -e "display notification \"${2//\"/\\\"}\" with title \"${1//\"/\\\"}\"" >/dev/null 2>&1 || true
}
# --- state helpers (tested in isolation by scripts/ios/tests/state-env-test.sh) ---------------
# state.env holds one KEY='value' per line, every value single-quoted (a ' inside becomes '\'').
# Until 2026-11-08 values were written bare, so a LAST_CAUSE with ( or ' made `. state.env` a
# syntax error: the run saw an empty state and skipped the once-a-day guard. load_state reads
# the file line by line and takes both forms (quoted, or bare as written before), never eval.
STATE_KEYS="INSTALLED_TAG PROFILE_EXPIRY LAST_RUN_DATE LAST_RESULT LAST_CAUSE LAST_SUCCESS"
shell_quote() {  # value → 'value' safe for `.`
  local s=$1
  s=${s//\'/\'\\\'\'}
  printf "'%s'" "$s"
}
save_state() {  # result [cause]; values are one line each (a newline becomes a space)
  local k v
  LAST_RUN_DATE=$TODAY; LAST_RESULT=$1; LAST_CAUSE=${2:-}
  for k in $STATE_KEYS; do
    v=${!k:-}; v=${v//$'\n'/ }
    printf '%s=' "$k"; shell_quote "$v"; printf '\n'
  done > "$STATE"
}
load_state() {  # file → sets the STATE_KEYS it names, other lines ignored
  local line key val
  [ -f "$1" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in *=*) ;; *) continue ;; esac
    key=${line%%=*}; val=${line#*=}
    case " $STATE_KEYS " in *" $key "*) ;; *) continue ;; esac
    case "$val" in
      \'*\') val=${val#\'}; val=${val%\'}; val=${val//\'\\\'\'/\'} ;;  # new quoted form
      \"*\") val=${val#\"}; val=${val%\"} ;;                          # tolerated, never written
    esac                                                          # else: bare pre-11-09 form
    printf -v "$key" '%s' "$val"
  done < "$1"
}
# --- end state helpers -------------------------------------------------------------------------
# Name the failure so the scheduled task (and Christian) see the cause, not just "failed".
classify_build_failure() {  # build log → one line
  if grep -q "No Accounts: Add a new account" "$1"; then
    echo "xcode-signed-out: Xcode has no Apple ID (an Xcode update signs it out). Fix: Xcode > Settings > Accounts, sign in, then rerun."
  elif grep -q "No profiles for" "$1"; then
    echo "no-profile: Xcode could not mint a provisioning profile for the free team; check the Accounts tab and the 7-day limit."
  elif grep -qi "Nuvio Engine\|prepare-ios-dependencies\|checksum mismatch" "$1"; then
    echo "engine-fetch: the Nuvio Engine framework download or checksum failed for this tag."
  elif grep -q "What went wrong\|generateRuntimeConfigs\|local.properties" "$1"; then
    echo "gradle: $(grep -m1 -A2 'What went wrong' "$1" | tail -1 | cut -c1-140)"
  elif grep -q "Your team has no devices" "$1"; then
    echo "no-device: the free team has no registered iPad; -allowProvisioningDeviceRegistration needs the iPad reachable."
  else
    echo "unclassified: $(grep -m1 -E 'error:' "$1" | cut -c1-140)"
  fi
}

[ -f "$CONF" ] || { echo "REFUSED: $CONF missing" >&2; exit 2; }
. "$CONF"
: "${IPAD_UDID:?}" "${CLONE:?}" "${TEAM_ID:?}" "${APP_BUNDLE_ID:?}"
REFRESH_DAYS="${REFRESH_DAYS:-2}"
WIDGET_BUNDLE_ID="$APP_BUNDLE_ID.DownloadsWidgetExtension"
DERIVED="$CLONE/build/DerivedDataDevice"
APP="$DERIVED/Build/Products/Release-iphoneos/Nuvio.app"
[ -d "$CLONE/.git" ] || { echo "REFUSED: clone missing at $CLONE" >&2; exit 2; }

INSTALLED_TAG=""; PROFILE_EXPIRY=""; LAST_RUN_DATE=""; LAST_RESULT=""; LAST_CAUSE=""; LAST_SUCCESS=""
load_state "$STATE"

# One real attempt per day: a success, a "nothing to do" or a failure ends the day.
if [ "$FORCE" = 0 ] && [ "$DRY" = 0 ] && [ "$LAST_RUN_DATE" = "$TODAY" ]; then
  case "$LAST_RESULT" in
    ok|nothing|failed) exit 0 ;;
  esac
fi

# 1. Release check -----------------------------------------------------------------------
LATEST="$INSTALLED_TAG"
if [ "$CHECK" = 1 ]; then
  "$HERE/check-release.sh" --quiet >>"$LOG" 2>&1
  rc=$?
  if [ $rc -eq 0 ] || [ $rc -eq 3 ]; then
    LATEST="$(cat "$CONF_DIR/latest-release" 2>/dev/null || echo "$INSTALLED_TAG")"
  else
    log "release check failed (exit $rc); keeping $INSTALLED_TAG"
  fi
fi

# 2. Decide --------------------------------------------------------------------------------
REASON=""
if [ -z "$INSTALLED_TAG" ]; then
  REASON="nothing installed yet"
elif [ -n "$LATEST" ] && [ "$LATEST" != "$INSTALLED_TAG" ]; then
  REASON="new release $LATEST (installed $INSTALLED_TAG)"
fi
DAYS_LEFT=""
if [ -n "$PROFILE_EXPIRY" ]; then
  exp_s="$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$PROFILE_EXPIRY" +%s 2>/dev/null || echo 0)"
  DAYS_LEFT=$(( (exp_s - $(date +%s)) / 86400 ))
  if [ "$DAYS_LEFT" -lt "$REFRESH_DAYS" ]; then
    REASON="${REASON:+$REASON; }profile expires in ${DAYS_LEFT}d"
  fi
fi
[ "$FORCE" = 1 ] && REASON="${REASON:+$REASON; }--force"

if [ -z "$REASON" ]; then
  log "nothing to do: $INSTALLED_TAG installed, profile ${DAYS_LEFT:-?}d left, latest $LATEST"
  save_state nothing
  exit 0
fi
log "refresh needed: $REASON"
TARGET="${LATEST:-$INSTALLED_TAG}"
if [ -z "$TARGET" ]; then
  log "FAILED: no release tag known (GitHub unreachable and nothing installed yet)"
  save_state failed "no-tag: GitHub unreachable and nothing installed yet"; exit 1
fi
if [ "$DRY" = 1 ]; then
  echo "DRY-RUN would build $TARGET and install on $IPAD_UDID"
  exit 0
fi

# 3. iPad reachable? -----------------------------------------------------------------------
if ! xcrun devicectl device info details --device "$IPAD_UDID" --timeout 20 >/dev/null 2>&1; then
  log "iPad $IPAD_UDID unreachable; will retry next slot"
  if [ "$(date +%H)" -ge 21 ]; then
    notify "Nuvio iPad refresh" "Could not reach the iPad today ($REASON). Unlock it on Wi-Fi and the job retries tomorrow."
  fi
  save_state unreachable "ipad-unreachable: devicectl could not reach the iPad; unlock it on the same Wi-Fi"
  exit 4
fi

# 4. Check out the tag and re-point signing ------------------------------------------------
cd "$CLONE" || exit 2
PBX=iosApp/iosApp.xcodeproj/project.pbxproj
XCCONFIG=iosApp/Configuration/Config.xcconfig
git checkout -q -- "$PBX" "$XCCONFIG" 2>/dev/null
if ! git fetch -q --tags origin >>"$LOG" 2>&1; then
  log "git fetch failed; building the current checkout"
fi
if ! git checkout -q --detach "$TARGET" >>"$LOG" 2>&1; then
  log "FAILED: cannot check out $TARGET"
  notify "Nuvio iPad refresh failed" "Cannot check out $TARGET in the side clone."
  save_state failed "git-checkout: tag $TARGET not found in the side clone"; exit 1
fi
git submodule update --init --recursive >>"$LOG" 2>&1 || log "warning: submodule update returned $?"

sed -i '' \
  -e "s/DEVELOPMENT_TEAM = [A-Z0-9]*;/DEVELOPMENT_TEAM = $TEAM_ID;/g" \
  -e "s/PRODUCT_BUNDLE_IDENTIFIER = [A-Za-z0-9.]*\.DownloadsWidgetExtension;/PRODUCT_BUNDLE_IDENTIFIER = $WIDGET_BUNDLE_ID;/g" \
  -e "s/PRODUCT_BUNDLE_IDENTIFIER = com\.nuvio\.[a-z]*;/PRODUCT_BUNDLE_IDENTIFIER = $APP_BUNDLE_ID;/g" \
  "$PBX"
sed -i '' "s/^TEAM_ID=.*/TEAM_ID=$TEAM_ID/" "$XCCONFIG"
if grep -qE "PRODUCT_BUNDLE_IDENTIFIER = com\.nuvio\.(app|media);" "$PBX"; then
  log "FAILED: bundle id rewrite did not take"; notify "Nuvio iPad refresh failed" "Bundle id rewrite did not take; see $LOG"
  save_state failed "bundle-id-rewrite: upstream changed its pbxproj bundle ids; update the sed in refresh-ipad.sh"; exit 1
fi
if [ ! -f local.properties ] && [ -n "${LOCAL_PROPERTIES_SRC:-}" ] && [ -f "$LOCAL_PROPERTIES_SRC" ]; then
  cp "$LOCAL_PROPERTIES_SRC" local.properties
fi
# Always the "full" flavor: the default "appstore" flavor has no P2P engine and refuses
# torrent streams ("This stream type is not supported"). Set it both ways so a fresh
# local.properties cannot fall back.
export NUVIO_IOS_DISTRIBUTION=full
if ! grep -q '^NUVIO_IOS_DISTRIBUTION=full' local.properties 2>/dev/null; then
  sed -i '' '/^NUVIO_IOS_DISTRIBUTION=/d' local.properties 2>/dev/null
  printf '\nNUVIO_IOS_DISTRIBUTION=full\n' >> local.properties
fi
# The full flavor links the Nuvio Engine xcframework; upstream's script fetches the version
# this tag pins (checksum-verified) into ../nuvio-engine beside the clone, once per version.
if [ -x scripts/prepare-ios-dependencies.sh ]; then
  if ! ./scripts/prepare-ios-dependencies.sh >>"$LOG" 2>&1; then
    log "FAILED: prepare-ios-dependencies.sh (Nuvio Engine download)"
    notify "Nuvio iPad refresh failed" "Could not fetch the Nuvio Engine framework for $TARGET; see $LOG"
    save_state failed "engine-fetch: prepare-ios-dependencies.sh failed (download or checksum) for $TARGET"; exit 1
  fi
fi

# 5. Drop our old profiles so Xcode mints fresh 7-day ones -------------------------------
for dir in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" "$HOME/Library/MobileDevice/Provisioning Profiles"; do
  [ -d "$dir" ] || continue
  for p in "$dir"/*.mobileprovision; do
    [ -f "$p" ] || continue
    appid="$(security cms -D -i "$p" 2>/dev/null | plutil -extract Entitlements.application-identifier raw - 2>/dev/null)"
    case "$appid" in
      "$TEAM_ID.$APP_BUNDLE_ID"|"$TEAM_ID.$WIDGET_BUNDLE_ID") rm -f "$p"; log "removed old profile $(basename "$p") ($appid)" ;;
    esac
  done
done

# 6. Build ---------------------------------------------------------------------------------
log "building $TARGET (Release, iphoneos) ..."
BUILD_LOG="$LOG_DIR/xcodebuild-$TODAY.log"
export JAVA_HOME="${JAVA_HOME:-/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home}"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! xcodebuild -project iosApp/iosApp.xcodeproj -scheme iosApp -configuration Release \
      -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" \
      -allowProvisioningUpdates -allowProvisioningDeviceRegistration build >"$BUILD_LOG" 2>&1; then
  cause="$(classify_build_failure "$BUILD_LOG")"
  log "FAILED: build ($cause)"
  notify "Nuvio iPad build failed" "${cause:-see $BUILD_LOG}"
  save_state failed "$cause"; exit 1
fi
[ -d "$APP" ] || { log "FAILED: $APP missing after build"; notify "Nuvio iPad build failed" "No Nuvio.app produced"; save_state failed "no-app: xcodebuild succeeded but produced no Nuvio.app"; exit 1; }
NEW_EXPIRY="$(security cms -D -i "$APP/embedded.mobileprovision" 2>/dev/null | plutil -extract ExpirationDate raw - 2>/dev/null)"
log "built $TARGET; profile valid until ${NEW_EXPIRY:-?}"

# 7. Install -------------------------------------------------------------------------------
if ! xcrun devicectl device install app --device "$IPAD_UDID" "$APP" >>"$LOG" 2>&1; then
  log "FAILED: devicectl install"
  notify "Nuvio iPad install failed" "Build $TARGET is ready but devicectl could not install it; see $LOG"
  save_state failed "install: devicectl could not install the build; see the refresh log"; exit 1
fi

INSTALLED_TAG="$TARGET"; PROFILE_EXPIRY="${NEW_EXPIRY:-}"; LAST_SUCCESS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
save_state ok
log "OK: Nuvio $TARGET installed on the iPad, profile until ${NEW_EXPIRY:-?}"
notify "Nuvio $TARGET on the iPad" "Installed and signed until ${NEW_EXPIRY%%T*}. ($REASON)"
exit 0

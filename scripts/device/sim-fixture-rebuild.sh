#!/bin/bash
# sim-fixture-rebuild.sh: rebuild the NuvioTV UI-test fixture simulator as a GUEST, in one command.
#
#   scripts/device/sim-fixture-rebuild.sh [--sim <udid>] [--app <NuvioTV.app>] [--force-clean]
#                                          [--no-cw] [--verify-only] [--keep-booted] [--out <dir>]
#
#   --sim <udid>     target simulator (default FA87E9B6-F28D-4DF9-84E4-A5A4C5DBFC4E, the fixture).
#                    "NuvioTV template" is refused: refresh it afterwards with `sim.sh template`.
#   --app <path>     a DEBUG simulator build of NuvioTV.app. Installed when the app is missing or
#                    with --force-clean. Default: the submodule's
#                    NuvioMobile/iosApp/build/DerivedData/Build/Products/Debug-appletvsimulator/NuvioTV.app
#   --force-clean    uninstall the app first (all its data goes), then install --app. Required when
#                    the app on the simulator belongs to a signed-in account; without it the script
#                    refuses (exit 3) and changes nothing.
#   --no-cw          skip the Continue Watching seed.
#   --verify-only    only run the verification step.
#   --keep-booted    leave the simulator booted at the end (default: shut it down if this run booted it).
#   --out <dir>      where the driver's .xcresult, the console captures and screenshots go
#                    (default ~/Library/Caches/nuvio-sim-fixture/runs/<timestamp>).
#
# What the fixture is (what the UI suite expects; see docs/sim-fixture-2026-11-19.md):
#   * a GUEST session started through the app's real Welcome › "Continue as Guest" path, so
#     `anonymous_user_id` (guest id) and `account_owner` = "" (owner: nobody) are written by the app
#     itself (AuthSessionModel GuestChosen → wipe → PersistOwner(null) → SaveGuestId);
#   * one local profile "Chris" (index 1, no PIN, auto-enter off), made through Add Profile › Save;
#   * add-ons: Cinemeta only (the app's own first-Home seed). The stream stubs "A"/"B" are NOT
#     fixture state: StreamPicker/AddonsHub serve and install them per test (DiscoveryStubServer);
#   * one stored Continue Watching entry (The Matrix, movie:tt0133093, 45 of 136 min), written by the
#     app's own guest-only seed (`-debug.continueWatchingSeedJsonB64` → upsertPlaybackProgress);
#     NOT tt0111161, which StageStrip S15 / HomeWatchlist seed and remove themselves;
#   * every setting at its fresh-install default.
#
# How the UI is driven without a Simulator window: scripts/device/sim-fixture/GuestFixtureDriver.swift
# is compiled here with swiftc into a UI-test bundle, hosted in the platform's stock XCTRunner.app
# and run with `xcodebuild test-without-building -xctestrun` (XCUIRemote presses). The app's Xcode
# project and its UI test target are not touched.
#
# Verification (always last): two relaunches with `simctl launch --console-pty`; each must print
# `[AuthSession] boot owner=none guest=trusted` and no `wipe started`; then the stored keys are
# checked (profile Chris, Cinemeta only, ≥1 progress entry) and a screenshot of the picker is
# saved. Ends with one line: `FIXTURE PASS` or `FIXTURE FAIL: <reasons>`.
#
# Output prints key NAMES, counts, profile names and add-on HOSTS only: never a value of a
# defaults key (add-on URLs can carry tokens; never `plutil -p` the domain).
#
# Locks: the whole run holds the simulator lock (scripts/build/with-sim-lock.sh, re-exec below);
# swiftc and xcodebuild run inside the build lock (with-lock.sh), sim lock outside, build inside.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUNDLE_ID="com.nuvio.media.NuvioTV"
SIM="FA87E9B6-F28D-4DF9-84E4-A5A4C5DBFC4E"
APP="$ROOT/NuvioMobile/iosApp/build/DerivedData/Build/Products/Debug-appletvsimulator/NuvioTV.app"
FORCE_CLEAN=0; NO_CW=0; VERIFY_ONLY=0; KEEP_BOOTED=0; OUT=""
ARGS=("$@")
while [ $# -gt 0 ]; do
  case "$1" in
    --sim) SIM="$2"; shift 2 ;;
    --app) APP="$2"; shift 2 ;;
    --force-clean) FORCE_CLEAN=1; shift ;;
    --no-cw) NO_CW=1; shift ;;
    --verify-only) VERIFY_ONLY=1; shift ;;
    --keep-booted) KEEP_BOOTED=1; shift ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,48p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Hold the simulator lock for the whole run (one re-exec).
if [ "${NUVIO_FIXTURE_SIM_LOCK_HELD:-}" != "1" ]; then
  export NUVIO_FIXTURE_SIM_LOCK_HELD=1
  exec "$ROOT/scripts/build/with-sim-lock.sh" "$0" "${ARGS[@]+"${ARGS[@]}"}"
fi

log() { echo "[sim-fixture] $*"; }
die() { echo "[sim-fixture] ERROR: $*" >&2; echo "FIXTURE FAIL: $*"; exit "${2:-1}"; }

[ -n "$OUT" ] || OUT="$HOME/Library/Caches/nuvio-sim-fixture/runs/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
log "output: $OUT"

# ---- simulator ----------------------------------------------------------------------------
SIM_LINE="$(xcrun simctl list devices | grep -F "($SIM)" | head -1)"
[ -n "$SIM_LINE" ] || die "no simulator with udid $SIM" 2
case "$SIM_LINE" in *"NuvioTV template"*) die "refusing the NuvioTV template; rebuild FA87, then sim.sh template" 2 ;; esac
log "simulator: $(echo "$SIM_LINE" | sed 's/^ *//')"
BOOTED_HERE=0
if ! echo "$SIM_LINE" | grep -q "(Booted)"; then
  log "booting"
  xcrun simctl boot "$SIM" || die "simctl boot failed"
  BOOTED_HERE=1
fi
xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || true
finish() {
  if [ "$BOOTED_HERE" = 1 ] && [ "$KEEP_BOOTED" = 0 ]; then
    xcrun simctl terminate "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
    log "shutting the simulator down (this run booted it)"
    xcrun simctl shutdown "$SIM" >/dev/null 2>&1 || true
  fi
}
trap finish EXIT

data_dir() { xcrun simctl get_app_container "$SIM" "$BUNDLE_ID" data 2>/dev/null; }
# The app's preferences live in its DATA CONTAINER (Library/Preferences/<bundle>.plist); `simctl
# spawn defaults read <bundle>` reads the simulator's global domain instead and misses them
# (2026-11-19: it reported a guest-chosen app as having no guest id). Read the plist directly.
pref_state() { # set / empty / absent: never the value
  local dd; dd="$(data_dir)"
  python3 - "$dd/Library/Preferences/$BUNDLE_ID.plist" "$1" <<'PY'
import plistlib, sys
try:
    d = plistlib.load(open(sys.argv[1], 'rb'))
except Exception:
    d = {}
k = sys.argv[2]
print('absent' if k not in d else ('set' if d[k] not in ('', None, False, 0) else 'empty'))
PY
}
app_installed() { xcrun simctl get_app_container "$SIM" "$BUNDLE_ID" app >/dev/null 2>&1; }

check_debug_app() { # the seeds are #if DEBUG; a Release build has none of their strings
  local bin="$1/NuvioTV"
  [ -f "$bin" ] || bin="$1/$(defaults read "$1/Info" CFBundleExecutable 2>/dev/null)"
  grep -aq "debug.continueWatchingSeedJsonB64" "$bin" "$1"/*.dylib 2>/dev/null \
    || die "$1 is not a DEBUG build (no debug seed strings); build Debug for the simulator" 2
}

install_app() {
  [ -d "$APP" ] || die "no app at $APP (pass --app)" 2
  check_debug_app "$APP"
  log "installing $(basename "$APP") from $(dirname "$APP")"
  xcrun simctl install "$SIM" "$APP" || die "simctl install failed"
}

xcrun simctl terminate "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true

if [ "$VERIFY_ONLY" = 0 ]; then
  # ---- account guard + clean install ------------------------------------------------------
  if [ "$FORCE_CLEAN" = 1 ]; then
    log "--force-clean: uninstalling $BUNDLE_ID (all its data)"
    xcrun simctl uninstall "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
    install_app
  elif ! app_installed; then
    install_app
  else
    OWNER_STATE="$(pref_state account_owner)"
    GUEST_STATE="$(pref_state anonymous_user_id)"
    log "on device: account_owner=$OWNER_STATE anonymous_user_id=$GUEST_STATE"
    if [ "$OWNER_STATE" = set ]; then
      die "the app on $SIM is signed in to an account (account_owner recorded); rerun with --force-clean to uninstall it first" 3
    fi
    DD="$(data_dir)"
    if [ -n "$DD" ] && ls "$DD/Library/Preferences/$BUNDLE_ID.plist" >/dev/null 2>&1; then
      if python3 - "$DD/Library/Preferences/$BUNDLE_ID.plist" <<'PY'
import plistlib, sys
d = plistlib.load(open(sys.argv[1], 'rb'))
sys.exit(0 if any(k.startswith(('trakt_auth_payload', 'simkl_auth', 'mdblist_api_key')) and d[k] for k in d) else 1)
PY
      then die "tracker credentials are stored in the app on $SIM; rerun with --force-clean" 3; fi
    fi
    check_debug_app "$(xcrun simctl get_app_container "$SIM" "$BUNDLE_ID" app)"
  fi

  # ---- build the standalone driver (cached by source hash) ---------------------------------
  SRC="$HERE/sim-fixture/GuestFixtureDriver.swift"
  PLAT="$(xcode-select -p)/Platforms/AppleTVSimulator.platform/Developer"
  SDK="$(xcrun --sdk appletvsimulator --show-sdk-path)"
  HASH="$( (shasum "$SRC"; xcodebuild -version) | shasum | cut -c1-12)"
  DRV="$HOME/Library/Caches/nuvio-sim-fixture/driver-$HASH"
  RUNNER="$DRV/FixtureDriver-Runner.app"
  if [ ! -f "$DRV/.built" ]; then
    log "building the driver into $DRV"
    rm -rf "$DRV"; mkdir -p "$DRV"
    cp -R "$PLAT/Library/Xcode/Agents/XCTRunner.app" "$RUNNER"
    mv "$RUNNER/XCTRunner" "$RUNNER/FixtureDriver-Runner"
    plutil -replace CFBundleExecutable -string FixtureDriver-Runner "$RUNNER/Info.plist"
    plutil -replace CFBundleName -string FixtureDriver-Runner "$RUNNER/Info.plist"
    plutil -replace CFBundleIdentifier -string com.nuvio.fixturedriver.xctrunner "$RUNNER/Info.plist"
    XT="$RUNNER/PlugIns/FixtureDriver.xctest"
    mkdir -p "$XT"
    cat > "$XT/Info.plist" <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleExecutable</key><string>FixtureDriver</string>
<key>CFBundleIdentifier</key><string>com.nuvio.fixturedriver</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleName</key><string>FixtureDriver</string>
<key>CFBundlePackageType</key><string>BNDL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleSupportedPlatforms</key><array><string>AppleTVSimulator</string></array>
<key>MinimumOSVersion</key><string>17.0</string>
<key>UIDeviceFamily</key><array><integer>3</integer></array>
<key>XCTContainsUITests</key><true/>
</dict></plist>
PL
    "$ROOT/scripts/build/with-lock.sh" xcrun --sdk appletvsimulator swiftc \
      -target arm64-apple-tvos17.0-simulator -sdk "$SDK" \
      -F "$PLAT/Library/Frameworks" -I "$PLAT/usr/lib" -L "$PLAT/usr/lib" \
      -module-name FixtureDriver -parse-as-library -emit-library -Xlinker -bundle \
      -framework XCTest -lXCTestSwiftSupport \
      -o "$XT/FixtureDriver" "$SRC" || die "swiftc failed"
    codesign -f -s - "$XT" >/dev/null 2>&1 || die "codesign (bundle) failed"
    codesign -f -s - --entitlements "$RUNNER/RunnerEntitlements.plist" "$RUNNER" >/dev/null 2>&1 \
      || codesign -f -s - "$RUNNER" >/dev/null 2>&1 || die "codesign (runner) failed"
    touch "$DRV/.built"
  else
    log "driver cached: $DRV"
  fi

  # ---- run the driver ----------------------------------------------------------------------
  CW_SEED=""
  if [ "$NO_CW" = 0 ]; then
    CW_SEED="$(printf '%s' '[{"type":"movie","id":"tt0133093","title":"The Matrix","positionMin":45,"durationMin":136,"poster":"https://images.metahub.space/poster/medium/tt0133093/img","background":"https://images.metahub.space/background/medium/tt0133093/img","logo":"https://images.metahub.space/logo/medium/tt0133093/img"}]' | base64)"
  fi
  XCTESTRUN="$OUT/FixtureDriver.xctestrun"
  # xcodebuild insists on a UITargetAppPath and (re)installs it before the run. Hand it a copy of
  # the bundle that is installed on the simulator right now: the reinstall is the same binary and
  # an over-the-top install keeps the app's data container.
  INSTALLED="$(xcrun simctl get_app_container "$SIM" "$BUNDLE_ID" app)" || die "app not installed"
  rm -rf "$OUT/target"; mkdir -p "$OUT/target"; cp -R "$INSTALLED" "$OUT/target/NuvioTV.app"
  python3 - "$XCTESTRUN" "$CW_SEED" "$BUNDLE_ID" <<'PY'
import plistlib, sys
path, seed, bundle = sys.argv[1:4]
fw = "__PLATFORMS__/AppleTVSimulator.platform/Developer/Library/Frameworks"
lib = "__PLATFORMS__/AppleTVSimulator.platform/Developer/usr/lib"
env = {"FIXTURE_CW_SEED_B64": seed, "FIXTURE_BUNDLE_ID": bundle, "FIXTURE_PROFILE_NAME": "Chris"}
plistlib.dump({
    "__xctestrun_metadata__": {"FormatVersion": 1},
    "FixtureDriver": {
        "TestHostPath": "__TESTROOT__/FixtureDriver-Runner.app",
        "TestBundlePath": "__TESTHOST__/PlugIns/FixtureDriver.xctest",
        "TestHostBundleIdentifier": "com.nuvio.fixturedriver.xctrunner",
        "IsUITestBundle": True,
        "IsXCTRunnerHostedTestBundle": True,
        "UITargetAppBundleIdentifier": bundle,
        "UITargetAppPath": "__TESTROOT__/target/NuvioTV.app",
        "TestingEnvironmentVariables": {"DYLD_FRAMEWORK_PATH": fw, "DYLD_LIBRARY_PATH": lib},
        "EnvironmentVariables": env,
        "UserAttachmentLifetime": "keepAlways",
        "SystemAttachmentLifetime": "keepAlways",
    },
}, open(path, "wb"))
PY
  # __TESTROOT__ is the xctestrun's directory: point it at the cached runner.
  ln -sfn "$RUNNER" "$OUT/FixtureDriver-Runner.app"
  log "running the guest walk (Continue as Guest › Add Profile Chris › Home$( [ -n "$CW_SEED" ] && echo ' › Continue Watching seed'))"
  "$ROOT/scripts/build/with-lock.sh" xcodebuild test-without-building \
      -xctestrun "$XCTESTRUN" -destination "platform=tvOS Simulator,id=$SIM" \
      -resultBundlePath "$OUT/driver.xcresult" -collect-test-diagnostics never \
      > "$OUT/driver.log" 2>&1
  DRV_RC=$?
  grep -E "\[FixtureDriver\]|error:|Test Case .* (passed|failed)|\*\* TEST" "$OUT/driver.log" | sed 's/^/  /' | tail -40
  [ "$DRV_RC" = 0 ] || die "the driver failed (rc=$DRV_RC); see $OUT/driver.log and $OUT/driver.xcresult"
  xcrun simctl terminate "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
fi

# ---- verification ------------------------------------------------------------------------------
FAIL=()
boot_capture() { # boot_capture <n>: launch with the console attached for ~35 s
  local f="$OUT/console-$1.txt"
  xcrun simctl terminate "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 2
  xcrun simctl launch --console-pty "$SIM" "$BUNDLE_ID" -debug.rememberLastProfile NO > "$f" 2>&1 &
  local pid=$!
  sleep 35
  xcrun simctl io "$SIM" screenshot "$OUT/picker-$1.png" >/dev/null 2>&1 || true
  xcrun simctl terminate "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 2
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  local line; line="$(grep -m1 -F "[AuthSession] boot" "$f" | tr -d '\r')"
  log "relaunch $1: ${line:-<no [AuthSession] boot line>}"
  echo "$line" | grep -q "owner=none guest=trusted" || FAIL+=("relaunch $1 boot line is not a trusted guest with owner none")
  if grep -qE "\[AuthSession\] (wipe started|lost reset|guest id cleared)" "$f"; then
    FAIL+=("relaunch $1 wiped or reset ($(grep -oE "\[AuthSession\] (wipe started|lost reset[^\r]*|guest id cleared)" "$f" | head -1))")
  fi
}
boot_capture 1
boot_capture 2

DD="$(data_dir)"
[ -n "$DD" ] || FAIL+=("app data container not found")
PLIST="$DD/Library/Preferences/$BUNDLE_ID.plist"
REPORT="$(python3 - "$PLIST" "$DD/Library/Caches/PayloadStores" <<'PY'
import json, plistlib, sys, os, urllib.parse
plist, stores = sys.argv[1:3]
fails, out = [], []
try:
    d = plistlib.load(open(plist, 'rb'))
except Exception as e:
    print(json.dumps({"fails": [f"preferences unreadable: {type(e).__name__}"], "out": []})); sys.exit()
out.append(f"preference keys: {len(d)}")
out.append("key names: " + ", ".join(sorted(k for k in d if not k.startswith('debug.'))))
guest = d.get('anonymous_user_id')
owner = d.get('account_owner')
out.append(f"anonymous_user_id: {'set' if guest else 'absent'}; account_owner: {'empty (nobody)' if owner == '' else ('absent' if owner is None else 'SET (account)')}")
if not guest: fails.append("no guest id")
if owner != '': fails.append("owner is not recorded as nobody")
if d.get('account_wipe_pending'): fails.append("wipe marker set")
try:
    p = json.loads(d.get('profile_payload') or '{}')
except Exception:
    p = {}
profiles = p.get('profiles') or []
names = [x.get('name') for x in profiles]
out.append(f"profiles: {len(profiles)} {names}; payload bound to the guest: {p.get('userId') == guest and bool(guest)}; rememberLastProfileEnabled={p.get('rememberLastProfileEnabled')}")
chris = [x for x in profiles if x.get('name') == 'Chris']
if not chris: fails.append("no Chris profile")
else:
    c = chris[0]
    idx = c.get('profile_index', 1)
    out.append(f"Chris: profile_index={idx} pin_enabled={c.get('pin_enabled', False)} uses_primary_addons={c.get('uses_primary_addons')}")
    if c.get('pin_enabled'): fails.append("Chris has a PIN")
    if profiles and profiles[0].get('name') != 'Chris': fails.append("Chris is not the first profile")
    if p.get('userId') != guest: fails.append("profile payload is not bound to the guest id")
    if p.get('rememberLastProfileEnabled'): fails.append("auto-enter (remember last profile) is on")
    urls = [u for u in (d.get(f'installed_manifest_urls_{idx}') or '').split('\n') if u.strip()]
    hosts = [urllib.parse.urlsplit(u).netloc for u in urls]
    out.append(f"installed add-ons (profile {idx}): {len(urls)} hosts={hosts}")
    if hosts != ['v3-cinemeta.strem.io']: fails.append(f"add-ons are not Cinemeta only ({len(urls)} installed)")
    wp = os.path.join(stores, 'WatchProgress', f'watch_progress_payload_{idx}.json')
    try:
        entries = json.load(open(wp)).get('entries') or []
    except Exception:
        entries = []
    out.append(f"watch progress entries (profile {idx}): {len(entries)} {[e.get('videoId') for e in entries]}")
    if not entries: fails.append("no stored watch progress")
    if any(e.get('videoId') == 'tt0111161' for e in entries): fails.append("tt0111161 is stored (the tests seed/remove it themselves)")
tracker = [k for k in d if k.startswith(('trakt_auth_payload', 'simkl_auth')) and d[k]]
if tracker: fails.append("tracker auth keys present: " + ", ".join(tracker))
print(json.dumps({"fails": fails, "out": out}))
PY
)"
echo "$REPORT" | python3 -c 'import json,sys; [print("[sim-fixture]   "+l) for l in json.load(sys.stdin)["out"]]'
while IFS= read -r f; do [ -n "$f" ] && FAIL+=("$f"); done < <(echo "$REPORT" | python3 -c 'import json,sys; [print(f) for f in json.load(sys.stdin)["fails"]]')
log "screenshots: $OUT/picker-1.png $OUT/picker-2.png"

if [ ${#FAIL[@]} -eq 0 ]; then
  echo "FIXTURE PASS ($SIM: guest Chris, Cinemeta, Continue Watching stored, two relaunches without a wipe)"
  exit 0
fi
echo "FIXTURE FAIL: $(IFS='; '; echo "${FAIL[*]}")"
exit 1

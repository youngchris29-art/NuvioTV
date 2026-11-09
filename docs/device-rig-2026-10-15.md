# Device rig: NuvioTV device passes from the Mac (2026-10-15)

A Claude session can now walk NuvioTV on the Living Room Apple TV 4K (3rd gen, tvOS 27.2, devicectl
UDID `00008110-001A6DCE0AF2201E`, LAN `192.168.1.86` / `Living-Room.local`) without anyone holding the
Siri Remote: inputs go over pyatv's Companion protocol, pictures come back over `devicectl`, and the app's
console streams into a log file. This replaces the 2026-08-03 finding that device passes were
"irreducibly manual". Scripts live in `scripts/device/`; evidence from the proof run is in
`docs/research/device-rig-2026-10-15/`.

## What it is

| Piece | What it does |
|---|---|
| `scripts/device/.venv` | pyatv 0.18.0 on **Python 3.12** (`/opt/homebrew/bin/python3.12`). pyatv's `atvremote` calls `asyncio.get_event_loop()`, which Python 3.14 removed, so the venv must stay on 3.12. Ignored by git. |
| `scripts/device/pair.py` | One-time Companion pairing with a hand-built config (see "Pairing"). Writes the credential string to `~/.config/nuviotv-device/atv-credentials` (mode 600). |
| `scripts/device/atv.sh` | `press`, `hold <button> [s]`, `swipe x0 y0 x1 y1 [ms]`, `click`, `touch`, `wake`, `sleep`, `features`, `launch <bundle>`, `seq <steps…>`, `raw`. Loads `~/.config/nuviotv-device/atv.env` + the credentials, re-resolves the Companion port from Bonjour on every call. |
| `scripts/device/atvctl.py` | The sequence runner behind `atv.sh seq`/`press`/`hold`: several inputs over ONE connection (`down sleep=0.3 down select hold=right,4 swipe=100,500,900,500,60 text=…`). A separate `atvremote` call costs ~3.7 s of connection setup; a 12-step walk through `seq` runs in ~4 s. Presses last `PRESS_MS` (default 100 ms). |
| `scripts/device/shot.sh` | `devicectl device capture screenshot` → 3840×2160 PNG, 1.3 s idle, up to 4 s while a title plays. `SHOT_SMALL=1` writes a 960-px copy for reading. |
| `scripts/device/rec.sh` | `start`/`stop`/`for <s>`/`frames <mp4> [fps]`. Backend auto-detected once and cached in `~/.config/nuviotv-device/rec.backend`: `devicectl` screen-record if the box supports it, else the Mac's AVFoundation Apple TV source, else a **screenshot burst** (the only one this box offers, see below). |
| `scripts/device/console.sh` | `start [log] [-- app args]` launches `com.youngchris29.NuvioTV` with `devicectl device process launch --terminate-existing --console` and tails stdout/NSLog into the log untruncated (the 09-30 walks' recipe); `stop`, `tail`, `grep`. |

Nothing under `~/.config/nuviotv-device/` is in the repo: `atv.env` (name, address, port, Companion id,
UDID, credentials path) and `atv-credentials`. `NUVIOTV_DEVICE_CONF` points the scripts elsewhere.

## Pairing (done 2026-10-15; redo only after a reset of the TV or the Mac)

The Living Room box advertises `_companion-link._tcp` on port 49153 with TXT keys `rpMac rpHN rpFl rpHA
rpMd rpVr rpAD rpHI rpBA` and **no `rpMRtID`**, and it advertises neither AirPlay nor MRP (both
`dns-sd -B` and pyatv's scan see only the Mac). pyatv derives a Companion device's identifier from
`rpMRtID`, so both `atvremote scan` and `--scan-hosts 192.168.1.86` auto-discover the service and then
drop the device as identifier-less (`--debug` shows "Auto-discovered Living Room at 192.168.1.86:49153
via Protocol.Companion" followed by an empty result). `--manual --id <anything>` sidesteps that, and
`pair.py` does the same through the API:

```bash
scripts/device/.venv/bin/python scripts/device/pair.py 192.168.1.86 49153 74c6de7c4e51 \
  ~/.config/nuviotv-device/pair.pin ~/.config/nuviotv-device/atv-credentials
```

It begins pairing (the TV shows "Authenticate / Your authentication code is: N N N N"), then waits up to
20 minutes for the PIN in the file. **The PIN is readable off `shot.sh`'s screenshot**, so the whole
pairing ran without anyone in the room: `pair.py` → `shot.sh` → read the four digits → `echo NNNN >
pair.pin` → `PAIRING_OK`. The TV shows the Authenticate card over the app and dismisses it on its own.
`rpFl=0x36782` carries the PIN-pairing-supported bit; the `features` call afterwards lists Up/Down/
Left/Right/Select/Menu/Home/PlayPause/Volume, AppList/LaunchApp, AccountList/SwitchAccount, PowerState/
TurnOn/TurnOff, Text*, **Swipe, Action, Click** as Available on tvOS 27.2 — the pyatv-on-tvOS-27
compatibility result is: Companion works, nothing else is advertised.

The Companion port is re-resolved on every `atv.sh` call (`dns-sd -L "Living Room"
_companion-link._tcp local.`, 3 s cap, falls back to `ATV_COMPANION_PORT` from `atv.env`) because tvOS
picks a new port after a reboot. `ATV_ID` is the `rpHN` value; any stable string works for a manual id.

## Running a pass

```bash
scripts/device/console.sh start docs/research/<pass>/console.log      # relaunches the app, streams the log
scripts/device/shot.sh picker                                            # look before you walk
scripts/device/atv.sh seq right sleep=1 select sleep=8                   # Test 2 is one right of Chris
scripts/device/atv.sh seq left sleep=1.2 down sleep=0.3 down sleep=0.3 down sleep=0.3 down sleep=0.3 down sleep=0.6 select
scripts/device/atv.sh hold right 4                                       # FF scan
scripts/device/atv.sh swipe 150 500 750 500 160                          # swipe-scrub rightwards
REC_BACKEND=burst scripts/device/rec.sh for 12 docs/research/<pass>/scan.mp4 &  scripts/device/atv.sh hold right 4; wait
scripts/device/console.sh grep '\[Thumbs\]|\[Harvest\]|iframe'
```

Facts that shape a walk (all seen on 2026-10-15):

- **Profile.** Every pass runs in **"Test 2"** (avatar "T"; picker order Chris / Test 2 / KT / Add
  Profile). Never select Chris. After `console.sh start` the picker is up with Chris focused: `right`,
  `select`.
- **Walk from a screenshot, not from an assumed position.** The Settings root remembers its last
  focused category (a blind five-down from "Account & Profiles" landed in Developer); panes open at
  the top. Row counts used today: Settings root Account & Profiles 0 … Player 5 … Developer 9; Player
  pane Native player = 13 down from the top; Developer pane Seek Preview Frames (A/B) = 16 down.
- **Swipe axis.** The surface is 0…1000 in both axes; x decreasing = finger moving left = focus moves
  left. `swipe 100 500 900 500 60` (fast, long) carried focus four cards with momentum on a Home row,
  which no press can do. A rightward swipe during playback is a scrub (see step 11 below).
- **Select on a Continue Watching card opens the Sources picker** (Auto-Play Best is off in Test 2);
  the picker's initial focus is sometimes the add-on header, sometimes the first stream — screenshot
  first. Select on a poster whose card has morphed into the playing inline trailer enters the
  full-screen trailer, not Detail.
- **Menu.** The player's Menu precedence holds (bar up → first Menu drops the bar, second exits). See
  the 0 ms caveat below: keep `PRESS_MS` ≥ 100.
- `console.sh start` once relaunched the app into the **background** (tvOS home screen with the icon
  focused, the app's init lines in the log); `atv.sh launch com.youngchris29.NuvioTV` or a Select on
  the icon foregrounds it. `launch` also recovers from an eject.
- Console logs carry add-on config tokens in subtitle URLs (`…/stremio/<token>/…`): redact before
  committing a log (`sed -E 's#(/stremio/)[^/ "]+#\1<redacted>#g'`).
- Per-call cost: `atv.sh seq` ≈ 3.7 s connection + the steps; `shot.sh` 1.3–4 s. Budget ~10 s per
  "move, look" cycle.

- ⚠️ **Companion Menu exits the native (AVKit) player when the native chrome is hidden** (rewritten 2026-11-03 from the Insights cast device pass of 2026-11-02). A Companion Menu press while the chrome is hidden exits the native player, so an accidental Menu there drops the rig straight out of playback (on 2026-11-02 a Cast card was focused with the actor view closed and the player exited to Home). With the top panel or a tool overlay open, Menu closes that layer first. On 2026-10-17 six 150 ms Menu presses with the top panel closed did not exit; that build predates the Insights chrome rework. A physical Siri Remote exits normally. AVKit's system transport bar isn't in screenshots either. To leave native playback from the rig, relaunch with `console.sh start` (playback progress is saved).

## What the rig can and cannot judge

Can: focus position and row paging (screenshots), every console-visible fact (engine route, `[Thumbs]`
/ `[Harvest]` / `[HLS]` lines, exits, crashes), Settings state, picker contents, transport-bar state
mid-hold (a screenshot from a parallel process lands inside a 4 s hold), coarse motion (burst frames
with timestamps).

Cannot (stays manual, Christian at the panel): what the display outputs (HDR/DV mode switch, Match
Content), tone-map look, audio (language, sync, dropouts), the feel of a scroll or a bounce at frame
accuracy, and anything in the tvOS system UI that a Companion press cannot reach. Screenshots are the
app's rendered frame, not the panel.

**Recording.** `devicectl device capture screen-record` answers *"The capability 'Screen Recording' is
not supported by this device"* (CoreDeviceError 1001) on this Apple TV; QuickTime Player lists no
Apple TV among its video recording devices and AVFoundation exposes none, so there is no real
recording route from this Mac. `rec.sh` falls back to a **screenshot burst**: four parallel `devicectl`
captures (one capture is 1.3 s idle, ~4 s during playback, so parallel workers get ~0.5–0.7 fps),
frame files named by capture-completion ms, `frames.tsv` with offsets, and a 1 fps mp4. That is enough
to say "the position moved 06:04 → 06:05 inside the scan" and to catch a frozen picture; it is not
enough for bounce/stutter triage, which still needs a phone video of the panel (how Steven's videos
were read).

## Caveats found on 2026-10-15

- ⚠️ **0 ms Menu ejects the app.** pyatv's own press sends HID down and up back to back. Twice, a
  0 ms Menu that exited the **mpv** player left the app in the background on the tvOS home screen
  (console silent after `[Failover] viewWillDisappear isLeavingPlayer=true`; the following Selects
  launched Infuse). Timed 150 ms presses (`hold=menu,0.15`) exited to the Sources picker both times,
  and the native player never ejected on either kind. `atvctl.py` therefore holds every press
  `PRESS_MS` (default 100 ms). Not reproduced with a physical remote; logged here as a rig caveat and a
  possible robustness item for the mpv exit path (the P1 round-1 Menu recogniser gating is the
  neighbourhood).
- The parent session's `--console` stream must be stopped before `console.sh start`; `--terminate-
  existing` kills the app, and the old stream ends with it (it did, cleanly).
- The 7-day **free-team profile**: the dev build installed on 2026-10-15 carries a profile that
  expires **2026-10-22 04:23Z**. After that, installs fail with `0xe8008011` and launches with
  `FBSOpenApplicationServiceErrorDomain 1`. Renew: delete the stale `tvOS Team Provisioning Profile:
  com.youngchris29.NuvioTV*` files in `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`,
  rebuild with `-allowProvisioningUpdates` and the per-target bundle-id override (memory
  `device-build-bundle-id-collision`), `devicectl device install app`, then `console.sh start`.
- The XCUITest-on-device route (NuvioTVUITests with a `com.youngchris29.NuvioTVUITests` override) was
  **not needed** and was not exercised: Companion pairing succeeded.

## Proof run: player P3 device pass, steps 8–12 (Test 2, build 135 from `0673f73c2`)

Console: `docs/research/device-rig-2026-10-15/console-rig.log` (redacted). Screenshots are 1280-wide
JPEGs in the same folder. The state the pass left behind: **native player ON, Seek Preview Frames =
Harvest Only (the default)**.

- **Step 9 PASS (both engines).** Developer › Seek Preview Frames = Off (`dev-off-set.jpg`).
  *Native* (native ON, Lizzie Borden Took an Ax, SDR MKV → `[PlayerRouter] native — SDR`): the master
  is the pre-P3 one, `[HLS] master iframes=0 independent=0`, no `iframe.m3u8` request, 0 `[Thumbs]`,
  0 `[Harvest]`; a 4 s held Right scanned with the time running (02:47 → 03:26) and the picture frozen
  (`step9-native-mid-hold.jpg`, `-after-hold.jpg`) — the pre-P3 `canPlayFastForward` behaviour; exit
  logged `[Remux] failed at cancelled`. *mpv* (native OFF, same title → `[Failover] mpv start watchdog
  armed`): 45 s of healthy play (`[MPVStats] … cache=95.9s underruns=0`), 0 `[Thumbs]`, 0 `[Harvest]`
  (`step9-mpv-playing2.jpg`).
- **Step 8 PASS on the SDR leg (HDR10 and DV legs owed).** Harvest Only, native ON, same title:
  `[HLS] master iframes=1 independent=0 iframePlaylist independent=1 mode=trim`, `200 iframe.m3u8`;
  a 4 s held Right requested **29 `iframe-*.m4s`, all 200, 0 404s** (00041–00069, 247–489 KB each,
  `mode=trim`), the burst (`step8-scan-burst.mp4`, `frames.tsv`) shows the bar with the FF glyph and
  the position moving 06:04 → 06:05 across the first 1.7 s of the ramp. **Paused swipe-scrub
  re-check: not blank.** After `play_pause` + a rightward swipe, AVKit requested `iframe-00085…00089`
  (`[HLS] iframe iframe-00085.m4s from seg (11175242 → 346732 bytes, mode=trim)`) and the screen
  showed the 11:47 frame with the bar (`step8-paused-scrub-a.jpg`), then the committed position
  playing a second later (`-b.jpg`). So `#EXT-X-INDEPENDENT-SEGMENTS` on the I-frame playlist changed
  the 10-08 spike's "never requests an I-frame" result; whether what showed is AVKit's scrub preview
  or the committed seek frame needs Christian's eyes once (the rig cannot tell a preview from a
  committed frame). Exit: `[Remux] failed at cancelled`.
- **Step 11 PASS on what the rig can reach.** On mpv (Harvest Only): `[Harvest] took=122.1ms
  size=1920x1080 … src=mpv` 20 s into playback, then `stored n=1` (the "within 15 s" line in the
  checklist is the first capture after the 20 s healthy-play gate; the parent log's timings agree);
  swipe scrub: `[Scrub] begin base=257.76 thr=160 curve=orivio`, `stroke end intent=h travel=1254
  vx=7623`, bar up with chapter ticks and the "Chapter 05" label at 20:54 (`step11-swipe-scrub-a.jpg`),
  `cancel why=idle` 8 s later; hold step: bar up, position 4:46 → 4:58 across a 2.5 s hold
  (`step11-hold-mid.jpg`, `-after.jpg`); Menu precedence: bar up → first Menu kept playing, second
  exited with `[Failover] viewWillDisappear isLeavingPlayer=true` + Vulkan teardown; the Aspect pill
  is in the bar's icon row (`step11-menu1.jpg`). Not walked: Left/Right Click skip, the Aspect pill's
  menu, Menu over the up-next chip.
- **Step 12 PASS.** Home (`step12-home-final2.jpg`), Search with the letter keyboard and Recent
  Searches (`step12-search.jpg`), a Test Folder collection page and a Detail page
  (`step12-detail4.jpg`), the native bar and info hint (`step9-native-mid-hold.jpg`) all render as
  before.
- **Still owed:** step 8's HDR10 and DV legs (need those titles and the panel), step 10 (no Cue-less
  MKV on the box), step 5's Harvest Only control run (20 min, RSS row read by a human), the step 3
  post-play-card leg.

## Round 3 additions (10:21–10:50 ET)

- `scripts/device/preflight.sh`: refuses a walk unless the tunnel is up, the console stream follows the
  CURRENT app pid, and that process's last `[ProfileSelect] selecting profile N` is the Test profile
  (`TEST_PROFILE_INDEX`, default 3). Born of a real miss: tvOS had relaunched the app cold overnight,
  the first blind Select of the morning picked Chris on the fresh picker, and three minutes of
  navigation ran in his profile before the rail avatar gave it away. **Never start a walk with a
  Select; screenshot first; never trust yesterday's console stream.**
- Normalizing walks: `left ×8` always arms the rail from any row; `up ×12` always reaches the top of
  the Settings root or a pane; count down from there. Panes open at the top; the root remembers.
- `hold` releases in a `finally`; a pyatv protocol error mid-hold once left Right held on the TV (the
  native scan ran on for 20 s, two Menus were swallowed) until a plain Right press released it. After
  any `ProtocolError` during a hold, send `atv.sh press <button>`.
- `text=<string>` types into the Search field over Companion (`.searchable` keyboard focused).
- Select on a Detail whose hero trailer is already playing enters the full-screen trailer; press Play
  within ~2 s of the Detail appearing, or Menu out and reopen.
- Step 8's HDR10 and DV P8.1 legs ran through the rig (record in the P3 plan OUTCOME round 3), plus
  finding P3-F7 (a DV profile 5 MP4 fails native with CoreMediaErrorDomain -12927 and falls over to mpv).

- ⚠️ **HDR output kills screenshots.** While the panel is in HDR/DV output mode (Match Content →
  Dynamic Range on), `devicectl … capture screenshot` fails with "connection was invalidated"
  (Mercury 1001) on every attempt (10+ over 80 s during a 4K HDR10 stream on mpv) and succeeds a
  second after the title is left; during native HDR10/DV legs it was intermittent. Plan HDR legs
  around console evidence, and read UI-only values (the Info tab's RSS) on SDR titles or log them.
- The mpv Info panel opens on a FAST vertical swipe (`swipe=500,100,500,900,80`); a 200 ms one is a
  pan, not a swipe, and is ignored. Menu closes the panel; a Down press keeps it.
- `play_pause` over Companion did not pause the mpv player once (position kept advancing); the native
  player paused fine. Verify a pause from the console position, not from the press.

- `console.sh start <log> -- <app args>` works (the `--` is passed to devicectl); `-debug.mpvSmokeURL
  <url>` presents the mpv player over the root on a DEBUG build, profile gate or not, which makes any
  file on the Mac a test title (a Range-capable server is needed: `python3 -m http.server` has none).
- The Seek Preview Frames picker opens with **Off** focused, not the current value: Off = select,
  Harvest Only = down ×1, Harvest + Decode = down ×2.
- ⚠️ **Leaving the mpv player ejected the app twice** (once with a 0 ms press, once with 150 ms), and
  the next blind presses ran in whatever tvOS showed (Infuse, which started a film from Christian's
  library). After every player exit, screenshot before the next press; `preflight.sh` catches the
  profile but not the foreground app. P3-F8 in the plan.
- A walk that starts inside a player is the worst case: Left/Up/Down/Select become seeks, pauses and
  bar actions. Never chain a navigation walk after an exit without a screenshot in between.

- Swipe scrub commits with a touch `click` right after the swipe (`swipe=150,500,850,500,120 sleep=1 click`);
  without the click the scrub cancels on idle. One stroke ≈ 10 min on a 45 min episode, 17 min on a film.
- Timing-critical presses (the up-next card's ~8 s window) need ONE held Companion session: a
  per-call connect costs 3.7 s and a dropped press loses the window. `atvctl.py` has it as a step:
  `atv.sh seq 'waitlog=[UpNext] search begin|<console log>|600|1.5' menu` blocks on the console line,
  settles 1.5 s and presses Menu over the same connection (exit 3 on timeout).
- The Companion port can change mid-session (49153 → 59539 at ~12:05); `atv.sh` re-resolves it, but
  anything that caches `ATV_COMPANION_PORT` must re-read Bonjour. `dns-sd -L` parsing in zsh: use
  `sed -E 's/.*:([0-9]+) \(interface.*/\1/'`, not a bash `=~`.
- In Off mode the mpv Info tab hides the Seek Previews row (and with it the RSS), so an Off-mode RSS
  control is not readable until RSS is logged.
- A `--console` stream can go quiet while the app lives (11:31–11:42); when the log stops moving under
  playback, relaunch through `console.sh start`.

- **The Menu eject is Companion-only.** Five quick Back taps on the real remote out of the mpv player
  never backgrounded the app (12:32–12:38); the three ejects today were all rig input. Keep the
  screenshot-after-exit rule, and treat P3-F8 as a rig caveat unless a remote ever shows it.

- (2026-10-16, Batch B round 2) `console.sh stop` waits for the stream process to exit: a devicectl
  stream killed mid-write prints "App terminated due to signal 15" at its OLD offset, which punched
  90 NULs into a log that the next `start` had already truncated and reused; `preflight.sh` greps
  with `-a` so such a log no longer reads as "binary" (its pid check used to fail on it).
- Installing a fixture add-on in Test 2 goes through Add-ons › Install from manifest URL with
  `text=` over Companion (Select on the field → `text=<url>` → Down ×3 → Select on done → Down →
  Select on Install); the DEBUG `-debug.addonManifestUrls` seed refuses a signed-in account. Removal:
  walk to the row, `hold=select,0.9` → Remove Add-on → Right → Select on the alert's Remove.
  Fixtures: `scripts/device/fixtures/ytid-addon.py` (one ytId stream), `landscape-addon.py` (a
  `posterShape: landscape` catalog with trailers).
- A devicectl screenshot can succeed in the first ~10 s of an HDR/DV title (the panel has not
  re-synced yet) and then fail for the rest of the play; shoot early.

## P3 fix-ups built with the rig's findings (branch `claude/p3-fixups` in the player clone)

- `[Mem] +Ns rss=… MB mode=… store=… harvest=… decode=…` once a minute for the whole mpv playback
  (DEBUG), so the Seek Preview mode comparison no longer needs the Info row; the row itself stays
  visible in Off mode in DEBUG ("off · RSS …").
- The engine router sends a DV profile 5 file in an MP4/MOV container to mpv (P3-F7) with the reason
  "DV P5 in MP4 (remux unsupported)"; P5 in Matroska and P8.1 in MP4 are unchanged; two self-check
  expectations added.

## Next

- Give `shot.sh` a JPEG mode and keep evidence folders under ~10 MB (today's 4K PNGs ran 20–34 MB
  each before conversion).
- A `walk.sh` with named routes (`home`, `settings:player`, `settings:developer`, `picker`) built from
  the row counts above, each ending in a screenshot assert.
- Re-test the 0 ms Menu eject with a physical remote's shortest tap; if it reproduces, it is an app bug.

## 2026-10-22 additions (Wave 3 / open-items session)

- **IPv4 flaps.** The box loses its IPv4 path several times a day while IPv6 stays up (no A record, `ping` dead, `ping6 fe80::…%en0` 10 ms; devicectl keeps working). `atvctl.py` (`seq` / `press` / `hold`) now falls back to the link-local IPv6 when the v4 connect fails, printing `[atvctl] IPv4 … unreachable; using IPv6 …`. `atv.sh`'s atvremote path (`features`, `launch`, `raw`) and `ready.sh`'s Companion check are still v4-only, so a flap reads as "pairing is broken"; a conf copy with the v6 address (`NUVIOTV_DEVICE_CONF=<dir>`) works for `seq`.
- **Wake prompt.** A box woken with the TV off shows tvOS's own "who's watching" picker under the screensaver; the Companion cannot clear it and the app launches behind it. Siri Remote only. The box runs as the Christian tvOS user.
- **Profile.** The app can auto-enter **Chris**; launch Debug builds with `-debug.rememberLastProfile NO`, screenshot the picker, Right → Test 2, and require `[ProfileSelect] selecting profile 3` before any press. Release builds ignore the override: read the line and the Home content.
- **Screenshot before presses.** Instruments' `--launch` does not guarantee the app is in front: a 40-press walk once ran in another app. `docs/research/wave3c-r0-2026-10-21/walks.sh` is launch → screenshot → (human read) → walk. After each Instruments session the devicectl tunnel is gone for up to a minute and `xctrace` "times out waiting for device to boot": 45 s gap, three attempts.
- **Instruments launch args** for Steven's device-local settings are listed in memory `rig-lessons-2026-10-21`; `-debug.playerRouterHosts YES` reveals full hosts in Release `[PlayerRouter]` lines (redacted otherwise, since Wave 3c).
- **Profile expiry (2026-10-22 12:12Z).** When the 7-day free-team profile lapses, `devicectl install` fails with error 3002 and a rebuild with `-allowProvisioningUpdates` only works while Xcode › Settings › Accounts still holds a live session for the youngchris29 Apple ID; otherwise xcodebuild prints "No Accounts: Add a new account in Accounts settings" and "No profiles for 'com.youngchris29.NuvioTV' were found". Christian signs in again, then the device Debug and Release builds renew the profile. The already-installed build keeps launching.
- **Instruments scratch (2026-10-22).** Every `xctrace record` leaves a 1–5 GB `$TMPDIR/instruments*.ktrace` behind; 47 of them (131 GB) filled the disk three times in one day, which is what killed the trace saves ("Cannot save trace document") and left the app behind the tvOS Home screen on launch. `walks.sh` sweeps them after each walk; after any other Instruments run: `rm -rf $TMPDIR/instruments*.ktrace`.

### 2026-10-22, later: `console.sh stop` kills the app
`console.sh stop` SIGTERMs the `devicectl … launch --console` stream, and the launched app goes with it (`App terminated due to signal 15` at the end of the log). The header comment that said the app keeps running was wrong and is corrected. Consequences: a pass that stops the stream mid-flow leaves the box on tvOS Home (the 10-22 tear-down's Remove dialog was lost this way), and any presses sent afterwards land in whatever tvOS shows — screenshot first. To keep the app alive after the stream, launch it again without `--console` (`atv.sh launch com.youngchris29.NuvioTV`), which keeps the profile and state the stopped instance persisted.

### 2026-10-22: the build and simulator locks live in the outer repo now
`scripts/build/with-lock.sh` (machine-wide build lock, `~/Claude/Projects/.build.lock`) and `scripts/build/with-sim-lock.sh` (the FA87 simulator lock, `~/Claude/Projects/.sim-FA87.lock`) replace the copies that lived under each clone's gitignored `iosApp/build/` and vanished with the Wave 3 clones. Usage from any clone: `"$OUTER/scripts/build/with-sim-lock.sh" "$OUTER/scripts/build/with-lock.sh" xcodebuild test …` for a simulator session, `with-lock.sh` alone for a build. The sim lock always wraps the build lock, never the reverse.


## 2026-11-09 additions: box lock, a sim per project, keep-awake, settings snapshot

From the Add-ons hub / Detail Polish / Stream Picker #25 retrospectives (two projects on one Mac, one sim and one box, 2026-11-08: pattern kills, a rebooted FA87, the box taken mid-pass, 12 h of waiting). Rules in CLAUDE.md "Long-running work".

- **Box lock** `scripts/device/lock.sh take|release|wait|check|who box <project>`: a lease file `~/Claude/Projects/.box.lock` naming the project, when it took the box and its ETA. `ready.sh --project <name> [--eta <text>]` takes it (exit 3 BUSY when another project holds it; never kill the holder), `done.sh <project>` releases it. `atv.sh` (except `features|app|apps`) and `console.sh start|stop` refuse with exit 75 while another project holds it; `NUVIO_LOCK_BYPASS=1` is for Christian's own hand use. A lease older than 6 h counts as abandoned and may be taken over (printed). `lock.sh who` also reads the two existing flocks (`.sim-FA87.lock`, `.build.lock`) and says whether their holder pid is alive.
- **A sim per project** `scripts/device/sim.sh clone <project>`: clones "NuvioTV <project>" from the shut-down template "NuvioTV template" (itself a clone of the fixture; `simctl` refuses to clone a booted device, and FA87 is booted most of the day). Prints the udid and the `-destination` string. `sim.sh list|udid|boot|delete <project>`; `sim.sh template [--from <udid>]` recreates the template when FA87 is shut down. FA87 stays the fixture for the final gate; UI legs and iterations run on the clone, wrapped in `with-sim-lock.sh` only when they touch FA87.
- **Keep-awake** `scripts/device/keep-awake.sh start [hours]|stop|status`: one `caffeinate -dims -t` per Mac with a pid file in `~/.config/nuviotv-device/`; `ready.sh` starts it for 4 h. System Settings › Battery › Options › "Prevent automatic sleeping on power adapter when the display is off" is a one-time hand setting on top.
- **Settings snapshot** `scripts/device/settings-snapshot.sh take <label>|diff [a [b]]|list`: copies the app's prefs plist out of its data container over devicectl (works on the Living Room box) into `~/.config/nuviotv-device/snapshots/` (mode 600; never the repo: it holds debrid keys and Trakt tokens). `ready.sh --walk` takes a `pre` snapshot; `done.sh` diffs the box against it and prints every key that changed with its profile index (`_3` = Test 2); values of keys that look like secrets or payloads print as "changed".
- **`ready.sh --walk` launches instead of refusing**: when the app is not running or the console stream is dead it runs `console.sh start` and waits up to 20 s for the pid, then preflight. `--no-launch` keeps the old refusal. If the profile picker shows after the launch, select Test 2 before the first step.
- **`done.sh <project> [--keep-app]`**: settings diff, Home press (the box rests on the tvOS home screen), lock release. The console stream stays up (stopping it kills the app).

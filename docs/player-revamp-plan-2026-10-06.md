# Player revamp: implementation plan, batches P1–P5 (2026-10-06)

**Status: APPROVED 2026-10-06. D1–D10 all taken as recommended ("ask me the questions and start P1"). P1 STARTED 2026-10-06: clone `~/Claude/Projects/NuvioMobile-player`, branch `claude/player-p1` off `tvos-shared-extraction` `5feef338`, push disabled, MPVKit symlinked, `local.properties` copied. See OUTCOME.** **Release model decided 2026-10-06: ONE rc after P5**, carrying the Search & Discover batch (merged, uncut, `tvos-shared-extraction` `5feef338`) plus P1–P5; see "Merge, cut, comms". Checkpoint rule: if P3 has not merged within ten days of P1 starting, cut an interim rc with Search & Discover + P1 + P2.

**Sources:**
- Research: `docs/research/player-revamp-research-2026-10-06.md` (field survey, Nuvio-port survey §3b, redesign spec §5, scrub + preview design §6, tiers §7). Item codes below (A1, B19, C13…) are that report's.
- Reference geometry: Orivio's `FusionMetrics` and scrub constants (research §3b.6), the Infuse measurements in `docs/research/orivio-tv-handoff.md` §7.10, and its §7.9 thumbnailer defect list.
- Official grammar: `NuvioMedia/NuvioTV` `PlayerScrubRates.kt`, `PlayerNextEpisodeRules.kt`, `SkipIntroVisibilityRules.kt` (research §3b.1).
- Code facts: read on 2026-10-06 from the submodule at `cbdd1aa2` (Evidence below).

Paths are relative to `NuvioMobile/iosApp/NuvioTV/` unless noted.

## Where to run this

A **local Claude Code session on the Mac**, in a **fresh local clone** of the submodule (`~/Claude/Projects/NuvioMobile-player`), never `git worktree` on the submodule. Every wave ends on a build, a simulator check or a device check; the mpv path in particular needs hardware because the simulator cannot swipe and `gpu-next` asserts there. In a clone MPVKit is a symlink over the gitlink: stage by explicit paths, never `git add -A`.

## Decisions (Christian, 2026-10-06: every row below taken as recommended)

| # | Question | Recommended → DECIDED | Why |
|---|---|---|---|
| D1 | **Swipe scrubs while playing, or only when already paused?** | While playing (system grammar, Orivio) | The system player and Infuse do it; the 160 pt tap-vs-swipe threshold from the Orivio handoff handles pad brushes. bobsupra's paused-only rule is the safe fallback if the device pass shows accidental scrubs. |
| D2 | **What does a held Left/Right do?** | Preview-then-commit with the 10/20/30/60 table (every Nuvio port), with the system's 2×/3×/4× scan as a Playback setting "Hold Left/Right: Step / Scan" | Keeps the grammar testers know from Nuvio, fixes the seek-per-step defect, and still offers the Apple feel. Default Step. |
| D3 | **Scrub rate** | Orivio's `max(duration / 4800, 0.25)` s/pt, 45 pt intent threshold | One line, duration-scaled, hardware-proven on an Apple TV Nuvio port. bobsupra's flick curve ships behind the same Developer knob for the A/B. |
| D4 | **Bar geometry** | Infuse numbers (bar centre 95 pt from the bottom, 86 pt insets, 44 pt title, 62 pt pills, 400 × 225 preview) | Measured off 1080p captures by two ports; our native engine is AVKit, so the mpv bar should sit where AVKit's does, not where our current 28 pt-padded card does. |
| D5 | **Edge click = 10 s, or chapter when chapters exist?** | 10 s; a Playback setting "Left/Right Click: Skip 10 s / Previous-Next Chapter" (Infuse) default Skip | Chapters are new to the app; nobody has asked. |
| D6 | **Thumbnail sources** | Harvest from the main decode + FFmpeg keyframe decoder for the unwatched region. **No community storyboard server, no second mpv handle.** | Zero extra connections to the debrid CDN; bobsupra's harvest proves the first half, Orivio's grabber the second. A community pool is a product and privacy question for another day. |
| D7 | **Native I-frame playlist** | Spike first (half a day), then build if AVKit accepts fMP4 byte-range I-frame entries from loopback | Cheapest preview path in the whole plan if it works; zero cost to learn it does not. |
| D8 | **Glass tint** | Drop the 35 % black tint on the bar, keep a 300 pt bottom scrim | Matches the native engine's bar on the same TV. |
| D9 | **Developer knobs** | Ship P1/P2 knobs (rate curve, thresholds, hold model) for one rc; strip to settings or constants at the next cut | The Steven loop tunes feel better than any simulator number. |
| D10 | **P5 scope** | Include B19 subtitle auto-sync, B20 amplification + centre-mix, B22 post-play recommendations, B23 per-show speed | Four official-app features no Apple TV port has shipped; P5 is where "most complete tvOS port" becomes true. Drop any one without touching the others. |

### Defaults I chose (override any when approving)

- **Hide rules:** 4 s after the last input while playing, never while paused, never while a pill has focus; 0.25 s fade. The pause card waits for the bar to hide (never stacked).
- **Times:** elapsed left, remaining right; a light tap flips the right label to the wall-clock end time ("ends 11:48 PM") and back (Infuse/Orivio grammar). No permanent clock by default; "Show Clock" is a Playback toggle, default off (Stremio/official ATV have it).
- **Scan (if D2 picks Scan or the setting is flipped):** `speed` 2/3/4 cycling on repeat presses, audio muted, `audio-pitch-correction=no`, back to 1× on release.
- **Two-stage commit:** `seek <t> absolute+keyframes`, then `absolute+exact` after 150 ms idle unless `demuxer-cache-state` already covers the target. Cache: `demuxer-max-back-bytes` 64 MiB (new "Streaming Buffer" sub-value, device-local), forward unchanged.
- **Thumbnail store:** 320 × 180 JPEG `CGImage`s, LRU 200 (≈ 6 MB), keyed by the stream identity digest the rejected-link memory already uses, dropped on exit. Harvest every 10 s of playback via `screenshot-raw` (video only). FFmpeg pre-warm every 10 s across the unwatched region at `.utility` priority, 1080p-class decode cap, one in flight, 50 ms debounce on scrub requests.
- **Chapters:** ticks on the bar, chapter title above the preview card, a Chapters tab in the top panel only when `chapter-list` is non-empty.
- **Aspect modes:** Fit / Fill / Zoom / Stretch, cycling pill with a 2 s flash (vatax3), wired to the synced `resizeMode` where the values map (Fit/Fill/Zoom), Stretch device-local.
- **New settings default off** unless stated; release notes say so for each (standing rule).
- **Strings:** English first in `Localizable.xcstrings`, the five locales (de/es/fr/it/vi) through `scripts/populate-localizable-xcstrings.py` + `merge-translations-into-xcstrings.py` at the end of each batch; every new Settings row gets a `SettingsDescriptionID` + a description (the revamp's catalog, `Screens/Settings/SettingsDescriptions.swift`).

## Sequencing (hard dependencies)

1. **The Search & Discover batch is merged and uncut** (submodule `tvos-shared-extraction` at `5feef338`, 31 commits past the rc3 build `65074a19`, device pass PASSED per CLAUDE.md on 10-06). It rides the same rc as this plan. P1 branches off `5feef338` or whatever the branch tip is when P1 starts.
2. **P1 → P2 → P3** are strictly ordered: P2's scrub needs P1's bar and preview playhead; P3's thumbnails need P2's store and scrub card. **P4** (native parity) is independent of P2/P3 and can interleave after P1. **P5** needs nothing from P1–P4 and can run in parallel in a second clone if a session is free; it touches `shared/` (B19) so it rebases last.
3. Each batch is its own submodule branch off `tvos-shared-extraction`, fast-forwarded in on Christian's go after its own review rounds and its own device pass **on a dev build** (installed over `devicectl`, Test profile). **No rc between batches.** One rc after P5, after the full regression pass below.
4. Review: Codex is over quota until 2026-10-29 (`CLAUDE.md`), so each batch runs read-only Opus review rounds to CLEAN with the usual record; if the quota resets mid-plan, the last round of the open batch runs through `.claude/skills/codex-review/tools/review.sh --repo NuvioMobile --base <branch point>`.

## Evidence (code facts, submodule `cbdd1aa2`)

**mpv player** (`Screens/MPVPlayerView.swift`, 2307 lines):
- `MPVPlaybackState` (`:29`) publishes `positionSec`, `durationSec`, `isPaused`, `isBuffering`, `controlsVisible`, tracks, `panelOpen`, `skipPrompt`, `playbackSpeed`, `subtitleDelaySec`, `audioDelaySec`, `showStreamInfo`, `streamInfo`, `isEnded`, plus closures (`selectAudio`, `setSpeed`, `setSubtitleDelay`, `setAudioDelay`, `replay`, `reclaimFocus`, `upNextPlayNow/Cancel/Dismiss`). No scrub, chapter, buffered or preview state exists.
- `MPVTVPlayerViewController` (`:94`) owns the `TVMetalLayer`, the mpv handle, `pressesBegan` (`:1321-1370`: Select/PlayPause toggle, Left/Right `beginSeek`, Down = up-next → skip chip → panel, Menu = dismiss chip → exit), `pressesEnded` (`:1372-1381`, `endSeek`), `beginSeek` (`:1383-1402`: immediate ±10 s, 0.4 s timer with steps 20/30/…/60, **each step a real `seekBy`**), `seekBy`/`seekAbsolute`/`issueSeek` (`:1428-1473`: every seek goes through the skip planner and `eventQueue`, tracked to `MPV_EVENT_PLAYBACK_RESTART` by generation), `flashControls` (`:1475-1484`, 4 s hide unless paused). The only touch recogniser is a `UISwipeGestureRecognizer(.down)` (`:267-275`).
- libmpv helpers (`:1817-1875`): `command(_:args:)` over `mpv_command`, `getDouble/Int/String/Flag`, `setFlag`. **No `mpv_command_node` wrapper**, which `screenshot-raw` needs (its result is an `MPV_FORMAT_NODE_MAP` with `w/h/stride/format/data`).
- Overlay (`:2113-2157`): `PlayerControlsOverlay` = title, glyph, elapsed, `ProgressBar` (capsule, 10 pt), remaining, "Swipe down for info"; `.glassEffect(.regular.tint(.black.opacity(0.35)))`, radius 24, padding 28 + `Theme.Spacing.screen`. Nothing focusable.
- Options (`:396-440`): `vo=gpu` (or `gpu-next` on device), `gpu-api=vulkan`, `gpu-context=moltenvk`, `hwdec=videotoolbox`; buffer keys `player.bufferMB` / `player.readaheadSec` (`Screens/PlaybackModels.swift:12-27`).
- Subtitle delay persists per title through `PlayerTrackPreferenceStorage.shared.loadSubtitleDelayMs(videoId:)` / `saveSubtitleDelayMs` (`:767`, `:1103`); audio delay does not (`Player/MPVPlaybackTab.swift:58`).
- Top panel: `Player/PlayerTopPanel.swift` tabs Info · Subtitles · Audio · Playback; `Player/MPVPlayerPanelAdapter.swift` and `Player/NativePlayerPanelAdapter.swift` are the per-engine adapters; `Player/PlayerTopPanelModel.swift` the model.
- Skip chip: `Player/SkipSegmentPlanner.swift`, `PlayerActionChip`, fired with Down (`:2016-2036`). Up-next: `Screens/NextEpisodeAutoPlay.swift` (`NextEpisodeEngine`, the chip caption in `Player/PlayerChipStyle.swift:74-82`).
- Pause card `PauseInfoCard` (`:2230`), post-play `PostPlayView` (`:2175`), stream info `StreamInfoOverlayView` (`:2281`).
- Start watchdog `Player/MPVStartWatchdog.swift`; wakeup relay `MPVWakeupRelay` (BUG-141: unset before `mpv_terminate_destroy`).

**Native player**: `Screens/NativePlayerScreen.swift` (387), `Screens/NativePlaybackCoordinator.swift` (1303). `NativePlayerHostController` (`Player/PlayerPanelHost.swift:20-53`) builds a bare `AVPlayerViewController` (no `speeds`, `customInfoViewControllers`, `transportBarCustomMenuItems`, `externalMetadata`), adds a Down tap + down swipe for the app panel. The panel adapter offers Info · Subtitles · Audio only (`NativePlayerScreen.swift:331`). The loopback master is written by `SegmentMap.masterPlaylist(signaling:…)` (`Screens/SegmentMap.swift:157`) and the media playlist by `mediaPlaylist(initName:segmentPrefix:)` (`:119`, fMP4 with `EXT-X-MAP`); `LocalHLSServer.swift` serves them and duplicates subtitle `EXT-X-MEDIA` lines into slots (`:196-205`). The segment map is derived from the source keyframe index (`SegmentMap.swift:10-17`; MKV Cues can be a sparse subset of real keyframes, `RemuxSession.swift:16-21`). Subtitles are WebVTT renditions (`SubtitleVTT.swift`, `EmbeddedSubtitleSink.swift`); no `AVTextStyleRule` anywhere. Mid-play fallback to mpv at the same position exists (`Coordinator:1280-1302`).

**FFmpeg in the app:** `Screens/MediaProbe.swift` (`avformat_open_input` with headers, `:102-103`), `Screens/RemuxSession.swift` (`av_seek_frame(…, AVSEEK_FLAG_BACKWARD)` at `:416`, `:773`), `Screens/AudioTranscoder.swift` (`avcodec_send_packet`), `Screens/DoviRpuConverter.swift`. MPVKit (`../MPVKit/Package.swift:34`) links `Libavcodec`, `Libavformat`, `Libavutil`, `Libswscale`, `Libswresample`, `Libavfilter`; Swift files import `Libavcodec`/`Libavformat`/`Libavutil` today, `Libswscale` not yet.

**Settings:** `Screens/Settings/PlayerSettingsPane.swift` (sections Playback / Video / Buffering / Next Episode, `SettingsToggleRow`/`SettingsPickerRow` with `descriptionID:`), `Screens/SettingsViewModel.swift` (`@Published private(set) var preloadNextEpisodeSources` + `setPreloadNextEpisodeSources`, mirrored from `PlayerSettingsUiState`), `Screens/Settings/SettingsDescriptions.swift` (`case playerPreloadNextEpisode = "player.preloadNextEpisode"`). Shared: `shared/.../features/player/PlayerSettingsRepository.kt` (`resizeMode`, `holdToSpeed*`, `showLoadingOverlay`, `showParentalGuide`, secondary languages, all unread on tvOS).

**Tests:** `iosApp/NuvioTVTests/` (102 files; player ones: `MPVStartWatchdogTests`, `MPVWakeupRelayTests`, `NativePreparingLabelTests`, `NextEpisodeEngineTests`, `PlayerAudioLanguagePlanTests`, `SkipSegmentPlannerTests`, `SubtitleVTTShiftTests`, `TrailerLocalHLSListenerTests`), `iosApp/NuvioTVUITests/` (FA87 harness; the mpv smoke rig presents the player from `debug.mpvSmokeURL` + `debug.mpvSmokeDelaySec`, `Screens/MPVSmokeTest.swift:5-17`).

**Cut and review tooling:** outer `scripts/cut-rc.sh` (preflight-gated, `--from` resume, litterbox → filebin + gofile); `.claude/skills/codex-review/tools/review.sh` (Codex quota reset 10-29; Opus read-only rounds until then).

---

## Batch P1: the AVPlayer-grammar bar

**Scope:** A4 bar redesign, A11 preview-then-commit held seek, A5 hold-to-scan (behind the D2 setting), A10 buffered bar, B9 end-time flip + optional clock, B3 skip chip auto-hide, B5 audio-delay persistence, B21 engine button on the failure alert. No new decoders, no gestures beyond presses.

### Target design

- **`PlayerTransportBar`** (new file `Player/PlayerTransportBar.swift`, replaces `PlayerControlsOverlay` + `ProgressBar`): title lockup (44 pt semibold + 28 pt meta line: `S1 E4 · Episode name · provider`), pill row right of the title (Subtitles, Audio, Speed, Sources, Episodes when a series, More), the track (86 pt insets, centre 95 pt from the bottom, 10 pt rest / 14 pt active), played fill white, buffered fill white 35 %, skip-segment spans as a lighter 4 pt band, times 28 pt monospaced under the bar ends, a 300 pt bottom scrim 0.55 → 0 instead of the black tint. Everything `.ignoresSafeArea()`.
- **Preview playhead model** (`Player/TransportPreview.swift`, pure Swift, unit-tested): `enum Mode { idle, stepping(dir, accumulated), scanning(rate), scrubbing(target) }`, `previewSec`, `commitPolicy` (keyframes → exact after 150 ms), the 10/20/30/60 step table keyed to hold ticks, the scan rate cycle. P2 reuses it for swipes.
- **Held arrow:** `beginSeek` keeps its timer but writes to the preview model; the bar follows `previewSec`; `pressesEnded` commits once through `issueSeek` with `absolute+keyframes` then the exact stage. Short press stays an immediate ±10 s (or ±chapter per D5 once P2 lands).
- **Scan mode** (setting): `speed` 2 → 3 → 4, muted, preview playhead follows `time-pos`; release restores 1×.
- **Buffered fill:** poll `demuxer-cache-state.seekable-ranges` on the existing props tick; merge gaps < 5 s of film.
- **Times:** light tap (pad touch without click, `UITapGestureRecognizer` with empty `allowedPressTypes`) flips remaining ↔ end-time for 4 s; "Show Clock" toggle draws `HH:MM` top-trailing with the stream-info card's placement rules.
- **Focus:** the pill row is focusable (`.focusSection()`); Up from the track lands on the pills; Down from the pills returns; the mpv controller reclaims first responder when the bar hides (`state.reclaimFocus`, `:1904` pattern). Focus reset is driven from a `controlsSession` counter bumped on hidden → shown, never from `onAppear` (Orivio's 199 ms → 7 ms lesson).
- **Hide rules** as in Defaults. **Skip chip** auto-hides 10 s after it appears, returns on any press (official ATV `SkipIntroVisibilityRules`).
- **Audio delay** persists per title next to the subtitle delay (`PlayerTrackPreferenceStorage` gains `loadAudioDelayMs/saveAudioDelayMs`).
- **Failure alert:** the manual-pick alert (`StreamPickerView.swift:1050-1095`, `PlaybackFailure`) gains "Try with mpv" / "Try native" when the other engine can take the stream, same position.

### Files

`Screens/MPVPlayerView.swift` (press handling, seek commit, state additions, overlay swap), new `Player/PlayerTransportBar.swift`, `Player/TransportPreview.swift`, `Player/PlayerPills.swift`; `Player/PlayerTopPanel.swift` (pills open the matching tab); `Player/MPVPlaybackTab.swift` (audio delay persistence); `Screens/PlaybackModels.swift` (`player.holdMode`, `player.showClock` device-local keys), `Screens/Settings/PlayerSettingsPane.swift` + `SettingsDescriptions.swift` (two rows); `Screens/StreamPickerView.swift` (engine buttons); `Localizable.xcstrings`.

### Waves

- **W0 (main session):** branch, read the Evidence files, write the two specs (bar geometry + remote grammar; preview model + commit policy) as `docs/research/player-p1-spec-{bar,preview}.md`, one Opus critique.
- **W1 (two agents, parallel, file-owned):** agent A builds `TransportPreview` + the seek rewiring in `MPVPlayerView.swift` + tests; agent B builds `PlayerTransportBar` + pills + hide rules + clock/end-time.
- **W2 (one agent):** settings rows + strings, skip chip auto-hide, audio-delay persistence, failure-alert engine buttons.
- **W3 (main session + one agent):** UI legs on FA87 (`debug.mpvSmokeURL` rig): bar geometry probe (`debug_transportProbe` AX label with the bar frame + mode), hold-step leg (commit count = 1 per hold), scan leg (speed property), chip auto-hide leg; Release build.

### Gates

NuvioTVTests green (+ `TransportPreviewTests`: step table, commit policy, scan cycle, 20 cases), jvm / K/N unchanged, Debug + Release sim, UI legs above, Opus review rounds to CLEAN.

### Device pass (Living Room ATV, Test profile)

1. Bar sits where the native engine's bar sits on the same title (photo both). 2. Hold Right: one glide on release, no stutter during the hold; the bar's preview counts 10/20/30/60. 3. Scan setting: 2×/3×/4× cycling, silent, 1× on release. 4. Buffered fill grows ahead of the playhead on a slow debrid link. 5. Light tap flips to "ends HH:MM". 6. Pause: bar stays; a pill takes focus; Menu hides the bar, second Menu exits. 7. Skip chip hides after 10 s, returns on a press. 8. Audio delay survives a relaunch of the same title. 9. Failure alert offers the other engine and resumes at the same position. 10. Show Hero OFF / Steven's config smoke: nothing in Home changed.

---

## Batch P2: swipe scrub, aspect modes, chapters, harvest store

**Scope:** A1 swipe scrub with the preview card (time + chapter title, no frames yet), A7 aspect modes, A6 chapters on mpv, A12 harvest-from-decode thumbnail store (frames appear in the card for anything already played).

### Target design

- **Input:** `UIPanGestureRecognizer(allowedTouchTypes: [.indirect])` on the player view, `delegate` arbitration with the existing down-swipe and the P1 light-tap: horizontal intent at 45 pt (Orivio), vertical intent at 110 pt opens the panel, undecided diagonals consumed by nobody. `UILongPressGestureRecognizer(allowedPressTypes: [.leftArrow, .rightArrow], minimumPressDuration: 0.4)` replaces the timer-based hold detection so a short press and a hold are distinct recognisers.
- **Scrub:** rate per D3 behind `-debug.scrubCurve orivio|bobsupra` and `-debug.scrubRate <s/pt>`; preview playhead from P1; Select commits (two-stage), Menu cancels, Play commits and plays, Left/Right nudge ±10 s on the preview, Up cancels. Title lockup and end labels fade during a scrub; the target time sits under the playhead; the preview card (400 × 225, 30 pt above the playhead, clamped to the track) shows a frame from the store when one exists within ±GOP, else the time only.
- **Store:** `Player/SeekPreviewStore.swift` actor: `thumbnail(near:)`, `insert(_:at:)`, LRU 200, JPEG-backed `CGImage`, keyed by stream digest; harvested every 10 s of playback via a new `commandNode("screenshot-raw", ["video"])` wrapper (BGRA → `CGImage` → 320 px JPEG off-main). Also fills on every landed seek.
- **Chapters:** read `chapter-list` on file load into `state.chapters: [(title, sec)]`; ticks on the track; chapter title above the card; a Chapters tab in the top panel (rows seek on select); D5's setting maps edge clicks to chapters when present.
- **Aspect:** Fit / Fill / Zoom / Stretch via `video-aspect-override`, `panscan` (Fill = `panscan=1.0`, Zoom = `video-zoom` 0.15, Stretch = `keepaspect=no`); an Aspect pill cycles with a 2 s flash; initial value from the synced `resizeMode`.
- **Native engine:** nothing in P2 except reading `chapter-list` equivalents is deferred to P4 (`AVNavigationMarkersGroup`).

### Files

`Screens/MPVPlayerView.swift` (recognisers, `commandNode`, chapter + aspect properties, harvest tick), `Player/TransportPreview.swift` (scrub mode), `Player/PlayerTransportBar.swift` (card, ticks), new `Player/SeekPreviewStore.swift`, `Player/ScrubGestureArbiter.swift` (pure, unit-tested), `Player/PlayerChaptersTab.swift`; `Player/PlayerTopPanel.swift`; settings rows (edge-click mode, aspect default) + strings.

### Waves

- **W0 (main):** spec `docs/research/player-p2-spec-scrub.md` (gesture arbitration table, rate curves, card geometry, store contract), Opus critique.
- **W1 (three agents):** A gestures + arbiter + scrub mode; B store + `commandNode` + harvest + card frame plumbing; C chapters + aspect + settings.
- **W2 (main + one agent):** UI legs: the simulator cannot swipe, so the legs drive `TransportPreview` through a `-debug.scrubInject <pts>` launch arg that feeds synthetic pan samples; store leg asserts a harvested frame exists after 25 s of the smoke clip; chapters leg on an MKV with chapters (add one to the UI-test fixture server); aspect leg reads `video-aspect-override`.
- **W3:** Release build, review rounds.

### Device pass (Test profile)

1. Swipe while playing: card follows, time under the playhead, title fades; Select lands within one GOP, Menu cancels. 2. Swipe while paused: same. 3. Brush the pad: no scrub (tap threshold). 4. A/B `-debug.scrubCurve` Orivio vs bobsupra with Steven's wrist; pick one. 5. Scrub back into watched footage: frames appear in the card. 6. Chapters MKV: ticks, Chapters tab, edge click = chapter when the setting says so. 7. Aspect pill cycles; the synced phone value is the start value. 8. Memory: Stream Info shows RSS before/after a 20-minute play (new row), store ≤ 10 MB.

---

## Batch P3: seek preview frames (spike first)

**Scope:** A3 I-frame playlist on native (spike first), A2 FFmpeg keyframe thumbnailer for the unwatched region on mpv, behind a Developer toggle for one rc.

### Spike (half a day, main session)

Write an `EXT-X-I-FRAMES-ONLY` media playlist from `SegmentMap` (one `EXT-X-BYTERANGE` per segment-start keyframe pointing at the moof+mdat bytes around that sample) and an `EXT-X-I-FRAME-STREAM-INF` line in `masterPlaylist`, serve from `LocalHLSServer`, play a known MKV through the native engine on the device, scrub: does AVKit show frames? Does it tolerate the playlist growing with the remux frontier? Record the answer in OUTCOME. If yes, build it; if no, the native engine shares the mpv store through a custom scrub overlay later (not in this plan).

### Target design (mpv)

- `Player/KeyframeThumbnailer.swift` (Swift over `Libavformat`/`Libavcodec`/`Libswscale`): `open(url, headers)`, `frame(at:)` = `av_seek_frame(AVSEEK_FLAG_BACKWARD)` → decode one I-frame (`AV_CODEC_FLAG2_FAST`, `skip_loop_filter = ALL`, **never `skip_frame = NONKEY` on MKV**) → `sws_scale` to 320 px → JPEG → store; stamps the keyframe PTS and accepts ±GOP in the lookup; a cancelled pass keeps what it decoded; passes merge, never assign (Orivio §7.9). HDR sources tone-map with `zscale`+`tonemap` through `Libavfilter`, or decode to SDR via VideoToolbox when the hardware context is available.
- **Scheduler:** one in flight; scrub requests debounce 50 ms and pre-empt the pre-warm; pre-warm walks the unwatched timeline every 10 s at `.utility`, pauses while `isBuffering`, stops at a 1500-frame cap; uses the same `proxyHeaders` and the credential-free URL path the addon subtitle download uses (`MPVPlayerView.swift:549-557`).
- **Native (if the spike passed):** `SegmentMap.iFramePlaylist()`, master line, server route, and the remuxer records every keyframe it writes (not just Cues) so previews are finer than one per segment.
- **Developer toggle** "Seek Preview Frames: Off / Harvest only / Harvest + decode" (default Harvest only in this rc); Stream Info gains a "preview: N frames · M MB · last decode X ms" row.

### Gates and device pass

Unit tests on the scheduler (pure) and the store merge rules; a sim leg over the fixture MKV asserting ≥ 10 frames pre-warmed in 60 s; Release build. Device: 1. Scrub into unwatched 4K HEVC footage: frames within 300 ms; the card never blocks the playhead. 2. Debrid link: the stream itself never stalls while the pre-warm runs (watch `cache` seconds in Stream Info). 3. RSS delta ≤ 60 MB after 20 minutes. 4. DV P7 file: thumbs come from the base layer, no crash. 5. Native spike result reproduced on hardware. 6. Exit mid-decode: no crash (BUG-141 class), the decoder's interrupt callback fires.

---

## Batch P4: native-engine parity

**Scope:** A8 Playback tab on native (`customInfoViewControllers` for Episodes + Sources, `speeds` for the system pill, `transportBarCustomMenuItems` shortcuts), A9 subtitles follow the app style via `AVTextStyleRule`, B16 pause card on native, B17 late addon subtitles, A6-native chapters via `AVNavigationMarkersGroup` when the remuxer reads MKV Chapters, B24 loading overlay with artwork + status line (both engines, `showLoadingOverlay` setting wired).

### Target design

- `NativePlayerHostController` sets `playerVC.speeds` (0.5–2 matching mpv), `customInfoViewControllers = [EpisodesTabVC, SourcesTabVC]` hosting the same SwiftUI rows the mpv Playback tab uses, `transportBarCustomMenuItems` = [Sources, Episodes] `UIAction`s, `externalMetadata` (title, S/E, artwork, description) so the Info tab and Now Playing read right.
- `AVTextStyleRule` built from `SubtitleStyleState` (colour, size as a fraction of the display, outline, background, bold) on every `AVPlayerItem`.
- Pause card: the same `PauseInfoCard` hosted over the AVPVC view when paused for 1.5 s and the transport bar is hidden (`willTransitionToVisibilityOfTransportBar` delegate).
- Late subtitles: hold the master until the addon search settles or 3 s, whichever first; after that, a new rendition re-serves the master and the coordinator reselects (`Coordinator:156-186` pattern).
- Chapters: `RemuxSession` reads MKV `Chapters` (libavformat `AVChapter`), `NativePlaybackCoordinator` builds `AVNavigationMarkersGroup`; mpv already has them from P2.
- Loading overlay (`Player/PlayerLoadingOverlay.swift`): poster + logo + "Resolving link · Connecting · Buffering 38 %" from the existing probe/remux states; replaces the bare spinner on both engines.

### Files

`Player/PlayerPanelHost.swift`, `Screens/NativePlayerScreen.swift`, `Screens/NativePlaybackCoordinator.swift`, `Screens/RemuxSession.swift` (chapters), `Screens/SubtitleVTT.swift` (style rule helper), new `Player/PlayerLoadingOverlay.swift`, `Player/NativePlayerPanelAdapter.swift`; strings.

### Waves

W0 spec + critique; W1 two agents (A: AVPVC configuration + tabs + metadata + pause card; B: text style rule + late subtitles + chapters in the remuxer); W2 one agent for the loading overlay on both engines; W3 UI legs (native rig: the existing `NativePreparingLabelTests` path) + Release + reviews.

### Device pass (Test profile)

1. A DV title on native: speed pill lists 0.5–2; Episodes and Sources tabs appear in the swipe-down panel; the Info tab shows poster and synopsis. 2. Subtitle colour/size set in Settings shows on native. 3. Pause 1.5 s: the card appears, hides on any press. 4. Addon subtitles that arrive late are selectable in the same session. 5. MKV with chapters: Chapters tab on native. 6. Loading overlay shows the poster and status line on both engines; no flash of the old spinner.

---

## Batch P5: ahead of the other ports (can run in parallel)

**Scope (D10):** B19 automatic subtitle sync + Sync Line, B20 amplification + centre-mix, B22 post-play recommendations, B23 per-show playback speed.

### Target design

- **B19** lives in `shared/` as `SubtitleAutoSync.kt` (port the official `autosync/AutomaticSubtitleSync.kt` algorithm: fixed-offset check, then an affine retime of the whole cue list against the embedded track or the audio-derived anchors the official app uses; the official code is the spec, read it in full before porting). tvOS: a "Sync Automatically" row in the Subtitles tab (runs once, reports the offset, applies through the existing delay path) and "Sync Line" (pick a cue from a list, press when you hear it; computes the delay). Works on both engines because both already re-time through the delay.
- **B20** on mpv: `volume-max=200`, a Boost row 0–10 dB in the Audio tab (`volume` 100–316 %), a "Dialogue" row applying `af=lavfi=[pan=stereo|c0=0.7*c0+0.5*c2|c1=0.7*c1+0.5*c2]`-style centre gain on multichannel sources, or `dynaudnorm` as "Night mode". Persist per device, not per title.
- **B22** `PostPlayView` gains a More Like This row (the Detail page's existing provider: TMDB / Simkl / MDBList) with focusable posters that open Detail; the native engine gets the same view when the item ends without an up-next (today it has none).
- **B23** per-show speed through `PlayerTrackPreferenceStorage` keyed on `parentMetaId`, applied on load, a "Remember speed for this show" toggle in the Playback tab.

### Waves

W0 spec (B19 needs its own algorithm note), one Opus critique; W1 two agents (A: shared `SubtitleAutoSync` + jvm/K/N tests ported from upstream's; B: audio rows + per-show speed); W2 one agent (post-play row both engines); W3 gates (jvm, K/N, NuvioTVTests), UI legs for the post-play row and the speed memory, Release, reviews.

### Device pass (Test profile)

1. An addon subtitle that is 2 s off: Sync Automatically lands it; Sync Line lands it. 2. Boost 6 dB audibly louder, no clipping on a loud trailer; Dialogue mode raises speech on a 5.1 film. 3. End a movie: More Like This row, posters open Detail. 4. Set 1.25× on a show, play the next episode: 1.25×.

---

## Merge, cut, comms (single cut, decided 2026-10-06)

**Per batch (on Christian's go):** fast-forward the branch into `tvos-shared-extraction`, delete it locally and on `origin`, bump the outer pointer with a one-line record commit, append the batch's record to OUTCOME. No cut, no DM. Device passes run on a dev build (`com.youngchris29.NuvioTV`, Test profile) so a regression is attributable to one batch.

**After P5 (one rc):**
1. **Full regression pass** on the Living Room ATV, Test profile, from the merged tip, before the build bump. Checklist:
   - Home: Stage and Classic, Up/Down paging, a folder, Continue Watching resume, the rail (Always Visible / Hide While Browsing), OLED True Black on.
   - Search & Discover: typed search with results holding during a new query, a result opened (saved to Recent), Discover placement both ways, grouped rows, the all-catalogs-failed Retry, People row, Discover genre memory.
   - Library: List pill, chips, Sort pill, smart filters, hold menu Mark as Watched.
   - Detail: Cinematic and Classic, Play, Start Over, trailer bridge in and out, episodes with season posters.
   - Player, mpv: the ten P1 steps, the eight P2 steps, the six P3 steps; Up Next through to the next episode; a failover to the next source; Menu dismisses the chip then exits.
   - Player, native: the six P4 steps; a DV P8 title with Match Content on; fallback to mpv at the same position on a forced failure.
   - P5: the four steps.
   - Settings: every new row shows its description; defaults match the notes; a cold launch with Wi-Fi off reaches Home's Retry.
   - Infuse hand-off with the x-callback return recording progress.
2. `scripts/cut-rc.sh` as the next beta.19 rc (build 136 unless another cut lands first), tag pushed, IPA on litterbox with filebin + gofile backups, size verified, outer pointer bumped.
3. Release notes with `--prev-tag tvos-v0.3.0-beta.19-rc3`: a section per batch (Search & Discover, P1–P5), every new setting with its default (off unless stated), the Search & Discover notes already drafted in that batch's record. Strip the generated commit list.
4. **Steven's DM** through the SlopMonster loop (5/5 shown with the score), one message in bubbles per area, with the asks that need his config: the bar photo next to the native engine's bar, the scrub-curve A/B verdict and which curve he kept, a 4K scrub video, a DV title's swipe-down panel, a subtitle he knows is off for the auto-sync, and the Search & Discover walk. Tell him the rc3 link expired and this build replaces it.
5. Tracker rows: one FEAT per batch plus BUG rows for anything the passes find; the Search & Discover rows already exist.

**Checkpoint rule:** if P3 has not merged within ten days of P1 starting, cut an interim rc with Search & Discover + P1 + P2 (same steps, shorter checklist: Home, Search & Discover, Library smoke, P1 + P2 player steps), DM Steven, and the final rc after P5 carries the rest.

## Agent roster (estimate)

| Batch | Explore/spec | Build agents | Review rounds | Device |
|---|---|---|---|---|
| P1 | 1 critique | 3 (2 + 1) | 2–3 Opus | 1 pass, 10 steps |
| P2 | 1 critique | 4 (3 + 1) | 2–3 Opus | 1 pass + the curve A/B |
| P3 | spike in main | 2 | 2 Opus | 1 pass, 6 steps |
| P4 | 1 critique | 3 | 2 Opus | 1 pass, 6 steps |
| P5 | 1 critique | 3 | 2 Opus | 1 pass, 4 steps |

About 15 build agents and 11 review rounds across five rcs; never more than three agents at once (cost guardrail), builds serialised in the main session.

## Risks worth knowing before the go

- **The simulator cannot swipe.** Every P2 gesture claim is hardware-only; the UI legs inject synthetic pan samples into the preview model and prove the plumbing, not the feel.
- **Focus vs. first responder.** Focusable pills on the bar mean the mpv controller loses first responder while the bar is up; the `reclaimFocus` hand-back on hide is on the P1 critical path, and a wrong order reproduces the "Up does nothing" class.
- **Two seek stages and the skip planner.** `issueSeek` tracks one generation; the keyframes → exact pair is two seeks, and the planner must treat the pair as one user seek or auto-skip rules misfire. `TransportPreview` owns that (P1 tests).
- **Debrid connection limits.** The FFmpeg thumbnailer is a second connection to the CDN. P3 ships Harvest-only by default and the decode half behind the Developer toggle until the device pass shows no stream stalls.
- **Apple TV memory.** 320 px JPEG store, LRU 200, one decoder, 1080p-class cap, torn down on exit; Stream Info reports RSS so the pass can read it.
- **`screenshot-raw` on `vo=gpu` through MoltenVK** is a GPU readback per harvest; if it costs a frame drop on 4K, harvest from the next keyframe instead (decoder-side `screenshot-raw video` is the same path; measure in P2's device pass).
- **MKV Cues are sparse.** Native I-frame previews come one per segment unless the remuxer logs every keyframe it writes (P3 does).
- **Codex is out until 10-29.** Opus rounds are the review record for P1–P3; note it in each batch record.
- **One cut after five batches means ~3 weeks without a tester build.** Steven's rc3 link expires ~10-08 and his rc3 verdict is still owed; Search & Discover is unseen until the cut. The ten-day checkpoint rule above is the release valve. His verdict will land on a six-batch pile, so the DM is split by area and the device-pass records per batch are what make a "the player feels wrong" note bisectable.

## OUTCOME

### Status (2026-10-06)

- Decisions D1–D10 taken as recommended. Release model: one rc after P5 with Search & Discover; ten-day checkpoint rule.
- **P1 started.** Clone `~/Claude/Projects/NuvioMobile-player` (`git clone --no-local` of the submodule, `origin` push URL set to `DISABLED`), branch `claude/player-p1` off `5feef338`; MPVKit symlinked from the main checkout; `local.properties` copied (17 lines). ⚠️ Stage by explicit paths in the clone; never `git add -A`.
### P1 Wave 0 (2026-10-06)

- Baseline Debug simulator build in the clone: BUILD SUCCEEDED (`iosApp/build/logs/p1-baseline-debug.log`, 327 warnings, all pre-existing); the generated `SupabaseConfig.kt` carries `https://api.nuvio.tv`, so `local.properties` took.
- Two Opus specs written read-only from the clone at `5feef338`: `docs/research/player-p1-spec-bar.md` (4.4k words) and `docs/research/player-p1-spec-preview.md` (7.2k words), then one Opus critique that edited both in place and recorded itself in `docs/research/player-p1-critique-2026-10-06.md`. Decisions the critique made, for Christian's eye at Gate 1:
  1. **Hold ramp is time-based**, not tick-based: 10 s steps while the hold is under 0.6 s, 20 s under 1.2 s, 30 s under 2.0 s, then 60 s; first tick at 0.4 s, then every 0.25 s. Knobs `-debug.holdTickSec`, `-debug.holdRampScale`. (The official app keys its table to Android key repeats at ~20/s, which would mean 60 s steps within a second; at four ticks a second that moves the preview 240 s per second, so the ramp was slowed.)
  2. **Scan is Apple's latched model**: scanning continues after release, Right cycles 2→3→4→2, Select/Play ends it in place, Menu returns to where the scan started, Left/Up/Down end it in place. A held Left never scans (mpv has no reverse play); it steps.
  3. **Paused bar:** never hides while paused unless the Pause Info Card setting is on, in which case it hides after 5 s idle and the card fades in; any press except Menu removes the card and returns the bar. Focus on a pill blocks the hide.
  4. **Pills are player-driven focus** (the mpv controller routes presses and publishes `focusedPill`; the pills draw non-focusable). System focus is the documented alternative, only if device-pass item 6 asks for swipe movement between pills. **Consequence: clicks, not swipes, move between pills in P1.**
  5. **Agents run sequentially**, A (preview/commit/scan/buffered + model) → B (bar + pills + press regions) → C (chip auto-hide, audio-delay persistence incl. `shared/`, failure-alert engine buttons, settings rows, strings, Release build). The `MPVPlayerView.swift` region split is in the bar spec §1.
  6. **Menu precedence:** panel → step/scan cancel → up-next chip → pill → bar → exit. Menu never dismisses the skip chip.
  7. **Buffered ranges** read `demuxer-cache-state` as a string assumed JSON; a one-shot DEBUG log on the first build proves it; fallback one span `[time-pos, demuxer-cache-time]`.
  8. Chips move to bottom 240 / trailing 86 while the bar shows.
- Spec facts worth keeping: the main thread never reads an mpv property (`MPVPlayerView.swift:158-176`), so cache-state and the pre-scan mute read run on `eventQueue`; native failures never reach the alert today because `PlayerScreen` always passes `onFallback`, so "Try with mpv" only appears after a forced-native retry fails; audio-delay persistence is a `shared/` change (`PlayerTrackPreferenceStorage` is an `expect object`, plus the `audio_delay_ms|` prefix in `AccountDataStores.kt:480`); the Streaming Buffer setting already sets `demuxer-max-back-bytes = max(bufferMB/2, 16)` (`:469`), the spec raises the floor to 64 MiB.
- Smoke fixture for the UI legs: `iosApp/build/smoke/test-long.mkv` (600 s HEVC, 2 s keyframes, generated with `~/bin/ffmpeg`) served by `iosApp/build/smoke/range_server.py` on 127.0.0.1:8000 (disposable; the `build/` dir is gitignored).

### P1 Wave 1 (2026-10-06, in progress)

- Agent A (Sonnet) started on spec-preview §1–§5: `TransportPreview.swift`, `TransportBarModel.swift`, `SeekProbe.swift`, planner `refineSeek`/`recordUserSpan`, controller wiring, cache option, tests, UI legs 1–3.

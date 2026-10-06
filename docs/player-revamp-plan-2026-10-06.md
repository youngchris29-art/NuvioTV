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

- **Agent A (Sonnet) DONE:** commits `c515029d0` (TransportPreview + 2 test classes), `3fe12e1db` (TransportBarModel, SeekProbe, PlayerTuning keys), `ac5589080` (planner `refineSeek`/`recordUserSpan` + tests), `ad0b21b54` (controller wiring), `eb8cd18ee` (UI legs). Debug green. Unit: TransportPreviewTests 25/25, BufferedRangesMergeTests 6/6, SkipSegmentPlannerTests 38/38 (69/0). UI legs on FA87 with the 600 s fixture and `-player.bufferMB 8`: leg 1 hold-step commits once PASS; leg 2 exact stage cancelled by a new press PASS (`stages=k commits=2`); leg 3 scan latches and cycles 2→3→4, Select ends it (`speed=1.0 mode=idle paused=0`) PASS. **`demuxer-cache-state` reads as JSON** (`ranges=1 fallback=0`), so no node walker is needed in P1; the fallback span stays.
  - ⚠️ **Simulator wall (device check owed):** `testScanMenuCancelsBackToOrigin` is wrapped in `XCTExpectFailure(strict: false)`: the controller cancels the scan and goes idle on Menu, but the simulator then dismisses the player anyway (`pressesCancelled` for Menu, `viewDidDisappear` ~0.6 s later). A menu `UITapGestureRecognizer`, `require(toFail:)` on the system's menu tap and `accessibilityPerformEscape` were tried and reverted. Same consume-the-press pattern as the up-next dismiss, which passes on the Apple TV. Expect agent B's Menu-hides-bar leg to hit the same wall.
  - Deviations recorded by A (all faithful to the prose): probe `stages` reads `k` → `ke` when the exact stage fires, `e` for exact-only; a replaced key's release is ignored without stopping the hold timer; `holdTick` calls `flashControls()` until B's hide rule lands; `startScan` requires `!moved`; forward click in Scan mode sets/clears `previewSec`; `setSpeed` ignored while scanning; Menu in a hold/scan stops the hold timer first; `handleSwipeDown` cancels the exact stage, timer and mode; knobs read in `init` (`debug.holdTickSec`, `debug.commitExactDelayMs`) and `viewDidLoad` (`debug.holdRampScale`); `SeekProbe`/`SeekProbeLabel` under `#if DEBUG`.
- **Agent B (Sonnet) DONE:** commits `659d08f44` (bar view, pill row, layout tests), `3532c5804` (controller wiring), `6870f639c` (UI legs). Created `Player/PlayerTransportBar.swift` (`TransportBarLayout`, `TransportTimeFormat`, `TransportSpanMath`, `TransportHideRule`, `PlayerTransportMetrics`, the view, `debug_transportProbe`, `PlayerTransportClock`, the DEBUG Darwin light-tap bridge), `Player/PlayerPills.swift`, `NuvioTVTests/PlayerTransportBarLayoutTests.swift` (17/17); edited `FlatControlStyles.swift` (`PlayerPillDisc`), `PlayerChipStyle.swift` (`barUpBottomInset` 240, `barUpTrailingInset` 86), `PlayerTopPanel.swift` (`initialTab`), `Localizable.xcstrings` ("Speed", "More", "ends %@"), `MPVPlayerView.swift` (B regions; deleted `PlayerControlsOverlay`, `ProgressBar`, the old pause timer). Debug green. UI legs on FA87: `testBarGeometryProbe` PASS (`y=95 x0=86 x1=1834 vis=1 pills=5`); `testPillFocusWalk` PASS (Up → track → pill:subtitles, Right → pill:audio, Down → track, Select opens the Subtitles tab); `testLightTapFlipsEndTime` PASS (`ends=1` then `ends=0` after 4.5 s); `testBarHideRules` PASS (~4 s playing, ≥ 4.5 s paused, never with a pill focused); `testMenuHidesBarThenExits` passes with the simulator-wall halves wrapped in expected failures (device check: Up, Menu hides the bar with the video staying, Menu exits).
  - Deviations: legs live in A's `PlayerTransportUITests.swift`; the clock shares the stream-info card's trailing VStack in `MPVPlayerScreen` rather than the bar view; `controlsVisible.didSet` resets `focusedPill`/`showsEndTime` (equivalent to the per-bump reset); `performLightTap(force:)` with `force: true` on the DEBUG path; the runner posts the Darwin notification via `CFNotificationCenterPostNotification`; paused-hide leg checks the lower bound only; every leg waits for the first 4 s bar to hide; no Reduce Motion leg; pill row is clicks-only (critique decision 4).
- **Agent C (Sonnet) DONE:** commits `91726fbe8` (planner chip auto-hide + 5 tests), `f98cdba16` (audio-delay persistence: `shared/` `PlayerTrackPreferenceStorage.kt` expect + apple/jvm/android actuals, `SubtitleAudioModels.kt` `AUDIO_DELAY_MIN/MAX_MS`, `AccountDataStores.kt` `audio_delay_ms|` prefix, plus Swift), `a012d62fc` (failure-alert engine retry: `forcedEngine`, `PlayerScreen`/`NativePlaybackCoordinator`/`StreamPickerView`), `260a7f407` (`pressesBegan` chip reveal, `debug.mpvSmokeSkipInterval` hook, Settings rows "Hold Left/Right" + "Show Clock" with descriptions, Developer knob rows, strings), `c0c87906d` (leg 4 + smoke-hook fix). **Gates on `c0c87906d`: Debug + Release sim green; jvm 1439/0; K/N 1457/0; NuvioTVTests 1444/0; leg 4 `testSkipChipAutoHides` PASS** (`chip=1` back after a Left press 11 s after it hid).
  - Deviations: leg 4 uses a `0,100000,op` interval (the smoke file resumes from saved progress, never inside 5–60 s); DEBUG `smokeSkipActive` flag keeps the real empty `fetchSkipSegments` result from overwriting the injected interval; new string keys appended as English-only `{}` entries (Xcode reorders on save; the five locales come at the end of the batch per the plan); Developer picker rows have no subtitle; no About rows for the new knobs (the trailer knobs have none either).
- **P1 BUILT, tip `c0c87906d`** (13 commits off `5feef338`).

### P1 review rounds (2026-10-06, read-only Opus; Codex over quota until 10-29)

- **r1** over `5feef338..c0c87906d` (`docs/research/player-p1-review-r1.md`): **1 P1 / 3 P2 / 14 P3**, clean on every listed failure class (no main-thread mpv reads, teardown order unchanged, wipe prefix + expect/actual parity complete, xcstrings JSON valid, failure-alert retry cannot loop). P1: the light-tap click guard is set only for Select/PlayPause, so arrow clicks (touches too) flip "ends …" on every pill walk or step. P2: no `pressesCancelled` override (a cancelled hold keeps ticking, the bar never hides, the next release commits a run-on preview; a cancelled Menu reaching `super` is probably the simulator dismissal); on a slow uncached commit the exact-stage deadline and `commitLandWork` both fire at 1.5 s so the keyframes picture never shows and the preview snaps back (`runExactStage` must move `commitGeneration` to the exact generation and re-arm the landing timer); two Menu UI legs cannot fail (test-scoped `XCTExpectFailure`). **Fix pass (Opus) DONE as `ec4e19fdc`:** everything fixed except P3 #15 (strings-file sorting, cosmetic, Xcode rewrites it). New `Screens/Player/PlayerRemoteRules.swift` with pure `LightTapGuard` (every press begin/end/cancel resets the 0.5 s guard; a tap is ignored while any press is down) and `MenuPrecedence.resolve` (panel → step/scan cancel → up-next chip → pill → bar → exit, via a new `upNextVisible` hook), `PlayerRemoteRulesTests` 10; `pressesCancelled` added (a held arrow stops its timer and drops the preview without committing, a latched scan is left alone, an already-handled Menu is swallowed; model test `testCancelledHoldThenNewPressStartsFresh`); the exact stage takes over the commit's landing handback and re-arms the fallback at 3 s, and the 1.5 s deadline waits for the keyframes seek to have started; `XCTExpectFailure` scoped to the one "player still presented" assertion, the rest of the leg reports skipped when the cover is gone; native retry prefers `resumeAtSec`; a link retried on the other engine is cleared from the rejected list; a hold while paused steps instead of scanning. Unit: TransportPreviewTests 27, SkipSegmentPlannerTests 43, PlayerTransportBarLayoutTests 17, PlayerRemoteRulesTests 10 (97). UI: hold-step PASS, scan latch PASS, skip-chip PASS (`chip=1 … pos=410.0`), light-tap PASS; both Menu legs SKIPPED on the simulator (it still closes the player after a handled Menu even with `pressesCancelled` swallowing it) → **device pass must cover: a light tap during a pill walk; Menu hides the bar and cancels a scan with the player staying open.** Debug + Release green.
- **r2** over `5feef338..ec4e19fdc` (`docs/research/player-p1-review-r2.md`): r1 verification 14 fixed, #6 fixed differently (zero-length span at the origin, harmless), #3 partly, #2 with a gap, #15 declined, no regressions. **0 P1 / 1 P2 / 5 P3.** P2 = the open half of r1 #3: the keyframes commit's 1.5 s landing fallback (main) and the exact-stage deadline (hops to `eventQueue`) fire together, clearing `previewSec` while mpv is still at the origin, so the fill snaps back on a slow seek until the exact seek lands. P3: a press cancelled during a latched scan leaves the hold timer running; a stale `panelOpen` sends Menu to `super`; a forced-native retry still offers "Try with mpv"; with the pause card off nothing re-arms the hide when playback resumes without input; `pressesDown` may leak a press. **Fix pass DONE as `9a2f5c37e`** (`MPVPlayerView.swift`, `PlayerScreen.swift` only): `exactDeadlineFired` re-arms the landing fallback at 4 s on main before the hop while `commitGeneration` matches, `runExactStage` then replaces it with its 3 s handback; a cancelled arrow stops the hold timer in every mode except a stepping hold of the other key; Menu's "panel open" is `presentedViewController != nil` only; `otherEngineEligible` is `context.forcedEngine == nil` on a native failure; paused → playing with the bar up re-runs `scheduleHide()`; `pressesDown` cleared in `viewDidAppear` and `reclaimFocus`. Unit 97/0; hold-step + scan legs PASS; Debug + Release green. Device-pass additions: a slow uncached seek (Right ×3, release) must hold the fill at the target until the seek lands; after opening and closing the panel a light tap must still flip the time label.
- **r3** over `9a2f5c37e` (`docs/research/player-p1-review-r3.md`): **CLEAN, 0 P1 / 0 P2 / 2 P3**; all six r2 findings verified fixed (the panel always presents through `controller.present`, `MPVPlayerView.swift:2525-2536`, so the `presentedViewController` check is safe; the hide re-arm never fights a focused pill or the card). P3-1: `scheduleExact`'s 0.15 s work item was nilled without cancelling, so after a ~1.5 s keyframes landing it could run a newer commit's exact stage early. P3-2 (low confidence): the slow-seek fix relied on libdispatch firing the deadline before the 1.5 s land timer. **Both fixed by the main session as `907d72002`:** the exact work item is generation-bound and cancelled in `runExactStage`; `armCommitLanding(yieldsToExact:)` makes only the first 1.5 s fallback of a keyframes-first commit skip while that commit's exact stage is pending (the 4 s and 3 s re-arms never yield, so a keyframes seek that never starts still hands back). Gates on `907d72002`: Debug + Release sim green; UI legs hold-step, exact-stage-cancelled, scan-latch PASS.
- **P1 review record closed at r3 CLEAN + `907d72002`** (16 commits off `5feef338`). Next: device pass (Christian, Living Room ATV, Test profile).

### P1 device pass (owed; Living Room Apple TV, **Test profile**, dev build `com.youngchris29.NuvioTV` from `907d72002`, INSTALLED 2026-10-06 as build 135 over devicectl, 135 MB)

Play any mpv-routed title (an MKV without Dolby Vision, or Settings → Playback → Native player OFF for the pass). Gate 1 items for Christian's eye are marked ★.

1. **Bar placement.** Press Up: the bar sits where the native engine's bar sits on a DV title (photo both). Title 44 pt, meta line under it, pills right of the title, times under the bar ends, no black panel behind the track, a soft scrim at the bottom.
2. **Hold Right (Step mode, default).** The preview playhead and the target time move 10 s steps for the first half-second, then 20, 30, 60 s; the video stays still during the hold; on release one glide to the target, no stutter, the fill holds the target until the picture lands (★ slow uncached seek: Right ×3 at a deep point in a big file).
3. **Short Left/Right click.** ±10 s, immediate, as before.
4. **Scan.** Settings → Playback → Hold Left/Right → Scan. Hold Right: scanning continues after release at 2×, silent; press Right again → 3×, again → 4×, again → 2×; Select ends it in place at 1× playing; a new hold then Menu returns to where the scan started **with the player still open** (simulator-blocked, this is the check). Held Left steps instead of scanning.
5. **Buffered fill.** On a slow debrid link the lighter fill runs ahead of the playhead and grows.
6. **Light tap.** With the bar up, rest a finger on the pad without clicking: the right label flips to "ends 11:48 PM" for 4 s. ★ During a pill walk (Up, Right, Right) a light tap must NOT flip the label on each click. After opening the panel with Down and closing it with Menu, a light tap must still flip the label.
7. **Pills.** Up from the track lands on Subtitles; Right/Left move between pills (★ clicks only, not swipes, in P1); Select opens the matching panel tab; Down returns to the track; with a pill focused the bar never hides. Menu with a pill focused drops to the track.
8. **Hide rules.** Playing: hides ~4 s after the last input. Paused with Pause Info Card ON (default): the bar hides after ~5 s and the card fades in; any press except Menu removes the card and brings the bar back. ★ Paused with the card OFF: the bar never hides.
9. **Menu precedence.** Panel open → Menu closes the panel. Bar up → Menu hides the bar, video stays (simulator-blocked). Bar hidden → Menu exits. Up-next chip visible → Menu dismisses the chip first.
10. **Skip chip.** On a title with IntroDB data the chip appears, hides after 10 s on its own, and comes back on any press while still inside the interval; Down then skips.
11. **Audio delay.** Set +0.5 s in the Playback tab, exit, replay the same title: still +0.5 s.
12. **Failure alert.** Force a failure (a dead link from the Sources tab): the alert offers the next source and "Try with Native Player" / "Try with mpv" where the other engine can take it; the retry resumes at the same position.
13. **Show Clock.** Settings → Playback → Show Clock ON: `HH:MM` top-trailing with the bar; OFF by default.
14. **Developer rows.** Developer → Hold Tick / Exact Delay pickers exist and read Auto.
15. **Nothing else moved:** Home, Search, Detail, the native engine's own bar and swipe-down panel unchanged; a cold launch in Steven's config (Show Hero OFF) smoke.

Record results in the plan's OUTCOME; new bugs get BUG rows.

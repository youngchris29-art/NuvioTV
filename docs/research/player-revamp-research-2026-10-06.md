# NuvioTV player revamp: research report (2026-10-06)

Scope: both tvOS players (the libmpv player in `MPVPlayerView.swift` and the AVPlayerViewController path in `NativePlayerScreen.swift`), measured against (a) the general field: Infuse 8, Plex, Swiftfin, Kodi, VLC, Emby, Stremio and the tvOS 26 system player; (b) the Nuvio ports: the official Android TV app, the official webOS/Tizen app, the three other Apple TV ports (bobsupra, vatax3 with its cb541 fork, Orivio), the peden88 Android TV fork, and the AetherEngine bobsupra now plays through; (c) the three Apple TV Stremio-addon clients testers compare against (Fusion, Omni, Vidi). Plus the technical options for the two features Christian asked for: fast scrubbing by swiping the remote and a seek preview in the timeline. The last section proposes a batch order.

Method: one read-only inventory of our player code (file:line anchors below); one web survey of the general field (30 fetches); one technical survey of the tvOS APIs and mpv/FFmpeg options (30 fetches); shallow clones of the seven port repos read at HEAD on 2026-10-06 (heads in §3b; clones live in this session's scratchpad, nothing was built); one web survey of Fusion/Omni/Vidi and the official Android TV release notes (25 fetches). Anything the surveys could not confirm from a primary source is marked UNVERIFIED rather than guessed.

---

## 1. Headline

1. **NuvioTV's mpv player is behind every surveyed app on one axis: seeking, and the sibling Apple TV ports are the ones furthest ahead.** It has no swipe scrubbing, no preview, no chapters, no buffered bar. Seeking is arrow-only (±10 s, then held steps up to 60 s), and every held step is a real network seek. All three other Apple TV ports scrub with thumbnails today: bobsupra harvests stills from the live decode plus a community storyboard server, Orivio runs an FFmpeg keyframe grabber with a measured velocity curve and a fine-tune wheel, and the peden88 Android fork pulls server-side Seekr thumbnails with automatic frame calibration. Infuse, the system player and Swiftfin do too.
2. **The native (AVPlayer) path gets Apple's scrubber for free but shows no thumbnails**, because the loopback HLS master the remuxer serves has no I-frame playlist. That is the single cheapest high-value fix in this report: `RemuxSession` already knows every keyframe, so it can write an `EXT-X-I-FRAMES-ONLY` rendition and AVKit will draw the previews itself.
3. **For the mpv player, the right preview source is "harvest from the main decode first, FFmpeg keyframe decoder second", not a second mpv instance.** bobsupra's engine proves the harvest idea on Apple TV with zero extra HTTP connections or decoders; our app already links libavformat/libavcodec through MPVKit and already does backward keyframe seeks in `RemuxSession.swift:416` for the parts the viewer has not reached yet. A second mpv handle would open a second HTTP connection to the debrid CDN, which is exactly what Real-Debrid style per-link connection limits punish.
4. **The AVPlayer look is reachable with the pieces already on screen, and the numbers exist.** The mpv overlay is already a Liquid Glass bottom bar with a title and times. What is missing is the system grammar: title lockup over a full-width scrubber, pills to the right of the title, a preview card above the playhead, buffered fill, a wall-clock end time, pills that take focus, and the "never auto-hide while paused" rule. Orivio's `FusionMetrics` carries the whole Infuse geometry measured off 1080p captures, and bobsupra's and Orivio's code carry the scrub velocity curves and hold ramps (§6.1), so the tuning starts from hardware-proven constants rather than guesses.
5. **Beyond seeking, the biggest functional gaps are chapters, aspect/zoom modes, the missing Playback tab on the native engine, and native subtitles ignoring the app's style.** The official Android TV app also has three player features none of the Apple TV ports have ported yet: automatic subtitle sync (affine retime), audio amplification with centre-mix, and an engine-switch button on the error screen. Everything else is polish, listed in §7 with tiers.

---

## 2. Where NuvioTV's players stand today

Paths are under `NuvioMobile/iosApp/NuvioTV/Screens/`.

### 2.1 Routing

`PlayerScreen.swift:3-16` probes the stream and picks an engine. Native wins when `player.nativeDolbyVision` is on (default ON since beta.13) and the file is MKV/MP4 with DV P5/P8 (P7 only as single-track MEL/FEL with a parseable RPU; FEL goes to mpv when `dvP7FelPreferMpv` is on) and at least one AAC/AC3/EAC3/FLAC/ALAC/MP3 track, or a TrueHD/DTS track that gets transcoded to AAC (`PlayerEngineRouter.swift:41-98`). Everything else, and every native failure, lands on mpv.

### 2.2 mpv player (`MPVPlayerView.swift`, 2307 lines, plus `Player/*`)

| Area | Today | Anchor |
|---|---|---|
| Overlay | One floating bottom bar: title, play/pause glyph, elapsed, 10 pt capsule progress bar, remaining time, "Swipe down for info". Liquid Glass tinted black 35 %, radius 24. | `:2112-2171` |
| Not on the bar | Buffered/cache fill, chapter ticks, wall-clock end time, focusable buttons, preview. | |
| Show/hide | Auto-hides 4 s after any press unless paused; 0.25 s fade. | `:1475-1484`, `:1997` |
| Remote | Select/Play-Pause toggle; Left/Right seek; Down = up-next, else skip chip, else top panel; Menu = dismiss chip, else exit. Touch surface: only a swipe-down recogniser. No pan, no edge tap, no long press, nothing on Up. | `:1321-1381`, `:267-275` |
| Seeking | Immediate ±10 s; held arrow repeats every 0.4 s with steps 20, 30 … capped at 60 s; relative `seek` commands off-main. No scrub mode, no target preview, no thumbnail. | `:1383-1473` |
| Panel | Top panel (Down or swipe-down): Info · Subtitles · Audio · Playback tabs, glass, full width. | `Player/PlayerTopPanel.swift` |
| Subtitles tab | Off / embedded / addon rows, "Searching…", Timing row ±1 s / ±0.1 s clamped to ±60 s, persisted per title. | `Player/PlayerSubtitlesTab.swift:62-88` |
| Audio tab | Language column + route picker (`AVRoutePickerView`). | `Player/PlayerAudioTab.swift` |
| Playback tab | Speed 0.5–2×, audio delay ±0.25 s to ±10 s (not persisted), Stream Info toggle, Episodes jump list, Sources switch with resume. | `Player/MPVPlaybackTab.swift` |
| Stream Info | Top-trailing glass card: resolution, codec, fps, hwdec, bitrates, audio, cache seconds and MB/s, engine. | `:2280-2307` |
| Subtitle style | Colours, border style, bold, size (sp × 55/18, clamped 36–122), outline width, `sub-pos`, SDH strip, `sub-ass-override=no`. | `:925-962` |
| Video | `vo=gpu` (or `gpu-next` on device when Enhanced Renderer is on), Vulkan via MoltenVK onto a `CAMetalLayer`, `hwdec=videotoolbox`, `tone-mapping=auto`, `hdr-compute-peak`, `target-colorspace-hint`. Match Content via `AVDisplayCriteria(refreshRate:formatDescription:)`. DV is tone-mapped, never output as DV. | `:396-440`, `:789-861` |
| Audio | `ao=avfoundation,audiounit`, `audio-channels=auto`. No passthrough, no volume, no loudness control. | `:418-421` |
| Playback | Resume (incl. percentage-only Trakt/Simkl entries), progress every 5 s, Trakt/Simkl/MDBList scrobble, skip chip (intro/recap/outro/credits/post-credits, IntroDB + AniSkip, auto-skip per type), up-next caption chip with countdown, "Still watching?" after 3 autoplays, optional next-episode preload, pause info card after 1.5 s, post-play screen, next-link failover (8 h reject memory, 4 auto attempts), 25 s start watchdog. | `NextEpisodeAutoPlay.swift`, `Player/SkipSegmentPlanner.swift`, `:1486-1622` |
| Missing | Aspect/zoom/crop (layer gravity fixed at `:251`), chapters, deinterlace, sleep timer, PiP, in-player error UI, loading overlay with artwork. | |

### 2.3 Native player (`NativePlayerScreen.swift`, 387 lines, `NativePlaybackCoordinator.swift`, 1303 lines)

| Area | Today | Anchor |
|---|---|---|
| Pipeline | MKV → fMP4 remux (`RemuxSession`) served as loopback HLS (`LocalHLSServer`) to `AVPlayer`, 24 s forward buffer. | `Coordinator:6-9`, `:598` |
| Chrome | Full `AVPlayerViewController`: system transport bar, swipe scrub, edge skips, Subtitles/Audio/speed pills. No `customInfoViewControllers`, no `externalMetadata`, no `speeds`, no explicit PiP setting (system defaults apply). | `NativePlayerScreen.swift:325-326`, `Player/PlayerPanelHost.swift:20-53` |
| Thumbnails | None: the synthesised master has no `EXT-X-I-FRAME-STREAM-INF`. | grep of `LocalHLSServer`/`RemuxSession`/`SegmentMap` |
| Panel | App top panel on Down/swipe-down with Info · Subtitles · Audio only. No Playback tab, so no in-panel speed, audio delay, episodes or sources. | `:331` |
| Subtitles | Addon SRT/VTT become WebVTT renditions; embedded text tracks decoded per segment; styling follows the tvOS system caption style, the app's `SubtitleStyleState` is ignored (no `AVTextStyleRule` anywhere). Delay works by re-serving shifted VTT. Addon subtitles arriving after the master is built are lost for the session. | `SubtitleVTT.swift`, `Coordinator:156-186`, `:204-207` |
| Audio | AC3/EAC3 pass through the remux; TrueHD/DTS become AAC 5.1. | `PlayerEngineRouter.swift:93-98` |
| HDR/DV | True DV output including P7 → 8.1 via libdovi. | `DoviRpuConverter.swift` |
| Playback | Same skip planner and up-next engine as mpv via `contextualActions`. Falls back to mpv at the same position on item failure, 30 s stall, remux failure, or a seek past the remux frontier. | `:355-380`, `Coordinator:1280-1302` |
| Missing | Pause card, post-play screen, app loading overlay, aspect/zoom, chapters, sleep timer. | |

### 2.4 Shared settings that exist but tvOS never reads

`PlayerSettingsRepository.kt:35-100` carries `resizeMode` (Fit/Fill/Zoom), `holdToSpeedEnabled`/`holdToSpeedValue` (2.0), `showLoadingOverlay`, `showParentalGuide`, secondary preferred audio/subtitle languages, `introSubmitEnabled`, and the whole iOS video block (tone mapping, target primaries/transfer, deband, interpolation, brightness/contrast/saturation/gamma). None are consumed by the tvOS mpv setup, which hard-codes its options. Several of the features below are therefore "wire a setting that already syncs" rather than new state.

### 2.5 What the upstream Compose player has that tvOS does not

From `composeApp/.../features/player/`: horizontal swipe seek with a seek preview (`PlayerSurfaceGestures.kt`, `showHorizontalSeekPreview`), hold-to-speed, resize modes (`PlayerLayout.kt`), gesture feedback pill, `OpeningOverlay` loading screen, `PauseMetadataOverlay`, `ErrorModal`, `ParentalGuideOverlay`, in-player `SubtitleStylePanel` (499 lines), `IosVideoSettingsModal` with picture sliders, `SubmitIntroDialog` (IntroDB submission), PiP, a lock state, and a visual `NextEpisodeCard` where tvOS shows a text chip.

### 2.6 Tester signal on the player

The tracker has little direct player feedback, which fits a player that works but is plain: BUG-2/3 (performance, fixed), BUG-97 (playback failed on all streams, unreproduced), FEAT-5/21/56 (external players: Infuse, VLC, Outplayer, VidHub shipped; SenPlayer asked on GitHub #5, reply owed), FEAT-19 (Vietnamese subtitle default), BUG-129 (Sources tab vs up-next race, open), BUG-130 (full-screen trailer replays the seconds already watched, reply owed), BUG-139 (fixed; its note records that Atmos survives only as EAC3-JOC and TrueHD/DTS become AAC 5.1). Nobody has asked for scrubbing yet; Steven uses Infuse for playback, which is itself the signal.

---

## 3. What the other players do

Y = yes, P = partial, N = no, ? = not verified. Columns: Infuse 8 / Plex / Swiftfin (VLCKit) / Kodi / VLC tvOS / tvOS 26 system / Emby / Stremio ATV / Orivio / **NuvioTV mpv** / **NuvioTV native**.

| Feature | Inf | Plex | Swf | Kodi | VLC | Sys | Emby | Str | Oriv | **mpv** | **native** |
|---|---|---|---|---|---|---|---|---|---|---|---|
| ±10 s edge press | Y | ? | ? | Y (stepped) | ? | Y | ? | Y | Y | Y (arrow) | Y |
| Hold to scan 2×/3×/4× | Y | ? | ? | ? | ? | Y | ? | ? | Y | P (step ramp) | Y |
| Swipe scrubbing | Y | ? | Y | ? | ? | Y | ? | ? | Y | **N** | Y |
| Scrub preview thumbnails | Y | P | Y | Y (bookmarks) | ? | Y | N | ? | Y (FFmpeg) | **N** | **N** |
| Jog ring fine scrub | Y | ? | ? | ? | ? | Y | ? | ? | ? | N | Y (system) |
| Chapters | Y | ? | Y | Y | Y | Y | ? | ? | N | **N** | **N** |
| Buffered/cache bar | ? | ? | ? | Y | ? | N | ? | ? | Y | **N** | N |
| Skip intro/credits + auto mode | Y | Y | ? | ? | N | N | Y | ? | N | Y | Y |
| Up-next countdown | Y | Y | ? | ? | N | ? | ? | ? | Y | Y (chip) | Y (chip) |
| Playback speed | Y | ? | Y | ? | Y | Y | ? | ? | Y | Y | Y (system) |
| Audio/subtitle pickers | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| Subtitle styling in app | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | **N** (system style) |
| Subtitle delay | ? | N | ? | Y | ? | N | ? | Y | N | Y | Y |
| Audio delay | ? | N | ? | Y | ? | N | ? | ? | N | Y (not persisted) | N |
| Volume boost / dialogue | Y | Y | ? | Y | ? | P (Enhance Dialogue) | ? | ? | N | **N** | P (system) |
| Zoom / aspect modes | Y (iOS) | ? | Y | Y | ? | ? | ? | ? | Y | **N** | **N** |
| Stats HUD | Y | ? | ? | Y | ? | ? | ? | ? | N | Y | Y |
| Info/cast panel in player | Y | ? | ? | Y | ? | Y | ? | ? | Y | Y | Y |
| Sources panel in player | N | N | N | N | N | N | N | ? | Y | Y | **N** |
| Episodes in player | ? | ? | ? | ? | ? | ? | ? | ? | Y | Y | **N** |
| Pause overlay with metadata | ? | ? | ? | ? | ? | ? | ? | ? | Y | Y | **N** |
| Rewind on resume | ? | Y | ? | ? | N | N | ? | ? | N | N | N |
| Sleep timer | ? | Y | ? | ? | ? | ? | ? | ? | N | N | N |
| Subtitle download in player | ? | ? | ? | Y | Y | N | ? | Y | N | P (addon) | P (addon) |
| Clock on player | ? | ? | ? | ? | ? | ? | ? | Y | N | N | N |
| PiP | ? | Y | Y (native) | ? | ? | Y | ? | ? | Y | N | ? (default) |
| Engine choice | N | N | Y | N | N | N | Y | N | Y | Y (auto) | Y (auto) |

Per-app notes worth keeping:

- **Infuse 8.** Click = play/pause; click-and-hold an edge = FF/RW, click again to step the rate; an edge click is 10 s or a chapter skip depending on a single setting; jog-wheel scrubbing while paused; live-preview scrubbing; swipe-down options; quick access to speed and volume boost; skip intros/credits/recaps from IntroDB with auto or manual mode; a Playback Stats HUD; Match Content left to tvOS.
- **Plex (2025 rewrite).** Skip Intro / Credits / Ads each with disabled / manual / automatic; Rewind on Resume 1–30 s; Up Next during credits with a configurable countdown (Immediate to 60 s, 15 s default on TV) and a 2 h "Passout Protection"; Audio Boost; a sleep timer and PiP in the new player. Scrub thumbnails on the new Apple TV player were reported missing at the time of the forum thread.
- **Swiftfin.** VLCKit player: chapters, trickplay thumbnails, 19 subtitle formats, speed, aspect fill. Native player: PiP, 4 subtitle formats, no chapters, no trickplay.
- **Kodi.** The widest OSD: bookmarks with screenshots, subtitle and audio offsets in ms, volume amplification, centre-mix level, view modes (Normal/Zoom/Stretch/Original/Custom), tone-mapping, deinterlace, brightness/contrast, stepped skips 10 s → 30 s → 1 m → 3 m on repeated presses, a Player Process Info overlay.
- **VLC tvOS.** Chapters and titles, speed 0.25–4×, OpenSubtitles download during playback. A "2025 new player UI" could not be sourced.
- **tvOS 26 system player.** Edge press = 10 s; hold = scan cycling 2×, 3×, 4×; swipe to scrub with a thumbnail above the timeline; circle the ring for fine scrub; Liquid Glass transport bar (Apple TV 4K 2nd/3rd gen only); Info/InSight, Chapters, Subtitles and Audio tabs; Enhance Dialogue (Enhance / Enhance More / Off) and Reduce Loud Sounds.
- **Emby.** Preferred Video Player MPV / Native / Auto; skip intro; refresh-rate switching; no scrub previews on tvOS as of its last public note.
- **Stremio Android TV 1.9.x.** Device clock on the player, hide other languages in the subtitles menu, subtitle delay with a live preview, instant skips.
- **Orivio (the other Apple TV Nuvio port).** An Infuse-measured chrome (bar centre 95 pt from the bottom, 86 pt side insets, 44 pt bold title 60 pt above the bar, 62 pt glyph discs, everything ignoring the safe area), velocity-adaptive touchpad scrubbing with a time bubble, FFmpeg scrub thumbnailer with coarse + dense passes, cache-coverage bar, sources and episodes panels in the player, pause overlay with cast, aspect fit/zoom/stretch, a playback decision log. Its §7.9 records six serial defects that kept its preview window empty; read it before building ours.

Most common across the field, in order: track pickers with styling; 10 s edge skips with hold-to-scan; scrub previews; chapters; skip intro with an auto/manual mode; speed presets; up-next countdown; zoom modes; audio boost or dialogue enhancement.

Distinctive, one or two apps only: jog-ring scrub (Infuse, system), one-gesture edge click = 10 s or chapter (Infuse), Rewind on Resume (Plex), Passout Protection (Plex), stepped skip escalation (Kodi), offsets in the OSD (Kodi, Stremio), in-player subtitle download (VLC, Kodi, Stremio), Enhance Dialogue / Reduce Loud Sounds (system), sleep timer (Plex), skip button auto-hides after 10 s (Max), bookmarks (Kodi), clock on the player (Stremio).

---

## 3b. The Nuvio ports

Clone heads read on 2026-10-06: official Android TV `NuvioMedia/NuvioTV` `0dc762e` (10-05), `NuvioMedia/NuvioWeb` `25b984f` 1.2.3 (10-05), `bobsupra/NuvioTVOS` `ad10335` Beta 3.4.1 (10-05), `vatax3/NuvioTVOS` `ea4a0b1` v1.0.44 (09-30), `cb541/NuvioTVOS` `20ac1c5` (09-20), `peden88/NuvioTV` `6db8530` 1.0.0-custom (09-18), `prehakanson-art/OrivioTVAppleTV` `5e4c904` v0.12 (10-05), `superuser404notfound/AetherEngine` `7de2d5a` 7.28.0 (10-06). Paths are relative to each clone.

### 3b.1 Official Android TV (`NuvioMedia/NuvioTV`)

The reference every other port mirrors, so its numbers are the de-facto Nuvio grammar.

- **Engines:** ExoPlayer/Media3 primary, libmpv second. `InternalPlayerEngine { EXOPLAYER, MVP_PLAYER, AUTO }`; AUTO sends HDR/DV-named files to ExoPlayer, anime ids (`kitsu:`/`mal:`/`anilist:`) or anime genre to mpv, else ExoPlayer (`PlayerRuntimeControllerInitialization.kt:1933-1966`). Startup failover swaps engine once on error with a "switching to X" overlay and carries the track preference across (`PlayerRuntimeControllerEngineFailover.kt:11-40`). DV P7 modes: AUTO / HDR10 base layer / DV8.1 via libdovi / strip / off.
- **Controls:** auto-hide 3 s, suppressed while any panel is open (`PlayerRuntimeControllerPlaybackEvents.kt:1028-1040`); progress bar draws the buffered fraction (`PlayerScreen.kt:2696`); optional OSD clock top-right (`osd_clock_enabled`); indicators for stream source, aspect ratio, engine switch, display-mode (AFR) and torrent stats; a "More" dialog with aspect ratio, open external, speed, subtitle delay, switch to mpv, and report playback issue (the issue code shows for 5 s).
- **Seeking:** with the controls hidden, Left/Right is a *preview* seek with acceleration keyed to `KeyEvent.repeatCount`: 10 s, 20 s at ≥3 repeats, 30 s at ≥8, 60 s at ≥15 (`PlayerScrubRates.kt:12-19`). The preview accumulates in `pendingPreviewSeekPosition` and is committed once on key-up with `SeekParameters.CLOSEST_SYNC` (`PlayerScreen.kt:760-767`; `PlaybackEvents.kt:1239-1265`). A seek overlay, not the full controls, shows during hidden seeks. Up shows the controls and focuses the bar; Centre is play/pause when hidden; on the pause overlay Centre/Play resumes in one click and any other key dismisses (`PlayerScreen.kt:770-790`). **No seek thumbnails, no chapters.** Our tvOS step table matches this one exactly; the difference is that ours issues a real seek per step while the official app previews and commits once.
- **Panels:** audio overlay with tracks, audio delay in ms, **amplification dB, centre-mix dB**, `remember_audio_delay_per_device`; subtitle overlay (embedded + addon, forced, SDH strip, preferred/secondary language); subtitle style side panel (size, colour, bold, outline, width, vertical offset, background); subtitle timing dialog with **AutoSync V2** (a fixed-offset check, then a whole-film affine retime by dynamic programming, `autosync/AutomaticSubtitleSync.kt:1-8`); speed dialog; episodes side panel (season → episode → streams with an addon filter); sources side panel; stream-info overlay (`StreamInfoOverlay.kt`: engine, file name/size, video codec/res/fps/bitrate, audio codec/channels/rate/lang, subtitle name/codec/source); parental guide overlay; debug stats HUD; display-mode overlay; aspect toggle.
- **Playback:** skip intro auto-hides after 10 s (`SkipIntroVisibilityRules.kt:5`), post-credits aware; next-episode card thresholds by percent or minutes-before-end, outro-aware (`PlayerNextEpisodeRules.kt:61-93`), `POST_OUTRO_AUTOPLAY_GAP_MS 5000`, `NEAR_END_MS 500`; `preload_next_episode_sources`, binge-group reuse, auto-play timeout; still watching with a 60 s countdown and an episode threshold (`PlayerRuntimeControllerStillWatching.kt:8`); pause overlay after 5 s (`PlayerRuntimeController.kt:606`) with "You're watching", poster, S/E, cast; **post-play recommendations** (movie prefetch lead 5 %); loading overlay with a status line; external player launch with `ExternalPlaybackTracker` and auto-next after an external player; reuse-last-link cache; stall/first-frame/mpv-startup watchdogs; error recovery.
- **Distinctive:** AFR frame-rate + resolution matching (`core/player/FrameRateUtils.kt`, `MatroskaAfrProbe.kt`); parallel-range HTTP data source with a VOD disk cache; audio tunnelling / passthrough / downmix normalisation / skip-silence; libass render-type choice; episode shuffle; letterbox detector; Zidoo monitor; playback-issue reports. Release notes since 0.8 add "Remember playback speed per show", "Sync Line" (pick a cue to align) and long-press a track to turn subtitles off.

### 3b.2 bobsupra/NuvioTVOS (Swift tvOS, KMP shared, AetherEngine + MPVKit)

The most advanced seeking of any port, worth reading in full before Batch P2/P3.

- **Engines:** AetherEngine (vendored) primary, MPVKit fallback; `PlayerEngineSetting { auto, aether, mpv }` with a `resolve()` ladder (separate audio URL → mpv; trailer → aether; audio amplification → mpv; ASS "scale" mode on anime → mpv; HLS/live → aether; automatic Aether → mpv fallback on terminal error) (`Core/Player/PlaybackBackendPolicy.swift:10-175`).
- **Controls:** hide after 5 s, 10 s after a panel interaction (`UI/Player/PlayerControls.swift:154-441`); an Infuse-style scrub HUD with a `SeekPreviewTimelineCard` thumbnail (`:634-640`, `ScrubberViews.swift:232`); a **"peek bar" on a light touchpad contact without a click** (`ViewModels/PlayerViewModel.swift:3557`); a next-episode card with the episode thumbnail (`PlayerControls.swift:1231-1301`).
- **Input:** a window-level `UIPanGestureRecognizer` on indirect touches (`UI/Player/RemoteInput.swift:4,53`). Seek step user-selectable 5/10/15/30/60 s, default 15 (`Models/PlayerModels.swift:68-70`); `scrubJump = max(4 × step, 60)`. **Hold-seek ramp:** a 0.10 s tick, rate = step × 1.0 / 2.5 / 6.0 / 15.0 per second after a hold of < 1.2 / < 2.5 / < 4.5 / ≥ 4.5 s (`VM:2934-2952`). Swipe scrub is allowed only when playback was already paused at touch-down; horizontal swipes are suppressed while playing (`VM:3434-3446`). **Velocity curve** (`VM:3025-3046`): `delta = sign × |inc| × 0.06 × m`, with `m = 0.7 + 0.3 t` for |inc| ≤ 3 pt, `1 + 1.5 t × df` up to 8 pt, `(2.5 + 3.5 t) × df` beyond, `df = clamp(√(duration/3600), 0.8, 1.8)`; scrub publishes at 30 Hz.
- **Thumbnails:** `scrubThumbnail(maxWidth: 360, precise:)` (`Core/Player/AetherPlaybackController.swift:2514-2544`); `HybridSeekThumbnailPolicy` with a fine bucket of 0.5 s, a coarse bucket of 60 s, ≤ 120 coarse samples, max time error 0.5 s (`:1558-1562`); **passive harvesting of stills from the decoded buffer during playback, "0 extra HTTP/decoders"** (`:2585`); `TrickplayDiskCache` of ~15 KB JPEGs under a 100 MB budget (`:1628-1636`); `TrickplayProviding` for WebVTT/BIF/sprite sources (`:1621`); `TrickplayResolver` tries an addon-supplied trickplay URL, then a **community storyboard server** (`SettingsKey.trickplayServer`, `:1973-1995`); `TrickplayStoryboardBuilder` writes 10-column sprite sheets and `TrickplayUploader` pushes them back to that server (`:2043, 2137`). A seek-preview on/off toggle sits in the panel.
- **Panels:** subtitles / audio / speed / picture tabs (`PlayerControls.swift:1540-1600`): subtitle style, subtitle delay, audio delay, amplification, speed, seek step, seek preview, loading status, debug overlay, aspect; episodes and sources side panels; **AI subtitle translation** (Gemini / OpenRouter with batching and pacing, `AetherPlaybackController.swift:55-1052`); enhance-dialogue and reduce-loud-sounds switches; a **Scene panel** of actors and songs, X-Ray style (`UI/Player/Scene/`).
- **Playback:** IntroDB skip segments (auto-hide 10 s, season template seeding); next card 120 s before the end when there is no outro marker, auto-hide 10 s; pause overlay after 15 s; post-play recommendations; PiP (`Core/Player/PictureInPictureManager.swift`); a local `PlaybackStreamCacheServer` disk-cache proxy; loading overlay. No still-watching, sleep timer or external-player hand-off found.
- **AetherEngine public API** (README, `docs/api.md`, `docs/formats.md`): `setRate` clamped to 2× video / 3× audio-only; `seek(to:)` with `$isSeeking`, `$seekTarget`, began/landed events; seeks into watched content are cache hits (2 GiB cap); `FrameExtractor.thumbnail(at:)` nearest keyframe plus `snapshot(at:)` frame-accurate and `prewarm()`; subtitle cues as text/richText/image, external tracks, a **secondary simultaneous subtitle track**, native WebVTT renditions for PiP/AirPlay, CEA-608; `$mediaChapters` from MKV/MP4 (no port consumes it yet); `audioDelaySeconds`; `matchContentEnabled`; HDR10/10+/DV P5, P7 → 8.1, P8.1/8.4/HLG; Atmos EAC3-JOC stream-copy; a `$videoRoute` of remote-bypass vs loopback; live/DVR; SMB. The project is on 7.28.0 and moved under bobsupra's app a month ago; an earlier comparison in `docs/` already flagged it as covering formats we do not.

### 3b.3 vatax3/NuvioTVOS and its cb541 fork (Swift tvOS)

- cb541's player directories are an older snapshot reconciled to 0.8.9-beta (it lacks the `subtitleSync` picker, adds an unsigned-IPA GitHub Actions workflow). **No player additions in cb541.**
- **Engines:** `AVPlayerViewController` for H.264/HEVC/HLS (`Sources/Features/Player/PlayerView.swift:1352`), libmpv via MoltenVK for MKV and the rest (`MPVEngine.swift:9`); an in-player "switch engine" button; `autoSwitchInternalPlayerOnError`.
- **Controls (mpv path):** the Android control row verbatim: subtitles, audio, sources, switch engine, episodes, speed, aspect (cycles with a 2 s flash pill), open external, stream info, more (`MPVPlayerView.swift:640-700`). Hide after 5 s; the seek overlay lingers 1.5 s (`PlayerSeekOverlay.swift:22`). The AVPlayer path keeps the system transport with its scrub preview.
- **Input:** `PlayerRemotePolicy` with focus owners (sink/transport/progress/unmanaged): Left/Right seek, Up/Down reveal, Select reveals or resumes; the pause card is dismissed by the first press. The same 10/20/30/60 table; a held direction is emulated by `PlayerHoldSeekGate` UIPress recognisers ticking every 180 ms and committing 300 ms after the last step (`MPVPlayerView.swift:798-818, 1593-1640`). No thumbnails on mpv. Menu semantics live in a `PlayerExitPolicy` with a 0.35 s echo window.
- **Panels:** audio (delay ±0.1 s to a limit, amplification), subtitles (delay), subtitle appearance, **subtitle sync picker**, speed, stream info, sources, episodes; a stats overlay with CPU via `task_info`, buffer and bitrates (`PlaybackStatsSampler.swift`); `DisplayModeMatcher` for frame-rate matching.
- **Playback:** IntroDB + AniSkip with auto-hide 10 s, show delay 5 s, unexplained tail 5 s (`SkipSegmentVisibility.swift:32-134`); compact PostPlay plus a `StillWatchingOverlay`; pause card; loading overlay; external players Infuse / VLC / nPlayer / Outplayer (`Data/ExternalPlayers.swift:14-43`); a `PlaybackWakeLock`; a `MovieRecommendationsOverlay`. PiP referenced once only.

### 3b.4 peden88/NuvioTV ("NuvioTV Custom", Android TV fork of the official app)

Player-package diffs against the official app only:

- **Seek thumbnails from a server:** `SeekrPreviewThumbnailHost.kt` shows a three-frame preview (`PREVIEW_STEP_MS 10000`, linger 1500 ms); `SeekrFrameCalibration.kt` compares the 320 × 180 Seekr thumbs against 32 × 18 downsampled frames from the live player at three anchors in a ±3 s window (`MIN_SIMILARITY 0.56`, `MIN_MARGIN 0.035`, `MAX_SEEKR_OFFSET_MS 240000`, 9 s timeout) and derives an offset, with a manual "Preview Sync" nudge of 250 ms. This solves the problem that a community storyboard was cut from a different release than the file playing.
- `PlayerRemoteInputRouter.kt` (press/release ownership, preview-only seeks, double-fire suppression); `PlaybackStatsOverlay` with CPU/thermal/byte samplers; `core/player/ScreensaverController.kt` (OLED idle dim) and a full-app dimmer usable in-player; `AudioPassthroughPolicy`, `LosslessAudioTrackDefault`, `AudioCapabilityReport`, `Hdr10SeiInjector`, `DeniedTranscodePlanner`, `PlaceholderStreamPolicy` with probe and reject; `PrefetchedSelection.kt` (the detail-screen stream prefetch behind FEAT-49's "~2 s" claim); **skip providers SkipMe.db / IntroDB / TheIntroDB / PublicMetaDB / MovieHavenDB / VideoSkip / NotScare with confidence merging**; a post-play source picker (Trakt/TMDB/Kurato/BingeCat/Simkl/MDBList). Its base predates the official `AutomaticSubtitleSync`, `MpvHi10pFallback` and `LetterboxDetector`.

### 3b.5 NuvioMedia/NuvioWeb (webOS / Tizen)

- Four engines in `js/core/player/engines/`: HTML5 native, hls.js, dash.js, Tizen `webapis.avplay`, plus a webOS native-player launch. Timeouts: AVPlay seek 30 s, buffering 10 s, HLS rebuffer stall 15 s.
- Pause overlay after 5 s with up to 8 cast (`playerScreenHelpers-02:432-434`); animated parental guide; OSD clock; the same 10/20/30/60 table (`playerScrubRates.js:8-15`) accumulating a preview per key repeat and committing 1 s after the last press. **No thumbnails.**
- Amplification 0–10 dB; speeds 0.25–2; subtitle colours/outline/size/offset/delay; bitmap subtitles via a webOS service; aspect; episodes and sources panels; skip intro with a 10 s countdown and a 12 s seek suppression; **next-episode prefetch at 90 %** (`NEXT_EPISODE_PREFETCH_PERCENT 0.9`), resolve timeout 120 s; still watching; post-play recommendations.

### 3b.6 Orivio: numbers the handoff doc does not state

- `FusionMetrics` (`OrivioTV/Player/FusionPlayerControlsOverlay.swift:12-47`): bar centre 95 pt from the bottom, side inset 86, track 6, playhead 28, wheel 46, slit 4 × 20, rest dot 16, **preview frame 400 × 225 with a 30 pt gap**, time gap 13, title gap 30, time font 28, glyph disc 62 with 25 spacing, popover 440 with a 20 gap, time row 34. Bar modes: idle / nudging / scrubbing / fineTuning.
- **Scrub:** `secondsPerPoint = max(duration / 4800, 0.25)` (`PlayerViewModel.swift:6432-6438`), so a 2 h film scrubs at 1.5 s per point; intent threshold 45 pt (190 after a Skip pill grabbed at > 12 pt); 0.4 s move suppression. **Fine-tune wheel:** hold 0.15 s, ring radius 0.72, 24 s per revolution, ±20 s window (`:6782-6803`). **Nudge:** each press = `settings.skipSeconds`, no ramp, streak window 0.6 s, debounce 450 ms, `skipOvershoot 0.5`. **Scan:** `scanRate` ±2/±3 sweeps the preview with the player paused, committed on Play (`:1144-1149`).
- **Thumbnailer** (`ScrubThumbnailer.swift`): FFmpeg keyframe grabber, default 36 frames at 256 px wide, a 60 s wall-clock budget, `thread_count 2`, `rw_timeout` + interrupt callback; cadence 30 s coarse / 15 s scrub / 8 s drag / 2 s fine, fine sweep 1 s over a 90 s window, 120 s sweep budget, `previewLeadGate 15`.

### 3b.7 Fusion, Omni, Vidi (Apple TV Stremio-addon clients, web only)

- **Fusion** (r/FusionTheApp; free on the App Store since ~2026): a built-in player exists (TroyPoint), engine AVPlayer or KSPlayer (a Firecore forum poster groups Vidi/Omni/Fusion that way; exact engine UNVERIFIED); multiple external players with a default and an **"auto-forward the first source to the external player"** option; tester sentiment: "amazing UI on Apple TV, but the built-in player feels a bit weak". Everything else unknown.
- **Omni** (Joseph Steckler, ~$6, tvOS 18+): built-in 4K HDR player, external players, "auto play best stream", Trakt, iCloud sync. The App Store listing 404s from two fetchers; a Reddit excerpt says Stremio, Fusion and Omni were all pulled from the tvOS App Store at one point. Player details unknown.
- **Vidi** (Plata o Plomo AB, tvOS 17+): **KSPlayer default with libVLC as the alternative**; HDR10/10+/DV/Atmos claimed; addon subtitles grouped by addon and language, several subtitle addons at once, adjustable delay, custom appearance; Infuse and VLC as external players; long-press copies the stream URL; PiP with subtitles. Reviews say: no continuous auto-play, no skip intro.

### 3b.8 Port matrix

Y / N / P = partial. Columns: official ATV / bobsupra / vatax3 (cb541) / peden88 / NuvioWeb / Orivio / **NuvioTV mpv** / **NuvioTV native**.

| Feature | ATV | bob | vat | ped | Web | Oriv | **mpv** | **native** |
|---|---|---|---|---|---|---|---|---|
| Dual engine + auto pick | Y | Y | Y | Y | Y (4) | Y | Y | Y |
| Engine failover on error | Y | Y | Y | Y | P | Y | Y (native → mpv) | Y |
| In-player engine switch button | Y | N | Y | Y | N | N | **N** | **N** |
| Buffered bar | Y | Y | P | Y | Y | Y | **N** | N (system) |
| OSD clock / end-time toggle | Y | N | N | Y | Y | Y | **N** | **N** |
| Accelerating hold seek | Y | Y (ramp) | Y | Y | Y | N (scan) | Y | Y (system) |
| Preview-then-commit held seek | Y | Y | Y | Y | Y | Y | **N** (seek per step) | Y (system) |
| Swipe scrub | n/a | Y (paused) | P (AV only) | n/a | n/a | Y | **N** | Y (system) |
| Seek thumbnails | N | Y (hybrid + community) | P (AV only) | Y (Seekr) | N | Y (FFmpeg) | **N** | **N** |
| Fine-tune wheel | N | P | N | N | N | Y | N | Y (system ring) |
| Chapters | N | N (engine has them) | N | N | N | P | **N** | **N** |
| Audio delay | Y | Y | Y | Y | N | Y | Y (not persisted) | **N** |
| Audio amplification / centre-mix | Y | Y | Y | Y | Y | N | **N** | **N** |
| Subtitle delay + style | Y | Y | Y | Y | Y | P | Y | P (delay only) |
| Subtitle auto-sync | Y | N | Y (picker) | N | N | N | **N** | **N** |
| AI subtitle translation | N | Y | N | N | N | N | N | N |
| Speed | Y (per show) | Y | Y | Y | Y | Y | Y | Y (system) |
| Aspect / zoom | Y | Y | Y | Y | Y | Y | **N** | **N** |
| Episodes in-player | Y | Y | Y | Y | Y | P | Y | **N** |
| Sources in-player | Y | Y | Y | Y | Y | Y | Y | **N** |
| Stream info / stats | Y | Y | Y + CPU | Y + thermal | P | Y | Y | Y |
| Parental guide in-player | Y | N | N | Y | Y | N | **N** | **N** |
| Skip intro/outro | Y | Y | Y | Y (7 providers) | Y | Y | Y | Y |
| Auto-skip | Y | N | N | Y | N | Y | Y | Y |
| Next-episode card | Y | Y (thumb) | Y | Y | Y | Y | P (chip) | P (chip) |
| Next-episode source preload | Y | N | N | Y | Y (90 %) | N | Y | Y |
| Still watching | Y | N | Y | Y | Y | Y | Y | Y |
| Pause overlay | Y (5 s) | Y (15 s) | Y | Y | Y (5 s) | Y | Y (1.5 s) | **N** |
| Post-play recommendations | Y | Y | P | Y | Y | N | **N** | **N** |
| PiP | n/a | Y | P | n/a | n/a | Y | N | ? |
| External player hand-off | Y | N | Y (4) | Y | Y | Y | Y (4, from the picker) | same |
| Loading overlay with artwork | Y | Y | Y | Y | Y | Y | **N** | **N** |
| Frame-rate matching | Y | Y | Y | Y | N | Y | Y | Y (system) |
| Scene / X-Ray panel | N | Y | N | N | N | N | N | N |
| Peek bar on light touch | N | Y | N | N | N | N | N | N |
| Report playback issue | Y | N | N | Y | N | N | N | N |
| Local disk stream cache | Y (VOD) | Y (proxy) | N | Y | N | N | N | N |
| Sleep timer | N | N | N | N | N | N | N | N |

Correction to the web survey's draft matrix: it listed our mpv player as lacking audio delay and a stats HUD; both exist (`MPVPlaybackTab.swift`, `MPVPlayerView.swift:2280`). The port table above is from the code.

---

## 4. The gap list

Ordered by how far NuvioTV sits from the field.

1. **Seeking on mpv**: no swipe scrub, no preview, no scan rates, no buffered bar, no chapters, and a held arrow fires a real seek per step where every Nuvio port previews and commits once on release. Every other app in both tables has at least swipe or preview; all three sibling Apple TV ports have thumbnails.
2. **Seek preview on native**: the system scrubber runs but shows no frames.
3. **Chapters**: neither engine reads them. mpv exposes `chapter-list` for free; MKV remuxes from scene groups very often carry chapters.
4. **Aspect/zoom modes**: none on either engine, though `resizeMode` already syncs from the phone.
5. **Native engine's missing Playback tab**: no speed in the panel (the system pill exists), no audio delay, no episodes, no sources. These are `customInfoViewControllers` / `transportBarCustomMenuItems` / `speeds` away.
6. **Native subtitles ignore the app's style**: `AVTextStyleRule` is the documented route; Orivio applies it.
7. **mpv audio**: no passthrough, no volume or boost, no dialogue enhancement, audio delay not persisted.
8. **Overlay polish**: no loading overlay with artwork (setting exists), up-next is a text chip not a card, no in-player error chip (the "Trying another source" follow-up is already logged), no clock, no end time.
9. **Unused synced settings**: hold-to-speed, parental guide, secondary languages, picture controls, intro submission.
10. **Late addon subtitles are lost on native** for the session (`Coordinator:204-207`).
11. **Official-app features no Apple TV port has yet**: automatic subtitle sync (affine retime), audio amplification with centre-mix, in-player engine switch on the error screen, post-play recommendations, "report playback issue", per-show speed memory. First port to ship them gets the "most complete" claim.
12. **Port-only ideas worth a look**: bobsupra's peek bar on a light touch, Scene panel and community storyboards; peden88's multi-provider skip merging and Seekr calibration; Orivio's fine-tune wheel and paused Nx scan.

---

## 5. Redesign: the mpv player in the AVPlayer grammar

Goal: a viewer should not be able to tell which engine is playing. The native path already *is* AVPlayerViewController, so the target is a pixel-close sibling, not a new style.

### 5.1 Visual spec

Reference grammar (tvOS 26, Apple TV 4K 2nd/3rd gen): a bottom transport bar with a title lockup above a full-width scrubber; elapsed time at the left end, remaining (or wall-clock end) at the right; the system pills (Subtitles, Audio, Speed, PiP, custom items) to the right of the title line; a preview card floating above the playhead while scrubbing; chapter and interstitial marks on the track; everything in Liquid Glass, chrome "floating above the video"; the swipe-down panel is a tab strip over a dark scrim.

Proposed layout for `PlayerControlsOverlay` (replace `:2112-2171`), with Infuse's measured numbers as the starting geometry because they are the only hardware-measured set we hold:

| Element | Spec |
|---|---|
| Bar track | Full width minus 86 pt side insets; centre line 95 pt above the bottom edge; 10 pt capsule at rest, 14 pt while scrubbing; `.ignoresSafeArea()` like the system bar (Orivio found the safe-area inset "looked wrong until it ignored it") |
| Fills | Played fill in white (accent only when `accent_focus_ring` style demands it), buffered fill in white 35 % behind it, track in white 20 % |
| Marks | 2 pt chapter ticks in white 60 %; skip-segment spans (intro/recap/credits) as a 4 pt lighter band so the viewer sees where the chip will fire |
| Times | Monospaced digits 28 pt under the bar ends; right label toggles remaining ↔ wall-clock end time on a light tap (Infuse grammar) or always shows both as the system does: "1:12:40 · ends 11:48 PM" |
| Title lockup | Title 44 pt semibold 60 pt above the bar, subtitle line (S1 E4 · Episode name · provider) 28 pt regular underneath, same `metaStrong` token the hero uses |
| Pills | 62 pt glass discs right of the title line: Subtitles, Audio, Speed, Sources, Episodes (series), More. Focusable with the standard focus lift; Left/Right moves between them when the bar is up; Down from the pills lands on the bar |
| Preview card | 320 × 180 glass-bordered card 24 pt above the playhead, clamped to the bar's horizontal extent, with the target time 24 pt under it and the chapter title (if any) above it; title lockup and end labels fade out while scrubbing |
| Materials | `.glassEffect(.regular)` for the bar and pills, no black tint by default (the current 35 % black tint reads heavier than the system bar); a 0.55 → 0 bottom scrim 300 pt tall behind the bar for legibility on bright footage |
| Panel | Keep `PlayerTopPanel` as is: it already matches the system's tab strip. Add a Chapters tab when `chapter-list` is non-empty |
| Hide rules | 4 s after the last input while playing; never while paused; never while a pill has focus; 0.25 s fade; Up or any pad touch raises it |

Focus: the overlay should reset focus to the bar from state (an `overlay.showsTransport` change), not from `onAppear`. Orivio measured 199–317 ms → 7–8 ms from that one change; the libmpv controller must regain first responder when the overlay drops (`:1904` already handles this on panel close, extend it to the bar).

### 5.2 Remote grammar

The system player's published model, with the Infuse additions that are confirmed on hardware:

| Input | Playing, bar hidden | Bar up | While scrubbing |
|---|---|---|---|
| Click | Play/pause, bar up | Play/pause | Commit the seek |
| Play/Pause button | Toggle | Toggle | Commit and play |
| Edge press Left/Right | ±10 s, bar up | ±10 s (or chapter skip when the setting says so) | ±10 s on the preview playhead |
| Hold Left/Right | Scan 2×, press again 3×, again 4×; release = play at 1× | Same | n/a |
| Swipe Left/Right | Enter scrub mode, preview playhead follows the finger | Same | Move the preview playhead |
| Light tap (no click) | Bar up | Toggle remaining ↔ end-time labels | n/a |
| Up | Bar up | Pills row | Cancel scrub |
| Down / swipe down | Up-next, else skip chip, else panel (unchanged) | Panel | Cancel scrub, panel |
| Menu | Exit | Hide bar | Cancel scrub, keep the bar |
| Jog ring (2nd-gen remote) | Fine scrub at 1 s per 10° | Same | Same |

### 5.3 Transitions

The system player's grammar is "chrome floats in, video never moves". Keep the video layer untouched; the bar, pills and preview card use `.transition(.opacity.combined(with: .move(edge: .bottom)))` over 0.25 s. Scrub enter/exit cross-fades the title lockup and the end labels (0.15 s). The pause card (`PauseInfoCard`) stays, but should wait for the bar to hide first so the two never stack.

---

## 6. Fast scrubbing and seek preview: design

### 6.1 Input layer (mpv player)

- **Scrub**: `UIPanGestureRecognizer` with `allowedTouchTypes = [.indirect]` on the player view (bobsupra mounts it window-level, `UI/Player/RemoteInput.swift:4,53`). `translation(in:)` gives points of finger travel, `velocity(in:)` points/s. While the pan owns the touch the focus engine does not move focus, so keep it scoped to the full-screen player view where focus is parked on the invisible focusable view. Two hardware-proven curves to start from, both behind Developer knobs for one rc: Orivio's duration-scaled constant `secondsPerPoint = max(duration / 4800, 0.25)` with a 45 pt intent threshold (a 2 h film = 1.5 s/pt, a 20 min episode = 0.25 s/pt); or bobsupra's per-sample curve `delta = sign × |inc| × 0.06 × m`, `m` rising from 0.7 to `(2.5 + 3.5 t) × df` with `df = clamp(√(duration/3600), 0.8, 1.8)`, published at 30 Hz. Orivio's is simpler to reason about and reads like the system player; bobsupra's rewards flicks. Clamp to [0, duration]. Apple's own seconds-per-point is not published. Decide whether a swipe scrubs while playing (Orivio, system) or only when already paused (bobsupra, to protect against accidental pad brushes); the system grammar allows it while playing, and our 160 pt tap threshold logic from the Orivio handoff handles the brush case.
- **Edge press vs hold**: `UILongPressGestureRecognizer` with `allowedPressTypes = [.leftArrow, .rightArrow]` and `minimumPressDuration ≈ 0.4 s` for the scan; a press that ends before that is the ±10 s skip. Two models for the hold: (1) the system's playback scan at `speed=2/3/4` with `audio-pitch-correction` off and audio muted, cycling on repeat presses, back to 1× on release; (2) the Nuvio grammar every port shares: a stepped preview seek that **accumulates and commits once on release** (official ATV `PlayerScrubRates.kt:12-19` with the 10/20/30/60 table keyed to repeat count, committed with `CLOSEST_SYNC` on key-up; bobsupra's time ramp of step × 1 / 2.5 / 6 / 15 per second after 1.2 / 2.5 / 4.5 s). Our current ramp (`:1383-1407`) is the official table with one defect: it issues a real seek per step. The cheapest win is to keep the table and move to preview-then-commit (Orivio's paused Nx scan is the same idea with a thumbnail sweep). Offer the system scan as the alternative setting once scrubbing exists.
- **Jog ring (optional)**: `GCController.microGamepad` with `reportsAbsoluteDpadValues = true`; radius = √(x²+y²), ignore r < 0.5, accumulate the angle delta. Apple's stated supported route is AVPlayerViewController, so ship behind a toggle and verify on both remote generations.
- **Hardware only**: the simulator never swipes, so every gesture claim needs a device pass (field note already in memory).

### 6.2 Seek policy on the main mpv

- **During a scrub, do nothing on the main player.** Keep it paused on the current frame; the preview playhead and card carry the feedback.
- **On commit**: `seek <t> absolute+keyframes` first (instant picture), then if the user is idle 150 ms, `seek <t> absolute+exact` to land precisely (thumbfast's two-stage trick). Skip the first stage when `demuxer-cache-state.seekable-ranges` already covers the target.
- **Cache**: raise `demuxer-max-back-bytes` to 50–100 MiB and keep `demuxer-max-bytes` at 150–300 MiB so the ±1 min neighbourhood stays seekable without a network round trip; the existing Streaming Buffer and Network Readahead settings map onto these.
- **Why**: a keyframe seek on a remote MKV is one Cues lookup, one HTTP range request, decode from an I-frame: a few hundred ms. An exact seek adds decoding every frame from that keyframe to the target, up to 240 frames on a 10 s GOP of 4K HEVC: seconds, and each repeat while the finger moves stalls the demuxer thread. Log `seeking` transitions into the health pane so the device pass can read them.

### 6.3 Preview source, ranked for NuvioTV

0. **Harvest from the main decode (free, covers everything the viewer has already played).** bobsupra's engine does this on Apple TV with "0 extra HTTP/decoders" (`AetherPlaybackController.swift:2585`), bucketing stills into a 0.5 s fine / 60 s coarse policy and a 100 MB JPEG disk cache. On mpv the equivalent is a periodic `screenshot-raw` (video-only, no OSD) on the main handle, roughly every 10 s of playback, scaled to 320 px: a GPU readback, no decode, no network. It also fills in behind every seek the viewer makes. Pair it with (1) for the unwatched part of the timeline; the two write into one store keyed by keyframe PTS.
1. **FFmpeg keyframe decoder (recommended for the unwatched region on mpv).** `avformat_open_input` on the same URL with the stream's `proxyHeaders`, `av_seek_frame(AVSEEK_FLAG_BACKWARD)`, decode exactly one I-frame, `sws_scale` to 320 × 180, cache by keyframe PTS. The app already links libavformat/libavcodec/libswscale through MPVKit and already does this seek in `RemuxSession.swift:416` and `:773`; `MediaProbe.swift` holds the open-with-headers pattern. One `AVFormatContext`, no mpv core, no cache; full control of range requests; easy to pre-warm a filmstrip every 10 s in the background during playback (IINA's design). Cost: a 1080p HEVC I-frame is tens of ms in software on A12/A15, 4K 10-bit roughly 100–200 ms (estimate, UNVERIFIED); use `videotoolbox` through `AVHWDeviceContext` or cap at 1080p-class decode. HDR frames need an SDR tone-map (`zscale`/`tonemap` or a Metal shader); DV profile 7 thumbnails come from the base layer. Orivio's lesson list in its handoff §7.9: never set `skip_frame = AVDISCARD_NONKEY` on MKV (the decoder swallows every packet), stamp thumbs with the keyframe PTS and accept ±GOP tolerance in the lookup, merge passes instead of assigning, and let a cancelled pass keep what it decoded.
2. **Second libmpv handle (thumbfast in-process).** `vo=null`, `--no-audio --no-sub --hwdec=videotoolbox-copy|no --vd-lavc-skiploopfilter=all --vd-lavc-fast --vd-lavc-threads=2 --demuxer-max-bytes=256KiB --demuxer-readahead-secs=0 --vf=scale=320:-2 --pause --keep-open=always`, `screenshot-raw bgra` after each throttled `seek keyframes`. Handles everything mpv plays with identical HTTP behaviour. Cost: a second connection to the debrid CDN (Real-Debrid style per-link connection limits; verify before shipping), ~30–60 MB extra RSS, the BUG-141 teardown class (unset the wakeup before `mpv_terminate_destroy`). Keep as the fallback if the FFmpeg path trips on a container it cannot open.
3. **AVAssetImageGenerator.** Hardware decode, `maximumSize` 320, generous `requestedTimeTolerance` for keyframe speed. MP4/MOV only; MKV never; HLS UNVERIFIED. Use as the fast path when the stream `filename` ends in .mp4/.mov.
4. **Server-provided trick-play** (Plex BIF, Jellyfin tiles, HLS I-frame playlists). Zero decode cost, but Stremio addon streams carry no thumbnail field (`stream.md`: url/ytId/infoHash/fileIdx/subtitles/behaviorHints only) and Real-Debrid/TorBox/Premiumize serve raw byte-range links. Two ports work around that: bobsupra's `TrickplayResolver` tries an addon-supplied trickplay URL first, then a **community storyboard server** that its own `TrickplayUploader` feeds with 10-column sprite sheets; peden88 pulls **Seekr** thumbnails and runs `SeekrFrameCalibration` (three anchors, ±3 s window, similarity 0.56) because a shared storyboard was cut from a different release than the file playing. A community pool is a product decision with privacy and moderation costs; the calibration trick is worth copying if we ever consume one. Not worth parsers until a source we trust appears.

### 6.4 Preview on the native engine: write an I-frame playlist

AVKit draws its own scrub thumbnails and powers FF/RW scan from an `EXT-X-I-FRAME-STREAM-INF` rendition. The remuxer already indexes every keyframe (the Cues walk feeding `SegmentMap`) and writes the fMP4 segments, so `LocalHLSServer` can serve an `EXT-X-I-FRAMES-ONLY` media playlist whose entries are `EXT-X-BYTERANGE`s of the moof+mdat bytes around each keyframe sample. This needs a spike (one afternoon): confirm AVKit accepts fMP4 byte-range I-frame entries served from loopback, and whether it waits for the whole playlist or tolerates `EXT-X-ENDLIST` arriving as the remux frontier advances. If it works, the native engine gets previews with no decoder work at all, and the mpv thumbnailer's cache can reuse the same keyframe index. One caveat from `RemuxSession.swift:16-21`: MKV Cues are often a sparse subset of the real keyframes, so an I-frame playlist built from the up-front `SegmentMap` would offer one frame per segment; finer previews need the remuxer to record every keyframe it actually writes as it goes, which it can do for free since it cuts fragments on them.

### 6.5 Data shape

One `SeekPreviewStore` actor shared by both engines: `thumbnail(at: TimeInterval) -> CGImage?` (nearest keyframe within ±GOP), `prewarm(every: 10 s)` running at idle priority while playing, LRU of ~200 thumbs (≈ 35 MB at 320 × 180 BGRA, or ~6 MB as JPEG-compressed `CGImage`s), keyed by stream identity digest (the same digest the rejected-link memory uses), dropped on exit.

---

## 7. Feature suggestions, tiered

Effort: S = a day, M = two to four days with a device pass, L = a batch.

### Tier A: table stakes the field has and NuvioTV lacks

| # | Feature | Engine | Effort | Notes |
|---|---|---|---|---|
| A1 | Swipe scrub + preview playhead + two-stage commit (§6.1–6.2) | mpv | M | Hardware-only verification; Developer knobs for the velocity curve |
| A2 | Seek preview thumbnails via FFmpeg keyframe decoder (§6.3) | mpv | L | Reuse `MediaProbe`/`RemuxSession` patterns; filmstrip pre-warm as the second step |
| A3 | I-frame playlist in the loopback HLS (§6.4) | native | M (after a spike) | Also improves the system FF/RW scan |
| A4 | AVPlayer-grammar transport bar (§5) | mpv | M | Buffered fill, chapter ticks, end time, focusable pills, hide rules |
| A5 | Hold-to-scan 2×/3×/4× replacing the step ramp | mpv | S | `speed` + mute during scan |
| A6 | Chapters: ticks on the bar, chapter skip on edge press (setting, Infuse grammar), Chapters tab in the panel | mpv now, native via `AVNavigationMarkersGroup` | M | mpv `chapter-list`; native needs the remuxer to read MKV Chapters and feed `navigationMarkerGroups` |
| A7 | Aspect modes Fit / Fill / Zoom / Stretch | both | S–M | mpv `video-aspect-override`, `video-zoom`, `panscan`; native `videoGravity`; wire the synced `resizeMode` |
| A8 | Playback tab on the native engine | native | M | `customInfoViewControllers` for Episodes and Sources, `speeds` for the system pill, `transportBarCustomMenuItems` for Sources/Episodes shortcuts |
| A9 | Native subtitles follow the app's style | native | S | `AVTextStyleRule` from `SubtitleStyleState` (colour, size, outline, background, bold) |
| A10 | Buffered/cache bar | mpv | S | `demuxer-cache-state.seekable-ranges`; merge gaps by ~5 s of film (Orivio's lesson: a percentage merge made the bar lie) |
| A11 | Preview-then-commit held seek | mpv | S | Keep the 10/20/30/60 table, accumulate a preview playhead, commit once on release (every Nuvio port does this; ours seeks per step). Can ship before A1 |
| A12 | Harvest-from-decode thumbnail store | mpv | M | §6.3 option 0; `screenshot-raw` every ~10 s into the shared store; the first half of A2 and useful on its own for Continue Watching cards |

### Tier B: polish seen in one or more leaders

| # | Feature | Engine | Effort | Notes |
|---|---|---|---|---|
| B1 | Rewind on Resume (0–30 s, default 0) | both | S | Plex; one setting, applied in `computeResumePosition` and the native resume seek |
| B2 | Up-next countdown length + Passout Protection (stop autoplay after N h) | both | S | Plex; extends "Still watching?" |
| B3 | Skip chip auto-hides after 10 s, returns on a click | both | S | Max |
| B4 | Stepped skip escalation on repeated edge presses (10 s → 30 s → 1 m → 3 m) as an alternative to the hold scan | mpv | S | Kodi; a setting next to the chapter-skip toggle |
| B5 | Persist mpv audio delay per title (like subtitle delay) | mpv | S | `MPVPlaybackTab.swift:58` admits it |
| B6 | Loading overlay with poster/logo + "Preparing…" line, sharing the Detail artwork | both | S | `showLoadingOverlay` already syncs; replaces the bare spinner |
| B7 | Visual up-next card (poster, title, countdown ring) instead of the caption chip | both | M | Upstream `NextEpisodeCard.kt` shape; keep Menu-dismiss and the rider rules |
| B8 | In-player error chip "Trying another source…" and a manual "Try next" when auto flows end | both | S | Already a logged follow-up from the Orivio batch |
| B9 | Clock and end-time on the bar | both | S | Stremio, system |
| B10 | Volume boost and dialogue enhancement | mpv | M | `volume-max=200` + a Boost pill; "Night mode"/dialogue via `--af=lavfi=[dynaudnorm]` or `loudnorm`; centre-mix gain via `pan`. Native: cannot reach Enhance Dialogue (no public API, noted at `PlayerAudioTab.swift:6`) |
| B11 | Secondary preferred audio/subtitle language in Settings | both | S | Shared fields exist, tvOS never exposes them |
| B12 | In-player subtitle style panel (size, position, colour steppers) | mpv | M | Upstream `SubtitleStylePanel.kt`; the Subtitles tab grows a Style row |
| B13 | Manual subtitle search in the Subtitles tab (query by title, pick a language) | both | M | Already fetches addon subtitles; add a search field and language filter; VLC/Kodi/Stremio have it |
| B14 | Hide other languages in the subtitle list (the "only preferred" filter already exists on native as `allowedSubtitleOptionLanguages`) | mpv | S | Stremio |
| B15 | Sleep timer (15/30/60/90 min, end of episode) | both | S | Plex; pauses and shows the post-play screen |
| B16 | Pause card on native | native | S | Setting is labelled "(mpv player)" today |
| B17 | Late addon subtitles on native | native | M | Re-serve the master and reselect, or hold the master until the subtitle search settles with a cap |
| B18 | Playback decision log row in Stream Info (why this engine, why this source, DV/Atmos preflight) | both | S | Orivio; the router already produces the label |
| B19 | Automatic subtitle sync (fixed-offset check, then affine retime) + "Sync Line" (pick a cue to align) | both | M–L | Official ATV `autosync/AutomaticSubtitleSync.kt`; the retime lives in `shared/` and feeds the existing delay path; no Apple TV port has it yet |
| B20 | Audio amplification (0–10 dB) and centre-mix / dialogue gain | mpv | S | Official ATV audio overlay; mpv `volume-max` + `af=pan`/`lavfi` (merges with B10) |
| B21 | Engine switch button on the failure alert ("Try mpv" / "Try native") with the mpv failure cause | both | S | Official ATV 0.9.1 and vatax3; we failover silently today, the alert only offers the next source |
| B22 | Post-play recommendations (More Like This row on the end screen) | both | M | Official ATV, bobsupra, peden88, Web; `PostPlayView` already exists on mpv, native has none |
| B23 | Remember playback speed per show | both | S | Official ATV 0.8.10; keyed like the subtitle delay |
| B24 | Loading overlay status line ("Resolving link · Connecting · Buffering 38 %") | both | S | Official ATV `loading-status`; pairs with B6 |
| B25 | Switch engine from the panel while playing (same position) | both | S | vatax3's "switch engine" row; the native → mpv fallback path at the same position already exists (`Coordinator:1280-1302`) |

### Tier C: distinctive

| # | Feature | Engine | Effort | Notes |
|---|---|---|---|---|
| C1 | Jog-ring fine scrub on the 2nd-gen remote | mpv | M | GameController absolute dpad; Infuse and the system do it |
| C2 | Frame step while paused (Left/Right = one frame) | mpv | S | `frame-step` / `frame-back-step`; a film-nerd feature Infuse lacks |
| C3 | Picture controls (brightness/contrast/saturation/gamma) and deband/interpolation toggles | mpv | S | Shared iOS video settings already sync; mpv properties exist; interpolation needs `video-sync=display-resample` and is heavy on a fanless box, keep it off by default |
| C4 | Deinterlace toggle | mpv | S | `deinterlace=auto` default, manual on/off for TS sources |
| C5 | A-B loop | mpv | S | `ab-loop`; niche, language learners and rewatchers |
| C6 | Bookmarks (save a position with a frame, list in the panel) | both | M | Kodi; pairs naturally with the thumbnail store |
| C7 | Parental guide overlay in the player | both | S | Shared `showParentalGuide`; upstream `ParentalGuideOverlay.kt` |
| C8 | IntroDB submission from the player ("mark intro start/end") | both | M | Upstream `SubmitIntroDialog.kt`; shared `introSubmitEnabled` |
| C9 | Audio passthrough investigation | mpv | spike | AC3/EAC3 already pass through on native via the remux; on mpv, `audio-spdif=ac3,eac3` through `ao=avfoundation` is UNVERIFIED on tvOS. Worth a one-afternoon probe because Atmos survives only as EAC3-JOC today |
| C10 | PiP on native | native | S | `allowsPictureInPicturePlayback` defaults true; confirm it works through the loopback HLS and expose a pill; mpv PiP would need a sample-buffer bridge (Orivio's private bridge), skip |
| C11 | "Who's in this scene" (InSight-like) | both | L | TMDB cast only, no per-scene data; a cast strip on the pause card is the honest version, Orivio and the official app have it; bobsupra's Scene panel adds songs |
| C12 | Peek bar on a light touch (times only, no chrome) | mpv | S | bobsupra `PlayerViewModel.swift:3557`; a resting finger shows elapsed/remaining without raising the bar |
| C13 | Fine-tune wheel: hold, then circle the ring at 24 s per revolution in a ±20 s window | mpv | M | Orivio `:6782-6803`; the GameController route from C1, scoped to a window so it never races the scrub |
| C14 | Multi-provider skip segments with confidence merging | both | M | peden88 merges SkipMe.db / IntroDB / TheIntroDB / PublicMetaDB / MovieHavenDB / VideoSkip / NotScare; we have IntroDB + AniSkip; each extra provider is a shared-side fetch |
| C15 | AI subtitle translation in-player | both | L | bobsupra (Gemini / OpenRouter, batched); needs a key, a cost story and a privacy note; park unless asked |
| C16 | Report playback issue (one code on screen, log bundle attached) | both | M | Official ATV and peden88; would shortcut the tester DM loop that costs us a photo per bug |
| C17 | OLED idle dim / screensaver in the player | both | S | peden88 `ScreensaverController.kt`; pairs with the OLED True Black setting |
| C18 | Secondary simultaneous subtitle track | mpv | M | AetherEngine exposes it; mpv `secondary-sid` + `secondary-sub-visibility`; language learners |

---

## 8. Suggested sequencing

Batch P1 (one rc): A4 + A11 + A5 + A10 + B9 + B3 + B5 + B21. The chrome, preview-then-commit on the held arrow, the scan, the cache bar, times, the chip auto-hide, delay persistence, the engine button on the failure alert. No new decoders; a device pass on the Living Room ATV for the hide rules and focus.

Batch P2 (one rc): A1 + A7 + A6-mpv + A12. Swipe scrub with the preview playhead and the two-stage commit, aspect modes, chapters on mpv, and the harvest-from-decode store so the scrub already shows frames for everything watched so far. The scrub velocity constants (Orivio's and bobsupra's curves) go behind Developer knobs for one rc so Steven's hand can tune them.

Batch P3 (spike first, then one rc): A3 spike on the I-frame playlist; A2 FFmpeg thumbnailer behind a Developer toggle with the filmstrip pre-warm as a second step, sharing the P2 store. Measure RSS and the debrid connection count on hardware before the toggle defaults on.

Batch P4 (one rc): A8 + A9 + B16 + B17 for the native engine, so both engines reach parity on panels and subtitles.

Batch P5 (one rc, the "ahead of the other ports" batch): B19 subtitle auto-sync, B20 amplification + centre-mix, B22 post-play recommendations, B23 per-show speed. None of the Apple TV ports has these four; the official app has all of them.

Then the rest of Tier B in whatever order tester feedback orders them; Tier C opportunistically.

Risks to carry into every plan doc: the simulator cannot swipe (hardware-only verification for every gesture); Apple TV 4K memory with a second decoder (cap thumbs at 320 px, LRU, tear down on exit, the BUG-141 teardown pattern); debrid per-link connection limits (prefer the FFmpeg decoder over a second mpv handle, and reuse one connection for the filmstrip); libmpv first-responder hand-back when focusable pills enter the overlay (`:1904`); `target-colorspace-hint` is not an Apple HDR path, HDR stays on the main Metal layer and thumbs are SDR tone-mapped.

Upstream-report candidates from this research: the Compose player's `showHorizontalSeekPreview` has the same "no thumbnail source" limitation; the shared `resizeMode` and `holdToSpeed` settings sync to tvOS with no consumer (documentation note rather than a bug).

---

## 9. Sources

Apple: AVPlayerViewController, `contextualActions`, `customInfoViewControllers`, `infoViewActions`, `skippingBehavior`, `requiresLinearPlayback`, `speeds`, `AVNavigationMarkersGroup`, `AVInterstitialTimeRange`, `AVDisplayManager`, `AVAssetImageGenerator` reference pages; "Customizing the tvOS playback experience"; WWDC21 10191, WWDC22 10147, Tech Talk 503, WWDC21 10161 (EDR); Apple Support HT210525 (Siri Remote controls) and the tvOS 26 TV app guide; HIG Remotes; developer forum threads 651497, 722171, 697194, 788398, 796922; tvOS 26 release coverage (9to5Mac, AppleInsider, MacStories).
mpv: `DOCS/man/options.rst` and `input.rst` at master; po5/thumbfast `thumbfast.lua`.
Apps: Firecore playback-controls article 215090987, release notes, Infuse 8.4 blog, Match Content thread 17441; Plex "Player Experience" forum post, Apple TV settings article, 9to5Mac 2025-01-22, video preview thumbnails article, "New Player on the Apple TV" thread; jellyfin/Swiftfin README and `Documentation/players.md`; Kodi wiki Video playback + Keyboard controls; VideoLAN VLC Apple TV press page, MacStories first impressions; Emby 2.1.6 release and the tvOS preview-scrub thread; Max help 000002510; TechCrunch on YouTube Most Replayed; AlternativeTo on Stremio Android TV 1.9.1 and the tvOS IPA; prehakanson-art/OrivioTVAppleTV README; `docs/research/orivio-tv-handoff.md` §7.9–7.10; Roku BIF spec; stremio-addon-sdk `stream.md`; Brightcove and JW Player tvOS SDK docs; dcordero.me on circular Siri Remote gestures; shaybc/VLCTester; Swiftfin issues #799 and #1005.
Nuvio ports (shallow clones at the heads listed in §3b, read-only): `NuvioMedia/NuvioTV` (`ui/screens/player/`, `core/player/`, `data/local/PlayerSettingsDataStore.kt`, and the GitHub release notes 0.7.15-beta → 1.1.0-beta.4), `NuvioMedia/NuvioWeb` (`js/core/player/`), `bobsupra/NuvioTVOS` (`tvosApp/NuvioTV/Sources/Core/Player/`, `UI/Player/`, `ViewModels/PlayerViewModel.swift`, `Vendor/AetherEngine`), `vatax3/NuvioTVOS` and `cb541/NuvioTVOS` (`Sources/Features/Player/`), `peden88/NuvioTV` (player-package diff against the official app), `prehakanson-art/OrivioTVAppleTV` (`OrivioTV/Player/FusionPlayerControlsOverlay.swift`, `PlayerViewModel.swift`, `ScrubThumbnailer.swift`), `superuser404notfound/AetherEngine` (README, `docs/api.md`, `docs/formats.md`). Fusion/Omni/Vidi: troypoint.com/fusion-media-center; alternativeto.net/software/omni--content-hub; apps.apple.com/app/id6648776878 (Vidi); community.firecore.com thread 54685; r/RealDebrid search excerpts (1icckhe, 1shghiw).
Local: `MPVPlayerView.swift`, `NativePlayerScreen.swift`, `NativePlaybackCoordinator.swift`, `PlayerEngineRouter.swift`, `Player/*`, `MediaProbe.swift`, `RemuxSession.swift`, `SegmentMap.swift`, `MPVKit/Package.swift`, `shared/.../PlayerSettingsRepository.kt`, `docs/beta-feedback-tracker.md`, `docs/orivio-feature-comparison-2026-10-01.md`, `docs/nuviotv-android-feature-gap.md` (2026-07-02, the earlier official-app gap pass).

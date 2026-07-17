# NuvioTV Hybrid Player Plan — True Dolby Vision + MKV

**Status:** planned, not started · **Written:** 2026-07-15
**Goal:** play Dolby Vision HDR content with *true DV output* on Apple TV 4K **and** keep broad MKV/codec compatibility, by adding a native AVPlayer path alongside the existing MPVKit player.

---

## 0. Why a hybrid

No single engine can satisfy both hard requirements:

- **True DV output only happens through Apple's media pipeline.** tvOS 17.2+ plays DV Profile 5 and single-layer Profile 8.1 natively via AVPlayer (fMP4/HLS, `hvc1`/`dvh1` tagging + `dvvC` box). libmpv can only *tone-map* DV via libplacebo — the Apple TV never switches into Dolby Vision output mode, and mpv upstream confirms no open-source player can drive the native DV pipeline ([mpv #12993](https://github.com/mpv-player/mpv/issues/12993)).
- **AVPlayer cannot open MKV.** The proven workaround — used by Infuse, and replicated by KSPlayer's paid tier and VidHub in late 2025 ([KSPlayer #875](https://github.com/kingslay/KSPlayer/issues/875)) — is an on-device FFmpeg **stream-copy remux** (no re-encode): demux the MKV, emit fMP4 fragments, serve them to AVPlayer as local HLS over a loopback HTTP server.

So: **AVPlayer fed by a local remux for DV-eligible (and generally native-friendly) content; the existing MPV player as universal fallback for everything else.** Historical note: [tvos-port-plan.md](tvos-port-plan.md) §4.5 originally specified AVPlayer as the primary tvOS player with MPV as an enhancement — this work realizes that intent with the routing inverted only where AVPlayer genuinely can't play the file.

A major implementation shortcut discovered during scouting: the local MPVKit package (`NuvioMobile/MPVKit`) already ships full FFmpeg xcframeworks **with umbrella modulemaps** — `import Libavformat`, `import Libavcodec`, and `import Libdovi` work from app Swift code today, with zero package changes. The probe, remux, and P7→8.1 RPU conversion layers need **no new dependencies**.

---

## 1. Architecture overview

Routing happens once per playback start, on the resolved URL, before any player UI commitment:

```
Play request (PlaybackContext)
├─ "Native player for Dolby Vision" setting off → MPV (today's behavior)
├─ Cheap pre-filter (StreamBehaviorHints.notWebReady, parsed codec/hdr strings)
│     → obvious MPV cases skip the probe entirely
├─ Probe URL with avformat (~1–2 s typical, hard 4 s timeout; failure or
│  non-seekable source → MPV)
│    container ∈ {mkv, mp4, mov, webm-family}?        no → MPV
│    video: HEVC DV P5 / P8.1 ───────────────┐
│           HEVC DV P7 (RPU→8.1 convert, Ph5)│ yes → candidate
│           HEVC HDR10/SDR, H.264 ───────────┘
│           anything else (VP9/AV1/VC1/interlaced) → MPV
│    audio (selected/default track):
│           AAC/AC3/EAC3(+JOC Atmos)/FLAC/ALAC/MP3 → passthrough
│           TrueHD/DTS → Phase 4: v1 MPV, v2 transcode → AAC 5.1
│           other → MPV
│    subs:  user needs embedded bitmap subs (PGS/VobSub) → MPV
│           text subs (SRT/ASS embedded, external SubtitleFile) → native overlay
├─ NATIVE PATH: RemuxSession (stream-copy → fMP4 fragments)
│               → LocalHLSServer (127.0.0.1, random port, token path)
│               → AVPlayer / NativePlayerScreen
└─ Any native-path error, pre- or mid-playback
                → fallback: reopen same PlaybackContext in MPV at last position
```

### Components

| Component | File (new unless noted) | Role |
|---|---|---|
| `PlaybackModels` | `NuvioTV/Screens/PlaybackModels.swift` | `PlaybackContext`, `SubtitleFile`, `PlayerTrack`, `SkipSegment`, `SkipPrompt`, `StreamInfoSnapshot`, `PlayerTuning` — extracted from MPVPlayerView.swift |
| `PlayerScreen` (dispatcher) | `NuvioTV/Screens/PlayerScreen.swift` | Single entry point for all call sites; probes, routes, presents the chosen engine, owns fallback |
| `MediaProbe` | `NuvioTV/Screens/MediaProbe.swift` | avformat wrapper: container, codecs, DV config, HDR metadata, tracks, duration, seekability, keyframe index |
| `PlayerEngineRouter` | `NuvioTV/Screens/PlayerEngineRouter.swift` | Pure `route(probe:settings:) → EngineDecision` with human-readable reason; unit-testable |
| `RemuxSession` | `NuvioTV/Screens/RemuxSession.swift` | FFmpeg demux → per-segment fMP4 mux (stream copy), timestamp rebasing, read-ahead, segment cache |
| `LocalHLSServer` | `NuvioTV/Screens/LocalHLSServer.swift` | NWListener loopback HTTP server serving playlist/init/segments (pattern from `RemoteSetupServer.swift`) |
| `NativePlayerScreen` | grows out of existing `NuvioTV/Screens/PlayerView.swift` | AVPlayerViewController + overlays, full feature parity |
| `PlaybackProgressRecorder` + skip helpers | extracted from MPVPlayerView.swift | Engine-agnostic watch-progress / Trakt / skip-segment logic shared by both engines |

### Existing seams (verified in code)

- All playback today goes through `MPVPlayerScreen` in [MPVPlayerView.swift](../NuvioMobile/iosApp/NuvioTV/Screens/MPVPlayerView.swift) (~1,790 lines). Call sites: `StreamPickerView.swift:191`, `LibraryView.swift:88`, `CloudLibraryUI.swift:83`, `NextEpisodeAutoPlay.swift:181` and `:436`.
- The natural engine seams already exist: `PlaybackContext` (engine input) and `MPVPlaybackState` (UI-facing observable output). No engine protocol exists yet.
- A vestigial, unreferenced AVPlayer wrapper lives in [PlayerView.swift](../NuvioMobile/iosApp/NuvioTV/Screens/PlayerView.swift) (36 lines; declares `PlayerScreen` — the dispatcher takes over that name). AVPlayer is already proven in this target: the Detail-screen trailer player deliberately uses AVPlayer to avoid a second MoltenVK context.
- Pre-playback metadata for the cheap pre-filter: `StreamBehaviorHints` (`notWebReady`, `filename`) and `StreamClientResolveParsed` (`hdr`, `codec`, `audio`, `channels`) in `NuvioMobile/shared/src/commonMain/kotlin/com/nuvio/app/features/streams/StreamModels.kt`. These are parsed-from-title heuristics — helpful to skip the probe, never authoritative for routing *to* native.
- ATS is a non-issue: `NSAllowsArbitraryLoads = true` is already set in the NuvioTV Info.plist (don't "clean it up" — the local HLS server depends on cleartext loopback HTTP). Deployment target is tvOS 26, far above the 17.2 floor for DV 8.1 — no availability gating.
- Xcode project uses `fileSystemSynchronizedGroups`: new `.swift` files under `NuvioTV/` join the target automatically; no pbxproj surgery per phase.

### Shipped FFmpeg build constraints (read from the artifact's `config.h` — these shape the design)

- **No `hls` or `segment` muxer.** Present: `mov/mp4`, `mpegts`, `matroska`, `dash`. → fMP4 fragments come from the mov/mp4 muxer with custom AVIO; playlists are hand-written text (trivial, and we want control anyway).
- **No AC3/EAC3 encoders.** Present encoders: `aac`, `alac`, `flac`, `pcm*`, `*_videotoolbox`. TrueHD/DTS **decoders** are present. → v2 audio transcode target is AAC 5.1; EAC3 requires rebuilding MPVKit (Phase 4 v3 option).
- **All bitstream filters enabled** (incl. `dovi_rpu`, `hevc_metadata`, `hevc_mp4toannexb`), all protocols enabled (http/https with range seek — the JIT segmenter depends on this).
- `Libdovi.xcframework` (dovi_tool's C API) ships in the package — the P7→8.1 backstop is already linked.

---

## 2. Design decisions

**D1 — Local HTTP server, not `AVAssetResourceLoaderDelegate`.**
*Why:* the resource-loader delegate only fires for custom-scheme URLs; with HLS that forces every playlist *and* media segment through the delegate, which Apple has stated is unsupported for media-segment delivery, and it defeats CoreMedia's pipelined range loading. Every proven implementation (Infuse per KSPlayer #875, VidHub, AetherEngine) serves real HTTP on loopback.
*How:* reuse the NWListener HTTP/1.1 pattern from [RemoteSetupServer.swift](../NuvioMobile/iosApp/NuvioTV/Screens/RemoteSetupServer.swift), including its random-token path-prefix trick. Bind 127.0.0.1 only, random free port.
*Rejected:* resource loader (above); GCDWebServer/Swifter dependency (unneeded — the in-repo pattern suffices).

**D2 — VOD playlist with just-in-time segment generation.**
*Why:* duration and the keyframe index are knowable up-front (MKV Cues via avformat; fast index scan as fallback), so we can serve a complete `EXT-X-PLAYLIST-TYPE:VOD` playlist immediately: AVPlayer gets the real duration, a working scrubber, and instant seek-anywhere. A request for segment N seeks the demuxer to N's keyframe and emits one independent fragment. Sequential read-ahead of 2–3 segments; disk LRU cache in `Caches/`.
*Rejected:* EVENT/growing playlists — seeking past the remuxed point becomes a restart hack and the duration display is wrong. Exact per-segment durations go in the playlist (from the keyframe map); each fragment carries its own `tfdt` so HLS tolerates this fine. Target segment duration ~6 s (revisit with real-device data).

**D3 — fMP4 via the mov/mp4 muxer + hand-written playlists.** (Forced by the missing hls muxer, but the right call regardless.)
Init segment (`moov`) + independent fragments (`movflags`-style `frag_custom`/`dash`/`delay_moov` split) captured through a custom AVIO write callback into the segment cache. `hvc1` codec tag; attach `AVDOVIDecoderConfigurationRecord` stream side data so movenc writes the `dvvC` box (verify whether n8.1.2 still needs `strict=unofficial` — carry the `ffmpeg -tag:v dvh1 -strict unofficial` reference). Playlist `CODECS` per the Apple HLS Authoring Spec: P5 `dvh1.05.xx`; P8.1 `hvc1...` plus `SUPPLEMENTAL-CODECS` DV cross-compatibility signaling.

**D4 — One audio track per remux session; track switch = session rebuild.**
Probe lists every track; the existing track-picker UI shows them all; picking a different audio track tears down the RemuxSession and rebuilds it with the new stream index, resuming at the current position (sub-second on a warm loopback connection — this is Infuse's behavior).
*Rejected:* muxing all audio tracks as HLS alternate renditions — N parallel segment pipelines for no user-visible gain.

**D5 — App-rendered subtitle overlay for v1, not WEBVTT renditions.**
External `SubtitleFile`s (SRT/VTT from addons) are downloaded, parsed to cues, and rendered by a SwiftUI overlay synced via `addPeriodicTimeObserver`. Embedded MKV *text* subs (SRT/ASS) are extracted at probe/remux time and fed to the same overlay.
*Why:* WEBVTT renditions require segmented VTT with `X-TIMESTAMP-MAP` alignment, and AVPlayer's built-in rendering obeys system accessibility styling — breaking parity with the app's KMP-synced subtitle-style settings that libass honors today. Bitmap subs (PGS/VobSub) are a routing criterion → MPV.

**D6 — Conservative, observable routing.**
Native path only when *every* box checks; anything ambiguous → MPV, which plays everything today. The Stream Info overlay gains an "Engine" row: `Native (DV P8.1)` / `mpv (reason: DTS audio)`. The whole feature sits behind a new `PlayerTuning.nativeDVKey` (`"player.nativeDolbyVision"`) UserDefaults flag with a Settings > Playback toggle — **"Native player for Dolby Vision (beta)", default off** until DV output is verified on at least two TV brands. Device-local, un-synced, matching the existing `PlayerTuning` convention.

**D7 — Fallback restores position through the existing progress flow.**
The MPV controller already resumes from `WatchProgressRepository` (gated at >10 s). On native-path failure: flush progress via the shared recorder, then the dispatcher re-presents MPV for the *same* `PlaybackContext` with a `resumeOverrideSec` parameter (dispatcher-level, not on PlaybackContext) to cover the <10 s gate and same-tick races. Max one fallback per context id; never native→native.

---

## 3. Phased milestones

Each phase is independently shippable and leaves MPV playback untouched until Phase 3 flips the switch.

### Phase 0 — Player abstraction + feature flag (pure refactor, zero behavior change)

1. Create `Screens/PlaybackModels.swift`; move `PlaybackContext`, `SubtitleFile`, `PlayerTrack`, `SkipSegment`, `SkipPrompt`, `StreamInfoSnapshot`, `PlayerTuning` out of MPVPlayerView.swift (currently lines ~11–88; nothing depends on their location).
2. Create `Screens/PlayerScreen.swift`: dispatcher `PlayerScreen(context:onPlayNext:)` — for now it just returns `MPVPlayerScreen`. Delete the vestigial AVPlayer wrapper bodies in the old `PlayerView.swift` (unreferenced — confirmed) so the dispatcher owns the `PlayerScreen` name; the file itself is regrown in Phase 3.
3. Update the five call sites (`StreamPickerView.swift:191`, `LibraryView.swift:88`, `CloudLibraryUI.swift:83`, `NextEpisodeAutoPlay.swift:181/:436`) to present `PlayerScreen`. Keep `.id(ctx.id)` / `.ignoresSafeArea()` at the call sites — fresh-controller-per-context applies to both engines.
4. Extract engine-agnostic helpers from the MPV controller: `PlaybackProgressRecorder` (the `WatchProgressPlaybackSession` construction + `saveProgress` logic, ~lines 746–800) and the skip-segment fetch (`fetchSkipSegments`, ~line 649).
5. Settings: add the "Native player for Dolby Vision (beta)" toggle next to the Enhanced Video Renderer row (`SettingsView.swift:74–110` pattern + `SettingsViewModel`).

**Ship test:** MPV playback byte-for-byte identical; toggle visible but inert.

### Phase 1 — Stream prober + router (still plays via MPV)

1. `Screens/MediaProbe.swift` — `import Libavformat` / `Libavcodec`. `avformat_open_input` on the resolved URL with tight probe limits; extract: container, video codec + profile, **DV configuration** (`AV_PKT_DATA_DOVI_CONF` stream side data → profile/level, `el_present_flag`, `rpu_present_flag`, `bl_present_flag`), HDR10 mastering metadata, all audio tracks (codec/channels/language), subtitle tracks (text vs bitmap), duration, source seekability, and the **keyframe/Cues index** (persisted for Phase 2's segment map).
2. `Screens/PlayerEngineRouter.swift` — pure `route(probe:settings:) → EngineDecision { engine, reason }`. Unit tests on canned `ProbeResult`s (this is the highest-value test surface in the project).
3. Wire into the dispatcher behind the flag: probe runs on a utility queue with a hard ~4 s timeout (timeout → MPV, never block the fullScreenCover presentation), the decision is **logged and shown in the Stream Info overlay**, but playback still goes to MPV.

**Ship test:** flag on → Stream Info shows "would route: Native (DV P8.1)" etc.; zero playback risk.

### Phase 2 — Remux engine + local HLS server (headless)

1. `Screens/RemuxSession.swift` — owns the demuxer context and a per-segment mov/mp4 muxer. Produces: init segment (`moov`, `hvc1`/`dvh1` tag, `dvvC`), independent fragments at the Phase 1 keyframe-map boundaries, timestamp rebasing per fragment (`baseMediaDecodeTime` = segment start), custom AVIO sinks into an in-memory + disk segment cache, background read-ahead worker (2–3 segments), seek = re-open demuxer at target keyframe.
2. `Screens/LocalHLSServer.swift` — NWListener on 127.0.0.1: `/{token}/media.m3u8`, `/{token}/init.mp4`, `/{token}/seg{N}.m4s`. Segment requests block (with timeout) on RemuxSession producing that segment. Content-Types: `application/vnd.apple.mpegurl`, `video/mp4`, `video/iso.segment`.
3. Pitfalls to handle: source servers without HTTP range support (probe detects → MPV); dts/pts discontinuities in sloppy MKVs; audio priming/edit lists when the audio track's first packet precedes the video keyframe (start audio ≤ segment start; rely on `tfdt`); server lifecycle tied to the player view controller (tvOS suspension tears everything down — recreate by re-entering playback); `Caches/` LRU cap (~2 GB, revisit).

**Ship test:** no UI change. Verify emitted output with `curl` + `ffprobe` on segments + **Apple's `mediastreamvalidator`** (the gold standard); a debug-only hook plays a known MKV through a bare AVPlayer.

### Phase 3 — NativePlayerScreen (feature parity — the switch flips here)

1. Grow `PlayerView.swift` into `NativePlayerScreen`: `AVPlayerViewController` (free tvOS transport UI, scrubbing, Now Playing) with `customOverlayViewController`/`contentOverlayView` overlays for: skip-intro pill, up-next card (reuse `NextEpisodeEngine` — already a separate `@StateObject`), subtitle overlay (D5), track picker (audio via D4 session rebuild; subs via overlay), stream-info overlay (probe data + `AVPlayerItemAccessLog` bitrate), progress recording + Trakt scrobbling via the Phase 0 helpers.
2. Map the MPV screen's bespoke remote affordances (up = tracks, down = up-next) onto the native controller.
3. Flip the dispatcher: flag on + router says native → `NativePlayerScreen`.

**Ship test:** parity checklist vs the MPV screen (resume, progress save cadence, skip intro, autoplay, track picking, stream info, post-play).

### Phase 4 — Audio strategy

- **v1 (shipped with Phase 3):** TrueHD / DTS / DTS-HD → router sends to MPV. Reason: no E/AC3 encoder in the shipped binaries; decode-to-PCM via MPV is today's behavior anyway.
- **v2 (DONE, 2026-07-16):** `AudioTranscoder.swift` — decode (`truehd`/`dca`) → swresample downmix/resample → native `aac` encoder (AAC-LC 5.1-back for 6+ ch, stereo/mono below; >48 kHz halves to 48/44.1k; 384/192/96 kbps), muxed alongside the copied video, chosen only when the file has NO stream-copyable audio track. One transcoder per seek-anywhere run (fresh decoder/swr/fifo/encoder after every reposition; the run's muxer takes codecpar from the encoder — GLOBAL_HEADER gives movenc the AudioSpecificConfig for esds). Audio pts = run anchor (first decoded frame mapped onto the playlist origin) + output-sample counting; defensive nonneg/monotonic dts clamp absorbs encoder priming. Sim-validated end to end (TrueHD 5.1 + DTS 5.1 MKVs: readyToPlay, full play-through, exact 40.0s audio duration, seek-into-hole repositions transcode cleanly). **DEVICE-VALIDATED 2026-07-16 night (tvOS 27, Apple TV 4K): a real DTS-HD MA 7.1 BluRay remux plays natively with AAC 5.1, user-confirmed perfect A/V sync through far-forward and backward-into-hole scrubs (fresh transcoder per reposition); process footprint flat ~375 MB.** Field fixes that testing surfaced: the Cues-priming gate (prime on any too-sparse index, not just <2 entries — probing deposits 3-6 entries on remux-bitrate files, which silently defeated priming and sent every tail-Cues remux to mpv) and the stream-picker badge-image OOM (AsyncImage full-res decodes; now a per-URL downsampled cache). Loses lossless/Atmos — by design; picture (true DV) wins.
- **v3 (optional, big):** rebuild MPVKit binaries with `--enable-encoder=ac3,eac3 --enable-muxer=hls` — EAC3 keeps a bitstream AV receivers treat as Dolby (and simplifies D3). Means owning the MPVKit build pipeline (`NuvioMobile/MPVKit/Makefile`) instead of consuming upstream release artifacts. Decide only if v2's AAC 5.1 proves unsatisfying.

### Phase 5 — DV Profile 7 → 8.1 + hardening

1. P7 detection in probe (`el_present_flag` / dual-layer). In RemuxSession: drop EL NALs (`nuh_layer_id > 0` / unspec63), extract RPU NALs (unspec62), convert P7 RPU → 8.1 — **first choice** FFmpeg's `dovi_rpu` bsf if n8.1.2 supports conversion (verify; it may only strip), **else** the shipped libdovi C API (`dovi_parse_unspec62_nalu` → `dovi_convert_rpu_with_mode(2)` → `dovi_write_rpu`) — reinsert, retag `dvvC` as profile 8.1.
2. MEL vs FEL: MEL conversion is visually lossless; FEL discards real enhancement data (same tradeoff Infuse takes). Default: FEL routes native (DV badge over last-percent fidelity) with a sub-setting to prefer MPV.
3. Hardening: classify native-path errors (server 5xx, `AVPlayerItem.status == .failed`, stall watchdog: N stalls in M seconds) → single `fallbackToMPV(at:)`; cache eviction; routing telemetry polish.

---

## 4. Fallback & error strategy

- **Pre-playback** (probe failure/timeout, router says no): silent MPV — user sees exactly today's behavior.
- **Mid-playback** (item failed, stall watchdog, segment production error): flush progress via `PlaybackProgressRecorder` → dispatcher re-presents MPV with `resumeOverrideSec` → one-line toast "Switched to compatibility player".
- Never fall back native→native; max one fallback per context id (no loops).
- Audio session: MPV activates `.playback` on start; the fallback path must not deactivate the session between engines.

---

## 5. Testing & verification

### Sample-file matrix

| File | Expected engine | Expected output |
|---|---|---|
| DV P5 MKV (HEVC, EAC3) | Native | DV badge on TV |
| DV P8.1 MKV (dovi_tool-made) | Native | DV badge |
| DV P7 MEL MKV | MPV until Phase 5, then Native | HDR10 → DV after Ph5 |
| DV P7 FEL MKV | MPV until Phase 5, then Native (setting-dependent) | HDR10 → DV after Ph5 |
| HDR10 HEVC MKV | Native | HDR10 |
| H.264 + AC3 MKV | Native | SDR, AC3 passthrough |
| EAC3-JOC (Atmos) MKV | Native | Atmos lit on receiver |
| TrueHD Atmos MKV | Native + AAC 5.1 (v2) | AAC 5.1 (Atmos lost) |
| DTS-HD MA MKV | Native + AAC 5.1 (v2) | AAC 5.1 |
| FLAC audio MKV | Native (FLAC→ALAC/passthrough per probe) | lossless |
| PGS subs needed | MPV | bitmap subs render |
| External SRT | Native | overlay subs |
| Non-seekable HTTP source | MPV | plays |
| Sloppy-mux MKV (bad dts) | Native attempt → fallback | ends on MPV, position kept |

### DV engagement verification (device + TV only)

- The TV's own info panel / "Dolby Vision" badge is ground truth.
- tvOS Developer HUD (Settings > Developer) for pipeline confirmation.
- Check interplay with the Apple TV "Match Dynamic Range" setting and the app's frame-rate-match option (`PlayerTuning.matchFrameRateKey`).
- Verify on ≥2 TV brands before defaulting the flag on.

### Simulator limits

Probe, router, remux, and server are all simulator/unit testable (router unit tests on canned ProbeResults; `curl` against the local server; `ffprobe`/`mediastreamvalidator` on emitted artifacts from a Mac). DV output verification is hardware-only — precedent: `enhancedRenderer`/libplacebo is already device-only in this codebase.

---

## 6. Risks & open questions

- **movenc DV boxes on n8.1.2:** does writing `dvvC` still require `strict=unofficial`? Verify in the first Phase 2 spike.
- **`dovi_rpu` bsf capability:** conversion P7→8.1 or strip-only on FFmpeg 8.1? Determines Phase 5 effort; libdovi backstop is confirmed shipping in the package either way.
- **JIT segment latency** on high-bitrate remuxes over slow sources → AVPlayer stall behavior; tune read-ahead and segment duration with real devices.
- **Audio-session handoff** between engines during mid-stream fallback.
- **Licensing:** the app links the LGPL `MPVKit` product (verified in project.pbxproj; the GPL product in the manifest is unused), but the shipped binaries self-report `--enable-nonfree` in their FFmpeg config (openssl-linked MPVKit default). Pre-existing, unrelated to this feature — recorded here for App Store diligence. Going through AVPlayer means Apple covers DV/Atmos licensing (no Dolby fees).
- **Defaulted decisions to revisit before Phases 4–5:** v2 transcode target AAC 5.1 (EAC3 only via MPVKit rebuild — is receiver bitstream worth owning the build pipeline?); P7 FEL default routing (native/DV badge vs MPV/fidelity); ~6 s segments and ~2 GB cache cap.

---

## 7. References

- KSPlayer #875 — reverse-engineered write-up of the Infuse approach (FFmpeg demux → local HLS → AVPlayer with DV intact): https://github.com/kingslay/KSPlayer/issues/875
- AetherEngine — open-source (LGPL) reference implementation of FFmpeg→VideoToolbox→native-DV on Apple platforms; very young project, treat as reference not dependency: https://github.com/superuser404notfound/AetherEngine
- mpv cannot drive native DV output: https://github.com/mpv-player/mpv/issues/12993 · https://github.com/mpv-player/mpv/issues/11308
- Swiftfin player capability matrix (the cautionary two-engines-no-remux tale): https://github.com/jellyfin/Swiftfin/blob/main/Documentation/players.md
- Apple HLS Authoring Specification — DV `CODECS`/`SUPPLEMENTAL-CODECS` sections; `mediastreamvalidator` tooling
- Apple: Incorporating HDR video with Dolby Vision: https://developer.apple.com/av-foundation/Incorporating-HDR-video-with-Dolby-Vision-into-your-apps.pdf
- tvOS 17.2 added DV Profile 8.1 playback: https://community.firecore.com/t/tvos-17-and-dolby-vision-8-1/43133
- Infuse DV P7/P8 behavior thread: https://community.firecore.com/t/dolby-vision-profile-7-8-support-ts-mkv-files/19713
- dovi_tool / libdovi (shipped as `Libdovi.xcframework` in the MPVKit package): https://github.com/quietvoid/dovi_tool
- FFmpeg DV tagging reference: `ffmpeg -c:v copy -tag:v dvh1 -strict unofficial`
- MPVKit build pipeline (for the Phase 4 v3 rebuild option): `NuvioMobile/MPVKit/Makefile`

## Field findings — device debugging, 2026-07-16 (tvOS 27 beta, Apple TV 4K 3rd gen)

Established by elimination on the physical device, each step evidence-backed (console request log,
served-playlist dumps, pulled remux artifacts, remote AVPlayer probe rig):

1. **Source defects the remux must repair** (all implemented): missing/non-monotonic video DTS
   (regenerate wholesale on a uniform grid, −6 frames reorder slack), High-tier hvcC declarations
   (patch record to Main tier), empty extradata (recover via extract_extradata BSF), TARGETDURATION
   violations from long GOPs (serve-time repair), empty-at-open playlists (gate on non-empty).
2. ~~tvOS 27 rejects a master carrying `VIDEO-RANGE=PQ` at parse time~~ **CORRECTED (2026-07-16
   evening, remote device A/B): `VIDEO-RANGE` is REQUIRED on tvOS 27 for PQ/HDR content.** PQ media
   behind a master that does NOT declare it is rejected at media admission (-12927 right after the
   first segment fetch — the failure long misattributed to EVENT-join/mux structure); the same media
   plays when the master declares `VIDEO-RANGE=PQ` alongside full RFC 6381 CODECS +
   SUPPLEMENTAL-CODECS + RESOLUTION + FRAME-RATE (device-validated, incl. against Apple's
   `adv_dv_atmos` reference stream). Note a bare-`hvc1` master WITH `VIDEO-RANGE=PQ` fails at master
   parse (-1002) — the declaration needs the full codec context. The original "rejects at parse"
   observation came from the confounded EVENT-era test matrix. Also device-validated the same
   evening: the owned-segmenter VOD+JIT output (muxed A/V, no styp, synthesized playlists) plays
   as-is with SDR content — the -12927 was never about the container/mux structure.
3. **The remaining blocker: EVENT-playlist join.** The device plays the remuxed media behind a
   master when playlists are VOD (ENDLIST present) and fails (-12927, right after the first segment
   fetch) when they are EVENT/growing — in every combination of codecs/audio/segment-count (≥3
   completed segments enforced). Decision D2's original design (complete VOD playlist up front,
   segments produced/served just-in-time) is therefore REQUIRED on tvOS 27, not an optimization.
   Remux speed for debrid sources ≈ download speed (can be ≈ realtime), so waiting for remux
   completion is not a substitute for long content.

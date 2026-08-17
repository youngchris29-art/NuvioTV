# Native (AVPlayer) player — tvOS-style swipe-down panel: Subtitles · Audio · Info

Drafted 2026-08-16. Target: the native `AVPlayerViewController` screen
(`NuvioMobile/iosApp/NuvioTV/Screens/NativePlayerScreen.swift`), i.e. the engine chosen by
`PlayerEngineRouter` when Settings → Playback → "Native player for Dolby Vision (beta)" is ON
(HEVC/H.264 in MKV/MP4 with copyable/transcodable audio → native; everything else → mpv). The mpv
screen keeps its own swipe-up panel (BUG-3) and is out of scope here.

Reference UX: the system tvOS player panel (Christian's photo: Info · Subtitles · Audio tabs;
Subtitles = language list + Off; Audio = LANGUAGE column, SOUND column, HEADPHONES/SPEAKERS
output routing).

---

> **2026-08-17 addendum — tvOS 26 reality (supersedes §0's premise).** Christian's device clip of
> the W1–W3 build showed that **tvOS 26's `AVPlayerViewController` has no swipe-down tabbed panel
> at all**: a `customInfoViewControllers` tab renders as a bottom-left **"Info" pill under the seek
> bar** whose content expands above the transport bar, and Subtitles/Audio are transport-bar
> popover buttons. The sim "rendering no tabs" (§5e) was that same reality, not a sim quirk. The
> W1–W3 *plumbing* (embedded WebVTT renditions, demuxed audio renditions, language plan) is all
> still load-bearing — it now feeds an **app-drawn Infuse-style top panel** instead (W5b, §5f).

## 0. Where we actually are (this changes the shape of the work)

The swipe-down panel **already exists** on the native screen — it's `AVPlayerViewController`'s own
panel — so this is not "build a panel", it's "make the three tabs carry the right things". Today:

| Tab | Today | Gap vs. the ask |
|---|---|---|
| **Info** (system) | Empty-ish: `AVPlayerItem.externalMetadata` is never set (no title/artwork/description). | Should show title (+ S/E), poster, synopsis. |
| **Stream Info** (custom, `customInfoViewControllers`, `NativePlayerScreen.swift:195`) | Router decision, CODECS/DV/range, resolution·fps, audio, segment map, bandwidth, access-log stats (`NativePlaybackCoordinator.streamInfoRows`, `:503`). Refreshed on ticks. | This *is* the "stream info button" content. Keep; possibly merge with Info (see §3). |
| **Subtitles** (system) | Lists **addon subtitles** (OpenSubtitles etc.) + stream-attached files, because polish batch 2 (D5) already turns them into `EXT-X-MEDIA TYPE=SUBTITLES` WebVTT renditions in the synthesized master (`SegmentMap.masterPlaylist`, `SegmentMap.swift:163`; served JIT by `LocalHLSServer.serveSubtitle`, `:310`). "Off" is native. | ✗ **Embedded text subtitles from the MKV are dropped** (`RemuxSession.swift:244` walks video+audio only). ✗ Preferred subtitle language from Settings → Playback is **not applied** on the native path (mpv applies it; native leaves `AUTOSELECT=YES` to tvOS system prefs). |
| **Audio** (system) | Shows exactly one language (the muxed track: URI-less `EXT-X-MEDIA TYPE=AUDIO`) + the SOUND / output-routing columns. Alternate tracks live in a **transport-bar "Audio" `UIMenu`** (`NativePlayerScreen.swift:232`) that rebuilds the whole remux session on pick (D4). | ✗ Other tracks aren't in the panel's LANGUAGE list. ✗ Preferred audio language not applied. |

Also note: "audio tracks from addons" — addons don't supply audio tracks (only subtitles + streams);
the audio list is the file's tracks (`RemuxSession.audioTracks`, `RemuxSession.swift:163`).

Everything below therefore feeds the *system* panel rather than replacing it. That is the cheapest
route AND the only one that gives the exact tvOS look (output routing, AirPods, accessibility
styling come for free — you can't rebuild those in SwiftUI).

---

## 1. Subtitles tab

### 1a. Embedded subtitle tracks (MKV/MP4 text subs) — the big piece
Goal: SRT/ASS/SSA/mov_text/WebVTT tracks inside the file appear in the Subtitles tab alongside addon
subs, labelled by language/title.

Why it can't reuse the addon approach: addon subs are whole files, so a single-segment VOD VTT
works. Embedded subs are interleaved with the video clusters — the only way to get them is the demux
pass the remux worker is already doing, which produces them progressively. So they must be
**segmented WebVTT renditions** aligned to the existing segment map (the exact thing D5 originally
rejected — correct for addon files, wrong for embedded tracks).

Design:
- `RemuxSession` gains N "subtitle sinks": for every text-subtitle stream (skip bitmap PGS/VobSub —
  those already route the file to mpv via the probe), collect decoded cues (`avcodec` subtitle
  decode → `AVSubtitle` text; ASS → strip override tags with the existing `SubtitleVTT` cleaner)
  and, at each segment boundary (`SegmentMap` keyframe cuts, `SegmentMap.swift`), emit
  `sub-eN/seg-K.vtt` = `WEBVTT` + `X-TIMESTAMP-MAP=MPEGTS:…,LOCAL:00:00:00.000` + the cues that
  intersect [segStart, segEnd) (repeat cues that span a boundary; times mapped onto the playlist
  origin exactly like video pts).
- `LocalHLSServer`: serve `sub-eN.m3u8` (media playlist with one entry per segment, same
  `EXT-X-TARGETDURATION` / MEDIA-SEQUENCE as `media.m3u8`) and `sub-eN/seg-K.vtt` with the same
  "block until produced / on-demand seek" semantics video segments use. Empty segments serve a
  header-only VTT (valid).
- `SegmentMap.masterPlaylist`: append embedded renditions to the `subs` group with
  `NAME=<title or localized language>`, `LANGUAGE=<iso>`, `CHARACTERISTICS` for SDH/forced where the
  MKV flags say so (`forced`/`hearing_impaired` dispositions → `FORCED=YES` / `public.accessibility.describes-music-and-sound`).
- `MediaProbe` already lists subtitle streams (`MediaProbe.swift:41` `SubtitleStreamInfo`, populated
  `:132`) but **`PlayerEngineRouter` never reads `p.subtitles`** — a PGS-only BluRay remux goes native
  today and its subs are silently dropped. Do **not** start routing those to mpv (nearly every UHD
  remux carries PGS; that would gut the DV path). Instead: emit text tracks only, and add a Stream
  Info row "Bitmap subtitles: N (PGS/VobSub — not shown by the native player; use mpv)" so the
  omission is explained. Bitmap-to-native is a possible later item (PGS → `IMSC`/bitmap-in-VTT is not
  something AVPlayer accepts; would need OCR or an overlay — out of scope).
- Seek-ahead: AVPlayer only requests sub segments around the playhead; the reader repositions for
  video anyway, so cue collection restarts from the seek point — same rules as audio.
- Cap/labels: reuse `SubtitleVTT.renditions` dedupe/unique-name logic so "English" ×3 (embedded +
  two addon files) become distinguishable ("English · Embedded", "English · OpenSubtitles").

Effort: **M–L** (the largest item; ~2 days incl. sim smoke). Risk: medium — touches the remux
writer but not the DV-validated video path (new sinks, no change to the video/audio muxer).

### 1b. Apply the app's subtitle preferences (Settings → Playback → Preferred Subtitle Language)
- Resolve the target language list with the **same shared KMP helpers mpv uses**
  (`PlayerLanguagePreferencesKt.resolvePreferredSubtitleLanguageTargets` / `…AudioLanguageTargets`,
  `DeviceLanguagePreferences.shared.preferredLanguageCodes()` — see `MPVPlayerView.swift:433–505`),
  so primary + `secondaryPreferred*Language` + "device"/"original" semantics stay identical across
  engines. Then `AVPlayer.setMediaSelectionCriteria(AVPlayerMediaSelectionCriteria(preferredLanguages: targets, mediaCharacteristics: …), forMediaCharacteristic: .legible)`
  (and `.audible`; the audible half is inert until §2A but harmless).
- `"none"` → empty criteria + master renditions `AUTOSELECT=NO` so tvOS doesn't auto-enable captions
  from system prefs; a real language → best match gets `AUTOSELECT=YES` (+ `DEFAULT=YES` if we want
  mpv-parity "starts on").
- `SubtitleStyleState.useForcedSubtitles` → `FORCED=YES` renditions + `.legible` criteria with
  `public.subtitles.forced-only`; `showOnlyPreferredLanguages` → `AVPlayerViewController.allowedSubtitleOptionLanguages`
  (currently unused anywhere in the repo) so the tab lists only the preferred languages.
- Effort: **S–M** (half a day + sim checks).

### 1c. "Turn subtitles on/off"
Native "Off" row already exists in the tab. Nothing to build; verify it survives the D4 rebuild path
(it does today via `pendingSubtitleName`, `NativePlaybackCoordinator.swift:62`) — becomes moot if §2A
lands (no rebuilds).

### 1d. Late-arriving addon subtitles
The master is rendered once; subs arriving after the gate lapses are invisible
(`NativePlaybackCoordinator.swift:214–231`). Not part of the ask, but the panel will make it visible.
Cheap mitigation: bump the gate when the fetch is still `searching…`, or log-only. Decide in review.

---

## 2. Audio tab — two ways to get all tracks into the LANGUAGE column

### 2A (recommended) — Demuxed alternate audio renditions, one demux pass
Make the master the standard Apple shape: **video-only variant + `AUDIO="aud"` group with one
`EXT-X-MEDIA` per playable track, each with a URI** (`aud-N.m3u8`). The system Audio tab then lists
every language natively, switching is instant and seamless (no "Switching Audio…" spinner, no
session teardown, subtitle selection is untouched), and `preferredAudioLanguage` works via
`setMediaSelectionCriteria(.audible)`.

Design:
- `RemuxSession`: split the single muxed writer into a **video muxer** (unchanged pipeline, drops
  the audio stream) + an **audio muxer** for the *currently requested* track producing audio-only
  fMP4 segments on the same segment map (`aud-N/init.mp4`, `aud-N/seg-K.m4s`). Same demux reader,
  so bandwidth is unchanged. Transcode path (TrueHD/DTS → AAC via `AudioTranscoder`) plugs into the
  audio muxer as today.
- Track switch = the reader is told "audio stream index := M" and re-positions to the segment
  AVPlayer next asks for (reuse the existing seek/on-demand-production machinery); the video segment
  cache stays valid. Only the *selected* track's pipeline runs at any time (this keeps D4's
  "no N parallel pipelines" rationale intact — D4 rejected muxing *all* tracks eagerly, not lazy
  demuxed renditions).
- `LocalHLSServer`: serve `aud-N.m3u8` / segments with block-until-produced; requests for a
  non-active track trigger the switch. Guard against AVPlayer probing multiple renditions at start
  (only produce for the rendition it actually plays; a probe of `aud-M.m3u8` alone must not flip the
  active track — flip on the first *segment* request).
- `SegmentMap.masterPlaylist`: `CODECS` still lists video + the selected audio codec token; per-track
  `EXT-X-MEDIA` with `NAME`/`LANGUAGE`/`CHANNELS="6"`, `DEFAULT=YES` on the preferred one. Unplayable
  tracks (PCM) are simply omitted (today they're shown-disabled in the UIMenu; the Stream Info tab
  can keep the count so the omission is explained).
- Delete the transport-bar `UIMenu` and the D4 rebuild (`selectAudioTrack`, `pendingSubtitleName`,
  `pendingResumeSec` carry-over) once green — or keep the rebuild as a fallback if the demuxed
  form is rejected on some TV (see risk).
- Effort: **L** (~3–4 days incl. sim smoke + a device pass). Risk: **medium-high** — this changes the
  device-validated DV master shape from muxed to demuxed. Mitigations: demuxed A/V is Apple's own
  reference shape (their DV streams are demuxed), keep the video muxer byte-identical, and keep the
  `signalingAttempt` retry ladder; add a `debug.remuxSmokeDemuxedAudio` knob to A/B the muxed form
  during rollout. Sim can validate H.264/HDR10 fixtures; **DV engagement must be re-verified on the
  Living Room Apple TV** (the sim rejects PQ masters).

### 2B (fallback / stopgap) — Custom "Audio Track" tab
A second `customInfoViewControllers` tab (SwiftUI list: language · codec · layout · title,
checkmark on active, disabled rows for unplayable) driving the existing D4 rebuild. **S** effort
(half a day), zero remux risk — but the system Audio tab still exists showing one language, so the
panel has two audio-ish tabs and switching still shows the spinner. Only worth doing if 2A slips a
beta and we want the tracks reachable from the panel now.

**Recommendation:** commit to 2A; ship 2B only if 2A misses the target beta.

---

## 3. Info tab

- Populate `AVPlayerItem.externalMetadata` (`AVMetadataItem`s: `commonIdentifierTitle`,
  `iTunesMetadataTrackSubTitle` = "S1 · E4 · Episode name", `commonIdentifierDescription` = synopsis,
  `commonIdentifierArtwork` = poster via `ArtworkStore`, `quickTimeMetadataGenre`/year if cheap).
  `PlaybackContext` already carries title/streamSubtitle (`PlaybackModels.swift:41`); synopsis/poster
  come from the detail meta the dispatcher has. This also fixes Now Playing / Control Center. **S**.
- Keep the stream rows. Two options, decided by a 30-min sim spike: **does the system Info tab
  disappear when `externalMetadata` is empty?**
  - If it does → rename our custom tab to **"Info"**, give it a header (poster, title, S/E line,
    synopsis) above the existing rows → exactly three tabs: Info · Subtitles · Audio, matching the
    ask 1:1.
  - If it doesn't → populate the system Info tab (above) and keep ours as **"Stream Info"** (four
    tabs). Either way the stream rows must update their self-explanations:
    "switch via the Audio menu in the transport bar" (`NativePlaybackCoordinator.swift:525`) →
    "N tracks — choose in the Audio tab"; add an "Embedded subtitles: N" row next to
    "Addon subtitles"; add "Subtitle: <selected or Off>" and "Audio: <selected>" rows read from
    `currentMediaSelection`.
- Info-tab layout stays HIG-plain (system panel = system typography); no design-system chrome
  needed — the panel is Apple's, per `docs/design/hig-hybrid-contract.md`. While in there, move
  `NativeStreamInfoView` (`NativePlayerScreen.swift:261–268`) off raw `.font(.callout)`/`.secondary`
  onto `Theme.Font.*` / `Theme.Palette.text*` tokens (pre-existing contract deviation).
- Implementation note: `AVPlayerContainer.updateUIViewController` gates reinstalls behind
  `context.coordinator.actionsSignature` (`NativePlayerScreen.swift:207–212`) — any new per-update
  state (allowed languages, tab set) must join that signature or be set once in `makeUIViewController`,
  or the transport bar re-animates every SwiftUI tick.

Also fix the stale section of `docs/tvos-hybrid-player-plan.md` (Phase 3 at `:143` and D5 at
`:99–101` still describe an app-rendered subtitle overlay / `customOverlayViewController` that were
superseded by the WebVTT-rendition approach) so the two plan docs agree.

---

## 4. Waves (file-ownership split, one build at a time)

| Wave | Items | Files | Effort |
|---|---|---|---|
| **W0 spike** (main session) | Info-tab hide/show behaviour with empty metadata; confirm AVPlayer accepts a demuxed master from `LocalHLSServer` with a video-only variant (H.264 fixture, sim); confirm subtitle segment `X-TIMESTAMP-MAP` cues render from a synthetic 3-segment VTT playlist. | throwaway probes under `debug.avplayerProbeURL` | ½ day |
| **W1 ✅ 2026-08-16** | §3 Info tab (rename "Stream Info" → "Info", poster/title/S·E/synopsis header, updated stream rows — no `externalMetadata`, per spike 1); ~~native engine default-ON~~ → **moved to W2's commit** (`UserDefaults.register(defaults: [PlayerTuning.nativeDVKey: true])` at launch so `SettingsViewModel`/`PlayerScreen` `bool(forKey:)` reads flip together; toggle label loses "(beta)"; Settings copy + l10n); §1b/§2 media-selection criteria from `PlayerSettingsRepository` (audible criteria inert until W3 but harmless); AUTOSELECT/DEFAULT rules in `masterPlaylist`. | `NativePlayerScreen.swift`, `NativePlaybackCoordinator.swift`, `SegmentMap.swift`, `PlayerScreen.swift` (pass meta) | 1 day |
| **W2 ✅ 2026-08-16** | §1a embedded subtitle sinks + segmented VTT serving + master renditions + probe/router check; **+ the native default-ON flip** (register defaults, label, l10n) — same commit, so no build ships default-ON without embedded subs. | `RemuxSession.swift`, `LocalHLSServer.swift`, `SegmentMap.swift`, `SubtitleVTT.swift`, `MediaProbe.swift` | 2 days |
| **W3 ✅ 2026-08-17** | §2A demuxed audio renditions; remove UIMenu + D4 rebuild (behind the smoke knob first). | `RemuxSession.swift`, `LocalHLSServer.swift`, `SegmentMap.swift`, `NativePlaybackCoordinator.swift`, `NativePlayerScreen.swift`, `RemuxSmokeTest.swift` | 3–4 days |
| **W4** | l10n of new strings (fr/es/de/it/vi via the xcstrings scripts), Codex review → fix → re-review, README + screenshot (release script enforces), tracker/plan entries. | `Localizable.xcstrings`, docs | ½ day |

W2 and W3 both touch `RemuxSession`/`LocalHLSServer` → **serial**, W2 first (smaller, and its
segment-aligned sink pattern is what W3's audio muxer copies).

---

## 5. Verification

- **Sim (headless, existing rig — `Screens/RemuxSmokeTest.swift`, DEBUG-only, drives a real
  `NativePlaybackCoordinator`; trigger via `simctl spawn … defaults write com.nuvio.media.NuvioTV debug.remuxSmokeURL …`
  then `simctl launch --console-pty`):** `debug.remuxSmokeURL` + `debug.remuxSmokeSubURL` fixtures;
  add a two-audio + embedded-SRT MKV fixture (mkvmerge); extend `RemuxSmokeTest` with: legible
  group lists embedded + addon renditions; selecting an embedded rendition yields cues at the right
  playlist times (read `AVPlayerItem.currentMediaSelection` + probe served VTT via loopback curl);
  audible group lists all playable tracks; selecting the second track switches within <2 s with no
  item replacement (`playerItem` identity unchanged, position continuous); preferred-language
  settings pick the expected default for both. Repurpose `debug.remuxSmokeAudioSwitchSec` to drive
  the media-selection switch instead of the rebuild.
- **UI harness:** none of the 31 `NuvioTVUITests` drive the video player today; add nothing there
  for W1–W3 (headless smoke is the right layer). ⚠️ the tvOS 27.0 runtime never reports `hasFocus` — existence-driven checks only
  (see memory `tvos-ui-sim-verification`). Panel-open via XCUIRemote swipe-down is unreliable in
  the sim (D-pad ≠ swipe); assert on the served playlists + media-selection state instead, and take
  a screenshot with the panel opened by `.menu` long-press if it works on 27.0.
- **Device (manual, irreducible):** DV P8.1/P7 title with the demuxed master (DOLBY VISION badge
  still lights), Audio tab lists all languages and switches seamlessly, Subtitles tab shows embedded
  + addon entries and renders cues, Info tab shows poster/title/synopsis, AirPods routing column
  unaffected. Same Living Room Apple TV pass as beta.13's checklist.
- **Codex gate** after W1–W3 each (`codex-companion.mjs review --wait`, direct + unsandboxed).

---

## 5b. W0 spike results (2026-08-16, tvOS 26.5 sim `FA87E9B6`, Debug build)

All three questions answered YES; no design change needed.

1. **System Info tab hides when `externalMetadata` is empty — CONFIRMED.** Headed native player
   (`debug.mpvSmokeURL` + `player.nativeDolbyVision=YES` on the H.264 MKV fixture), Down press:
   the panel shows **only** our "Stream Info" tab (screenshot `scratchpad/s1_panel.png`). In the sim
   Subtitles/Audio tabs are also absent with a single audio rendition and no subs (on device the
   Audio tab still exists for output routing). ⇒ Three tabs = rename our tab "Info" + header; do
   NOT set `externalMetadata` (that would resurrect the system Info tab and make four).
   Now Playing metadata can still be set via `MPNowPlayingInfoCenter` if wanted (separate from the
   panel).
2. **Demuxed master accepted (2A shape) — CONFIRMED.** Static package (`fixtures/hls/master.m3u8`:
   video-only variant, `AUDIO="group_aud"` with eng DEFAULT + fra, both URI'd, fMP4) via the probe
   loop with the new `debug.avplayerProbeSelections=1`: `READY`, `audible options: English[eng],
   French[fra]`, `select(French)` → `selected=true pos 2.1→6.0 rate=1.0` (no item replacement,
   continuous playback), two rounds identical. Server request trail: AVPlayer **never requested
   `var_fra.m3u8` until the switch**, then pulled `init_fra.mp4` + `s_fra_000…` starting at the
   segment containing the playhead. ⇒ lazy per-rendition production is safe: a media-playlist
   request for a non-active track IS the switch signal (no probe-of-all-renditions problem), and the
   audio pipeline must (re)start at the playhead's segment.
3. **Segmented WebVTT renders — CONFIRMED.** Hand-made `sub.m3u8` (5×4 s `sub_K.vtt`, each with
   `X-TIMESTAMP-MAP=MPEGTS:0,LOCAL:00:00:00.000`, boundary-spanning cues repeated): `legible
   options: English[en]`, `AVPlayerItemLegibleOutput` delivered cues at 0.9 s / 4.9 s / 10.9 s for
   cues starting 1 / 5 / 11 s (delivered ~100 ms early — normal), fetched lazily only after
   selection. ⇒ W2's sink shape is right.

Rig left in place for W1–W3: `scratchpad/range_server.py 8000 fixtures/` (Range + HLS MIME +
`/report`), fixtures `test2a-sub.mkv` (19 s), `long2a-sub.mkv` (180 s, H.264 + eng/fra AAC +
embedded SRT), `hls/` static package. `RemuxSmokeTest.swift` gained
`debug.avplayerProbeSelections` (kept — permanent rig, DEBUG-only).

## 5c. W1 — BUILT + sim-verified + Codex-gated 2026-08-16 (uncommitted, 15 files, +611/−65)

**Landed:**
- **Info tab** (`NativePlayerScreen.swift`): custom tab renamed "Info"; header = poster/episode
  still · title · "S1 · E4 · <stream label>" · 2-line synopsis, then the live rows in a
  **two-column non-lazy `Grid`** (AVPlayerViewController sizes the panel from the hosted SwiftUI
  content's *measured* height — a `ScrollView`/`LazyVGrid` measures short and the panel clips the
  bottom rows; `preferredContentSize` is ignored). Theme tokens throughout. Screenshot:
  `scratchpad/w1_panel8.png` — all 11 rows + header visible.
- **Header data plumbing**: `PlaybackContext.synopsis` + `episodeStill` (kept apart from `poster`,
  which the progress recorder persists as the *series* poster — Codex caught a still leaking into
  it); `StreamPickerView(poster:episodeStill:synopsis:)` fed from Detail (primary + series
  Play/Resume via `SeriesPlayRoute.episodeStill/synopsis`), EpisodesSection, Home continue-watching
  (`episodeThumbnail`/`pauseDescription`), next-episode autoplay (next episode's own still/overview
  only, never the previous episode's). Blank Kotlin strings count as missing everywhere.
- **Rows** (`NativePlaybackCoordinator.streamInfoRows`): + "Subtitles: <selected|Off>" from
  `currentMediaSelection`; + "Embedded subtitles: N text · not yet offered natively" /
  "Bitmap subtitles: N PGS/VobSub · not shown natively" from the new
  `RemuxSession.subtitleTracks` inventory (`RemuxSubtitleTrack`, `isTextSubtitle` covers
  SRT/ASS/SSA/mov_text/WebVTT/TTML/MicroDVD/SAMI/SubViewer/MPL2/HDMV text/…); Bitrate row merges
  indicated + declared, Transferred merges stalls (panel fits 10–11 rows).
- **Language preferences on the native path** (`LanguagePlan`, resolved with the same shared KMP
  helpers mpv uses — `resolvePreferred*LanguageTargets`, `resolveSubtitleAutoSelectionPlan`):
  `setMediaSelectionCriteria` for `.audible`/`.legible` (forced-only ⇒
  `.containsOnlyForcedSubtitles`; shared plan nil ⇒ leave player defaults); master
  `AUTOSELECT/DEFAULT` per rendition (`SubtitleRenditionFlags` through `LocalHLSServer` →
  `SegmentMap.masterPlaylist`: subs off ⇒ all `AUTOSELECT=NO`; preferred ⇒ matches `AUTOSELECT=YES`,
  first match `DEFAULT=YES`); "Show only preferred languages" ⇒
  `allowedSubtitleOptionLanguages` (unfiltered preferred list); **initial audio track honours
  Preferred Audio Language** via `RemuxSession.Config.preferredAudioPicker` (Codex: the muxed
  stream carries one rendition, so criteria alone can't fix a wrong first pick); Off survives an
  audio-switch rebuild (`pendingSubtitleOff`); PREFERRED_ONLY / only-preferred filter addon subs at
  the source with the shared `filterAddonSubtitlesForSettings` (also applied on the mpv screen).
  Sim-verified headlessly: `subs=off` ⇒ `AUTOSELECT=NO`; `preferred_subtitle_language=en` ⇒
  `DEFAULT=YES,AUTOSELECT=YES` + AVPlayer selects it; `preferred_audio_language=fr` ⇒
  `[Remux] preferred-language audio pick → stream 2`, `fra *selected`.
- Harness: `MPVSmokeTest` context carries a synopsis + `debug.mpvSmokePosterURL` for header checks.

**Moved:** the **default-ON flip is deferred to the W2 commit** — Codex P1: an interim build with
default-ON but no embedded-subtitle renditions would lose captions on embedded-sub MKVs vs mpv.
Decision unchanged (beta.13 ships default-ON); only the commit ordering moved.

**Deliberately not done (Codex asks declined):** FAST_STARTUP addon-subtitle mode is NOT honoured
on tvOS — there is no manual subtitle-search action on either engine, so skipping the automatic
fetch would mean no addon subtitles at all (tried, reverted); primary "none" + secondary language
follows the shared resolver (= mpv screen behaviour: secondary auto-selects). **Follow-up logged:**
mpv picker doesn't filter *embedded* tracks under "Show only preferred languages" (pre-existing;
native will, via `allowedSubtitleOptionLanguages`, once W2 lands).

**Codex loop:** 14 rounds (`codex-companion review --wait`), findings fixed each round until the
remaining items were out-of-scope mpv-parity asks; last round's only finding is the follow-up above.

## 5d. W2 — BUILT + sim-verified + Codex-gated 2026-08-16

**Landed:** embedded text subtitle tracks are offered in the system Subtitles tab on the native path.
- `EmbeddedSubtitleSink` (new): one per text track (subrip/ass/ssa/mov_text/webvtt/ttml/…), fed by
  the remux worker's demux loop (`RemuxSession.runRemux` routes the stream's packets to it), decodes
  with libavcodec (`avcodec_decode_subtitle2` → ASS dialogue / plain text → `SubtitleVTT.vttCueText`),
  times cues from packet pts/duration (+ `start_display_time`, `end_display_time` fallbacks), and
  writes `esub-<sink>-NNNNN.vtt` when video segment N finalizes (`X-TIMESTAMP-MAP=MPEGTS:0`,
  absolute playlist times, boundary-spanning cues repeated, header-only files for empty segments).
  Reposition: pending cues cleared before the seek; packets read during the boundary scan are
  ingested (pre-roll). EOF writes the last segment. Tracks without a decoder are skipped
  (`subtitleSinkIndices`) so no rendition can point at files that never appear.
- `LocalHLSServer`: `esub-K.m3u8` (per-segment VOD playlist, `SegmentMap.embeddedSubtitlePlaylist`)
  and `esub-K-NNNNN.vtt` served through the video segments' JIT path (`segmentIndex` parses both
  names). `SubtitleRendition` gained `source: .remote(URL) | .embedded(sink:)`, `forced`,
  `hearingImpaired`; master gets `FORCED=YES` / SDH `CHARACTERISTICS`.
- Renditions: embedded first, then addon; names "English", "English (SDH)", "English (Forced)",
  "English · Commentary" (title used as-is when it starts with the language), deduped across both
  lists (`SubtitleVTT.embeddedRenditions`).
- Language plan: forced-only ⇒ DEFAULT only a forced match; normal ⇒ DEFAULT only a full (non-forced)
  match; **forced renditions are always AUTOSELECT=YES** (HLS requires it with FORCED=YES; forced
  tracks show per the player's rules — foreign dialogue — regardless of the subtitle preference,
  which is also mpv's default). Codex flip-flopped on this across rounds 1/3/4; decided, documented.
- Info row: "Embedded subtitles: N · in the Subtitles tab" (or "k of N" when a track had no decoder).
- **Native engine default-ON** landed here (`UserDefaults.register(defaults:)` in `NuvioTVApp.init`,
  toggle titled "Native player (Dolby Vision & HDR)").
- Harness: `RemuxSmokeTest` now logs the first cues AVPlayer renders for the selected subtitle.

**Sim-verified (tvOS 26.5, `test2a-sub.mkv` / `long2a-sub.mkv`):** `[Remux] embedded subtitle
sinks: 1 (#3→esub-0)`, legible group lists "English · Embedded English", AVPlayer requests
`esub-0.m3u8` + per-segment VTTs, all four cues render at 1/5/11/16 s, the 5–9 s cue appears in
both `esub-0-00001.vtt` and `esub-0-00002.vtt`; seeks (90 s, 30 s) and an audio-switch rebuild keep
the rendition (empty 52-byte segments, no 503s, selection restored). Not exercised: a mid-file
reposition on a source that hasn't remuxed to EOF (the 16 MB fixture finishes first) — device pass.

## 5e. W3 — BUILT + sim-verified + Codex-gated 2026-08-17

**Landed (2A):** the master is now Apple's demuxed shape — a **video-only variant + one `AUDIO`
rendition per playable source track** (`aud-<streamIndex>.m3u8`, `aud-<T>-init.mp4`,
`aud-<T>-NNNNN.m4s` on the same segment grid), `CODECS` = video + the union of the tracks' tokens,
`DEFAULT=YES` on the track production starts with (Preferred Audio Language pick), `CHANNELS`,
`LANGUAGE`, unique `NAME`s.
- `RemuxSession.runRemux`: each run drives **two muxers** (video-only, and the ACTIVE track's
  audio-only, copy or transcode) from one demux pass, both cut at the video keyframe boundaries;
  per-representation `SegmentWriter` init names; a run interrupted before its first fragment flush
  does NOT mark its init written (delay_moov). **Audio switch = a run boundary**:
  `selectAudio(streamIndex:atSegment:)` (mailbox + read-kick like a reposition; a segment-carrying
  switch also sets the reposition target so the JIT window covers it) → the worker ends the run and
  restarts at the requested segment on the new track; `activeAudioStream` is published. Empty audio
  window mid-stream ⇒ session failure ⇒ mpv fallback (not an invalid segment); only the final
  segment tolerates an empty audio window (KNOWN LIMITATION: zero-byte file — movenc can't emit a
  zero-sample fragment).
- `LocalHLSServer`: audio playlists/segments through the JIT path; a request for a non-active
  track's file switches the worker **only if that track is AVPlayer's current audible selection**
  (`selectedAudio` closure — stale requests for the old rendition can't ping-pong production).
- `NativePlaybackCoordinator`: relays AVPlayer's audible selection (media-selection notification
  **and** a per-tick check — the notification alone did not fire in the sim; the option is mapped
  to our track via its common-metadata title = rendition NAME, since `displayName` is the
  localized language) → `remux.selectAudio`; the D4 rebuild (`selectAudioTrack`,
  `pendingResumeSec`, subtitle carry-over) and the transport-bar Audio `UIMenu` are **gone**;
  audible criteria applied once per item (never re-applied after a manual pick); the subtitle
  selection is left alone on an audio switch (mpv parity: auto-select once). Retry item re-binds
  the observers. Info row: "Audio tracks: N · in the Audio tab".
- Harness: `debug.remuxSmokeAudioSwitchSec` now switches via media selection and reports
  selection/position/`remuxActive`; `debug.avplayerUIURL` presents a bare `AVPlayerViewController`
  (sim control); `NuvioTVUITests/InfoPanelProbeTests` (env-gated `TEST_RUNNER_INFO_PANEL_PROBE=1`)
  opens the panel via `XCUIRemote` — the reliable way to drive the panel in the sim.

**Sim-verified (tvOS 26.5):** demuxed master accepted; two-track fixture plays; **mid-run switch**
(throttled source, `[Remux] audio switch: abandoning segment 13 → audio track → stream 2 from
segment 13`) with a brief stall while the new track's init + first segment are produced (same cost
as the old rebuild), seeks before/after the switch, playback continuous on the new track; unthrottled:
switch at 93 s → 93.3→101.0 in 8 s at rate 1.0, `remuxActive=#2`, embedded subtitle cues still render.
**Sim caveat (important):** the tvOS simulator's `AVPlayerViewController` renders **no system panel
tabs at all** — not for our master and not for Apple's reference `bipbop_adv` stream (alternate
audio + subtitles); only `customInfoViewControllers` tabs appear. The Subtitles/Audio tabs and the
seamless switch UX are therefore **device-only verification** (Living Room Apple TV, plus DV
engagement on the demuxed master).

**Codex loop:** 6 rounds; fixed: init-written tracking, JIT window for switch targets, unique NAMEs,
selection-tied switching, criteria not re-applied after manual picks, mid-stream empty audio ⇒ fail,
retry-item rebinding. Round 6 clean.

## 5f. W5b — App-drawn swipe-down top panel + uniform chips — BUILT + sim-verified 2026-08-17

**Ask (Christian, 2026-08-17, from the device clip vs. Infuse):** no Info under the seek bar; a
swipe-down / D-pad-down top panel like Infuse with Info · Subtitles · Audio; Menu closes it; all
pop-up chips (Skip Intro/Recap/Outro, Next Episode) uniform and HIG. Decisions via AskUserQuestion:
Info · Subtitles · Audio in the custom panel; **keep the native transport-bar Subtitles/Audio
popovers** (Enhance Dialogue / Reduce Loud Sounds have NO public API — only `.moviePlayback`
session mode makes them eligible); native path first, mpv reuses the panel in a follow-up; chips =
`contextualActions` on native.

**W0 spike (sim 26.5, `FA87E9B6`) — ALL PASS:** a container VC (child = AVPlayerViewController)
with `UITapGestureRecognizer(allowedPressTypes: [.downArrow])` + `UISwipeGestureRecognizer(.down)`
on its view (delegate allows simultaneous recognition) sees the Down press whichever AVPVC view
holds focus; presenting a clear `.overFullScreen` `UIHostingController` gives focus containment
(Select hit the panel's buttons), Menu swallowed in its `pressesBegan` closes the panel and does NOT
pop the player, playback ticks continue underneath, Down while the transport bar is visible opens
the panel too (bar stays under it — accepted). No transport-bar flash on the hidden-controls path.

**Built (`Screens/Player/`):**
- `PlayerPanelHost.swift` — `NativePlayerHostController` (+ `onOpenPanel`/`onPanelClosed`,
  `present(panel:)`, `closePanel`), `PlayerPanelHostController<Content>` (Menu swallow, swipe-up
  close, `PlayerPanelPresenting`). `AVPlayerContainer` now wraps the host; `customInfoViewControllers`
  removed; `dismantleUIViewController` closes any open panel.
- `PlayerTopPanel.swift` — top-anchored glass panel; tab row = default tvOS `Button`s whose
  selection follows focus; **Up from a list re-lands on the CURRENT tab** (the focus engine would
  otherwise pick the geometrically nearest tab and silently switch — found by the probe);
  `PlayerPanelOptionRow` (checkmark rows, `.borderless`), `PlayerPanelSectionCaption`.
- `PlayerInfoTab.swift` — `NativeInfoHeader` (now "S3 · E2 · Episode name" from `context.episodes`,
  release name demoted to a caption) + metadata chip row + the 2-column rows (moved verbatim).
- `PlayerSubtitlesTab.swift` (Off first, embedded, addon; Forced/SDH details; scrolls with focus),
  `PlayerAudioTab.swift` (LANGUAGE column full-width so Down from the centred tab lands on it — not
  on the route picker; SPEAKERS & HEADPHONES column: route name + `AVRoutePickerView` + the
  Enhance-Dialogue pointer caption).
- `PlayerTopPanelModel.swift` (engine-agnostic), `NativePlayerPanelAdapter.swift` (Combine sinks on
  the coordinator's groups/`selectionVersion`/`audioTracks`, tick → rows/chips only when changed,
  AVAudioSession route name), `PlayerSwipeHint.swift` (1 s after readyToPlay for 4 s; again 1.5 s
  into a pause; hidden while the panel is open).
- `NativePlaybackCoordinator`: `legibleGroup`/`audibleGroup` published, `selectionVersion`,
  `subtitleRenditionsByName`, `isPaused` (KVO `timeControlStatus`), `select(subtitle:)`/`select(audio:)`
  (same `AVPlayerItem.select(_:in:)` path as the native popovers → the popover and the panel agree),
  `renditionName(of:)`, `subtitleOptionAllowed`, `infoChips()`.
- `PlaybackModels`: `PlaybackContext.meta: PlaybackMeta?` (year/runtime/imdbRating/ageRating/genres,
  threaded from `DetailView` through `StreamPickerView`) + `fileSizeBytes` (`behaviorHints.videoSize`).
- Chips: `PlayerChipStyle.swift` (`PlayerActionChip`, `PlayerChipCaption`, symbols, 0.25 s ease,
  `lastSecondExclusion`); native `UpNextCard` gone → static-title contextual actions ("Play Next
  Episode" / "Continue Watching", phase KIND in the signature, never the count) + caption above
  (`contextualActionClearance = 96`, device-tune); mpv `SkipPromptPill`/`UpNextCard` →
  `PlayerActionChip` + `PlayerChipCaption` (still D-pad-Down triggered, outro clamp kept).
- l10n: 10 keys × fr/es/de/it/vi (parity); pruned 5 dead keys; accessibility values are
  `Text(verbatim:)` so "selected" never enters the catalog.

**Sim probe (`NuvioTVUITests/PlayerTopPanelProbeTests`, `TEST_RUNNER_PLAYER_PANEL_PROBE=1`, app
pre-warmed via `debug.mpvSmokeURL` on `long2a-sub.mkv`):** PASS — Down opens on Info; Right →
Subtitles (Off + "English · Embedded English"); Down·Down·Select → row selected (`[NativePlayer]
subtitle selection → English · Embedded English`), Up·Select → Off; Up·Right → Audio; Down·Down·Select
→ French (`audio selection → stream 2 (French)`); Menu → panel gone, `player.native` still there;
Select (bar) → Down → opens again. Gotchas: an `accessibilityIdentifier` on a SwiftUI CONTAINER
overrides every descendant's id (took the tab ids with it) — only tag leaves; `xcodebuild test`
output is block-buffered when piped — run it under `script -q <log>` and read the log.

**Device pass (item 8 in the beta13 plan) still owed:** real swipes, glass over real video, route
picker sheet, Enhance Dialogue still in the native popover, chip/caption geometry on tvOS 26.

## 6. Decisions — CONFIRMED by Christian 2026-08-16: **2A** (native demuxed audio renditions),
## **three tabs** (fold stream rows under "Info"), **native engine default-ON**, **target beta.13**.
## W0 spike started 2026-08-16.

(original decision list kept for context)

1. **Audio: 2A (native demuxed renditions, L, touches the DV master) vs. 2B (custom tab, S)?**
   Recommendation: 2A.
2. **Info: three tabs (fold stream rows under "Info") or four (system Info + "Stream Info")?**
   Depends on the W0 spike; recommendation: three if the system tab can be suppressed.
3. **Scope reminder:** the native engine is still opt-in ("beta", default OFF, `PlayerTuning.nativeDVKey`).
   This work only reaches users who flip it. Worth deciding in the same beta whether the toggle
   flips to default-ON for non-DV HEVC/H.264 (router already accepts them) — separate item, but it
   decides how many people see the panel.
4. **Target beta:** beta.14 (beta.13 is mid-flight: Wave 3 device-only + Wave 4 l10n remain). W1+W2
   are safe to land behind the toggle; W3 wants a device pass before release.

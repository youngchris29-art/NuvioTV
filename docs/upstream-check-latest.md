# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-10-31
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `38295004e` — dated report `docs/upstream-port-plan-2026-10-31.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `fa194b008` — dated report `docs/nuviotv-android-upstream-port-plan-2026-10-31.md`

## NuvioMobile — 2026-10-31

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `10feb659a` (last plan, 2026-10-30) -> `38295004e`. 17 non-merge commits, 26 files (+1373/-206), **0 paths under `shared/` upstream** (all `composeApp`, `iosApp`, `MPVKit`, `store.json`). Fork tip checked: submodule `c99fc3247`+, outer `784e9bd`.
**New baseline: `38295004e`.**

## Candidates for the tvOS fork

1. **PORT (M, HIGH-MED) — Player badge accuracy: codec detection + filename matching** (`4fa138b3f`, `48363a413`, `668f36241`, `59e1218a8`, `4cb1323dc`; `PlaybackMatchText.kt`, `PlayerMediaInfo.kt`, `PlayerBadges.kt`, `StreamBadgeRules.kt`, test `PlaybackMatchTextTest.kt` +112).
   The fork already carries `PlaybackMatchText.kt`, `StreamBadgeRules.kt` (`StreamBadgeMatcher`) in `shared/` and the Swift consumers `Screens/Player/PlayerBadgeMatch.swift`, `MPVPlayerView.swift`, `NativePlaybackCoordinator.swift`. Upstream changes to take:
   - `audioProfile: String?` -> `audioProfiles: List<String>`; `audioTokens` matches across all profiles; adds AC-4 tokens, PCM and DTS codec labels; Dolby Vision no longer maps to HEVC tokens.
   - New `refinePlaybackText(decoderText, metaCandidates)`: adds Atmos / DTS-HD MA / DTS:X / HDR10+ when the filename or stream title confirms what the decoder cannot report.
   - New `StreamBadgeMatcher.matchedPlayerBadges(playback, meta, filters)` two-phase match with `groupId` on `CompiledStreamBadgeFilter` (a filename hit never overrides a playback hit in the same group); whitespace collapsed before regex.
   Steps: port the three `shared/` files + tests verbatim, `graphify explain "audioProfile"` for Swift/Kotlin bridge users (`audioProfile` becomes `audioProfiles`, bridged as a Swift array), feed the active stream filename/title from the Swift coordinator into the new call, regenerate SharedCore. Gates: jvmTest + tvosSimulatorArm64Test, unit tests, device pass in the Test profile on an MKV Atmos/DTS-HD MA file. No new setting; mention improved player badges in release notes.
2. **PORT (M, MED) — Chapter-derived skip intervals** (`06f08dd8c`, `8c7a9745c`, `a744911ac`, `1755d4833`; `ChapterSkipIntervals.kt` +131, `SkipIntroRepository.kt`, `PlayerScreenRuntimeChapters.kt`, tests `ChapterSkipIntervalsTest` +139, `MergeSkipIntervalsTest` +115). Same feature as the NuvioTV Android item below (identical code now landed in Mobile). `segmentCategory` moves from private to `internal` top-level in `SkipIntroRepository.kt`; IntroDB parsing rejects non-finite/negative start; Trakt-style types "new credits", "mixed intro", "mixed credits" map to `ed`/`mixed-op`/`mixed-ed`. Pure Kotlin: port the title matcher, `mergeSkipIntervals` and tests into `shared/.../player/skip/`, feed it the chapters mpv/AVPlayer already report (`NativePlaybackCoordinator.swift`, `PlaybackModels.swift`). Device pass on a chaptered MKV (Test profile). Effort 3-4 h incl. tests; the small `SkipIntroRepository` hardening (finite/negative check, extra type names) can land alone in 30 min.
3. **WATCH (S) — MPVKit PiP decoder recovery** (`e1d8759ff`; submodule pointer `bfeb6fcfa` -> `04579bd15`, "update MPVKit for PiP decoder recovery"). The fork pins its own MPVKit symlinked into clones; check whether the new commit touches VideoToolbox/decoder-reset code that also affects tvOS (tvOS has no PiP). Effort S (read the MPVKit diff), only bump if it contains decoder fixes.
4. **SKIP — Android-only**: `CustomDefaultTrackNameProvider.kt`, `PlayerEngine.android.kt` (track naming / engine), `SkipIntroButton.kt` one-liner (Compose button).
5. **SKIP — locale/store**: pt-BR (ASS render modes, chapters, subtitle-appearance groups), Slovak (new files incl. autosync, mdblist, party, servers), Vietnamese strings, `store.json`, `Version.xcconfig`/bump commits (`38295004e`, `2d52c8b71`). The fork's xcstrings are separate; only revisit if the tvOS catalog should mirror new keys (check the pt-BR/vi strings for the chapter/ASS keys when item 2 is ported).

## Not applicable
Version bumps, store publish, Slovak/pt-BR/Vietnamese Compose resources.

## Carried
Items 1-2 from the 2026-10-30 report (IMDb one-decimal rating, unreleased-episode badge) remain open candidates.

## NuvioTV Android — 2026-10-31

Upstream `NuvioMedia/NuvioTV` (`dev`): `d063618d2` (last plan, 2026-10-30) -> `fa194b008`. 26 non-merge commits, 44 files (+1282/-229).
**New baseline: `fa194b008`.**

## Candidates for the tvOS fork

1. **MED, port the idea — Chapter-derived skip intervals, follow-ups** (`13fa3ad53` "use segmentCategory for skip button timer continuity", `ChapterSkipIntervals.kt` +8/-?, `ChapterSkipIntervalsTest`, `SkipIntroButton.kt`, `PostPlayRecommendationOverlay.kt` "Hold back to exit post recommendation screen" `e9ff0189b`). Continues the item from the 2026-10-30 plan; same code is now also in NuvioMobile (see Mobile plan item 2), so port once from the Mobile `commonMain` version. Effort M (3-4 h) as before.
2. **MED — Player badge accuracy** (`be6f2d317` "Badges Improves after review", `94ecdb9c2`, `0c09dbffc`; `PlaybackMatchText.kt` +52, `StreamBadgeRules.kt` +59, `PlayerMediaInfo.kt`, `PlayerBadges.kt`, `StreamBadgeChips.kt`, `PlaybackMatchTextTest` +121). Same change as Mobile item 1; port from the Mobile version (`shared/` files already exist in the fork). Android adds a `PlayerMediaInfo` rewrite (+66) worth reading for the AVPlayer/mpv property mapping.
3. **LOW — HDR dimming of player controls** (`0d08672f5` "dim player controls on HDR video", `PlayerControlsBrightness.kt` +39, setting in `PlaybackSubtitleSettings`/`PlayerSettingsDataStore`, `SubtitleStyleHdrOverrideTest`). tvOS idea: on HDR/DV playback, dim the app-drawn controls and subtitles so they do not glare. The fork's HDR probe fix is separate. Effort S-M (1-2 h) if wanted; would add a setting (name its default in release notes).
4. **LOW — Offline/VPN and poster connectivity** (`2da048d7f`, `455faeedb`, `23da71bf5`, `ImageConnectivity.kt` +57): treat a DNS VPN as online, always try the network for poster loads. Check tvOS reachability gating (`NWPathMonitor` use) for the same false-offline case; investigate first. Effort S.
5. **LOW — Home enrichment recomposition** (`28bed8d6b`, `af6d8daf4`): Compose perf; N/A for SwiftUI, but confirm the tvOS Home hero enrichment does not invalidate all rows.
6. **N/A:** MPV media-session/Bluetooth controls (`0be4de884`, `bb5cf59f1`, `0aa52c7c4`, `b9332010d`, `fc869b665`, `4b9eb966c`, `b7a729a50`, `MpvMediaSessionPlayer.kt`; Android MediaSession; tvOS uses MPNowPlaying already), RTL refresh-rate ordering, source navigation during scraping, autoplay for episodes selected in player (`4b8d0f41e`, Android player flow; verify tvOS episode switch triggers autoplay), Trakt progress service tweak, test repairs, version bump.

## Open items carried
Simkl/MDBList playback-tracking perf, Trakt refresh cancellation guard, libmpv no-retry on permanent HTTP errors; no resume progress for live streams, Montenegrin subtitle language; plugin sync profile pinning check (2026-10-30 item 2).

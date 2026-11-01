# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-01
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `46febb568` — dated report `docs/upstream-port-plan-2026-11-01.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `915e0117e` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-01.md`

## NuvioMobile — 2026-11-01

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `38295004e` (last plan, 2026-10-31) -> `46febb568`. 22 non-merge commits, 32 files (+2731/-617), **0 paths under `shared/`**. Mostly locale files.
**New baseline: `46febb568`.**

## Candidates for the tvOS fork

1. **PORT (S, MED) — Skip button timer continuity by category** (`a2110d6b8`; `SkipIntroButton.kt`, `PlayerScreenRuntimeEffects.kt`). The auto-hide effect and the keep-dismissed check compare `interval.type`; upstream now compares `segmentCategory(type)`, so a switch from provider `op[aniskip]` to `intro[chapters]` no longer resets the timer or re-shows a dismissed button. The fork already took the chapter-skip and Skip Intro hardening batch (2026-10-31); this is the follow-up. Files: the fork's Swift skip-button state in the player (search `graphify explain "segmentCategory"` for the Swift consumers; key the dismissed/auto-hide state on the category, not the raw type). Effort 30-45 min, unit test on the category compare, device check on an anime file with both aniskip and chapters (Test profile). No setting.
2. **WATCH (S) — Auto-failover re-arm only on source change** (`a4f69d0ed`, `5c3c19bc4`, `d6c32ec6c`; `PlayerScreenRuntimeUi.kt`). Upstream moves the failover reset effect out of the `key(playbackKey)` block and keys it on the source (`playbackKey.copy(playbackEngine = null)`), preventing a failover loop and an engine-selection bug on anime. It sits on `AndroidPlaybackEngine`/`resolveAutoPlaybackEngine`, which the tvOS fork does not use. Compare with the fork's own mpv-to-AVPlayer failover (`NativePlaybackCoordinator.swift`): confirm a failover cannot re-arm for the same source after the engine override changes. Read-only check, 30 min; port only if a loop is possible.
3. **SKIP — Compose "Episode N" localisation** (`99b5639fd` ... `e4f79a01e`, six commits; `DetailSeriesContent.kt`, `EpisodeWatchedActionSheet.kt`, `PlayerEpisodesPanel.kt`, `PlayerOverlays.kt`, `StreamsScreen.kt`, `StreamsTabletLayout.kt`). The fork's tvOS UI has its own xcstrings; grep the Swift for hard-coded "Episode %d" strings only if a tester reports one.
4. **SKIP — locale files**: ar, bg, el, es, fr (with autosync/mdblist/party/servers files), pt-BR, tr, vi. Compose resources; the fork's xcstrings are separate. fr/tr translation text can seed tvOS translations if the catalog is extended.
5. **SKIP — unrelated**: `PlayerScreenRuntimeUi.kt` import cleanup, `MetaDetailsRepository` import.

## Not applicable
Locale-only commits, Compose layout tweaks.

## NuvioTV Android — 2026-11-01

Upstream `NuvioMedia/NuvioTV` (`dev`): `fa194b008` (last plan, 2026-10-31) -> `915e0117e`. 12 non-merge commits, 29 files (+893/-71).
**New baseline: `915e0117e`.**

## Candidates for the tvOS fork

1. **WATCH (M, LOW-MED) — Night mode for audio playback** (`b8fb760fa`, `6dfd03091`; `PeakLimiter.kt` +47, `NightModeAudioProcessor` + test +140, `PlaybackAudioSettings.kt`, `PlaybackSettingsModel/ViewModel`, `PlayerUiState.kt`, strings). An ExoPlayer AudioProcessor that compresses dynamic range with a peak limiter; a toggle in Settings > Playback > Audio. Not portable as code (Media3 audio pipeline). tvOS equivalent: an mpv `af` chain (`acompressor`/`dynaudnorm`) for the mpv engine and nothing for AVPlayer (no hook). Candidate FEAT only if a tester asks; a new setting would need a default (Off) named in release notes. Read the compressor parameters from `NightModeAudioProcessor` first (30 min).
2. **WATCH (S) — Keep the player engine when the same stream restarts** (`8dd8e5500`; `PlayerRuntimeControllerErrorRecovery.kt`, `...Initialization.kt`, `...Streams.kt`, `...PlaybackEvents.kt`). Same theme as the Mobile failover fix. Check that the fork's engine choice persists across a restart of the same stream after a failover (`NativePlaybackCoordinator.swift`). Read-only, 20 min.
3. **SKIP — Android-only**: `fix(debrid): prepare links off the main thread` (`062eb1e61`, `DirectDebridStreamPreparer`; Android main-thread rule, tvOS prepare runs async already), Scroll the audio menu controls with focus (`6dfd03091`, Compose focus).
4. **SKIP — locale**: el, es, fr, he, vi, RTL buffer strings (`dfa1a0b9c`), HDR dim and night-mode strings.

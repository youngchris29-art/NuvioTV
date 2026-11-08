# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-08
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `de60c5a16` — dated report `docs/upstream-port-plan-2026-11-08.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `3eeb8b3d0` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-08.md`

## NuvioMobile — 2026-11-08

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `0f85c959c` (last plan, 2026-11-07) -> `de60c5a16`. 21 non-merge commits, 69 files (+4447/-976). Nothing under `shared/` changed upstream (all `composeApp`). The Anime-Skip port from the 11-07 plan is still not in the fork (`SkipIntroRepository.kt` has no `baseDuration`).
**New baseline: `de60c5a16`.**

### Candidates for the tvOS fork

1. **PORT (M), carried over — Anime-Skip correctness** (`030fe83eb`, `68156d224`, `409c372d1`, tests `66bdba357`; plan unchanged from 2026-11-07): `baseDuration` on `AnimeSkipEpisode` and the GraphQL query, `bestAnimeSkipIntervals()`, `toAnimeSkipIntervals(baseDuration)`, merge order IntroDB, AniSkip, Anime-Skip, fetch Anime-Skip outside the IntroDB branch. Files: `shared/.../player/skip/SkipIntroRepository.kt`, `SkipModels.kt`. Gate: `:shared:jvmTest :shared:tvosSimulatorArm64Test`.
2. **PORT (S) — Trakt episode-mapping visibility** (`620acb92c`, one hunk): `TraktEpisodeMappingService.getAddonEpisodes` becomes `internal` (used by the new MDBList mapper). The fork's own MDBList remap (landed 11-05, `4d9b47eed`) already covers the behaviour; only take this hunk if the fork's mapper wants to share the addon-episode fetch. Effort: trivial, optional.
3. **COMPARE (S) — MDBList anime episode remap** (`620acb92c`: `MdbListEpisodeMappingService.kt`, `MdbListProgressProjection.kt`, `MdbListTracker.kt`, `MdbListTrackingProgressProvider.kt`, `MdbListTrackingWrites.kt`, `MdbListWatchedSyncAdapter.kt`, tests). Same feature the fork shipped on its own 11-05. Diff upstream's `MdbListEpisodeMappingTest` cases (addon vs TMDB numbering) against the fork's tests once and add any missing fixtures; no new code expected.
4. **PORT (S) — Watched sync crash guard** (`8172e682b`): `WatchedRepository.kt` copies the unsynced key set before saving (concurrent-modification fix). One line; check the fork's `WatchedRepository` has the same loop. Files: `composeApp/.../watched/WatchedRepository.kt` (or the fork's shared copy).
5. **PORT (S) — Playback buffer start cap** (`6ad2d9baf`): `PlaybackBufferSettings.kt` caps buffer start times at the min buffer. Check whether the fork's tvOS player reads these settings (AVPlayer/mpv buffer knobs); if it does, take the clamp. Files: `PlaybackBufferSettings.kt`.
6. **PORT (S) — Addon subtitles reset only on source change** (`82ca7d119`): `PlayerScreenRuntimeEffects/PlaybackActions/State.kt` plus a test in `PlayerEngineSwitchTrackPreferenceTest`. Compose runtime, so only the logic idea applies: do not clear addon subtitle selection on an engine switch, only when the stream source changes. Look at the fork's SwiftUI player subtitle reset path before deciding.
7. **WATCH (L) — Automatic subtitle sync on iOS** (`df099ca85`, `4a40dda9a`): engine moved to `commonMain` (`AutomaticSubtitleSync`, aligner, charset detector, MP4 sample tables, HTTP index), enabled on iOS through an mpv bridge (`AutoSyncMpvPlatform.ios.kt`, `MPVPlayerBridge.swift` +42, `PlayerBridge.kt`). The fork has no autosync today. Real feature with new settings (mode, tolerance, preferred language), and it rides on mpv, which the fork has only on one route. Only on a tester request; if wanted, lift the engine into `shared/` first.
8. **SKIP — Android-only fixes**: `c1dfd9898` (playback foreground service), `81dc761ee` (caption settings read), `d534d14e9` (SSL setup errors as failed requests, Android interceptor).
9. **SKIP — i18n and version churn** (French/Greek/Hebrew/Japanese ratings, party, pip, autosync, mdblist strings; `20fb87e66`, `de60c5a16`). Ratings strings only matter if star ratings are ported.

## NuvioTV Android — 2026-11-08

Upstream `NuvioMedia/NuvioTV` (`dev`): `fe5c314bd` (last plan, 2026-11-07) -> `3eeb8b3d0`. 29 commits (about 18 non-merge): crash-fix batch, Trakt write-mapping fix, i18n, version bump.
**New baseline: `3eeb8b3d0`.**

### Candidates for the tvOS fork

1. **PORT (S) — Trakt writes keep episode numbers when Trakt has the episode** (`b1bf4bd83`, PR #4514): `TraktEpisodeMapping.kt` +14, `TraktEpisodeMappingService.kt` +5, test +63. The fork's Trakt mapping is `shared/.../trakt/TraktEpisodeMappingService.kt`; read the Android diff and apply the same guard (when the addon episode exists on Trakt, do not remap the number on a write). Gate: `:shared:jvmTest`.
2. **PORT (carried over, M)** — Anime-Skip fixes, same as the NuvioMobile item 1.
3. **SKIP — crash-fix batch** (`476d1d95a` job scheduler, `18c256fb6` parallel reads, `26949b898` subtitle width, `3eb236c40` playback speed type, `2fb930767` autosync waiters, `1a5a5eadf` nav title, `4692380a9`, `39e9fa1e4`, `5a6f9a0b7`, updater fixes `179469c8b`/`0f2fe22b9`/`fce6ad835`/`1c0fada0f`, ProGuard `43fa2bb9b`, `3dcd45d66`): Android/Compose or Android platform APIs. `18c256fb6` (recursion on a short chunk) is worth a glance if the fork has a parallel-read subtitle or range fetcher, otherwise nothing.
4. **SKIP — i18n** (Greek, French, Polish, Swedish, missing strings `c7c6c1e44`).

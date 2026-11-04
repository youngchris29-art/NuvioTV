# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-04
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `3e156936e` — dated report `docs/upstream-port-plan-2026-11-04.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `99fbd65d8` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-04.md`

## NuvioMobile — 2026-11-04

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `46febb568` (last plan, 2026-11-03) -> `3e156936e` (0.6.7-beta). 20 non-merge commits, 56 files. Mostly Android/iOS-app player work (subtitle addon extras, watch party layout), Android libass, locales, and iOS audio-session tweaks.
**New baseline: `3e156936e`.**

## Candidates for the tvOS fork

1. **PORT (M) — subtitle addon requests carry file extras (`filename`, `videoHash`, `videoSize`)** (`9cb86845f`, `f93f22b0f`, `1aacf178d`, `843e9e779`, `f73637893`, `42d0d41ec`). New `OpenSubtitlesHasher.kt` and `VideoHashComputation.kt` (iOS actual `VideoHashComputation.ios.kt` is 6 lines), `AddonSubtitleLoader.kt` builds the addon URL with extras, `SubtitleRepository.kt`/`SubtitleForwarder.kt` pass them; P2P streams hash via the local engine URL. Fork files: `shared/.../player/SubtitleRepository.kt`, `SubtitleForwarder.kt` (both present); `AddonSubtitleLoader.kt` and the hasher are not in the fork's `shared/` yet, so confirm where the fork builds subtitle addon URLs (`graphify explain "SubtitleRepository"`). Needs a tvOS hashing actual (byte-range reads over HTTP for the first/last 64 KB) and a unit test (upstream `SubtitleRequestExtrasTest`). No new setting. Improves subtitle sync matches on OpenSubtitles-style addons.
2. **PORT (S) — "Mark as watched" in the Continue Watching menu** (`7c57f775e`; `WatchingActions.kt` +37, test `ContinueWatchingMarkWatchedTest`). `WatchingActions.kt` exists in the fork's `shared/`; the shared action is portable. The tvOS `TitleHoldMenu.swift` already has a watched action, so check whether the CW hold menu reaches it for episodes; port the shared helper and test only if it does not. (Closes the 2026-11-03 Android WATCH item.)
3. **PORT (S) — keep stream info and the current-stream marker with reused links** (`c1fb6c5c2`; `StreamLinkCacheRepository.kt` +6, `PlayerCurrentStreamTest`). Shared cache part is portable; the rest is Compose panel code. Check the tvOS "current" marker in `StreamPickerView.swift` survives link-cache reuse. (Closes the 2026-11-03 Android WATCH item.)
4. **WATCH (S) — iOS audio session declares long-form video** (`531f24598`, `25e1ba282`, `2d3a12321`). The fork sets `.playback`/`.moviePlayback` (`NuvioTVApp.swift:129`, `MPVPlayerView.swift:767`) without `routeSharingPolicy: .longFormVideo`. tvOS has no music-style Now Playing misclassification as far as known; skip unless a tester reports Now Playing oddities. The `MPVKit` pointer bump is not applicable (fork pins its own).
5. **SKIP — Android-only / non-shared**: libass ASS fix (`65a528c2c`), watch-party resize and panel layout (`9f18bfee1`), version bumps and `store.json`, Arabic/French/Italian/Polish locale files (fork localizes through `Localizable.xcstrings`; harvest wording only when touching those strings), iOS Now Playing publish-on-change (`2d3a12321`, check only if the fork's Now Playing updates thrash).

Carried over from 2026-11-01: PORT (S) skip-button timer continuity keyed on `segmentCategory` (`a2110d6b8`), and WATCH the auto-failover re-arm check (`a4f69d0ed`, `5c3c19bc4`, `d6c32ec6c`) against the mpv-to-AVPlayer failover.

## NuvioTV Android — 2026-11-04

Upstream `NuvioMedia/NuvioTV` (`dev`): `a102f6bf5` (last plan, 2026-11-03) -> `99fbd65d8`. 11 commits (8 non-merge), 8 files. Android-only: tab divider length, shuffle button styling, pt-BR/other strings, version bump.
**New baseline: `99fbd65d8`.**

Nothing to port: no shared logic or behaviour changes. The 2026-11-03 candidates (Cantonese subtitle mapping, MDBList episode remap, stream search cache key) stay open; the CW mark-watched and current-stream-marker WATCH items are now tracked under the NuvioMobile port list above (upstream shipped both there).

## Candidates for the tvOS fork (Android, carried from 2026-11-03)


1. **PORT (S) — Cantonese subtitle language mapping** (`79dd4fa63`; `SubtitleLanguageMatching.kt`, `LanguageUtils.kt`). Maps `zhc`/`zc`/`yue`/`zh-ca` to a Cantonese code distinct from Chinese, plus a "Chinese (Cantonese)" display name. Fork equivalents: `shared/.../player/PlayerSubtitleMatching.kt`, `PlayerLanguagePreferences.kt` (both carry `zhs`/`zht` tables). Add aliases, display override, unit test. No new setting.
2. **PORT (M) — MDBList episode remap between addon and TMDB numbering** (`facf25ec3`; new `MdbListEpisodeMappingService.kt`, `AddonEpisodeListService.kt`). Fixes anime where the addon splits seasons differently from TMDB (watched marks, Continue Watching, scrobbles). The fork already has `TraktEpisodeMappingService` (`remapEpisodeByTitleOrIndex`) in `shared/`; the change extracts the addon episode-list fetch into a shared service and applies the remap to MDBList. `graphify explain` the MDBList provider consumers first; worth it only if the fork's MDBList path writes progress.
3. **WATCH (S) — stream search cache key** (`ed4bc05bf`). Upstream keyed searches on the binge group, so player/next-episode lookups missed the picker's search and re-queried every add-on. Check the fork's source-search cache and next-episode preload for the same key problem.
4. **WATCH (S) — Continue Watching "Mark as watched" item** (`b71ccb1f6`). `TitleHoldMenu.swift` has a watched action; confirm the CW hold menu offers it. Likely covered.
5. **WATCH (S) — current stream marker matches filename before name** (`2b4b640a8`, `7242ff8b6`). Check the tvOS "current" marker survives link reuse.
6. **SKIP — plugin (scraper) work** (preferred plugin on next episode, variant tokens, provider labels/grouping, PluginManager): no equivalent runtime in the fork.
7. **SKIP — Android-only**: low-RAM memory tiers, RTL ordering fixes, VPN network label, addon-chip focus, trailer gradient, settings resets/scroll, Polish strings, baseline-profile and benchmark tooling, episode picker search-all-sources.

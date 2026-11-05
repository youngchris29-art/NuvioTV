# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-05
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `77dfe7c2c` — dated report `docs/upstream-port-plan-2026-11-05.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `a6a826687` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-05.md`

## NuvioMobile — 2026-11-05

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `3e156936e` (last plan, 2026-11-04) -> `77dfe7c2c`. 7 non-merge commits, 33 files (+928/-110). All Android auto-sync (ASS/SSA subtitles via libass, no-fit fallback), one iOS mpv-bridge fix, locale trims.
**New baseline: `77dfe7c2c`.**

## Candidates for the tvOS fork

1. **SKIP — ASS/SSA auto-sync work** (`7674c7263`, `1d3ed3eb1`, `12080e9f4`, `16ea3f2a5`, `285fe3711`; `AutoSyncAssDialogueFilter.kt`, `AutoSyncLibassSubtitles.kt`, `AutoSyncSubtitleCueParser.kt`, `AutoSyncNoFitTracker.kt`, coordinators, nuvio-libass aar). The fork's `shared/` has no auto-sync pipeline (only `SubtitleAutoSyncUiState`); everything here lives in `composeApp` and the Android coordinator. Nothing portable unless the fork adopts auto-sync.
2. **WATCH (S) — add-on subtitle selected before mpv loads the file** (`bfaa6f0a4`, `b7b1a3f9f`; `iosApp/iosApp/Player/MPVPlayerBridge.swift`, `SubtitlePlaybackTests.swift`). Upstream's bridge queued the URL in `pendingSubtitleUrl` until `isFileLoaded`. The fork's `MPVPlayerView.swift` uses its own side-load queue on `eventQueue` (~line 1828), so the race may not apply; check that a remembered add-on subtitle chosen while the stream still opens is not dropped. Only a bug if reproduced.
3. **SKIP — locale/version churn** (autosync toast strings trimmed in ar/bg/el/es/fr/hr/hu/it/pl/pt-BR/sk/tr/vi, `store.json`, aar binary). Fork localizes through `Localizable.xcstrings`.

## NuvioTV Android — 2026-11-05

Upstream `NuvioMedia/NuvioTV` (`dev`): `99fbd65d8` (last plan, 2026-11-04) -> `a6a826687`. 33 commits, 60 files. Mostly Android: ASS/SSA auto-sync (mirrors the mobile work), locales, profile PIN Back, opt-in background decoder release, plus one shared progress-rule change.
**New baseline: `a6a826687`.**

## Candidates for the tvOS fork

1. **PORT (S) — drop the 2% start threshold for "in progress"** (`ca8bdce45`; `WatchProgress.kt`, `MetaDetailsViewModel.kt`, `HomeViewModelContinueWatching.kt`, `EpisodesSection.kt`). `isInProgress()` becomes `!isCompleted() && (position > 0 || percent > 0)`; Resume, Continue Watching and the "not started" badge all use it, so Resume never restarts at 0 for a sub-2% position. Fork: grep `shared/` for the progress model and the tvOS Detail/Home consumers (`graphify explain "WatchProgress"`); port only if the fork still gates on a start threshold. Note Test 2 runs the Trakt progress source, so verify against Trakt items. No new setting.
2. **WATCH (S) — drop a stale streams screen on Back after a binge skip** (`bbf2d4388`; `NuvioNavHost.kt`, `StreamScreen.kt`). Check the tvOS picker/next-episode flow for a leftover picker on Back.
3. **WATCH (S) — episode autoplay selection delay** (`f4c482e64`, PR #4406). Check tvOS autoplay does not wait on the full source list before starting.
4. **SKIP — Android-only**: ASS auto-sync (same as the mobile list), opt-in background decoder release (`3412e2803`), profile PIN Back (`212940d5d`), es-419/sk/pl/other strings, libass aar.

## Still open from 2026-11-03/04
MDBList episode remap (M) and the stream search cache key (S) carry over unchanged; Cantonese mapping, CW Mark as Watched and the subtitle add-on extras landed in the 2026-11-04 batch.

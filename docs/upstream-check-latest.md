# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-10-30
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `10feb659a` — dated report `docs/upstream-port-plan-2026-10-30.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `d063618d2` — dated report `docs/nuviotv-android-upstream-port-plan-2026-10-30.md`

## NuvioMobile — 2026-10-30

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `53869a027` (last plan, 2026-10-29) -> `10feb659a`. 21 non-merge commits (two tapframe duplicates of the settings-heading and iOS-font commits), **0 paths under `shared/` upstream**: all code is `composeApp`/`iosApp`. Fork tip checked: submodule `c99fc3247`, outer `7599089`.
**New baseline: `10feb659a`.**

## Candidates for the tvOS fork

1. **PORT (small) — IMDb rating shows one decimal** (`96061025f`; `DetailMetaInfo.kt`, `TabletDetailHero.kt`, `HomeHeroMetaRows.kt`): `formatOneDecimal` on the parsed rating instead of the raw string. The fork's Swift detail/hero rating text takes `imdbRating` raw; check `graphify explain "imdbRating"` and format in the Swift view model (or a `shared/` helper). Effort: **S (30-45 min)** plus a unit test.
2. **PORT (small) — Label unreleased episodes as unavailable** (`2f0185ce4`, `82dad3e8e`; `EpisodeAvailabilityBadge.kt`, `DetailSeriesContent.kt`, +1 string). The fork already has `HomeUnreleasedContentPolicy.kt` and `MetaDetailsRepository` release logic in `shared/`; add a badge on tvOS episode rows for future-dated episodes (new xcstrings key, en value required). Effort: **S-M (1-2 h)** incl. focus-safe badge and a test for the date cutoff. Mention the new behaviour in the release notes (no setting).
3. **WATCH/ADAPT — Subtitle appearance** (`cfd2348a8`, `67feafa32`, `5254ea8f9`, `d7a347f37`, `92baea427`, `f8d6c30bd`, `1539f6ed7`, `4be859b5d`/`c4a6a09cf`; `SubtitleAppearance.kt`, `SubtitleFonts*.kt`, `StyledSubtitle.kt`, `PlayerSettingsRepository.kt` +8, `PlayerSettingsStorage*.kt`, `MPVPlayerBridge.swift` +69, bundled Noto Sans + `subfont.ttf` rename): saved subtitle styles, custom font import, background/shadow/outline, preview. All Compose UI; the only reusable parts are the persisted style fields in `PlayerSettingsRepository` (move to `shared/` if the fork wants parity) and the mpv bridge's font/outline option mapping (`sub-font`, `sub-border-style`, `sub-shadow`), plus the finding that the default CJK fallback font was swapped for Noto Sans. Compare with the fork's native subtitle style settings before deciding; the tvOS player already drives mpv sub options itself. Effort: **M-L (4-6 h)** if wanted; nothing is a bug fix for tvOS, so rate LOW-MED.
4. **SKIP — App icon save/restore** (`87795e978`; `AppIconRepository.kt`, `AppIconPlatform*`): iOS alternate-icon persistence; tvOS uses its own App Store icon set. N/A.
5. **SKIP — Settings regroup / playback page split** (`c7ff35f08`, `31f848edb`/`783bb775c`, 9 new `Playback*Settings.kt`, `SettingsSearch.kt`, `Slider.kt`, `780c28649`, `7aa734428`): Compose settings UI refactor; the tvOS settings are SwiftUI with their own structure. N/A. (Possible idea only: group the long tvOS playback list the same way.)

## Not applicable (Android / Compose / locale)
- `SettingsPagesTest`, `SliderTest`, `SubtitlePlaybackTest` (Android instrumentation), `SubtitleTests.xcscheme`, test fixtures (`testFixtures/subtitles/*`), MDBList test-name rename (`854f7b437`).

## Carried from 2026-10-29
WatchProgressRepository off-main persist (`bb94cb1c1`) and the offline next-episode guard were ported or triaged in the 2026-10-29 batch; no new action here.

## NuvioTV Android — 2026-10-30

Upstream `NuvioMedia/NuvioTV` (`dev`): `d14832e1c` (last plan 2026-10-28) -> `d063618d2`. 17 non-merge commits, 27 files (+1340/-111).
**New baseline: `d063618d2`.**

## Candidates for the tvOS fork

1. **MED, port the idea — Derive skip-intro intervals from chapter titles** (`117e188ca`, `243f93ed1`, `2e4f29888`, `d37b8fe15`, `19f550eeb`, `98e691331`, `bb8bd3dc2`, `9d5e97c91`; new `ChapterSkipIntervals.kt` +131, `SkipIntroRepository.kt`, `PlayerRuntimeControllerChapters.kt`): when the skip API has no intervals, intro/recap/outro intervals are built from chapter names ("Opening", "Recap", "Credits"...), merged with API intervals (`mergeSkipIntervals`, tests `ChapterSkipIntervalsTest`, `MergeSkipIntervalsTest`), stale chapter state cleared on source switch, MKV probe gated, skip-button flicker fix. The fork has `shared/.../player/skip/` (`SkipModels.kt`, `SkipIntroRepository.kt`) and Swift chapter handling (`NativePlaybackCoordinator.swift`, `PlaybackModels.swift`); port the title-matching and merge as a pure function in `shared/skip/` with the upstream tests, feed it the chapters mpv/AVPlayer already report. Effort: **M (3-4 h)** incl. tests and a device pass on a chaptered MKV (Test profile).
2. **LOW — Plugin sync pinned to the profile that started it** (`f9186e63e`, `a4a2ba284`; `PluginSyncProfile.kt`, `PluginSyncScheduler.kt`, `StartupSyncService.kt`): prevents a profile switch mid-sync writing plugin state to the wrong profile and orders plugin sync after addons and watch progress. Check the fork's plugin sync (`PluginStateFiles`, profile-slot code) for the same race, esp. after the Caches payload-store change. Effort: **S-M (1-2 h)** investigate first.
3. **N/A:** Addons page focus restoration (`oathzed`, Compose TV focus), ambient-mode plurals, string updates (French, Slovak, Vietnamese).

## Open items carried (see 2026-10-26 plan)
Simkl/MDBList playback-tracking perf (diff `MdbListProgressProjection.kt` first), Trakt refresh cancellation guard, libmpv no-retry on permanent HTTP errors; from 2026-10-28: no resume progress for live streams, badge codec detection, Montenegrin subtitle language.

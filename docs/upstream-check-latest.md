# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-07
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `0f85c959c` — dated report `docs/upstream-port-plan-2026-11-07.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `fe5c314bd` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-07.md`

## NuvioMobile — 2026-11-07

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `ff846efe7` (last plan, 2026-11-06) -> `0f85c959c`. 56 non-merge commits (about 35 are Tamil/Vietnamese/Bengali/French strings), 99 files (+5984/-934). Nothing under `shared/` changed upstream (everything is `composeApp`), but the fork keeps `SkipIntroRepository` in `shared/`, so the Anime-Skip fixes apply by hand.
**New baseline: `0f85c959c`.**

## Candidates for the tvOS fork

1. **PORT (M) — Anime-Skip correctness** (`030fe83eb`, `68156d224`, `409c372d1`, tests `66bdba357`). Fork `shared/.../player/skip/SkipIntroRepository.kt` still matches the old code (query at ~line 310 lacks `baseDuration`; Anime-Skip ranks above AniSkip in `mergeByPriority` at lines 84/135/189; Anime-Skip is fetched only inside the IntroDB branch). Port: (a) add `baseDuration` to `AnimeSkipEpisode` (`SkipModels.kt`) and the GraphQL query; (b) `bestAnimeSkipIntervals()` picks the most complete community entry per episode; (c) `toAnimeSkipIntervals(baseDuration)` drops open-ended intro/recap and lets only an ending run to the episode end, when it starts in the second half; (d) merge order IntroDB, AniSkip, Anime-Skip; (e) fetch Anime-Skip from the AniList id outside the IntroDB branch, and only call the IntroDB TVDB resolver when IntroDB is configured. Port upstream's `AnimeSkipIntervalsTest` and the `ChapterSkipIntervalsTest` change into `shared/src/jvmTest` (or commonTest). Files: `SkipIntroRepository.kt`, `SkipModels.kt`. No new setting. Gate: `:shared:jvmTest :shared:tvosSimulatorArm64Test`. Same three Anime-Skip commits also landed in NuvioTV Android (one port covers both).
2. **WATCH (L) — star ratings** (`322987135`, `6982ec7d2`, `1255999dd`, `9c26a7cf8`, `2f9f4ae61`): rating source setting (Trakt/Simkl/MDBList), save and read user ratings, rating chip/sheet on Detail. Logic is in `composeApp` (`TrackingRatings.kt`, `SimklRatings.kt`, `MdbListUserRatings*.kt`), the UI is Compose. A real feature (new settings, three providers), so only on a tester request. If wanted: lift the three ratings files into `shared/` and build a SwiftUI rating chip on Detail; new setting default needs naming in the release notes.
3. **SKIP — Android player** (`2e20900fe` audio focus on calls, `4bf98fcf2` tablet landscape lock, `5e3bd9f0c` edge swipes) and `3ba11a229` header constraint: Android/Compose only.
4. **SKIP — Detail/Streams see-through chips and cinematic backdrop** (`f6ac2840c`, `5cf73ccc6`, `9877adfc0`, `d816059ef`): Compose styling, the fork has its own Detail design.
5. **SKIP — i18n and version churn** (Tamil app language, vi/bn/fr strings, `42e37ace0`, `0f85c959c`). Tamil could be a later xcstrings addition if a tester asks.

## NuvioTV Android — 2026-11-07

Upstream `NuvioMedia/NuvioTV` (`dev`): `248ed08bf` (last plan, 2026-11-06) -> `fe5c314bd`. 10 non-merge commits: 3 Anime-Skip fixes (identical to the NuvioMobile ones), 3 hero-carousel/trailer commits, Turkish/Japanese strings, version bump.
**New baseline: `fe5c314bd`.**

## Candidates for the tvOS fork

1. **PORT (shared with the NuvioMobile item 1)** — Anime-Skip fixes (`6312eb2a8`, `a3192c3d2`, `cb06272bd`): same change as mobile `030fe83eb`/`68156d224`/`409c372d1`; do it once in `shared/.../player/skip/SkipIntroRepository.kt`.
2. **SKIP — Home hero** (`5d925b210`, `2670d72de`, `42843eabc`): Android TV Compose carousel auto-scroll and trailer-pause fix; the fork's tvOS Home Stage is separate. Revisit only if a tester reports a stuck carousel on pause.
3. **SKIP — locales and version** (`c6e9c6395`, `73ebee1e8`, `c03870e3e`, `fe5c314bd`).

## Carried over
The 2026-11-06 PORT (Trakt reverse remap only when the addon lacks the episode, `f07acf603`) and the 2026-11-05 PORT (drop the 2% in-progress threshold, `ca8bdce45`) are unchanged; see `docs/nuviotv-android-upstream-port-plan-2026-11-06.md` and `-2026-11-05.md`.

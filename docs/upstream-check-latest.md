# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-03
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `46febb568` — dated report `docs/upstream-port-plan-2026-11-03.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `a102f6bf5` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-03.md`

## NuvioMobile — 2026-11-03

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`) has not moved: still `46febb568`. 0 new commits, nothing to port.
**Baseline unchanged: `46febb568`.**

Carried-over open items from the 2026-11-01 plan: PORT (S) skip-button timer continuity keyed on `segmentCategory` (`a2110d6b8`), and WATCH the auto-failover re-arm check (`a4f69d0ed`, `5c3c19bc4`, `d6c32ec6c`) against the fork's mpv-to-AVPlayer failover.

## NuvioTV Android — 2026-11-03

Upstream `NuvioMedia/NuvioTV` (`dev`): `1b6982960` (last plan, 2026-11-02) -> `a102f6bf5`. 63 commits (about 45 non-merge), 74 files. Android-only Kotlin/Compose; no `shared/` equivalent. Mostly Android plugin (scraper) work, low-RAM tuning, RTL fixes and a baseline-profile benchmark rewrite.
**New baseline: `a102f6bf5`.**

## Candidates for the tvOS fork

1. **PORT (S) — Cantonese subtitle language mapping** (`79dd4fa63`; `SubtitleLanguageMatching.kt`, `LanguageUtils.kt`). Maps `zhc`/`zc`/`yue`/`zh-ca` to a Cantonese code distinct from Chinese, plus a "Chinese (Cantonese)" display name. Fork equivalents: `shared/.../player/PlayerSubtitleMatching.kt`, `PlayerLanguagePreferences.kt` (both carry `zhs`/`zht` tables). Add aliases, display override, unit test. No new setting.
2. **PORT (M) — MDBList episode remap between addon and TMDB numbering** (`facf25ec3`; new `MdbListEpisodeMappingService.kt`, `AddonEpisodeListService.kt`). Fixes anime where the addon splits seasons differently from TMDB (watched marks, Continue Watching, scrobbles). The fork already has `TraktEpisodeMappingService` (`remapEpisodeByTitleOrIndex`) in `shared/`; the change extracts the addon episode-list fetch into a shared service and applies the remap to MDBList. `graphify explain` the MDBList provider consumers first; worth it only if the fork's MDBList path writes progress.
3. **WATCH (S) — stream search cache key** (`ed4bc05bf`). Upstream keyed searches on the binge group, so player/next-episode lookups missed the picker's search and re-queried every add-on. Check the fork's source-search cache and next-episode preload for the same key problem.
4. **WATCH (S) — Continue Watching "Mark as watched" item** (`b71ccb1f6`). `TitleHoldMenu.swift` has a watched action; confirm the CW hold menu offers it. Likely covered.
5. **WATCH (S) — current stream marker matches filename before name** (`2b4b640a8`, `7242ff8b6`). Check the tvOS "current" marker survives link reuse.
6. **SKIP — plugin (scraper) work** (preferred plugin on next episode, variant tokens, provider labels/grouping, PluginManager): no equivalent runtime in the fork.
7. **SKIP — Android-only**: low-RAM memory tiers, RTL ordering fixes, VPN network label, addon-chip focus, trailer gradient, settings resets/scroll, Polish strings, baseline-profile and benchmark tooling, episode picker search-all-sources.

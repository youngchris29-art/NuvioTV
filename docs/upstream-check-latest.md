# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-09
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `de60c5a16` — dated report `docs/upstream-port-plan-2026-11-09.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `12d96bced` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-09.md`

## NuvioMobile — 2026-11-09

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`) has not moved since the last run: still `de60c5a16`, no new commits. The Anime-Skip port (M, `SkipIntroRepository.kt`) from the 11-07 plan is still open.
**New baseline: `de60c5a16`.**

## NuvioTV Android — 2026-11-09

Upstream `NuvioMedia/NuvioTV` (`dev`): `3eeb8b3d0` (last plan, 2026-11-08) -> `12d96bced`. 8 commits (about 4 non-merge), 4 files.
**New baseline: `12d96bced`.**

1. **DECIDE (S) — forced subtitles and AutoSync on by default** (`7bc69ea42`, PR #4527): flips two defaults on Android (`useForcedSubtitles` fallback and AutoSync enabled). Not a shared/ change. Only the forced-subtitles default is a candidate for the fork (autosync on iOS is WATCH only); a default change needs a release-note line. Christian's call.
2. **SKIP — Hungarian i18n and version bump** (`f7f3a976d`, `0034a8e44`, `12d96bced`).

Carried over unchanged from 2026-11-08: Trakt write-mapping guard (Android `b1bf4bd83`, S, `shared/.../trakt/TraktEpisodeMappingService.kt`, gate `:shared:jvmTest`) and the Anime-Skip fixes (M).

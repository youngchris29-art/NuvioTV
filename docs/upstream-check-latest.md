# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-26
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `0d20af832` — dated report `docs/upstream-port-plan-2026-11-26.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `d55f8b635` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-26.md`

## NuvioMobile — 2026-11-26

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`) has not moved: `0d20af832` (fetched 2026-11-26). Fork tip checked: `f494a7014`. **Baseline stays `0d20af832`.** No new items. Open from 2026-11-25: debrid ampersand variants (`6f5a492df`, S, PORT), separate ASS/SSA style (M, design call, Codex design round), add-on subtitle auto-select check (S). Open from 2026-11-24: guest add-on push guard (`c72103eca`, S), subtitle format badge (`6c7386681`, M), series type check (S), Trakt library refresh queue fix (`103c5e07a`, M).

## NuvioTV Android — 2026-11-26
Upstream `NuvioMedia/NuvioTV` (`dev`): `b48e9d8d3` -> `d55f8b635`. 28 commits, 15 non-merge. Messages read; file lists read for four candidates. **New baseline: `d55f8b635`.**

| # | Item (upstream commits) | tvOS verdict | Effort |
|---|---|---|---|
| 1 | Series watched toggle in the Detail hero: marks or unmarks every aired episode through the "Mark season as watched" batch path and shows whether all are watched (`d2f18e006`) | CHECK. Does the fork's Detail hero have a series-level watched action? If not, a PORT candidate (feature parity with mobile). Touches Trakt/watched progress, so no real-Trakt writes in tests. Files: `iosApp/NuvioTV` Detail hero + watched-state store, `shared/` meta model. | M |
| 2 | Honor the stream type declared by plugins; probe stream format through the playback HTTP client (`3a28f5a2e`, `da9fc268a`) | CHECK. Fork routes by its own probe; see whether plugin-declared type (HLS/DASH/etc.) is carried from `StreamModels.kt` to the player route choice. Hot file `StreamModels.kt`: one owner. | S |
| 3 | Restore "show chapters" in profile settings sync (`fa685a17f`) | SKIP. No show-chapters setting in the fork. | n/a |
| 4 | Dolby Vision Level 5 offset zeroing, opt-in device-local (`7ab33be7a`, `4d7bf07bd`) | SKIP. ExoPlayer RPU NAL rewrite. | n/a |
| 5 | Usenet engine bumps and release-names setting strings; Croatian, Turkish, French strings (`45367b7d5`, `af9f06a4c`, `96017015f`, others) | SKIP for code. Strings could seed xcstrings. | n/a |

Recommended: items 1 and 2 are checks only; no ports ready to execute.

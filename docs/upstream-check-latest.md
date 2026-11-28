# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-28
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `de46440d0` — dated report `docs/upstream-port-plan-2026-11-28.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `b3f8f6d03` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-28.md`

## NuvioMobile — 2026-11-28

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `6d2fdab63` -> `de46440d0`. One non-merge commit: profile switching behind a shared launch screen (Compose AppGate/LaunchScreen/ProfileSelectionScreen rewrite plus a `ProfilePreload` cache that pre-decodes the next profile's watched and watch-progress payloads before a switch). All `composeApp/`, nothing under `shared/`. Fork tip checked: `9d1e4ad80`. **New baseline: `de46440d0`.** No ports. The preload idea is a CHECK only (M, design call): it adds per-profile state, so it waits behind the scope-identity batch and a Codex design round, and only matters if a device walk shows a profile-switch hitch. Open from earlier runs: debrid ampersand variants (`6f5a492df`, S, PORT), separate ASS/SSA style (M, design call, Codex design round), add-on subtitle auto-select check (S), guest add-on push guard (`c72103eca`, S), subtitle format badge (`6c7386681`, M), series type check (S), Trakt library refresh queue fix (`103c5e07a`, M), audio subtitle sync (XL, only if a tester asks).

## NuvioTV Android — 2026-11-28
Upstream `NuvioMedia/NuvioTV` (`dev`): `10ce212e1` -> `b3f8f6d03`. 8 commits, 5 non-merge. **New baseline: `b3f8f6d03`.**

| # | Item (upstream commits) | tvOS verdict | Effort |
|---|---|---|---|
| 1 | Fix upward hero focus from season posters after player return, smooth bottom row reveal (`b2e4871a5`) | CHECK on the fork's Detail screen after a player return, Test 2, both engines. | S |
| 2 | Slovak and Dutch strings, upload and minor housekeeping commits (`f0509416c`, `eff54f953`, `80af61ddd`, `adcbe72e1`) | SKIP. | n/a |

Recommended: item 1 is a check only; no ports ready to execute. The 2026-11-27 checks (hero auto-advance on focus, Classic hero meta row, MDBList first-frame ratings, chapters on Play Next Episode) still stand; see `docs/nuviotv-android-upstream-port-plan-2026-11-27.md`.

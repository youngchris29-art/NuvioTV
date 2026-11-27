# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-27
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `6d2fdab63` — dated report `docs/upstream-port-plan-2026-11-27.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `10ce212e1` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-27.md`

## NuvioMobile — 2026-11-27

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `0d20af832` -> `6d2fdab63`. 13 non-merge commits, all one family: the audio-based subtitle sync fallback (Silero VAD, ASR, mpv spot engine, iOS speech-model bridge), the autosync rewrite ported from NuvioTV Android, and Nuvio Engine 0.1.7. The fork has no autosync or audiosync code and none of the new code is under `shared/`. Fork tip checked: `baa9ec1c9`. **New baseline: `6d2fdab63`.** No ports. Audio sync is an XL design call, only if a tester asks (audio tap on both engines, model under Caches, new subtitle settings). Open from earlier runs: debrid ampersand variants (`6f5a492df`, S, PORT), separate ASS/SSA style (M, design call, Codex design round), add-on subtitle auto-select check (S), guest add-on push guard (`c72103eca`, S), subtitle format badge (`6c7386681`, M), series type check (S), Trakt library refresh queue fix (`103c5e07a`, M).

## NuvioTV Android — 2026-11-27
Upstream `NuvioMedia/NuvioTV` (`dev`): `d55f8b635` -> `10ce212e1`. 53 commits, about 27 non-merge. **New baseline: `10ce212e1`.**

| # | Item (upstream commits) | tvOS verdict | Effort |
|---|---|---|---|
| 1 | Hero carousel auto-advance while focused, eager hero catalogs that are also Home rows, detail meta prefetch (`87544aee2`, `acfbd4a07`, `415363d06`) | CHECK. Does the fork's hero pause on focus on purpose, and does a hero catalog that is also a row show blank until the row loads? | S |
| 2 | Classic hero: age rating, status badges, IMDb and MDBList in one row (`d0925c79e`, `91c72eed4`) | CHECK against the fork's Classic hero meta row. | S |
| 3 | MDBList speed: cached ratings on the first detail frame, indexed personal rating lookups, fewer late library/watched icons (`aa5680749`, `8e8a20726`, `09266a242`) | CHECK first-frame ratings and library-membership lookup. | M |
| 4 | Keep chapters when binging with Play Next Episode (`3feea816d`) | CHECK on both engines in Test 2. | S |
| 5 | ClearKey DRM, memory-only P2P cache, Usenet same-name fix, libass 0.0.15, Modern poster labels, add-on delete crash, reorder-list scroll, engine bump, new locale strings (Greek, Arabic, French, Hebrew) | SKIP. Android-only or features the fork does not have; strings could seed xcstrings. | n/a |

Recommended: items 1 to 4 are checks only; no ports ready to execute.

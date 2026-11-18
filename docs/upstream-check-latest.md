# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-18
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `b66f7725c` — dated report `docs/upstream-port-plan-2026-11-18.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `f0df1830c` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-18.md`

## NuvioMobile — 2026-11-18

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `dd0e84704` -> `b66f7725c`. 11 non-merge commits. Fork tip checked: `05214e042`.
**New baseline: `b66f7725c`.**

| # | Item (upstream commits) | tvOS verdict | Files in the fork | Effort |
|---|---|---|---|---|
| 1 | External episode ratings matched to the addon's episode order: `EpisodeRatingsAlignment` + tests, `ImdbEpisodeRatingsRepository` rewired (`97fbfa905`) | PORT. Compose-free; check against the fork's MDBList episode remap so the two do not double-shift. | `shared/.../features/details/ImdbEpisodeRatingsRepository.kt`, new `EpisodeRatingsAlignment.kt` + test | S-M |
| 2 | Trakt library refresh: automatic callers no longer queue behind a stalled refresh (`1e4157492`) | PORT. 19-line patch to `TraktLibraryRepository.kt` (refreshJob + mutex, `refreshOnce`). | `shared/.../features/trakt/TraktLibraryRepository.kt` | S |
| 3 | Cast filmography hides talk-show guest appearances (`547972efd`) | PORT if the fork's person credits feed a filmography row (`genre_ids` not in the fork's credit model). | TMDB metadata service in `shared/`, test | S |
| 4 | Downloads screen redesign, back handling, poster setting (`ffe769fa7`, `2dcfbb9f1`, `e00392db1`) | SKIP. Compose UI; no Downloads on tvOS. | n/a | n/a |
| 5 | Release CI, sideload source, version bump, store publish 1.1.0-beta.2 (`66ca8379e`, `62fcd6b9b`, `81f836d40`, `b66f7725c`, `87a1a8b07`) | SKIP. Upstream release plumbing. | n/a | n/a |

Carry-over still open: TorBox alternative-hash fix, subtitle outline clamp, next-episode source fallback check, optional Stremio tracking addons. Plex/Silo media servers remain deferred (no servers framework).

## NuvioTV Android — 2026-11-18

Upstream `NuvioMedia/NuvioTV` (`dev`): `8675a97a0` -> `f0df1830c`. 14 non-merge commits. Commit messages read; Kotlin not diffed.
**New baseline: `f0df1830c`.**

| # | Item (upstream commits) | tvOS verdict | Effort |
|---|---|---|---|
| 1 | Star ratings for titles and episodes, ratings source picker, MDBList/Simkl rating sync (`c4b07d284`, `62888d688`, `761d18801`, `6055873d4`, `6f9754b46`) | EVALUATE. Feature idea, not tester-requested; check write paths and the no-real-Trakt-writes rule first. | M-L |
| 2 | Home: focused poster stays expanded while hero trailers play; hero details hidden during fullscreen trailer (`4aa25bbdb`, `7dd9fcbfe`) | CHECK on a device pass; no code to port. | S |
| 3 | Continue Watching focus follows a card moved to the front after playback (`0042e28e7`) | CHECK; likely a repro worth running on tvOS Home. | S |
| 4 | Perf: subtitle menu no longer resolves every language per build (`d1b9ba4ce`) | CHECK the fork's subtitle menu cost. | S |
| 5 | Talk-show guest filter (`51ebccc1c`) | Same as NuvioMobile item 3. | S |
| 6 | Season posters in tabs, Jellyfin/Emby per-profile sign-ins, French/tracking-consent strings (`0a35557e0`, `30b2aeadf`, `fd140199d`, `fed121f3b`) | SKIP (fork has season posters; no servers framework). | n/a |

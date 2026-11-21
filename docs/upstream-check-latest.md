# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-21
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `c5a73772f` — dated report `docs/upstream-port-plan-2026-11-21.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `d2eeb3d0e` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-21.md`

## NuvioMobile — 2026-11-21

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`) moved: `e022cfdf7` -> `c5a73772f`. 20 non-merge commits (about 12 are translation commits: es, hu, tr, fr, he/iw). Fork tip checked: `3fde1ef41`. **New baseline: `c5a73772f`.**

| # | Item (upstream commits) | tvOS verdict | Files | Effort |
|---|---|---|---|---|
| 1 | Trakt library refresh no longer queues behind a stuck request (`103c5e07a`): non-forced callers return when a refresh job is active, forced callers join it; fixes unbounded waiter growth offline | PORT, carefully. Fork's `TraktLibraryRepository.refresh` still blocks every caller on `refreshMutex`, so waiters pile up when the network hangs. The fork's refresh also carries profile-scope state ("W7 (P1)", captured under the mutex), so the job must be launched on the repository scope with the profile capture inside it. Run a 3-minute Codex design round first (identity-root rule). | `shared/.../trakt/TraktLibraryRepository.kt` (+ a commonTest for the non-forced skip) | M |
| 2 | TorBox alternative-hash cache answers (`f81edc653`) | ALREADY PORTED. Fork has its own `resolveTorboxAliasMatches` with failed-re-ask handling (review r7-r9), stricter than upstream. Close the carry-over item. | none | n/a |
| 3 | iOS downloads excluded from iCloud/computer backups (`4baf886ee`, `NSURLIsExcludedFromBackupKey` on `Documents/nuvio_downloads`) | SKIP for tvOS (downloads UI and backups do not apply; the fork's `.ios.kt` file is only compiled for the Compose iOS target). Relevant to the iPad sideload only, which follows upstream by itself. | n/a | n/a |
| 4 | Player bottom controls use `safeDrawing` instead of `safeContent` on Android (`c31c30e1e`) | SKIP (Android gesture insets). | n/a | n/a |
| 5 | `fix(android): mark wifi as optional`, `bump version - hotfix` (iOS Version.xcconfig) | SKIP. | n/a | n/a |
| 6 | i18n: Spanish, Hungarian, Turkish, French (Plex/Silo, downloads, tracking addon, library filters), Hebrew `values-iw` | SKIP (fork keeps its own xcstrings pipeline). French/Hungarian wording for shared strings is a reference only if the fork localizes those languages. | n/a | n/a |

Carry-over still open: Stremio subtitle `label` as row title, subtitle outline clamp, next-episode source fallback check, episode-ratings alignment, talk-show guest filter (all unported). TorBox alternative-hash fix is closed (already in the fork). Plex/Silo media servers remain deferred (no servers framework).
**Recommended ports: 1 (Trakt refresh queue).**

## NuvioTV Android — 2026-11-21

Upstream `NuvioMedia/NuvioTV` (`dev`): `552cacf56` -> `d2eeb3d0e`. 17 commits (about 11 non-merge). Commit messages read; no Kotlin diffed. **New baseline: `d2eeb3d0e`.**

| # | Item (upstream commits) | tvOS verdict | Effort |
|---|---|---|---|
| 1 | Source fallback to the next source on VC-1 / tunneled decoder failure (`44549e9a0`) | CHECK. Android decoder specifics; the fork's next-source fallback applies to mpv/Aether/native failures. Confirm the fork falls back (not stalls) when a stream fails to decode at start. | S |
| 2 | Keep the playback position when switching source (`f4ce0aa64`) | CHECK. Verify the fork's stream-switch-in-player keeps the current position. | S |
| 3 | Restore the episode being watched after process death (`8c8028085`) | CHECK against the fork's resume-after-relaunch behaviour for series. | S |
| 4 | Trailer fixes: folder trailers continue on the details page (`5f5c19199`), trailer subtitles on first load (`2dc535d39`), Home stays visible while details fades over a framed hero trailer (`4d8cd878e`) | CHECK on a device pass; tvOS trailer path is different (SABR HLS repack), likely no overlap. | S |
| 5 | Apply saved hero sources before the first catalog load (`a0ec0aeae`) | CHECK. Compare with the fork's Home hero source selection on cold start. | S |
| 6 | Cloudstream `MainActivity` stub for `.cs3` lifecycle crash (`1dd7a70e8`) | SKIP (Android plugins). | n/a |
| 7 | Version bump hotfix 1.1.1, wifi optional (`92edd7f46`, `d2eeb3d0e`) | SKIP. | n/a |

Items 1-5 are checks only, no ports.

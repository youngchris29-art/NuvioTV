# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-22
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `642f6e031` — dated report `docs/upstream-port-plan-2026-11-22.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `d2eeb3d0e` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-21.md`

## NuvioMobile — 2026-11-22

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`) moved: `c5a73772f` -> `642f6e031`. 3 non-merge commits. Fork tip checked: `9290dd44c`. **New baseline: `642f6e031`.**

| # | Item (upstream commits) | tvOS verdict | Files | Effort |
|---|---|---|---|---|
| 1 | Jellyfin and Emby sign-ins kept separate per profile (`99f57aa97`): DeviceId per profile (primary keeps the installation ID, others append `-p<id>`) | SKIP. The fork has no `features/servers` / `MediaBrowserClient` code (checked `shared/` and `iosApp/NuvioTV`). Revisit only if the fork ports upstream's media-server feature. | n/a | n/a |
| 2 | Detail hero title takes the available width (`23d93d004`, one-line `fillMaxWidth` on the Compose `DetailHero`) | SKIP. Compose-only; the fork's hero is SwiftUI (`DetailView.swift`). | n/a | n/a |
| 3 | `chore(store): publish 1.0.1` (`f86087dcd`, `store.json`) | SKIP. | n/a | n/a |

No ports. The carry-over from 2026-11-21 stays open: Trakt library refresh queue fix (`103c5e07a`, M, Codex design round first).

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

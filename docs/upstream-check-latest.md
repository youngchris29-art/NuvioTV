# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-17
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `dd0e84704` — dated report `docs/upstream-port-plan-2026-11-17.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `8675a97a0` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-17.md`

## NuvioMobile — 2026-11-17

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `04cfe4af9` -> `dd0e84704`. 6 non-merge commits (Plex and Silo media servers, a mpv-android bump). Fork tip checked: `704143149`.
**New baseline: `dd0e84704`.**

| # | Item (upstream commits) | tvOS verdict | Files in the fork | Effort |
|---|---|---|---|---|
| 1 | Plex Media Server provider: account client, mapper, artwork, provider, PIN sign-in flow, internet-address preference, tokens kept out of party sharing (`17579e7b5`, `943f38d91`) | DEFER. Needs the `features/servers` framework (provider interface, repository, token renewal, sign-in sheets), which the fork does not have (no `servers/` dir in `shared/`, no Jellyfin/Emby either). Port the framework first as its own batch if testers ask for media servers; the Plex files are Compose-free Kotlin plus Compose sign-in sheets (SwiftUI needed). | none (new `shared/.../features/servers/`), Swift sign-in UI | XL |
| 2 | Silo provider on its own API, with report renewal like Silo's app (`5d928372d`, `29a26fbe8`) | DEFER. Same prerequisite as item 1. `SiloProvider.kt` is about 1000 lines plus tests. | as above | L after framework |
| 3 | Shared sign-in screens and wording refactor (`b2fd38e58`) | SKIP. Compose UI (`ServerSignInParts.kt`, `ServerSignInSheet.kt`); only relevant with items 1-2. | n/a | n/a |
| 4 | mpv-android-lib 0.1.12 -> 0.2.1 (`818934860`) | SKIP. Android player library; the fork's `gradle/libs.versions.toml` entry is only consumed by composeApp's Android target, and tvOS plays through MPVKit. | n/a | n/a |

No new item for the tvOS release path. Carry-over from 2026-11-16 still open: TorBox alternative-hash fix, subtitle outline clamp, next-episode source fallback check, optional Stremio tracking addons, Library filters (deferred).

## NuvioTV Android — 2026-11-17

Upstream `NuvioMedia/NuvioTV` (`dev`): `60eb9602a` -> `8675a97a0`. 28 commits including merges (about 12 substantive). Android TV app; commit messages and file lists were read, individual Kotlin files were not diffed.
**New baseline: `8675a97a0`.**

| # | Item (upstream commits) | tvOS verdict | Effort |
|---|---|---|---|
| 1 | Plex and Silo media servers, shared sign-in steps, Plex probe/stop-report fixes, Silo report renewal (`9af02059a`, `4247d5cb1`, `bb7b85d36`, `f0f1ffc31`, `c7e7a4338`) | Same as NuvioMobile items 1-2: DEFER, fork has no servers framework. | XL |
| 2 | External episode ratings matched to the addon's episode order, new `EpisodeRatingsAlignment.kt` with tests (`e2ecb1c5f`) | CHECK. Fixes ratings landing on the wrong episode when the addon's order differs from IMDb's. The fork landed an MDBList episode remap on 2026-11-05; confirm the tvOS episode-ratings path does not show the same off-by-order symptom on a series with split seasons, and port the alignment idea into `shared/` only if it does. No matching NuvioMobile commit yet. | S-M |
| 3 | Home hero: longer description pause around auto-scroll, RTL gradient mirror (`87b344693`, `28b075d35`) | SKIP. Compose hero carousel; tvOS hero is SwiftUI. The auto-scroll dwell is an idea to compare against the tvOS hero description if it truncates. | n/a |
| 4 | Sidebar keeps focus while Home loads (`520a0568f`) | IDEA ONLY. Android focus bug; check the tvOS rail does not lose focus during the first Home load (walk in the Test profile). | S, optional |
| 5 | Ambient-mode settings included in profile settings sync (`96d42a4d7`) | SKIP. Android-only setting. | n/a |
| 6 | Strings (Portuguese, Vietnamese, servers, party), version bump | SKIP. Resource files. | n/a |

# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-25
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `0d20af832` — dated report `docs/upstream-port-plan-2026-11-25.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `b48e9d8d3` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-25.md`

## NuvioMobile — 2026-11-25

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `bd9506cc8` -> `0d20af832` (fetched 2026-11-25). 8 non-merge commits. Fork tip checked: `c5c51abd3`. **New baseline: `0d20af832`.**

| # | Item (upstream commits) | Verdict | Files | Effort |
|---|---|---|---|---|
| 1 | Debrid: match ampersand filename variants (`6f5a492df`): after the exact and basename passes, retry with `" & "` normalised to `" and "` (path, then basename), plus a test | PORT. The fork's `matchingFiles` in `shared/` (line 204) has only the exact and basename passes; no ampersand handling. Copy the two extra passes and the test. Low risk, pure. Same fix as NuvioTV Android `4b71d71ae`, so the earlier Android CHECK item is now a port. | `shared/.../debrid/DebridFileSelectors.kt`, `DebridFileSelectorTest.kt` | S |
| 2 | Separate ASS/SSA subtitle style, default 100% with custom styling off, stored as one entry and synced (`769bf6e74`, `ecfd67d72`, `0e7f9a438`) | PORT (design call). The fork has a styled-subtitles toggle on Aether and a libass setting, but one shared size. A second style needs a new setting, a settings-sync field, and the tvOS style panel editing whichever style the shown track needs. New setting: name it and its default in the release notes. Touches settings sync (identity root): Codex design round first. | `shared/.../player/PlayerSettingsRepository.kt`, `SubtitleAppearance.kt`, `iosApp/NuvioTV` subtitle style panel, mpv/Aether bridge | M |
| 3 | Auto-select the preferred add-on subtitle when add-ons answer after playback starts (`29567e386`: keep selection open while add-on subtitles load) | CHECK. The logic is in composeApp's `PlayerScreenRuntimeTrackActions`, which the fork does not use. Look at the tvOS equivalent (`PlayerScreen.swift` / `SubtitleFallbackGuard.swift`) for a one-shot auto-select that stops when the first scan finds nothing while add-on subtitles are still loading. | `iosApp/NuvioTV/Screens/PlayerScreen.swift`, `Player/SubtitleFallbackGuard.swift` | S |
| 4 | Add-on subtitles not blocked when only the sync backend is unreachable (`5ff7a4e66`, now `NetworkCondition.NoInternet` instead of `isOfflineLike`); runtime state backed by `mutableStateOf` (`7c8b66b30`, test only) | SKIP. Compose runtime/state only; confirm tvOS offline gating does not treat a failed sync as offline. | n/a | n/a |
| 5 | Test replacement (`d018be8e3`), Polish string (`769bf6e74`) | SKIP. | n/a | n/a |

Recommended: item 1 (quick), item 2 (design call), item 3 is a short check. Carry-overs from 2026-11-24 stay open: guest add-on push guard (`c72103eca`, S, Codex design round), subtitle format badge (`6c7386681`, M), series type check (`PluginMediaType.kt`, S), Trakt library refresh queue fix (`103c5e07a`, M).

## NuvioTV Android — 2026-11-25

Upstream `NuvioMedia/NuvioTV` (`dev`): `9e5af3d6c` -> `b48e9d8d3`. 22 non-merge commits (shallow fetch). Commit messages read; no Kotlin diffed. **New baseline: `b48e9d8d3`.**

| # | Item (upstream commits) | tvOS verdict | Effort |
|---|---|---|---|
| 1 | Usenet result rows: show what the release name says, size left to the size badge, at most two languages; anime catalog ids mapped by IMDb id, meta, then Simkl (`655bccb`, `65d8075`, `27cc9a1`, `170be2e`, `de06162`) | SKIP. Needs the Usenet engine; no tvOS equivalent. | n/a |
| 2 | Details: draw the loading skeleton shimmer without recomposing; keep season tabs and episodes in view together; draw the background once (`08733d8`, `c488daf`, `54c5054`) | CHECK on a device pass: season tabs plus episodes in view together on the fork's Detail with many seasons. Compose perf items are SKIP. | S |
| 3 | Debrid ampersand filename variants (`4b71d71`) | PORT with NuvioMobile item 1 of today (`6f5a492df`): same fix. | S |
| 4 | Blu-ray LPCM clips, DTS-HD tracks; audio-track key not opening over disc titles (`927e815`, `928244d`) | SKIP. ExoPlayer Blu-ray work. | n/a |
| 5 | libass v0.0.14 with Laskco's fork (`1a18710`); NuvioMobile ASS/SSA style work follows | CHECK with NuvioMobile item 2 (separate ASS style). The libass bump is Android-only. | n/a |
| 6 | Modern sidebar blur fades with the collapse animation; rating stars shrink evenly in a narrow dialog; audio-sync lyrics filter (`5edbfbc`, `79f56fd`, `75e79d4`) | SKIP. Android Compose UI and an Android-only audio-sync feature. | n/a |
| 7 | Hebrew, Latin American Spanish, French, Hungarian strings; version bumps to 1.1.1 (`16021a0`, `526c690`, `87d255c` and others) | SKIP for code. French and Spanish strings could seed the fork's xcstrings. | n/a |

Recommended: debrid ampersand port (shared with NuvioMobile item 1). The 2026-11-24 Android CHECK items (collection cover fetch bound, trailer from More like this) stay open.

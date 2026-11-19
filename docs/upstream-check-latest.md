# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-19
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `e022cfdf7` — dated report `docs/upstream-port-plan-2026-11-19.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `acb970c42` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-19.md`

## NuvioMobile — 2026-11-19

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `b66f7725c` -> `e022cfdf7`. 2 non-merge commits. Fork tip checked: `5df83303a`.
**New baseline: `e022cfdf7`.**

| # | Item (upstream commits) | tvOS verdict | Files in the fork | Effort |
|---|---|---|---|---|
| 1 | Show the Stremio addon subtitle `label` as the row title in the subtitle list; the addon id becomes the description (`2954c9dc7`, `1f4c245d8`) | PORT (small). Upstream edits `composeApp` `AddonSubtitleLoader.kt` (not in the fork), `SubtitleAudioModels.kt` (adds `title`, and an addon `label` the fork's model lacks) and `SubtitleModal.kt` (Compose). In the fork the parse lives in `shared/.../player/SubtitleRepository.kt` (~l.398, `AddonSubtitle(` constructor) and the model in `shared/.../player/SubtitleAudioModels.kt`: add `title: String?`, fill it from the addon JSON `label`, then use it in the Swift subtitle list rows (MPV + Aether panels, native coordinator) with the language label as fallback. Add a parse test beside `SubtitleRequestExtrasTest`. | `shared/.../player/SubtitleRepository.kt`, `shared/.../player/SubtitleAudioModels.kt`, `iosApp/NuvioTV/Screens/*` subtitle row views, test | S |

Carry-over still open: TorBox alternative-hash fix, subtitle outline clamp, next-episode source fallback check, optional Stremio tracking addons; from 2026-11-18: episode-ratings alignment, Trakt library refresh no longer queues behind a stalled refresh, talk-show guest filter (all unported). Plex/Silo media servers remain deferred (no servers framework).

## NuvioTV Android — 2026-11-19

Upstream `NuvioMedia/NuvioTV` (`dev`): `f0df1830c` -> `acb970c42`. 32 commits (about 23 non-merge). Commit messages read; Kotlin not diffed.
**New baseline: `acb970c42`.**

| # | Item (upstream commits) | tvOS verdict | Effort |
|---|---|---|---|
| 1 | Subtitles on home/hero trailers: follow Strip SDH, only preferred/secondary language, styled with the player's subtitle settings, any caption when language is none, off by default (`6852ae550`, `c78ba3c1f`, `41a528be6`, `6e8a1df74`, `9723270ac`, `7f4e21436`, `8ab8234fc`) | EVALUATE. Feature idea; depends on whether the fork's trailer path (local HLS repack) exposes captions. Not tester-requested. | M |
| 2 | Hero trailer location that keeps posters collapsed; home trailers continue on the details page; no backdrop flash on handoff (`4ad1e8bc4`, `18fe69375`, `acb970c42`) | CHECK on a device pass against the fork's trailer location setting. | S |
| 3 | Stremio subtitle label as list title (`12c125ef9`, `a15263778`) | Same as NuvioMobile item 1. | S |
| 4 | Retry once over HTTP/2 after a 403; allow HTTP/2 for streams with proxyHeaders (`2cba17e43`, `830528215`, `696a59819`, `7d0757ccf`) | CHECK. Android OkHttp behaviour; check how the fork's AVPlayer/mpv loopback handles proxyHeaders 403s. | S |
| 5 | Back-buffer and minBufferMs performance-mode tweaks (`2cd82e788`, `362b91140`) | SKIP (ExoPlayer). | n/a |
| 6 | RTL avatar picker focus, Turkish strings (`e4afd2e3d`, `35157436e`, `826f6a0a0`) | SKIP. | n/a |

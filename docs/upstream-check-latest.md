# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-23
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `642f6e031` — dated report `docs/upstream-port-plan-2026-11-23.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `7097af17f` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-23.md`

## NuvioMobile — 2026-11-23

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`) has not moved: still `642f6e031` (fetched 2026-11-23). Fork tip checked: `9290dd44c`. **Baseline unchanged: `642f6e031`.**

No new commits, no ports. The carry-over from 2026-11-21 stays open: Trakt library refresh queue fix (`103c5e07a`, M, Codex design round first).

## NuvioTV Android — 2026-11-23

Upstream `NuvioMedia/NuvioTV` (`dev`): `d2eeb3d0e` -> `7097af17f`. 88 commits (58 non-merge). Commit messages read; no Kotlin diffed. **New baseline: `7097af17f`.**

| # | Item (upstream commits) | tvOS verdict | Effort |
|---|---|---|---|
| 1 | Blu-ray (BDAV/BDMV) playback in ExoPlayer, disc title picker, CLPI track names, PGS subtitles, EP-map seek, TrueHD (`4bd2502d2` .. `0cf406aed`, about 20 commits) | SKIP for now. Android ExoPlayer datasource work. Only worth a look if testers ask for BDMV/ISO streams in mpv/Aether (both can open `bluray:` sources natively). | n/a |
| 2 | On-device Usenet playback, built-in indexers, per-indexer fetch limits, provider connection tuner, settings menu rename (`53dffdd1a`, `ed2b409e2`, `a97133b69`, `f19852eed`, `37859c64a` and follow-ups) | SKIP. Depends on the standalone Usenet engine (JVM/Android library); no tvOS engine. Revisit only if the fork plans Usenet. | n/a |
| 3 | Retry season searches that failed for a moment (`65b7ef85a`) | CHECK. Compare with the fork's per-season stream/meta fetch error handling for a single transient failure. | S |
| 4 | Audio sync hears Blu-ray clips and starts at once; embedded-subtitle auto-sync several times faster (`d91051930`, `6bdc34f2b`, `2a2c4849f`) | SKIP. Android auto-sync feature the fork does not have. | n/a |
| 5 | ASS/SSA sizing and opt-in styling restored on libass/MPV (`233dd1f3b`) | CHECK. The fork has a styled-subtitles setting on Aether; confirm mpv ASS sizing matches. | S |
| 6 | Skip Intro button stays rounded while it fades (`695a51e9c`) | CHECK. Visual detail; compare the fork's Skip Intro fade. | S |
| 7 | Details rows composed ahead so scrolling does not stall (`e4b4286f6`); background trailer fades without an offscreen layer (`485c8a07c`) | CHECK on a device pass; SwiftUI has its own scrolling and fade costs. | S |
| 8 | Translation files (Arabic, French, audio sync, ratings strings) | SKIP. Android resources; the fork uses xcstrings. | n/a |

No ports; items 3 and 5-7 are checks only. The 2026-11-21 checks (decoder-failure fallback, position kept on source switch, episode restore, trailer fixes, hero sources) stay open.

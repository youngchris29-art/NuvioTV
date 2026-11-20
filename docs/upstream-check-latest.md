# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-20
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `e022cfdf7` — dated report `docs/upstream-port-plan-2026-11-20.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `552cacf56` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-20.md`

## NuvioMobile — 2026-11-20

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`) has not moved: still `e022cfdf7`. No new commits, no ports. Fork tip checked: `5df83303a`.
**Baseline unchanged: `e022cfdf7`.**

Carry-over still open: Stremio subtitle `label` as row title (S, 2026-11-19 item 1), TorBox alternative-hash fix, subtitle outline clamp, next-episode source fallback check, episode-ratings alignment, Trakt library refresh queueing, talk-show guest filter (all unported). Plex/Silo media servers remain deferred (no servers framework).

## NuvioTV Android — 2026-11-20

Upstream `NuvioMedia/NuvioTV` (`dev`): `acb970c42` -> `552cacf56`. 118 commits (about 95 non-merge). Commit messages read; Kotlin diffed only for file names. **New baseline: `552cacf56`.**

| # | Item (upstream commits) | tvOS verdict | Effort |
|---|---|---|---|
| 1 | Same-day upcoming episodes ordered by release time in Continue Watching (`b37084be7`, test `ContinueWatchingUpcomingSortTest`) | CHECK. Look at how the fork's Home/Continue Watching sorts upcoming episodes with equal dates; port the tiebreak if it sorts by date only. | S |
| 2 | Movies/Series filter on cast filmography (`e13bf2275`) | PORT candidate. Fork has `PersonDetailViewModel.swift`; add a type filter chip row on the person page. | S |
| 3 | Pause the detail trailer while cast or network pages cover the details (`253eaf6d4`) | CHECK on a device pass: does the fork's trailer keep playing under pushed person/network pages? | S |
| 4 | Audio-based subtitle sync fallback with ORT speech model, AutoSync status chip, sampling setting (`2defc5246` and ~45 follow-ups) | EVALUATE, not a port. Large ONNX Runtime feature; fork has `SubtitleAudioModels.kt` only for models. Needs a decision on model size, tvOS decode path (mpv/Aether) and tester demand. | XL |
| 5 | Drag reorder for catalog order, addons, collections, folders, MDBList rating providers (`TvReorderList`, ~60 commits) | CHECK. Android drag UI; the fork's Add-ons hub and Home rows already have their own ordering. Only the pinned-to-top collection ordering and MDBList provider ordering rules are worth comparing. | M |
| 6 | Collection editor unsaved-changes guard and focus restoration (`e5ec2c26c`, `0e2eb7ffd`, `67cbb11c3`) | CHECK against the fork's collection editor exit behaviour. | S |
| 7 | Confirm dialog before deleting a plugin repository (`2f58e48e5`) | CHECK whether the fork's plugin repo delete has a confirmation. | S |
| 8 | Hardware image decoding setting; decode posters at card size and match prefetch cache keys (`1ffb58f37`, `0845ea3b7`) | SKIP for the setting (Android). The card-size decode idea matches the fork's ArtworkStore; no action unless Home memory is a concern. | n/a |
| 9 | i18n: Polish, Spanish "Ajustes" strings, missing strings | SKIP (fork has its own xcstrings pipeline). | n/a |

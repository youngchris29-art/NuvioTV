# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-15
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `8ed9aa0af` — dated report `docs/upstream-port-plan-2026-11-15.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `e0e830b60` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-15.md`

## NuvioMobile — 2026-11-15

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `ba149964c` -> `8ed9aa0af`. 14 non-merge commits (4 code, 8 Vietnamese/French strings, 2 version/store). Fork tip checked: `7ae128074`.
**New baseline: `8ed9aa0af`.**

| # | Item (upstream commits) | tvOS verdict | Files in the fork | Effort |
|---|---|---|---|---|
| 1 | Player loading screen shows each start-up step (Building, Starting stream, Buffering) via a new `isOpening` flag on `PlayerPlaybackSnapshot` (`38f163e8c`) | SKIP. `PlayerLoadingStatus.kt` is composeApp-only and the fork has no counterpart in `shared/`; the tvOS player draws its own loading overlay. Idea only: the SwiftUI overlay could name the same three steps if testers ask. | none | n/a |
| 2 | Startup perf: fewer Home recompositions, stability config, hero meta repository tweak (`951ae17a9`) | SKIP / CHECK. Compose recomposition work. Only `HomeHeroMetaRepository.kt` (21 lines) is a shared candidate; confirm with `graphify explain` whether the fork has that file before dismissing. | `composeApp/.../HomeHeroMetaRepository.kt` | S, optional |
| 3 | Brand wordmark decoded off the main thread, benchmark build, baseline profile (`dc64e4aca`, `56abfaaae`) | SKIP. Android/Compose startup only. | none | n/a |
| 4 | Vietnamese and French strings, version bump, store publish (`3804f6d4f`, `98b4efea1`, `7711a04d4`, `dfc3da00b`, `6237da0f7`, `ac589b682`, `71eb7d32e`, `8922254b2`, `6b7f15e40`, `8ed9aa0af`) | SKIP. Resource files; the tvOS app uses `Localizable.xcstrings`. | none | n/a |

Carried over and still open from 2026-11-14: Next Up dismiss by content id (S, PORT), Continue Watching "On Select" (M, PORT), shared stream search sessions + source fallback (L, WATCH / DECIDE, hot files), debrid cache once per search (S), source list scroll reset (S, optional), hero gate check (S, optional).

## NuvioTV Android — 2026-11-15

Upstream `NuvioMedia/NuvioTV` (`dev`): `a3532b819` -> `e0e830b60`. 26 non-merge commits (about 12 strings: Arabic, Vietnamese, French; 2 are a revert and its reapply). Android TV app: ports are by idea, not by code.
**New baseline: `e0e830b60`.**

| # | Item (upstream commits) | tvOS verdict | Files in the fork | Effort |
|---|---|---|---|---|
| 1 | Source fallback past an auto-selected source whose debrid result cannot be played (expired result) on the stream screen and for the next-episode auto-play; sources tried are handed to the player so the configured count covers both; switching episodes restarts the fallback (`d020e4af7`, `b10a11d70`) | WATCH / DECIDE. Same area as the open shared source-fallback item (hot files `StreamsRepository.kt`, `StreamModels.kt`). Idea: when auto-pick resolves to an expired debrid result, try the next matching stream instead of dropping to the source list; reset the tried-count per episode. Fold into that batch rather than porting alone. | `shared/.../streams/StreamsRepository.kt`, `iosApp/NuvioTV/Screens/PlayerScreen.swift`, stream screen | M |
| 2 | Stremio player and library tracking addons: addons declaring the `player` or `library` resource get start/pause/stop and libraryAdd/Remove/watched events, fire-and-forget; install needs a consent checkbox (`868e6a4f0`, `9c86bb0e0`, `d1215e03e`) | DECIDE. New feature on the stremio-core protocol. A port needs a shared event dispatcher, hooks in watch progress and library, and a consent step in the Add-ons install flow. Ask Christian whether testers want it before planning. | `shared/.../addons`, watch progress and library repositories, Add-ons install UI | L |
| 3 | Episode autoplay search shows the loading overlay (`ec3863cea`) | CHECK. Verify the tvOS next-episode auto-play shows a loading state while the stream search runs; fix only with a repro. | `iosApp/NuvioTV/Screens/PlayerScreen.swift` | S, optional |
| 4 | Library empty-state wording keeps the type out and stays under the tracker buttons (`9981725ab`, `05addea18`) | SKIP. Android layout; glance at the tvOS Library empty-state copy only. | none | n/a |
| 5 | Settings stream tests labelled by connection count (`9ad4f4f5b`) | SKIP. Android settings label. | none | n/a |
| 6 | Media server subtitles kept when starting from the stream list (`c19a0e87a`) | SKIP. Media servers are not in the tvOS fork. | none | n/a |
| 7 | Ambient mode hides the on-screen keyboard; focus restore after QR (`c91ecb4ff`, `8850a555d`, `7327eabf3`, `e0e830b60`) | SKIP. Android IME handling. | none | n/a |
| 8 | Arabic, Vietnamese, French strings (`95232910c` and others) | SKIP. Android i18n. | none | n/a |

Earlier items (Continue Watching "On Select", series title on CW card, focus on playing stream, keep position on source switch) are unchanged; see the 2026-11-14 Android report.

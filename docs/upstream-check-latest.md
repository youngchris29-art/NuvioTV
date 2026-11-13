# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-13
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `805b0de87` — dated report `docs/upstream-port-plan-2026-11-13.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `9dfc70be4` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-13.md`

## NuvioMobile — 2026-11-13

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `e9f136bc7` -> `805b0de87`. 5 non-merge commits, about 40 files. Fork tip checked: `4c684b45d`.
**New baseline: `805b0de87`.**

| # | Item (upstream commits) | tvOS verdict | Files in the fork | Effort |
|---|---|---|---|---|
| 1 | Continue Watching "On Select" setting (`37e8a5c0e`): `ContinueWatchingClickAction` (STREAM default, DETAILS, DETAILS_FOR_UPCOMING), `clickAction` persisted as `click_action`, `setClickAction`, upcoming-episode rule shared with the Upcoming row | PORT. The enum, preference field and repository setter are shared and the fork has the same `ContinueWatchingPreferencesRepository`. Add the tvOS Settings row and the Home CW select handler (cloud library items keep playing; Start from beginning and manual play still open the stream). Default stays "stream"; name the new setting and its default in the release notes. Check the upcoming rule helper is not Compose-only before moving it to `shared/`. | `shared/.../watchprogress/WatchProgressModels.kt`, `ContinueWatchingPreferencesRepository.kt`, Home CW select logic in `iosApp/NuvioTV`, tvOS Settings screen, new test | M |
| 2 | Shared stream search sessions + fallback to next matching source (`8fba6c71e`): `StreamSearchSessions`, `PlayerSourceFallback`, settings (sources to try 1-10 default 3, start-up limit 5-45 s default 15 s), mutually exclusive with engine-switch-on-error | WATCH / DECIDE. The fork already has auto-play best-quality failover (`StreamAutoPlaySelector`, `PlayerScreen.swift`, `FirstPlayAutoPlay.swift`). The part worth taking is the shared search session so the picker and player source panel reuse one result set. It rewrites `StreamsRepository.kt` and `PlayerStreamsRepository.kt`, both hot files with one owning thread per batch: schedule it as its own wave, not a drive-by. Do not port the Android runtime effects. | `shared/.../streams/StreamsRepository.kt`, `player/PlayerStreamsRepository.kt`, new `StreamSearchSessions.kt`, `iosApp/NuvioTV/Screens/StreamPickerView.swift`, `PlayerScreen.swift` | L |
| 3 | Debrid cache checked once per source search, debrid account in the search key (`4c414a5f4`) | PORT only with item 2 (depends on `StreamSearchSessions`). The 7-line `LocalDebridAvailabilityService` change is harmless alone. | `shared/.../debrid/LocalDebridAvailabilityService.kt` | S (with 2) |
| 4 | Source list starts at the top when the addon filter changes (`fb026f75c`), scrolls to the playing stream (`7da9737cf`) | SKIP as code (Compose list state). Idea check: confirm the tvOS stream picker resets scroll on a filter change and the player source panel opens on the playing stream. | `iosApp/NuvioTV/Screens/StreamPickerView.swift` | S, optional |

## NuvioTV Android — 2026-11-13

Upstream `NuvioMedia/NuvioTV` (`dev`): `11689894f` -> `9dfc70be4`. 7 non-merge commits (the last is a version bump). Android TV app: ports are by idea, not by code.
**New baseline: `9dfc70be4`.**

| # | Item (upstream commits) | tvOS verdict | Files in the fork | Effort |
|---|---|---|---|---|
| 1 | Continue Watching "On Select" (`6b6e37edf`) | Same feature as NuvioMobile item 1 (NuvioMobile's commit says "same setting as NuvioTV"). Port once, from the NuvioMobile plan. | see NuvioMobile plan | M |
| 2 | Fallback to next matching source on failure (`c3a27b5e2`) | See NuvioMobile item 2: WATCH / DECIDE, the fork already has auto-play failover. | see NuvioMobile plan | L |
| 3 | Keep the series title when a CW card moves to the next episode (`fd0219950`) | CHECK. Verify the fork's next-up card keeps the series title in the tvOS Home row; fix only if a repro exists. | Home CW card model | S, optional |
| 4 | Focus the playing stream when the source panel opens (`f4e4d64b3`) | CHECK the tvOS player source panel focus; fork-side focus code differs. | `iosApp/NuvioTV/Screens/PlayerScreen.swift` | S, optional |
| 5 | Repaint letterbox bars above the libass overlay (`e30649bc0`), Indonesian strings (`a1c9229fd`) | SKIP. Android SurfaceView/libass layering; Android-only i18n. | none | n/a |

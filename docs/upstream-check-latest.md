# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-14
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `ba149964c` — dated report `docs/upstream-port-plan-2026-11-14.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `a3532b819` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-14.md`

## NuvioMobile — 2026-11-14

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `805b0de87` -> `ba149964c`. 7 non-merge commits (3 code, keyboard x2, 2 i18n, 1 upload). Fork tip checked: `9acd9407d`.
**New baseline: `ba149964c`.**

| # | Item (upstream commits) | tvOS verdict | Files in the fork | Effort |
|---|---|---|---|---|
| 1 | Dismiss a Next Up show by content id alone, old `id|season|episode` keys read as their show (`9da04b944`) | PORT. The fork's shared `nextUpDismissKey` still builds `id|season|episode`, so a dismissed show returns when the seed episode changes (anime remap, progress from another device). Change the key to the trimmed content id, add `normalizeDismissedNextUpKeys` (`substringBefore("|")`) on `setDismissed...`, load and `addDismissedNextUpKey`. Check `ContinueWatchingNextUp.kt` and `ContinueWatchingDismissedRestoreTest` / `NextUpEngineTest` for tests that assert the old key shape, and port upstream's new test. Needs no new setting. | `shared/.../watchprogress/WatchProgressModels.kt`, `ContinueWatchingPreferencesRepository.kt`, `ContinueWatchingNextUp.kt`, tests | S |
| 2 | Hero only after its source catalogs load (`1c5b22f4a`) | SKIP / CHECK. The fork solved the same flash with the BUG-86 hero commit gate (`HeroCommitGate.kt`, `HomeRepository.kt`). Idea check only: confirm the gate also holds the hero when a hero-source catalog fails or is disabled (upstream resolves on attempted, not succeeded). | `shared/.../home/HeroCommitGate.kt`, `HomeRepository.kt` | S, optional |
| 3 | Player keyboard support, up/down arrows change volume (`7620be62a`, `b4645191e`) | SKIP. Desktop/iOS keyboard handling in Compose; the tvOS remote has no volume keys in-app. | none | n/a |
| 4 | French, Slovak strings, an uploaded file (`acd28c220`, `bfb19685a`, `9c68a2147`) | SKIP. Android/Compose resources; the tvOS app uses its own `Localizable.xcstrings`. Check the French chapter-title strings only if the fork ships that setting. | none | n/a |

Carried over and still open from 2026-11-13: Continue Watching "On Select" (M, PORT), shared stream search sessions + source fallback (L, WATCH / DECIDE, hot files), debrid cache once per search (S, with the previous), source list scroll reset (S, optional).

## NuvioTV Android — 2026-11-14

Upstream `NuvioMedia/NuvioTV` (`dev`): `9dfc70be4` -> `a3532b819`. 8 non-merge commits, 2 of them strings. Android TV app: ports are by idea, not by code.
**New baseline: `a3532b819`.**

| # | Item (upstream commits) | tvOS verdict | Files in the fork | Effort |
|---|---|---|---|---|
| 1 | Keep the playback position when switching source (`520fb67cc`) | CHECK. Verify the tvOS player source panel resumes at the current position after a source switch on both engines; fix only if a repro exists. | `iosApp/NuvioTV/Screens/PlayerScreen.swift` | S, optional |
| 2 | Styled subtitles drawn at the ExoPlayer size on mpv (`eea656fd1`) | SKIP. Android mpv SurfaceView sizing. | none | n/a |
| 3 | Updater: install warning, system installer, stop re-asking after cancel (`64cfb8138`, `59313c18f`) | SKIP. Android APK updater. | none | n/a |
| 4 | Hebrew, Slovak and missing-string updates (`a393c34a3`, `b0876102f`, `25043e714`, `dee243497`) | SKIP. Android i18n. | none | n/a |

Earlier items (Continue Watching "On Select", source fallback, series title on CW card, focus on playing stream) are unchanged; see the 2026-11-13 Android report.

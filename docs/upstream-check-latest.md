# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-16
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `04cfe4af9` — dated report `docs/upstream-port-plan-2026-11-16.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `60eb9602a` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-16.md`

## NuvioMobile — 2026-11-16

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `8ed9aa0af` -> `04cfe4af9`. 32 non-merge commits (about 12 code, the rest strings, CI and version bumps). Fork tip checked: `7ae128074`.
**New baseline: `04cfe4af9`.**

| # | Item (upstream commits) | tvOS verdict | Files in the fork | Effort |
|---|---|---|---|---|
| 1 | TorBox cache check maps alternative-hash answers back to the requested hash and re-asks missing hashes (`1118dfbf8`, with test) | PORT. Real bug for TorBox users: a cached stream read as not cached. The fork's `LocalDebridService.kt` is in `shared/`, so the hunk applies (upstream path is `composeApp/`). Add `LocalDebridServiceTest` (absent in the fork). | `shared/.../features/debrid/LocalDebridService.kt`, new test | S |
| 2 | Stremio player and library tracking addons: new `AddonEvents.kt` dispatcher with per-addon queues, consent dialog, hooks in Library, Watched, player runtime (`964ecfd8d`, `8f5d9bcac`, `d89811ac6`, tests) | PORT, optional feature. Dispatcher, models and the Library/Watched/Addon repository hooks belong in `shared/` (all three repositories exist there; `ExternalPlaybackProgress` too). Needs a SwiftUI consent sheet and start/pause/stop calls from the tvOS player. Would be a new setting; name its default in release notes. Take `8f5d9bcac` and `d89811ac6` together with the first commit. | new `shared/.../addons/AddonEvents.kt`; `AddonRepository.kt`, `AddonModels.kt`, `LibraryRepository.kt`, `WatchedRepository.kt`; Swift consent sheet and player hooks | L |
| 3 | Subtitle outline width clamped to 1..5 with a default constant (`b8bbd700f`) | PORT the clamp only. The fork already has `outlineWidth` (default 2) in `shared/.../SubtitleAudioModels.kt` and persists it in `PlayerSettingsRepository.kt`. Add `subtitleOutlineWidthRange` and the two `coerceIn` calls so stale values cannot escape the range; surface a stepper in the tvOS subtitle settings only if the slider does not exist. | `shared/.../SubtitleAudioModels.kt`, `PlayerSettingsRepository.kt` | S |
| 4 | Next-episode auto-play falls back to another source when the auto-picked one fails, new `PlayerSourceFallbackRun` (`ff7500fdd`, with tests) | CHECK. Upstream logic is composeApp Compose player code. `PlayerNextEpisodeAutoPlay.kt` exists in the fork's `composeApp/` only; confirm how the tvOS player handles a dead next-episode source (`graphify explain "PlayerNextEpisodeAutoPlay"`). If tvOS stalls instead of trying the next source, port `PlayerSourceFallbackRun` into `shared/` and drive it from Swift. | `composeApp/.../PlayerNextEpisodeAutoPlay.kt` (reference), possible new `shared/` file | M |
| 5 | Library remembers last list and type, adds genre, year and watched filters (`2da28d707`) | PARTIAL. `LibraryDisplaySettings.kt` is in `shared/` and the new filter state and tests can come across; the UI (`LibrarySavedContent.kt`, `DropdownChip.kt`) is Compose, so tvOS needs a native filter bar. Defer unless testers ask for Library filtering. | `shared/.../library/LibraryDisplaySettings.kt` (+ Swift Library UI) | M-L |
| 6 | Styled subtitle overlay: keep colours, positions, top placement, merged dialogue (`9401da02f`, `c46fc19a7`, `6ae7ab660`) | SKIP. `SubtitleCuePresenter`, `StyledSubtitle*` do not exist in the fork; tvOS renders subtitles through MPV and its own SwiftUI layer. | none | n/a |
| 7 | Android gesture insets for bottom controls (`d374bdf02`) | SKIP. Android only. | none | n/a |
| 8 | iOS downloads excluded from iCloud and device backups (`718b526a6`) | SKIP. tvOS has no downloads feature. | none | n/a |
| 9 | Release CI (stable and beta, allow releases from main), version bumps, store publish 1.0.0 | SKIP. Upstream release plumbing. | none | n/a |
| 10 | Strings: Ukrainian, Simplified Chinese, pt-BR, Hebrew, RTL fixes, Urdu, French spacing | SKIP. Resource files; the tvOS app uses `Localizable.xcstrings`. Hebrew/Urdu RTL Search fix (`5964cdca7`) is Compose only. | none | n/a |

Recommended order: 1 (S, bug fix), 3 (S), then 4 after the check, then 2 as its own batch if wanted.

## NuvioTV Android — 2026-11-16

Upstream `NuvioMedia/NuvioTV` (`dev`): `e0e830b60` -> `60eb9602a`. 23 commits including merges (about 9 substantive). Android TV app; commit messages and the matching NuvioMobile diffs were read, individual Kotlin files were not diffed.
**New baseline: `60eb9602a`.**

| # | Item (upstream commits) | tvOS verdict | Effort |
|---|---|---|---|
| 1 | TorBox alternative-hash cache fix (`89989cf2b`) | Same fix as NuvioMobile item 1; one port covers both. | S (shared) |
| 2 | Subtitle outline width control (`2491dccef`) | Same as NuvioMobile item 3: clamp 1..5 only. | S (shared) |
| 3 | Styled subtitle overlay: colours, positions, merged dialogue centred next to side cues (`2c5398e85`, `eacad43c0`, `1768224fb`) | SKIP. Android overlay; tvOS uses MPV plus its own SwiftUI layer. | n/a |
| 4 | Focus fixes: collection import initial focus, collection GIF toggle theme, profile editor focus navigation (`279bc1090`, `32e467f9d`, `c90881344`) | IDEA ONLY. Compose D-pad focus; walk the tvOS collection import and profile editor in the Test profile for the same symptoms (initial focus, toggle colour while focused). | S, optional |
| 5 | mpv-android-lib 0.2.1 (`b3d0d294a`) | SKIP. Android player library. | n/a |
| 6 | Missing-string updates, French strings, Mo-unit spacing | SKIP. Resource files. | n/a |

# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-12
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `e9f136bc7` — dated report `docs/upstream-port-plan-2026-11-12.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `11689894f` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-12.md`

## NuvioMobile — 2026-11-12

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `83f07d4c2` -> `e9f136bc7`. 17 non-merge commits, 44 files (mostly Android player work, i18n and a version bump). Fork tip checked: `107f596d8`.
**New baseline: `e9f136bc7`.**

| # | Item (upstream commits) | tvOS verdict | Files in the fork | Effort |
|---|---|---|---|---|
| 1 | Stream link cache keeps tokenized links, refreshes expired saved links (`3d70db683`): drops the `hasLikelyExpiringPlaybackCredentials` guards in `StreamLinkCacheRepository`; `DirectDebridPlaybackResolver.resolve(forceRefresh)`; `StreamItem.debridResolved`; `CachedSourceRefreshCandidate` | PORT the shared half (cache + resolver + flag + its tests). The refresh-on-expiry trigger lives in Android `PlayerScreenRuntimeEffects`; wire the Swift player's error path to `resolve(forceRefresh = true)` only if a tvOS repro exists. Check `PlaybackUrlCredentials.kt` is still used elsewhere after the guards go. | `shared/.../streams/StreamLinkCacheRepository.kt`, `StreamModels.kt`, `debrid/DirectDebridResolver.kt`, `PlaybackUrlCredentials.kt`, new `StreamLinkCacheTokenTest` | M |
| 2 | Folder tabs respect "Show catalog type" (`05fd435ca`): `folderCatalogTabLabel`, `activeShowCatalogType` re-init key | PORT. The fork's `FolderDetailRepository` builds tab labels in shared and the tvOS folder view consumes them. Route `home_catalog_default_title` through the fork's `StringKey`/`resourceString` seam, not `getString`. | `shared/.../collection/FolderDetailRepository.kt`, new `FolderCatalogTabLabelTest` | S |
| 3 | Chapter title toggle (`637b21aa0`, `c3e199937`, `6ef2a6c6d`, `b3f34d25d`): `chapterTitleEnabled` setting (default On), `mpvChapters(property)` helper | PORT the setting only (shared `PlayerSettingsRepository` + storage + tvOS actual). The fork already reads chapters natively and shows `chapterTitle(at:)` on the scrub bar; add a Player setting (default On, name it in the release notes) gating that label. `mpvChapters` serves the Compose iOS bridge: skip. | `shared/.../player/PlayerSettingsRepository.kt`, `PlayerSettingsStorage.kt`, `iosApp/NuvioTV/Screens/Player/TransportBarModel.swift`, Player settings screen | S |
| 4 | HLS SPS/PPS init segment injection (`1d775bcd1`) | SKIP. Android Media3 DataSource code; AVPlayer and mpv paths differ. Revisit only if a tester reports HLS without parameter sets. | none | n/a |
| 5 | mpv: HTTP status on open failure (`f5f2c6e30`), audio-clock fallback when video time drops to 0 (`4d0e64cf2`), shared error wording (`30e3a85f3`) | WATCH. Ideas map to the fork's MPVKit error mapping and position handling; no fork repro. Triage in the next player batch. | `iosApp/NuvioTV` player error mapping | S, optional |
| 6 | DASH routing for explicit MIME hints (`25cc3e473`), Auto playback engine wording (`a7f96f8ed`) | SKIP. Android ExoPlayer routing and an Android-only string. | none | n/a |
| 7 | i18n: Dutch, French, Vietnamese, chapter and engine strings, `AppLanguage` Dutch reorder | PORT with items 2 and 3 where a string is shared; the Dutch ordering in `shared/.../settings/AppLanguage.kt` is a one-liner. | `AppLanguage.kt`, `Localizable.xcstrings` | S |
| 8 | Version bump, store publish (`4135f96cd`, `e9f136bc7`) | SKIP. | none | n/a |

Recommended order: items 2 and 3 with their strings (one small batch), then item 1. Hot-file note: item 1 touches `StreamModels.kt` and `StreamLinkCacheRepository.kt`, so one owning thread per batch.

Carried from earlier runs, still unported: MDBList remap cache (M), auth stays signed in on refresh failure (M), persisted addon subtitle by id (S), DECIDE forced-subtitles default (S). See `docs/upstream-port-plan-2026-11-10.md`.

## NuvioTV Android — 2026-11-12

Upstream `NuvioMedia/NuvioTV` (`dev`): `b8c166824` -> `11689894f`. 59 commits (about 40 non-merge), about 105 files. Android TV app: ports are by idea, not by code. NuvioMobile reaches parity on several of these, so check `cmp-rewrite` first.
**New baseline: `11689894f`.**

| # | Item | Verdict | Effort |
|---|---|---|---|
| 1 | Expired saved and tokenized link refresh (`e72921b68`, `PlayerRuntimeControllerExpiredLinkRefresh`, `DirectDebridResolver`) | Same change as NuvioMobile item 1. Port once from the Mobile side. | M |
| 2 | Subtitle appearance: font, background, shadow, live-preview editor, phone font upload (`9914a5bc7` to `8a0b393ce`, about 1,500 lines) | IDEA. The tvOS player styles subtitles through AVPlayer/mpv; importing fonts from a phone needs a tvOS-side upload server. Large; decide with Christian before scoping. | L (DECIDE) |
| 3 | Poster menus mark YouTube and add-on videos watched; single-item marks kept while a tracking provider is the source (`aaf8ed350`, `bd09e354f`) | IDEA. Check the fork's watched-mark path with Trakt or Simkl as the source. | M |
| 4 | Continue Watching: stable metadata, refresh when an upcoming episode airs, fewer launch lookups (`5924f3c95`, `7d4875ea1`) | IDEA. Compare with the fork's CW refresh; candidate for the next CW pass. | M |
| 5 | Trakt token refresh failures logged, progress polling skipped while signed out (`0b7dce79a`) | IDEA. Overlaps the open Mobile item "auth stays signed in on refresh failure". | S |
| 6 | Library: check mark for saved lists in the picker (`d976e3d07`); grid reflow fix (`ec0edb0a2`) | IDEA, small each. | S |
| 7 | Search refresh and focus fixes (`45b66a3e1` to `61bbd39d8`, `6c6302a54`) | SKIP. Compose-TV recomposition workarounds. | n/a |
| 8 | Player chapters setting and title toggle (`87da95685`, `39e7301bf`) | Same as NuvioMobile item 3. | S |
| 9 | AV1 HDR10+ OBU stripping, thermal headroom polling stop (`1b54716f7`, `76a5fb20f`) | SKIP. Android-only decoder workarounds. | n/a |
| 10 | Collections folder hero description scrolling (`96358e296`) | IDEA. Check the tvOS folder hero with long descriptions. | S |
| 11 | i18n catch-up (fr, pl, vi, others) | Pull only strings tied to ported items. | S |

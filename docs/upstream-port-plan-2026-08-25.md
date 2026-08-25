# Upstream port check — 2026-08-25

## Summary

`upstream/cmp-rewrite` (`NuvioMedia/NuvioMobile`) moved `4a0be3c1` → `f62de092`, 26 new commits (2026-08-21 through 2026-08-25). Every touched file lives in `composeApp/` (plus two mobile-only CI/script files) — **nothing in `shared/` by path**, same surface pattern as recent checks.

**But path-only is misleading this run.** This fork extracted `shared/` from upstream's `composeApp/` business logic (the `tvos-shared-extraction` lineage) — many `shared/src/commonMain/.../player/*`, `.../catalog/CatalogRepository.kt`, `.../details/MetaDetails*.kt`, `.../search/SearchRepository.kt`, `.../home/HomeCatalog*.kt`, and `.../streams/StreamAutoPlaySelector.kt` files are the **same code, relocated and de-internalized**, that tvOS actually depends on. Diffed a sample (`PlayerSettingsStorage.kt`) against upstream's `composeApp` version and confirmed: identical except `internal expect object` → `expect object`. This run's upstream batch hits several of these files directly, so — unlike a typical "composeApp-only, no action" week — there's real portable work here.

Fork state at check time: outer `main` @ `a9b42ae`. Submodule recorded pointer `e0b9ef9d` (`tvos-shared-extraction`), but actually checked out on `claude/sync-reliability` @ `9221cc5d` — expected, matches the in-progress, not-yet-merged sync-reliability port from 2026-08-24 (see that day's doc), not new drift.

## New upstream commits (`4a0be3c1..f62de092`), grouped by portability

### Group A — real `shared/` port candidates (business logic, confirmed relocated in this fork)

**A1. Subtitle/player engine batch — 10 commits, ~900 lines across `PlayerSettingsStorage.kt` (+android/ios actuals), `PlayerSettingsRepository.kt`, `PlayerTrackPreferenceStorage.kt` (+actuals), `PlayerSubtitleCueParser.kt`, `PlayerTrackSelection.kt`, `SubtitleAudioModels.kt`, `SubtitleRepository.kt`:**

- `5a60a95d` feat(player): port buffer-preserving sidecar subtitles and **remove startup mode options**
- `33c6cdc2` feat(player): parallelize addon subtitle fetching with incremental streaming
- `11221560` fix(player): restore ASS and TTML subtitle format parsing
- `47decd9d` fix(player): align forced subtitle auto-selection with TV
- `0451b02e` fix(player): select built-in subtitle immediately and preserve active selection
- `e6517baa` fix(player): prevent refreshTracks from wiping active addon subtitle selection
- `9d4560bc` fix(player): keep explicit subtitle selection after overlay close
- `2c7438d6` fix(player): make subtitle aggregation multiplatform
- (`789eeecf`, `a0bf3bff` are `SubtitleModal.kt` UI-only — see Group B)

**Confirmed this is unported:** `grep -rl "StartupMode" shared/src` still finds it in `PlayerSettingsStorage.kt`, `PlayerSettingsRepository.kt`, `PlayerTrackSelection.kt`, `SubtitleAudioModels.kt`, and the apple/jvm/android actuals — i.e. tvOS's `shared/` still carries the startup-mode concept upstream just removed in favor of buffer-preserving sidecar subtitles. This is the clearest signal the batch hasn't landed.

**Recommendation:** treat as its own dedicated port, same shape as the 2026-08-24 sync-reliability batch — a branch off the current `claude/sync-reliability` (or wherever `claude/beta15` lands), function-by-function logic port (not copy-paste — package/class shapes differ between `composeApp` and `shared`). Read each commit's actual diff in the submodule (`git show <sha>` for the 8 SHAs above) before porting. Two things worth flagging before starting:
- Removing `StartupMode` touches persisted settings (`PlayerSettingsStorage`) and the sync payload — check `PlayerSettingsRepository`'s serialization for a schema migration concern (old persisted values with a startup-mode field, now removed) before deleting the field outright.
- tvOS's subtitle rendering is native (`iosApp/NuvioTV/Screens/MPVPlayerView.swift`, `SubtitleVTT.swift`), not the Compose subtitle overlay upstream touched in the UI-only commits — but this batch's `shared/` pieces (parsing, track selection, addon fetch, aggregation) feed into whatever tvOS's native player consumes, so the port is still relevant even though the UI half isn't.

**A2. Crash-cluster fixes — from `191be42a` "fix: address mobile crash clusters (NUVIO-MOBILE-4 NUVIO-MOBILE-QK NUVIO-MOBILE-FZ)":**

Four of this commit's nine touched files are Android-Compose-only (`PlayerEngine.android.kt`, `PlayerNowPlayingService.android.kt`, `PlayerPictureInPictureManager.android.kt`, `CollectionManagementScreen.kt` UI) — not portable, no tvOS equivalent. The other four map onto `shared/` and look like genuine crash fixes worth porting:

- `SearchRepository.kt`: `resultChannel.send(...)` → `resultChannel.trySend(...)` in two spots inside a `runCatching` fold — avoids a suspend-point crash/deadlock risk when the channel is already closed or full.
- `StreamAutoPlaySelector.kt`: exclusion-word regex now escapes each word (`Regex.escape(it)`) before joining into the pattern — fixes a crash/wrong-match risk when an addon-provided exclusion word contains regex metacharacters.
- `HomeCatalogSettingsRepository.kt`: `preferences` moved from a plain `MutableMap` to an `atomicfu`-backed immutable-map reference (read via `.value`, replaced wholesale on write) — fixes a `ConcurrentModificationException` risk from concurrent map mutation.
- `HomeCatalogDefinitions.kt`: catalog-descriptor signature building rewritten from string-concatenation-with-`|`-delimiters to a proper streaming hash (`CatalogDescriptorSignature`, FNV-1a-style mix) — fixes signature collisions when a manifest field itself contains `|`, which could cause stale-catalog-not-refreshing bugs.

**Recommendation:** small, mechanical, low-risk — good candidates for a quick standalone port (half a day, four files, no UI work). Verify tvOS's `shared/` equivalents actually have the same bug shapes before porting (e.g. confirm `HomeCatalogSettingsRepository` in `shared/` still uses a mutable map) rather than assuming 1:1.

**A3. Small wins — one-liners, safe to fold into whichever port lands first:**

- `c630702f` "read per-episode rating from addon metadata" — `MetaVideo` gains `rating: Double?`, `MetaDetailsParser` reads `video.string("rating")`. `shared/features/details/MetaDetailsModels.kt` and `MetaDetailsParser.kt` are the direct targets (both exist in `shared/`, confirmed). The UI fallback wiring (`DetailSeriesContent.kt` episode cards) is Compose-only — tvOS would need its own equivalent fallback wherever it renders episode-card ratings, if it wants the UI benefit; the data-model plumbing is portable regardless.
- `96fb98c4` "fix(catalog): preserve scroll position after details" — one-line change to `CatalogRepository.kt`'s dedup guard (`isLoading` → `items.isNotEmpty() || isLoading`), so returning from a details screen doesn't re-trigger a loading flicker that resets scroll position. `shared/features/catalog/CatalogRepository.kt` is the direct target (confirmed exists).

### Group B — composeApp UI-only, no `shared/` counterpart, not portable (reference only)

- `789eeecf`/`a0bf3bff`/`9d4560bc` (UI halves) — `SubtitleModal.kt` auto-scroll/selection-persistence behavior in the Compose subtitle overlay. tvOS has its own native subtitle-track UI; if it wants matching UX (auto-scroll to active track, keep selection across overlay close) that's a separate native implementation, not a port.
- `99d7dfce` "Respect corner radius for trailers and episodes" — `DetailSeriesContent.kt`/`DetailTrailersSection.kt` Compose card styling. tvOS uses its own card/poster styling; low-priority spot-check only if the tvOS episode/trailer cards ever get a design pass.
- `PlaybackSettingsPage.kt` changes (part of A1's UI half, removing startup-mode picker) — Compose UI. Did not find an obvious tvOS "startup mode" toggle in a quick scan of `iosApp/NuvioTV/Screens` (grep for "startup" hit unrelated files — trailer/app startup, not subtitle startup mode), but this should be double-checked once the A1 `shared/` port is underway, in case a hidden toggle references the field being removed.
- `191be42a`'s Android-only files (`PlayerEngine.android.kt`, `PlayerNowPlayingService.android.kt`, `PlayerPictureInPictureManager.android.kt`) and `CollectionManagementScreen.kt` — Android Compose / notification / PiP crash fixes, no tvOS equivalent surface.
- CI/scripts: `.github/workflows/ios-test-build.yml`, `.github/workflows/android-release.yml`, `scripts/build-ios-ipa.sh`, `scripts/prepare-ios-dependencies.sh` — upstream's own mobile CI, not this fork's build pipeline.
- i18n: Greek (`0f4fcc1f`) and Bulgarian strings additions to `composeApp`'s `strings.xml` — mobile-only resource files; tvOS uses its own `.xcstrings`, out of scope unless tvOS's localization gets a dedicated pass.
- Merge commits (`f62de092`, `ec601c80`, `01506457`, `d810e035`, `f1bc3890`, `bb3cd8e9`, `fe286df4`, `60b5a35e`) — no independent content.

## Action items for Claude Code

- [ ] **[HIGH, NEW 2026-08-25] Port the subtitle/player engine batch (Group A1) into `shared/`.** 8 upstream commits, confirmed unported (`StartupMode` still present in `shared/`). Covers: buffer-preserving sidecar subtitles, parallelized addon subtitle fetch, ASS/TTML parser restoration, forced-subtitle auto-selection alignment, built-in subtitle immediate-select + selection preservation, refreshTracks no longer wiping addon subtitle selection, multiplatform subtitle aggregation fix, and removal of the startup-mode setting. Read each commit's diff in the submodule before porting; check `PlayerSettingsStorage`/`PlayerSettingsRepository` for a persisted-settings/sync-payload migration concern when removing the `StartupMode` field.
- [ ] **[MEDIUM, NEW 2026-08-25] Port the crash-cluster fixes (Group A2) into `shared/`.** Four mechanical fixes: `SearchRepository` `send`→`trySend` (avoid channel-send crash), `StreamAutoPlaySelector` regex-escape exclusion words (avoid malformed-regex crash), `HomeCatalogSettingsRepository` mutable-map→atomic-immutable-map (avoid `ConcurrentModificationException`), `HomeCatalogDefinitions` signature hashing rewrite (avoid `|`-delimiter collision causing stale catalogs). Low risk, no UI work, good candidate to knock out before or alongside A1.
- [ ] **[LOW, NEW 2026-08-25] Port the two one-line data-model fixes (Group A3).** `MetaVideo.rating` field + parser read (episode rating fallback from addon metadata) in `shared/features/details/MetaDetailsModels.kt`/`MetaDetailsParser.kt`; `CatalogRepository`'s scroll-position-preserving dedup-guard fix. Both confirmed to have direct `shared/` targets. Consider whether tvOS's episode-card UI should also consume the new `rating` fallback (separate, optional UI decision).
- [ ] **[carried, low priority, spot-check only] Player pause-description staleness.** Still open (upstream `c4934bce`, several days old) — tvOS uses a native player, not the Compose files upstream touched. Verify next time the tvOS player/pause-overlay UI gets touched.

## No action needed

- `SubtitleModal.kt` UI auto-scroll/selection-persistence (`789eeecf`, `a0bf3bff`, `9d4560bc` UI halves) — Compose-only, no tvOS equivalent surface to patch; would be a fresh native implementation if wanted, not a port.
- Corner-radius fix for trailers/episodes (`99d7dfce`) — Compose card styling, tvOS has its own.
- Android-only crash-fix files from `191be42a` (`PlayerEngine.android.kt`, `PlayerNowPlayingService.android.kt`, `PlayerPictureInPictureManager.android.kt`) and `CollectionManagementScreen.kt`.
- CI workflow / build script changes — upstream's own mobile CI pipeline.
- Greek/Bulgarian translation additions — mobile-only `composeResources`.
- Merge commits — no independent content.

## Standing decision items (unchanged since 2026-08-20)

1. **[PARKED] Supporter perks v1** (upstream `bd88760e`/`38e6ea28`/`b80ee5ab`/`52e28562`/`fbb64124`). `composeApp/`-only. Park until re-raised.
2. **[DEFERRED] Subtitle minimum font size** (upstream `d50f84fc`). tvOS's native subtitle renderer differs; decide next time player styling gets a pass.

## Next scheduled check

Re-fetch `upstream/cmp-rewrite`, diff past `f62de092`. If the A1 subtitle-engine port or A2 crash-cluster port landed, note the outcome here instead of re-investigating — grep `shared/src` for `StartupMode` as a quick "was A1 done" check (should be gone if ported and the field was actually removed). Also worth a spot-check on whether the `PlaybackSettingsPage.kt` startup-mode-picker removal has a tvOS-side counterpart to clean up.

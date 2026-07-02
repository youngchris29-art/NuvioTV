# Batch 4a (Progress + accounts — LEAVES ONLY) — Scout & execution

Batch 4 (watchprogress, watched, watching, collection, profiles, trakt) is the densely-coupled
**middle** of the dependency graph — ~60 data files with heavy cross-references and several
god-object aggregators. Christian chose to do it in two passes; **4a = clean leaves only, defer
every repository/aggregator.** This shrinks the graph so 4b's hard parts get clearer.

## Why the aggregators can't move yet

- `ProfileRepository` imports ~20 repos (downloads, mdblist, notifications, p2p, player, plugins,
  search, settings, library, home, details-settings…), almost none migrated.
- `core/storage/LocalAccountDataCleaner` imports 29 repos (clears every storage) — and
  `core/auth/AuthRepository` depends on it, so even `core/auth` is gated.
- `WatchProgressRepository` needs `core/auth` + the deferred `details/MetaDetailsRepository`.
- `details/MetaDetailsRepository`, `home/HomeRepository`, `library/*`, `features/cloud/*` are all
  unmigrated, and the trakt/collection/watchprogress repos fan into them.

So 4a moves only files whose deps are already in `:shared` (addons/tmdb/catalog/home-models/
details-models/core-sync/core-storage-ProfileScopedKey/core-profile) or are other 4a leaves.

## Moved to `:shared` (37 commonMain + 19 expect/actual pairs)

- **watchprogress:** ContinueWatchingEnrichmentCache, ContinueWatchingEnrichmentStorage(expect),
  ContinueWatchingPreferencesStorage(expect), CurrentDateProvider(expect), ResumePromptStorage(expect),
  WatchProgressClock(expect), WatchProgressRules, WatchProgressStorage(expect).
- **watched:** WatchedClock(expect), WatchedModels, WatchedStorage(expect).
- **watching:** domain/{SeriesContinuity, WatchingPolicies}, sync/{ProgressSyncAdapter,
  SupabaseProgressSyncAdapter, SupabaseWatchedSyncAdapter, WatchedSyncAdapter}.
- **collection:** CollectionCatalogResolver, CollectionJsonPreserver, CollectionMobileSettingsStorage(expect),
  CollectionStorage(expect), TmdbCollectionSourceResolver.
- **profiles:** AvatarStorage(expect), ProfileHoverHapticFeedback(expect), ProfilePinCacheStorage(expect),
  ProfileStorage(expect).
- **trakt:** TraktAuthBridge, TraktAuthStorage(expect), TraktCommentsModels, TraktCommentsSettings,
  TraktCommentsStorage(expect), TraktIdUtils, TraktImageUtils, TraktIsoDateParser, TraktLibraryStorage(expect),
  TraktPlatformClock(expect), TraktSettingsStorage(expect).

iOS actuals → `appleMain` as `*.apple.kt`; android → `androidMain`.

## Refactors applied

- **i18n:** only `TmdbCollectionSourceResolver` used Compose Resources — 12 new no-arg StringKeys
  (`collections_tmdb_*`, `collections_editor_tmdb_discover`) added to `:shared` StringProvider +
  composeApp provider; `getString(Res.string.X)` → `resourceString("<English>", StringKey.X)`.
- **Visibility:** all 19 storage/clock/haptic expects widened `internal expect`→`public expect`
  (most are `MainActivity.initialize`d across the module boundary); 6 `internal actual`s widened too.
  ~23 top-level `internal` helpers/models widened `internal`→`public` because staying composeApp
  repos/screens consume them (e.g. WatchProgressEntry, WatchedItem, WatchProgressCodec,
  TraktExternalIds/TraktImagesDto/TraktCommentsType, isWatchProgressComplete,
  resolveEffectiveContentId, parseTraktContentIds, isoCalendarDateOrNull, etc.).
- No FeaturePolicy use; no new seams (leaves-only).

## Deferred to 4b (and why)

- **Every `*Repository`** in the 6 areas (WatchProgress/ResumePrompt/ContinueWatchingPreferences,
  Watched, Collection/CollectionEditor/CollectionMobileSettings/FolderDetail, Profile/Avatar,
  TraktAuth/Comments/Library/Progress/Related/Scrobble/Settings) + CollectionSyncService.
- **Blocked leaves:** `watching/application/WatchingState` (needs `continueWatchingEntries` from
  cloud-blocked `WatchProgressModels`); `trakt/TraktPublicListSourceResolver` (needs
  `TraktListSort/SortHow` from the staying, @Immutable `CollectionModels`);
  `profiles/ProfilePinCrypto` (iOS actual uses `features.plugins.cryptointerop` cinterop) and its
  consumer `ProfilePinCache`; `watchprogress/WatchProgressModels` (cloud); `watched/WatchedRepository`,
  `watched/WatchedEpisodeActions` (deferred `sortedPlayableEpisodes`).
- All `*Screen`/dialogs/painters + `CollectionModels`/`ProfileModels` (Compose) — never move.

## Verify (run natively)

```
./gradlew :shared:compileKotlinTvosSimulatorArm64
./gradlew :composeApp:compileKotlinIosSimulatorArm64
./gradlew :shared:linkDebugFrameworkTvosSimulatorArm64
```
Likely follow-ups (same as prior batches): "public exposes internal type" on any widened data
class with an internal field type, and cross-module smart-casts in staying Compose UI on the moved
model nullables. git still blocked by stale `.git/index.lock` → used plain `mv`.

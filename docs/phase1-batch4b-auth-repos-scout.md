# Batch 4b (core/auth + models + free repositories) — Scout & execution

Christian chose "foundation + free repos." 4b breaks the two remaining foundation seams
(`core/auth`, the cloud model dep), moves the unblocked models, re-lands the 8 files reverted in
4a, and moves every repository that closes cleanly. The god-object aggregators stay.

## Seams created (the unlocks)

- **`core/account/AccountDataCleanerProvider`** (`fun interface AccountDataCleaner { wipe() }` +
  holder). `core/auth/AuthRepository.wipe()` paths called `core/storage/LocalAccountDataCleaner`
  (a 29-import god-object that clears every storage → migrates near-last). AuthRepository now calls
  the seam; composeApp installs `LocalAccountDataCleaner::wipe` at `App()` startup.
- **`features/watchprogress/CloudPosterProvider`** (`fun interface CloudPosterResolver` + holder).
  `WatchProgressModels.cloudLibraryPosterFallbackUrl()` used `features.cloud.{CloudLibraryContentType,
  cloudLibraryProviderPosterUrl}` (cloud depends on unmigrated debrid). Now delegates to the seam;
  composeApp installs the real resolver. `CloudLibraryContentType` = the const "cloud".
- Reused the existing **`ActiveProfileProvider.activeProfileId`** seam: the 3 profile-using repos
  (`CollectionSyncService`, and the deferred WatchedRepository/TraktScrobbleRepository) read only
  `ProfileRepository.activeProfileId`.

## Moved to `:shared` (21 commonMain + AuthStorage actuals)

- **core/auth:** AuthModels, AuthStorage(expect→public, +apple/android actuals), AuthRepository.
- **collection:** CollectionModels (dropped `@Immutable` + the androidx import — its only Compose
  touch), CollectionRepository, CollectionEditorRepository, CollectionMobileSettingsRepository,
  CollectionSyncService (profile seam), CollectionCatalogResolver, CollectionJsonPreserver,
  TmdbCollectionSourceResolver (all 4 latter were 4a-reverts; they needed CollectionModels which
  now moves).
- **watchprogress:** WatchProgressModels (cloud seam), WatchProgressRules (4a-revert).
- **watching/sync:** ProgressSyncAdapter, SupabaseProgressSyncAdapter (4a-reverts; need
  WatchProgressEntry which now moves).
- **trakt:** TraktAuthRepository, TraktCommentsRepository, TraktRelatedRepository, TraktAuthBridge
  (4a-revert), TraktPublicListSourceResolver (4a-revert; needed CollectionModels' TraktListSort/
  SortHow which now move).
- **profiles:** AvatarRepository.

## i18n (54 new StringKeys)

Decoupled 6 files (`AuthRepository`, `CollectionRepository`, `CollectionEditorRepository`,
`TraktAuthRepository` [StringResource-field pattern], `TraktCommentsRepository`,
`TraktPublicListSourceResolver`) via a scripted `getString(Res.string.X[,args])` →
`resourceString("<English, %N$ interpolated to ${arg}>", StringKey.X[, args])` pass. Added 54 keys
to `:shared` StringProvider enum + composeApp provider. `resourceString` was already made public in
4a. (One multi-line `runBlocking{}` wrapper left an orphan brace — fixed by hand.)

## Internal→public widenings

20 symbols consumed by staying composeApp (HomeRepository, HomeScreen, App.kt,
WatchProgressRepository, CollectionEditorScreen, tests): incl. `Collection`/`CollectionSource`/
`AvailableCatalog`/`ValidationResult`/`CollectionImportModelError`, `WatchProgressEntry`/
`StoredWatchProgressPayload`/`WatchProgressCodec`, and helpers `nextUpDismissKey`,
`toContinueWatchingItem`, `continueWatchingEntries`, `catalogRouteKey`, `findCollectionCatalog`,
`shouldStoreWatchProgress`, etc. (Scan now includes `data class` + extension funcs — the 4a gaps.)

## Deferred (still in composeApp)

- **ProfileRepository** (~20-dep god-object — migrates near-last with Home).
- **WatchProgressRepository** (player.PlayerPlaybackSnapshot + MetaDetailsRepository),
  **ResumePromptRepository**, **ContinueWatchingPreferencesRepository**.
- **TraktProgressRepository / TraktEpisodeMappingService** (MetaDetailsRepository),
  **TraktSettingsRepository / TraktLibraryRepository** (features.library), **TraktScrobbleRepository**
  (TraktProgressRepository), **WatchedRepository** (TraktSettingsRepository),
  **FolderDetailRepository** (home aggregators), **CollectionManagementScreen/Editor/FolderDetail
  Screens** (Compose).
- **ProfilePinCrypto/ProfilePinCache** (plugins cinterop), **ProfileHoverHapticFeedback**
  (tvOS UIKit — needs ios/tvos actual split).

## Verify (run natively)

```
./gradlew :shared:compileKotlinTvosSimulatorArm64
./gradlew :composeApp:compileKotlinIosSimulatorArm64
./gradlew :shared:linkDebugFrameworkTvosSimulatorArm64
```
Expect composeApp cross-module smart-casts on moved model nullables (Collection/WatchProgressEntry/
ContinueWatchingItem in staying screens) — fix with `?:`/local val. git still blocked → used `mv`.

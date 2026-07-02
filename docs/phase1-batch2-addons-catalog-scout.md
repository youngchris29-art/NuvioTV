# Batch 2 (Addons + Catalog) — Scout report & execution

Traced the actual import graph of the three packages the migration map called Batch 2
(`features/addons`, `features/catalog`, `features/tmdb`). **Finding: the mapped batch is not
movable as a whole.** catalog/tmdb lean on unmigrated aggregators and on `core/storage` +
`core/sync`, which are the "migrate-last" orchestrators. The realistic Batch 2 is **addons +
the shared home/catalog model leaves**, with `AddonRepository` unblocked by a small injected
provider. tmdb and `CatalogRepository` are deferred.

## What moved to `:shared` (DONE)

Common (`shared/src/commonMain/.../features/`):
- `addons/AddonModels.kt` — widened `toOverview()` + `enabledAddons()` `internal`→`public`
  (consumed by ~18 staying composeApp files); decoupled `generic_addon` string.
- `addons/AddonManifestParser.kt` — decoupled `addons_manifest_missing_field` (1 arg). Stays
  `internal object` (no cross-module consumer).
- `addons/AddonTransportUrls.kt` — widened `buildAddonResourceUrl()`→`public` (consumed by
  streams/details/player). `addonTransportBaseUrl` + `encodeAddonPathSegment` stay internal.
- `addons/AddonPlatform.kt` — `AddonStorage` widened `internal expect`→`public expect`
  (androidMain `MainActivity.AddonStorage.initialize()` calls it). The `httpGetText/...
  httpRequestRaw` expects were already public; ~14 staying files consume them via unchanged FQN.
- `addons/AddonRepository.kt` (`object`, no internal members) — **cycle broken** (see below);
  decoupled 6 strings.
- `home/HomeModels.kt` — defines `MetaPreview`, `PosterShape`, `stableKey`, `HomeUiState`,
  `HomeCatalogSection`. Widened `CatalogRequest` `internal`→`public` (consumed by the staying
  `CatalogRepository`). Imports only `addons.ManagedAddon` (moved) + `catalog.CatalogTarget`
  (already in `:shared` from Phase 0) → clean leaf.
- `home/HomeCatalogParser.kt` — stays `internal object` (only `CatalogData`, also moved,
  consumes it). No external imports.
- `catalog/CatalogModels.kt`, `catalog/CatalogData.kt` — widened `buildCatalogUrl()`→`public`
  (consumed by staying `SearchRepository`).

Actuals:
- `addons/AddonPlatform.ios.kt` → `shared/src/appleMain/.../AddonPlatform.apple.kt` (one actual
  serves iOS + tvOS; Darwin/ktor + NSUserDefaults). Decoupled `network_request_failed_http`
  (1 arg) + `network_empty_response_body`.
- `addons/AddonPlatform.android.kt` → `shared/src/androidMain/...` (OkHttp + `IPv4FirstDns`,
  both already in `:shared` from Batch 1). Same string decoupling.

## The one real coupling: AddonRepository ⟷ ProfileRepository (a cycle)

`AddonRepository` imported `features.profiles.ProfileRepository`, and `ProfileRepository`
imports `AddonRepository` **plus ~25 other repos** (collection, downloads, details, home,
library, mdblist, notifications, p2p, player, plugins, search, settings, streams, trakt, tmdb,
watched, watchprogress…). It is a top-of-graph god-object like `HomeRepository` — it cannot be
pulled forward without dragging the whole app.

But `AddonRepository` reads only **three shallow primitives**: `activeProfileId: Int`,
`activeProfile.profileIndex: Int`, `activeProfile.usesPrimaryAddons: Boolean`. So the cycle was
broken with the **same injected-provider pattern** used in Batch 1 for `StringProvider` and
`FeaturePolicy`:
- `:shared` `addons/AddonProfileProvider.kt` — `interface AddonProfileContext` (3 vals) +
  `object DefaultAddonProfileContext` (single primary profile) + `object AddonProfileProvider
  { var context }`.
- `AddonRepository` reads `AddonProfileProvider.context.*` instead of `ProfileRepository.*`.
- composeApp `addons/ProfileRepositoryAddonProfileContext.kt` adapts `ProfileRepository` to the
  seam; installed at `App()` startup next to `ComposeResourcesStringProvider.install()` /
  `AppFeaturePolicyAdapter.install()`. tvOS leaves the default.

This removes `:shared`→composeApp dependency, so no cycle.

## i18n decoupling (9 new keys)

Added 9 `StringKey`s to `:shared` `core/i18n/StringProvider.kt` and mapped them in composeApp
`ComposeResourcesStringProvider`: `generic_addon`, `addons_manifest_missing_field`,
`profile_primary_addons_required`, `addon_invalid_url`, `addon_already_installed`,
`addon_load_manifest_failed`, `addons_error_enter_url`, `network_request_failed_http`,
`network_empty_response_body`. Moved files call `resourceString("<English fallback>",
StringKey.x, args…)` (synchronous; dropped all `runBlocking { getString(Res.string.x) }`).
Phone app keeps every locale via the provider; tvOS = English fallbacks.

## Deferred (NOT moved) — and why

- **`features/tmdb/*` (entire stack).** `TmdbService` → `TmdbSettingsRepository` →
  `TmdbSettingsStorage` (`internal expect`), whose iOS/Android actuals import `core/sync`
  (`encode/decodeSync*`) and `core/storage` (`ProfileScopedKey`) — neither migrated. Revisit
  after `core/storage` + `core/sync` move (or break those seams too). `TmdbMetadataService`
  additionally needs `features/details/*` (Batch 3).
- **`features/catalog/CatalogRepository.kt`.** Aggregator pulling `collection` (CollectionRepo,
  TmdbCollectionSourceResolver, catalogRouteKey), `library` (LibraryRepo, toMetaPreview),
  `home` (HomeCatalogSettingsRepository, filterReleasedItems), `trakt`
  (TraktPublicListSourceResolver), `watchprogress` (CurrentDateProvider) → Batch 4/5.
- **`AddonsScreen.kt`, `CatalogScreen.kt`** — Compose UI; never move (tvOS uses SwiftUI).

## Net effect

tvOS now has, in `:shared`: the full addon HTTP layer (`httpGetText/PostJson/RequestRaw` +
RawHttpResponse), manifest parsing, addon install/enable/reorder/sync (`AddonRepository`), the
catalog URL builder + page fetch/merge/dedup (`CatalogData`), the catalog JSON parser
(`HomeCatalogParser`), and the core grid models (`MetaPreview`, `PosterShape`,
`HomeCatalogSection`, `CatalogUiState`). This is the addon → catalog fetch path. The
higher-level aggregation that fuses catalogs with collection/library/trakt (`CatalogRepository`,
`HomeRepository`) remains for Batch 4/5.

## Verify (run natively — sandbox can't build Apple targets)

```
./gradlew :shared:compileKotlinTvosSimulatorArm64
./gradlew :composeApp:compileKotlinIosSimulatorArm64        # validates commonMain (incl. App.kt wiring)
./gradlew :shared:linkDebugFrameworkTvosSimulatorArm64      # relink SharedCore for NuvioTV
# Android actual (needs SDK): ANDROID_HOME=$HOME/Library/Android/sdk ./gradlew :shared:compileDebugKotlinAndroid
```
Android `:shared` androidMain is a verbatim move (OkHttp + IPv4FirstDns already wired in
Batch 1); only env (ANDROID_HOME) blocks it locally, not code.

# Batch 3 (Details + Streams + storage/sync gate) — Scout & execution

Goal chosen with Christian: **gate + all unblocked leaves + finish tmdb**. The mapped "details +
streams" batch is mostly Compose UI (stays) plus a data layer that was gated on `core/storage` +
`core/sync`. Moving those two leaf utilities unblocked the details/streams settings/cache layer
**and** the tmdb stack deferred from Batch 2.

## The gate (the unlock)

Every settings/cache storage actual needed exactly two things, both small:
- `core/sync/SyncPreferenceJson.kt` — the `encode/decodeSync{String,Boolean,Int,Float,StringSet}`
  codecs. A clean leaf (no external deps). Moved to `:shared`; all 10 funcs widened
  `internal`→`public` (consumed by many staying settings-storage actuals, e.g. home/collection/
  player/profiles).
- `core/storage/ProfileScopedKey.kt` — built profile-scoped pref keys from
  `ProfileRepository.activeProfileId`. Broke that god-object coupling with a new
  `core/profile/ActiveProfileProvider` seam (`fun interface ActiveProfileIdProvider` +
  holder, default id 1). composeApp installs it from `ProfileRepository` at `App()` startup,
  next to the StringProvider / FeaturePolicy / AddonProfileProvider installs. tvOS uses the default.

## Moved to `:shared` (commonMain unless noted)

**tmdb (Batch 2 leftover, now unblocked):** `TmdbSettings`, `TmdbSettingsStorage`(expect)
+ apple/android actuals, `TmdbSettingsRepository`, `TmdbService`, `TmdbMetadataService`.
`TmdbMetadataService` also unblocked because the `MetaDetails/MetaPerson/MetaCompany/MetaTrailer/
MetaVideo/MoreLikeThisSource` types it needs live in `MetaDetailsModels` (moved this batch).

**details data leaves:** `HeroTrailerAudioState`, `HeroTrailerSelector`, `MetaDetailsReleaseLine`,
`PersonDetail`, `SeasonViewMode`(+`SeasonViewModeStorage` expect + apple/android actuals),
`SeriesGraphApi`, `SeriesSeasonSupport`, `RuntimeFormat`, `MetaScreenSettingsRepository`,
`MetaScreenSettingsStorage`(expect + actuals), `MetaDetailsModels`, `MetaDetailsParser`,
`CastSharedTransition`.

**streams data leaves:** `StreamModels`, `StreamParser`, `StreamBadgeRules`,
`StreamBadgePresentation`, `StreamBadgeSettingsRepository`, `StreamBadgeSettingsStorage`(expect+
actuals), `PlaybackUrlCredentials`, `StreamContextStore`, `StreamLaunchStore`,
`StreamLinkCacheRepository`(+`epochMs` expect + actuals), `StreamLinkCacheStorage`(expect+actuals),
`BingeGroupCacheRepository`, `BingeGroupCacheStorage`(expect+actuals), `StreamAutoPlaySelector`.

iOS actuals moved to `appleMain` as `*.apple.kt` (one actual serves iOS+tvOS); android actuals to
`androidMain`.

## Refactors applied while moving

- **i18n decoupling (5 files, 31 new StringKeys):** `MetaDetailsParser`, `RuntimeFormat`,
  `StreamModels`, `TmdbMetadataService`, `MetaScreenSettingsRepository`. Replaced
  `runBlocking { getString(Res.string.X[, args]) }` with `resourceString("<English fallback>",
  StringKey.X[, args])`. `MetaScreenSettingsRepository` previously held `StringResource`-typed
  section title/description fields → converted to `StringKey` + inline English fallback fields.
  Added the 31 keys to `:shared` `StringProvider` enum + composeApp `ComposeResourcesStringProvider`.
- **FeaturePolicy rewrite (2 files):** `StreamModels` + `StreamAutoPlaySelector` read
  `AppFeaturePolicy.p2pEnabled` → `FeaturePolicyProvider.policy.p2pEnabled`.
- **internal→public widenings** (consumed by staying composeApp code, incl. `MainActivity`
  storage `.initialize()` and `core/sync/ProfileSettingsSync`): all 6 storage expects
  (Tmdb/MetaScreen/SeasonViewMode/StreamBadge/BingeGroupCache/StreamLinkCache) + their
  `internal actual`s where present (MetaScreenSettingsStorage); `epochMs` expect+actuals
  (staying debrid resolvers import it); the SyncPreferenceJson codecs; and top-level helpers
  `normalizeTmdbLanguage`, `buildTmdbUrl`, `normalizeLanguage`, `castAvatarSharedTransitionKey`,
  `selectHeroTrailer`, `MetaTrailer.youtubePlaybackUrl`, `MetaDetailsParser`, `SeriesGraphApi`,
  `ImdbTapframeApi`, `metaVideoSeasonEpisodeComparator`, `normalizeSeasonNumber`, `seasonSortKey`,
  `formatRuntimeForDisplay/FromMinutes`, `String.hasLikelyExpiringPlaybackCredentials`,
  `MetaScreenSettingsRepository.applyFromSync`, plus test-consumed `StreamBadgeRulesParser`,
  `TmdbMetadataService.buildStandaloneMeta/applyEnrichment`.

## Deferred (still in composeApp) — and why

- `details/MetaDetailsRepository` — top aggregator: home (`HomeCatalogSettingsRepository`,
  `filterReleasedItems`), `mdblist.*`, `trakt.*`, `watchprogress.CurrentDateProvider`.
- `details/SeriesPlaybackResolver` — `watched.*`, `watchprogress.*`, `watching.domain.*`.
- `details/ImdbEpisodeRatingsRepository` — `library.LibraryClock`.
- `streams/StreamsRepository` — top aggregator: `debrid.*`, `player.*`, `plugins.*`,
  `details.MetaDetailsRepository`.
- `streams/StreamFetchSupport` — `plugins.*`.
- `streams/StreamAutoPlayPolicy` — `player.PlayerSettingsUiState`.
- All `*Screen.kt`, `components/*`, `StreamCard`, `StreamBadgeChip` — Compose UI (tvOS = SwiftUI).

These unlock in Batch 4/5 once watchprogress/watched/watching/trakt/mdblist/debrid/player/plugins
land.

## Tooling note

`git` was unavailable mid-batch (a stale `.git/index.lock` the sandbox couldn't remove), so files
were relocated with plain `mv` rather than `git mv`. Net on-disk result is identical; `git status`
will show the moves as delete+add rather than renames — re-add/commit normally.

## Verify (run natively)

```
./gradlew :shared:compileKotlinTvosSimulatorArm64
./gradlew :composeApp:compileKotlinIosSimulatorArm64
./gradlew :shared:linkDebugFrameworkTvosSimulatorArm64
```
Expect possible cross-module smart-cast errors in staying Compose UI (moved model nullables, e.g.
`MetaDetails`/`StreamItem` props) — same class as Batch 2's `AddonsScreen` fix; resolve with
`?:`/local val. Android `:shared` androidMain is a verbatim move (needs `ANDROID_HOME` to verify).

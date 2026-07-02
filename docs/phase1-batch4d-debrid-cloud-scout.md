# Phase 1 — Batch 4d scout: debrid + cloud

Scouted 2026-06-29, after Batch 4c (Trakt config + repos) verified green.

## Goal of the scout
The "scout first, then decide" pass over the remaining graph (~34 repos: library, player,
cloud, debrid + the top aggregators). Determine the next clean, well-scoped batch.

## Method & why the naive scan lies
1. **Import scan** (symbol defined only in composeApp) flagged *all 44* compose-free files in
   library/debrid/cloud/player as "clean" — a known false signal. Prior batches proved it misses
   (a) same-package references (Kotlin needs no import within a package), (b) generated-config deps.
2. **Same-package type scan** (types declared in staying Compose files, referenced by movers).
3. **Generated-config scan** (`grep` for `*Config` objects emitted only by composeApp's
   `GenerateRuntimeConfigsTask`).
4. **Cross-package edge scan** (`core.*` / `features.*` imports per moving file).

## Findings by area

### debrid — MOVE (17 of 18 files)
- All cross-feature imports resolve to already-migrated `:shared` (streams models all in
  StreamModels/StreamAutoPlay*/StreamBadgeRules/StreamLinkCacheRepository; addons in `:shared`).
- **1 blocker → DEFER `DirectDebridStreamPreparer.kt`**: imports
  `com.nuvio.app.features.player.PlayerSettingsUiState`, a type in the Compose-coupled
  `PlayerModels.kt` (stays). Move it with the player batch.
- **1 generated-config blocker → PLUMB**: `DebridProviderApis.kt` reads `PremiumizeConfig.CLIENT_ID`.
  `PremiumizeConfig` is a composeApp-only generated config (like TraktConfig in 4c). Plumb into
  `:shared`'s `GenerateSharedRuntimeConfigsTask` and `.delete()` the composeApp copy — **proven
  TraktConfig pattern from Batch 4c.**
- **expect/actual**: `DebridSettingsStorage` (expect) has actuals in `iosMain` + `androidMain`.
  Fold the iOS actual into `appleMain/*.apple.kt` (single actual serves iOS+tvOS) — standard.
- **i18n**: `DirectDebridResolver.kt` uses Compose `getString`/`Res.string` → decouple to
  `StringKey` + `resourceString(fallback, …)` (standard script + new StringKeys).

### cloud — MOVE (all 5 files)
- Imports only `debrid` (+ own package). Moves cleanly *with* debrid.
- **i18n**: `CloudLibraryRepository.kt` uses Compose resources → decouple (same as above).

### library — DEFER (aggregator)
- `LibraryRepository.kt` imports `core.ui` (Compose!), plus `home`, `profiles`, and 8× `trakt`
  (several trakt repos still staying). It is an aggregator, not a leaf. Belongs in the late batch.
- `LibraryModels/Storage/Clock` are individually clean but low-value to split off from the repo;
  move the whole `library` area together later.

### player — DEFER (needs model-split surgery)
- The model layer (`PlayerModels.kt` 13 types, `SubtitleAudioModels.kt` 9 types,
  `PlayerLanguagePreferences.kt` 4 types) lives in **Compose-coupled** files. ~10 otherwise-movable
  player files (PlayerSettingsRepository, PlayerTrackSelection, SubtitleRepository,
  PlayerScreenRuntime*Actions, …) depend on those types → all blocked until the pure data classes
  are extracted into movable `*Models` files. That extraction is a batch of its own.
- A handful of genuinely independent player files exist (PlayerSubtitleCueParser,
  PlayerTrackPreferenceStorage, SubtitleCacheProvider) but aren't worth a fragmented move.

## Recommended Batch 4d = **debrid + cloud** (22 commonMain files)
- Move 17 debrid leaves + 5 cloud files; fold `DebridSettingsStorage` actual into `appleMain`.
- Plumb `PremiumizeConfig` into `:shared` `GenerateSharedRuntimeConfigsTask` (input
  `PREMIUMIZE_CLIENT_ID` via `sharedRuntimeConfigValue`); delete composeApp copy.
- Decouple i18n in 2 files (`DirectDebridResolver`, `CloudLibraryRepository`).
- **Widen internal→public** (consumed by staying production code; tests resolve transitively after):
  `CloudLibraryUiState` (HomeScreen, LibraryScreen), `DebridDeviceAuthorization`,
  `DebridDeviceAuthorizationTokenResult`, `DebridProviderApis`, `DebridStreamPreferences`
  (DebridSettingsPage), plus helper ext-funs/props used by staying files: `displayName`,
  `findPlaybackTargetForProgress`, `normalized`, `withResolvedPlaybackUrl`, `queryString`.
  (Run the full widen-scan that includes `data class`/`sealed`/`value class` **and** extension
  funcs — the trap from Batch 4a.)
- **Defer**: `DirectDebridStreamPreparer` (player-model dep) + all of library + all of player.

## Verify
`:shared:compileKotlinTvosSimulatorArm64`, `:shared:compileKotlinIosSimulatorArm64`,
`:composeApp:compileKotlinIosSimulatorArm64`, `:shared:linkDebugFrameworkTvosSimulatorArm64`.

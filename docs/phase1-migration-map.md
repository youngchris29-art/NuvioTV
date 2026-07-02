# Phase 1 — Migration Map: getting real data into `:shared`

Analysis of what it takes to reuse the existing Kotlin data layer on tvOS, and the
ordered plan to do it. Based on tracing the actual import graph.

## The core finding

The data layer is **densely interconnected**, so there is no tiny "Home-only" batch:
- `HomeRepository` transitively reaches **addons, catalog, collection, profiles, trakt,
  watchprogress, details, streams** plus `core.{auth,i18n,network,sync}`.
- Even addons/catalog reference details, streams, home, collection in turn.
- **226 of 365** `commonMain` files are Compose-free (the data layer); **61 of 71**
  `iosMain` files likewise. These move into `:shared`.
- **One real coupling to break:** **38 files** use Compose Resources
  (`getString(Res.string.X)`) for user-facing strings, centralized via
  `core/i18n/LocalizedUiText.kt`. A non-Compose module can't use Compose Resources, so we
  replace that with a plain string provider (details below).

Consequence: `HomeRepository` is an **aggregator that sits at the top of the graph**, so it
moves near the *end*. We migrate bottom-up, in dependency order, and the Home screen lights
up once its dependencies are in `:shared`.

## Dependencies to add to `:shared` (from actual imports)

```
kotlinx-coroutines-core      (flow, sync, Dispatchers — heavily used)
kotlinx-serialization-json   (models + JSON)
ktor-client-core + darwin    (HTTP; darwin engine = iOS/tvOS)
io.github.jan-tennert.supabase: postgrest-kt, auth-kt, functions-kt
co.touchlab:kermit           (logging)
kotlinx-atomicfu
```
(All already in the version catalog; no Compose, coil, haze, navigation, or material3.)

## The i18n decoupling (the only refactor)

Replace the Compose-Resources string lookup with a non-Compose provider:
- Define `interface StringProvider { fun get(key: StringKey, vararg args: Any?): String }`
  in `:shared`.
- Rewrite `LocalizedUiText.kt` to call `StringProvider` instead of `getString(Res.*)`.
- Provide two implementations: (1) a simple bundled map seeded from the repo's existing
  `values/strings` (English first; other locales layered in later — the repo ships ~20),
  and (2) the SwiftUI app can inject a native provider later if we want iOS-side strings.
- This touches ~38 files mechanically (swap `getString(Res.string.x)` →
  `strings.get(StringKey.x)`); the keys already exist.

## Migration batches (dependency order)

**Batch 1 — Foundation (do first):** the bedrock everything imports.
- `core/network` (except `NetworkStatusRepository.kt` — Compose), `core/storage`,
  `core/build`, `core/format`, `core/sync`, `core/auth`.
- `core/i18n` rewritten onto the new `StringProvider` (+ the seeded English string map).
- Shared model files with no feature deps: `features/addons/AddonModels.kt`,
  `features/home/HomeModels.kt` (defines `MetaPreview`), catalog + details + stream models.
- Add the `:shared` dependencies above; add tvOS `actual`s for the foundation's
  `expect`s (mostly Darwin — reuse via an `appleMain` source set).
- ✅ Done when `:shared:linkDebugFrameworkTvosSimulatorArm64` compiles with the foundation in.

**Batch 2 — Addons + Catalog:** `features/addons/*` (minus `AddonsScreen.kt`),
`features/catalog/*` (minus `CatalogScreen.kt`), `features/tmdb/*`. Unlocks fetching
catalog rows. → first real data on the Home grid is now possible.

**Batch 3 — Details + Streams:** `features/details/*`, `features/streams/*` (data files
only). Unlocks the Details screen and stream resolution.

**Batch 4 — Progress + accounts:** `features/watchprogress`, `watched`, `watching`,
`collection`, `profiles`, `trakt`. Unlocks continue-watching + sync.

**Batch 5 — Home aggregator + the rest:** `features/home/HomeRepository.kt` and remaining
data files. Now the *real* `HomeRepository.uiState` drives the tvOS Home screen.

After each batch: `composeApp` keeps `implementation(projects.shared)` and stays buildable
(its Compose screens still compile against the moved classes); we rebuild the tvOS
framework and keep going.

## Alternative (faster to pixels, less reuse)

If you'd rather see a populated Home/Catalog screen sooner than the full migration allows,
we write a **lean self-contained catalog client** in `:shared` (a few hundred lines: addon
manifest + catalog JSON over ktor, plus minimal models) to drive the UI now, and migrate
the real repositories in the background later. Trade-off: some duplicated logic and eventual
reconciliation, against a working data-backed screen in one session instead of several.

## Recommendation

Proceed with **Batch 1 (Foundation)** of the real migration — it's the unavoidable bedrock
either way, and completing it tells us how cleanly the rest will move. The one decision that
affects Batch 1 is how to handle strings (i18n) — see question.

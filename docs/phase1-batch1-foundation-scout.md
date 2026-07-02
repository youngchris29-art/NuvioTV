# Batch 1 (Foundation) — Scout report & revised order

Traced the actual import graph of the three packages the migration map called the first
foundation move (`core/network`, `core/format`, `core/build`). **Finding: they are not all
leaves.** Only `core/format` is safe to move blindly. `core/network` and `core/build` are
entangled with (1) Gradle-generated config, (2) build flavors, and (3) cross-package
`internal` symbols consumed by code that stays in composeApp. Revised order below.

## Package-by-package

### `core/format` — CLEAN LEAF ✅ (move now)
- One file: `ReleaseDateDisplay.kt`. Only non-stdlib import is
  `com.nuvio.app.core.i18n.localizedMonthName` — already in `:shared`.
- No `internal` decls. All ~8 consumers are Compose screens that stay in composeApp and
  resolve it via `implementation(projects.shared)`. (Optional: also move its `commonTest`.)
- **Action:** move file → `:shared`, delete composeApp copy. Zero new deps. Trivial.

### `core/build` — FLAVOR-COUPLED ⚠️ (needs redesign, not a move)
- `AppFeaturePolicy.kt` is `expect object AppFeaturePolicy` with actuals in **distribution
  flavor** source sets, not platform ones: `iosFull`, `iosAppStore`, `androidFull`,
  `androidPlaystore`, `desktopMain`. Flavors differ materially (e.g. `pluginsEnabled`,
  `p2pEnabled`, `trailerPlaybackMode`).
- `:shared` has **no flavor source sets** — moving the expect there means one actual per
  platform, which destroys the full/appstore distinction composeApp depends on.
- Actuals also read generated `AppBuildConfig.IS_DEBUG_BUILD`.
- **Recommended approach (StringProvider pattern, not a move):** keep flavor policy in
  composeApp; add an injected `FeaturePolicy` holder/interface in `:shared`
  (`object FeaturePolicyProvider { var policy }`). composeApp populates it from its
  `AppFeaturePolicy` at startup; tvOS populates its own values. Shared-side consumers read
  the holder. (`AppVersionConfig` itself is just generated data — moves with the config
  plumbing below; it isn't flavor-coupled.)

### `core/network` — GENERATED-CONFIG + INTERNAL-LEAK ⚠️ (move after plumbing)
- Files: `SyncBackendConfig.kt`, `SupabaseProvider.kt`, `SyncBackendRepository.kt`,
  `SyncBackendStorage.kt` (+ `expect`), and `NetworkStatusRepository.kt`.
- **`NetworkStatusRepository.kt` STAYS** in composeApp: it's Compose (`@Composable`,
  `stringResource`, `Res.*`) and imports `features.addons.httpRequestRaw`.
- **Internal leak:** `SyncBackendRepository`, `SupabaseProvider`, `SyncBackendConfig`,
  `StoredSyncBackendSelection`, `SyncBackendStorage`, `fetchSyncBackendManifestText` are
  `internal` and consumed *outside* the package by files that stay in composeApp for now:
  `core/auth`, `core/sync`, `features/{settings,home,collection,watching/sync,addons,library,
  dev,profiles}`, `App.kt`, `MainActivity`. Per the known gotcha, `internal` is invisible
  across the module boundary → these must become `public` (or `@PublishedApi internal`) when
  the files move. Mechanical but touches many decls.
- **Generated config dep:** `SupabaseProvider` needs `AppVersionConfig` +
  `SupabaseConfig`; `SyncBackendRepository` needs `SyncBackendBootstrapConfig`. These are
  emitted by the `generateRuntimeConfigs` Gradle task into composeApp's build dir and added
  to **composeApp `commonMain`** via `kotlin.srcDir(generatedRuntimeConfigDir)`
  (build.gradle.kts ~L368). For `:shared` to compile these files, the generated config must
  be produced into / visible to `:shared`.
- **expect/actual:** `SyncBackendStorage` + `fetchSyncBackendManifestText` have an `iosMain`
  actual using ktor-Darwin + `NSUserDefaults` — both available on tvOS. An **`appleMain`**
  source set in `:shared` (shared by iosMain + tvosMain) serves both with one actual; add an
  android actual (mirror existing `SyncBackendStorage.android.kt`).

## The plumbing gate (blocks build + network)

`generateRuntimeConfigs` currently targets composeApp only. To move config-dependent files:
- Replicate/relocate generation so the generated classes live in `:shared` (e.g. register an
  equivalent task in `shared/build.gradle.kts` outputting to a shared `srcDir`).
- **Avoid duplicate-class clashes:** the same FQNs (`com.nuvio.app.core.network.SupabaseConfig`,
  `...core.build.AppBuildConfig`, etc.) must be generated in exactly **one** module. If they
  move to `:shared`, composeApp gets them transitively and must stop generating its own —
  but composeApp *also* generates feature configs (trakt, debrid, tmdb, community, intro-db,
  imdb) that aren't moving yet. So split generation: shared-bound configs (Supabase, version,
  build, sync-bootstrap) generated in `:shared`; the rest stay in composeApp.
- `local.properties` + version inputs must be wired into the `:shared` task too.

## Revised migration order (replaces "network/format/build first")

1. **`core/format`** → `:shared`. Trivial leaf; do first to keep momentum. ✅ ready now
2. **Add `:shared` deps**: coroutines, ktor-core + ktor-darwin, supabase (postgrest/auth/
   functions), kermit, atomicfu. Create `appleMain` (+ `androidMain`) source sets.
3. **Config plumbing**: generate Supabase/version/build/sync-bootstrap config into `:shared`;
   remove those four from composeApp's generator; keep feature configs in composeApp.
4. **`FeaturePolicy` injection** in `:shared`; composeApp + tvOS provide values.
5. **`core/network`** (minus `NetworkStatusRepository`): widen leaked `internal`→`public`,
   move files, add `appleMain`/`androidMain` actuals for `SyncBackendStorage`.

Steps 2–4 are the real gate; step 1 is independent and can land immediately.

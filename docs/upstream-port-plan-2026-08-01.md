# Upstream port check — 2026-08-01 (scheduled)

## Headline: the `simkl` branch has merged into `cmp-rewrite` — the watch item from 07-29/07-31 is now actionable

`upstream/cmp-rewrite` (NuvioMedia/NuvioMobile) moved `979d5680` → `3ba9cfd4` (~90 commits, tag `0.4.0` cut at the tip). The bulk of that movement is `upstream/simkl` — previously tracked across the 07-29 through 07-31 checks as "too large and unstable to port, revisit when it merges or goes quiet" — merging in via PR #1608/#1637 etc. That revisit trigger has now fired. This is a big, structural change, not a quick diff-and-patch. Read the whole doc before starting work; **do not** blindly transcribe the upstream diff.

Fork state: outer repo HEAD `e70424e` (beta.9 bugfix tracker docs, fork-only); submodule pinned `cdc1f162` (`tvos-shared-extraction` branch, `tvos-v0.3.0-beta.7-18-gcdc1f162`). Nothing upstream-derived has landed since the last port.

---

## Item A — small, independent, ready to apply now: "mark as unwatched" bug for whole series

Upstream commit `0e1e12a8` (2026-07-31, skoruppa). One-line bug: toggling "watched" off for a whole series only checked `WatchedRepository.isWatched(...)`, which misses series that are tracked via the separate `_fullyWatchedSeriesKeys` bucket — so the wrong branch of the toggle ran and the series didn't actually get marked unwatched.

Confirmed present in tvOS: `shared/src/commonMain/kotlin/com/nuvio/app/features/watched/WatchedRepository.kt` already has `_fullyWatchedSeriesKeys` (lines 115-116, 182, 880) but has **no** public accessor for it, and `shared/src/commonMain/kotlin/com/nuvio/app/features/watching/application/WatchingActions.kt` line 32 has the same unguarded `isWatched(...)` check — same bug, unfixed.

Fix (2 files, ~6 lines total):

1. In `WatchedRepository.kt`, add public accessor (upstream added this right after the existing `isWatched` function, near line 838 upstream):
```kotlin
fun isFullyWatchedSeries(id: String, type: String): Boolean {
    val key = watchedItemKey(type, id)
    return _fullyWatchedSeriesKeys.value.contains(key)
}
```
Match tvOS's actual `watchedItemKey`/`_fullyWatchedSeriesKeys` signatures at the port site — the field already exists in tvOS's file, just confirm the key-building helper name matches (it does, both are named `watchedItemKey`).

2. In `WatchingActions.kt` line ~32, change:
```kotlin
val isCurrentlyWatched = WatchedRepository.isWatched(
    id = preview.id,
    type = preview.type,
)
```
to:
```kotlin
val isCurrentlyWatched = WatchedRepository.isWatched(
    id = preview.id,
    type = preview.type,
) || WatchedRepository.isFullyWatchedSeries(id = preview.id, type = preview.type)
```

Low risk, no dependency on the Simkl work below. Build + verify a fully-watched series can be toggled back to unwatched from the details screen.

---

## Item B — independent, needs a product/architecture call: upstream removed realtime Supabase sync entirely

Commit `db87075b` (2026-07-31, tapframe): upstream deleted `RealtimeSyncInvalidationService.kt` outright (180 lines), stripped the wiring from `SyncManager.kt` (71 lines) and `App.kt` (34 lines), dropped the Supabase realtime dependency from `gradle/libs.versions.toml`, and removed its test file. Not a bug fix — a deliberate architecture removal, no upstream commit message/PR body explaining why (title is just "Remove realtime sync support").

tvOS's `shared/` still has the full realtime stack: `core/sync/RealtimeSyncInvalidationService.kt`, `RealtimeSyncRetryPolicy.kt`, `RealtimeEndpointProbe.kt`, plus the `SupabaseProvider.kt` realtime import and `SyncManager.kt` wiring — none of this has been removed.

**Do not mechanically delete this in tvOS without checking first.** Before acting:
- Check whether upstream's realtime removal is a reaction to a cost/reliability problem (Supabase realtime channel limits, battery/connection issues) or is simply superseded by the library delta-sync work tvOS already ported on 2026-07-29 (`LibrarySyncReconciler`, cursor-based pull). If cross-device instant invalidation is still valuable for tvOS (e.g., a mobile client marks something watched and tvOS should reflect it without waiting for the next poll), keep it.
- If you do decide to remove it, this is mechanical (delete 3 files + revert the `SyncManager.kt`/`SupabaseProvider.kt`/gradle wiring) — but confirm no other tvOS-only code (e.g., Top Shelf refresh triggers, background refresh) depends on the realtime invalidation callback first.

This is a judgment call for Christian/Claude Code to make together, not a rubber-stamp port.

---

## Item C — the big one: provider-neutral tracking abstraction + full Simkl anime-tracking feature

**Scope, stated plainly:** 170 files changed upstream, +15,642/-2,523 lines, spanning a brand-new `features/tracking/` abstraction layer, a brand-new `features/simkl/` feature (27 files), and a rewrite of the existing Trakt integration plus `WatchedRepository`, `WatchProgressRepository`, `LibraryRepository`, and `SyncManager` to route through the new abstraction instead of calling Trakt directly. None of this exists in tvOS's `shared/` yet (`find shared/src -iname "*simkl*" -o -iname "*tracking*"` returns nothing).

**This should not be executed as a single mechanical diff-port.** It rewires the sync/watch-state spine that's already shipped to beta users on tvOS (Trakt integration, `[[nuvio-tvos-port]]` per-profile auth isolation). Recommend treating it as its own multi-phase project with a scoping session first, not a nightly patch job.

### What upstream built

**New abstraction layer — `features/tracking/`** (9 files, ~920 lines): a provider-neutral interface so the app can register N tracking backends (currently Trakt + Simkl) instead of hardcoding Trakt everywhere.
- `TrackingProvider.kt` (252 ln) — core provider interface/registry (`TrackingProviderRegistry.registerLibraryProvider/registerWatchedProvider/registerProgressProvider`, referenced from the new `TrackingProviderBootstrap.kt`).
- `TrackingReads.kt` (156 ln) / `TrackingWrites.kt` (94 ln) — read/write contracts each provider implements.
- `TrackingSources.kt` (54 ln) — `effectiveLibrarySourceMode` / `effectiveWatchProgressSource` (replaces the old Trakt-only `effectiveLibrarySourceMode`/`shouldUseTraktProgress` that `SyncManager.kt` used to import directly from `features/trakt`).
- `TrackingSettings.kt` (43 ln), `TrackingAttribution.kt` (35 ln), `TrackingLibraryMembership.kt` (31 ln), `TrackingMedia.kt` (165 ln), `TrackingScrobbleCoordinator.kt` (93 ln).
- New wiring entry point: `core/tracking/TrackingProviderBootstrap.kt` (32 ln) — `ensureTrackingProvidersRegistered()`, called once at startup, registers both Trakt and Simkl providers into the registry. Full contents already pulled and shown below since it's short and is the map of every symbol the rest of the port touches:

```kotlin
package com.nuvio.app.core.tracking

import com.nuvio.app.features.simkl.SimklAuthRepository
import com.nuvio.app.features.simkl.SimklMutationRepository
import com.nuvio.app.features.simkl.SimklLibraryRepository
import com.nuvio.app.features.simkl.SimklProgressRepository
import com.nuvio.app.features.simkl.SimklTrackingLibraryProvider
import com.nuvio.app.features.simkl.SimklTrackingProgressProvider
import com.nuvio.app.features.simkl.SimklWatchedSyncAdapter
import com.nuvio.app.features.simkl.SimklSyncRepository
import com.nuvio.app.features.tracking.TrackingProviderRegistry
import com.nuvio.app.features.trakt.TraktAuthRepository
import com.nuvio.app.features.trakt.TraktScrobbleRepository
import com.nuvio.app.features.trakt.TraktTrackingLibraryProvider
import com.nuvio.app.features.trakt.TraktTrackingProgressProvider
import com.nuvio.app.features.watching.sync.TraktWatchedSyncAdapter

fun ensureTrackingProvidersRegistered() {
    TraktAuthRepository.descriptor
    TraktScrobbleRepository.ensureRegistered()
    SimklAuthRepository.descriptor
    SimklSyncRepository.state
    SimklLibraryRepository.uiState
    SimklProgressRepository.uiState
    SimklMutationRepository.ensureRegistered()
    TrackingProviderRegistry.registerLibraryProvider(TraktTrackingLibraryProvider)
    TrackingProviderRegistry.registerLibraryProvider(SimklTrackingLibraryProvider)
    TrackingProviderRegistry.registerWatchedProvider(TraktWatchedSyncAdapter)
    TrackingProviderRegistry.registerWatchedProvider(SimklWatchedSyncAdapter)
    TrackingProviderRegistry.registerProgressProvider(TraktTrackingProgressProvider)
    TrackingProviderRegistry.registerProgressProvider(SimklTrackingProgressProvider)
}
```

Note upstream also added `TraktTrackingLibraryProvider`/`TraktTrackingProgressProvider` — i.e. Trakt itself got wrapped in adapter classes to conform to the new provider interface. tvOS's existing Trakt code (`shared/features/trakt/*`, 21 files, already ported and working with per-profile auth isolation) would need these same adapter wrappers, not a rewrite of the underlying Trakt logic.

**New feature — `features/simkl/`** (27 files, ~4,120 lines): a full Simkl.com integration for anime tracking (MAL/Kitsu ID resolution per-season, since Simkl indexes anime differently than TMDB/Trakt), PKCE OAuth, and scrobble/library/progress sync — architecturally parallel to Trakt but for a different provider.

| File | Lines | Purpose |
|---|---|---|
| `SimklAuthModels.kt` / `SimklAuthParsing.kt` / `SimklAuthRepository.kt` | 72 / 64 / 427 | OAuth token models, response parsing, the auth repository itself |
| `SimklPkce.kt` | 51 | PKCE code-verifier/challenge generation for the OAuth flow |
| `SimklApiClient.kt` / `SimklApiMetadata.kt` | 324 / 47 | HTTP client + API metadata for Simkl's REST API |
| `SimklApplicationAdapters.kt` | 242 | Wires Simkl into the app-level `TrackingProvider` contracts |
| `SimklAnimeIdPreference.kt` / `SimklAnimeWatchedFallback.kt` | 30 / 37 | User-selectable anime-ID resolution + fallback watched-state logic for shows with mismatched season/episode counts across providers |
| `SimklLibraryAdapter.kt` / `SimklLibraryProjection.kt` | 266 / 126 | Library (watchlist) sync adapter + read-model projection |
| `SimklMutationReceipt.kt` / `SimklMutationReconciliation.kt` / `SimklMutationRepository.kt` | 278 / 152 / 499 | Local-first mutation queue with server reconciliation (offline-tolerant writes) |
| `SimklPlaybackReconciliation.kt` / `SimklScrobbleReconciliation.kt` / `SimklScrobbleResult.kt` | 70 / 260 / 153 | Scrobble (play-progress) reconciliation logic |
| `SimklProjections.kt` | 585 | Largest file — read-model projections combining Simkl state with local metadata |
| `SimklRefreshPolicy.kt` | 69 | Rate-limit/backoff policy for API refresh calls |
| `SimklSyncEngine.kt` / `SimklSyncModels.kt` / `SimklSyncRemote.kt` / `SimklSyncRepository.kt` / `SimklSyncStorage.kt` | 137 / 199 / 99 / 267 / 7 | Sync orchestration + persistence |
| `SimklWatchDiagnostics.kt` | 127 | Diagnostic logging for sync/watch state issues |
| `SimklBrandPainter.kt` / `SimklPlatform.kt` | 12 / 20 | Compose-only brand icon painter + `expect`/`actual` platform hook (has `.ios.kt`/`.android.kt` actuals — tvOS would need a `.tvos.kt` or shared-with-ios actual) |

**Refactored existing files** (these are where the risk is — high blast radius, already-shipped code):
- `features/watched/WatchedRepository.kt` (+507/-diff) and `features/watchprogress/WatchProgressRepository.kt` (+416/-diff) — rewritten to read/write through `TrackingProviderRegistry` instead of Trakt-specific calls directly.
- `core/sync/SyncManager.kt` (198 lines touched) — swaps `import com.nuvio.app.features.trakt.{TraktAuthRepository,TraktPlatformClock,TraktSettingsRepository,effectiveLibrarySourceMode,shouldUseTraktProgress}` for `import com.nuvio.app.features.tracking.{TrackingProviderRegistry,TrackingSettingsRepository,WatchProgressSource,effectiveLibrarySourceMode,effectiveWatchProgressSource}`. This is the file that actually rewires the sync loop tvOS relies on today.
- `features/library/LibraryRepository.kt` (378 lines touched), `features/library/LibraryModels.kt`, `LibraryDisplaySettings.kt`, `LibrarySavedContent.kt`.
- New file `features/watchprogress/WatchProgressMetadataProjection.kt` (92 ln, new) + `WatchProgressSourceProjection.kt` (new) — includes the small "take videoid from meta for track services" fix (`ebbc9709`) as part of its initial content, not a separate patch.
- `features/watching/application/WatchingActions.kt` / `WatchingState.kt`, `features/watching/sync/{TraktWatchedSyncAdapter,WatchedSyncAdapter}.kt`.

**UI-only, Compose-specific, not portable as Kotlin** (would need hand-built SwiftUI equivalents, separate from this backend port — same pattern as prior "UI batch" work): `TrackingSettingsPage.kt` (634 ln, new, replaces the old 823-line `TraktSettingsPage.kt`), `TrackingProviderCards.kt` (784 ln, new), `TrackingAdaptivePicker.kt` (255 ln, new), `SimklSyncInfoDialog.kt` (112 ln, new), `TrackingListPickerDialog.kt` (renamed from `TraktListPickerDialog.kt`), plus `HomeScreen.kt`/`HomeContinueWatchingSection.kt`/`MetaDetailsScreen.kt`/`LibraryScreen.kt`/`ProfileSelectionScreen.kt`/`SettingsScreen.kt` touch-ups and the `abbfb62b` "badges to TmdbEntityBrowser" commit (ties into `SimklApplicationAdapters.kt`/`SimklProjections.kt`).

Upstream also added ~15 new test files under `commonTest` for Simkl/tracking (`SimklApiClientTest`, `SimklSyncEngineTest`, `SimklMutationReconciliationTest`, `TrackingReadsTest`, etc., ~3,700 lines of tests) — worth pulling over if/when the corresponding production code is ported, since they'd validate the reconciliation logic tvOS would be adapting blind otherwise.

### Recommended approach — do not attempt in one pass

1. **Product decision first (Christian):** does tvOS want Simkl anime tracking as a feature right now? Trakt already covers general watch tracking; Simkl's value-add is specifically better anime season/episode ID resolution (MAL/Kitsu). This is a scope call, not an engineering one — make it before writing code.
2. **If yes — Phase 1 (de-risking, no visible behavior change):** port the `features/tracking/` abstraction layer + wrap tvOS's existing Trakt code in the new provider adapters (`TraktTrackingLibraryProvider`/`TraktTrackingProgressProvider`), and refactor `SyncManager.kt`/`WatchedRepository.kt`/`WatchProgressRepository.kt`/`LibraryRepository.kt` to route through `TrackingProviderRegistry` with **only Trakt registered**. Ship and verify this produces byte-identical sync behavior to today before adding a second provider — this isolates "did the refactor break Trakt" from "does Simkl work" as two separate questions.
3. **Phase 2:** port the 27-file `features/simkl/` package (backend only — auth, API client, sync engine, mutation reconciliation). No UI yet; verify via unit tests (port the upstream Simkl test suite alongside) that auth + sync + reconciliation work standalone.
4. **Phase 3:** register Simkl into the provider registry alongside Trakt, verify combined sync behavior (both providers active, conflict resolution when both are enabled).
5. **Phase 4 (separate SwiftUI effort, own scoping pass):** design and build tvOS-native Settings > Tracking UI (provider picker, Simkl connect flow, sync status) — this is net-new 10-foot UI design work, not a port, and should be scoped like the prior Liquid Glass/UI-batch efforts (`[[nuvio-tvos-remaining-scope]]`, `[[nuvio-tvos-ui-improvements]]`).

Do **not** start with Phase 2/3 before Phase 1 lands and is verified — that would mean debugging both a sync-layer refactor and a brand-new OAuth provider at the same time.

---

## Confirmed N/A this run

- `ad1b8b79` "handle torrent cache pressure on Android" — Android-only (`P2pStreamingEngine.android.kt`).
- `2de02d53`/`c53b2173` Slovak (`values-sk`) localization strings — tvOS uses its own `resourceString`/`StringKey` i18n system, not upstream's Compose string resources.
- `d92b4d4c` "remove recent history icons" from search — pure Compose UI, no shared logic.
- `3ba9cfd4` version bump, `289ea2c4` XML declaration cleanup — packaging noise, not applicable to tvOS's own beta/build numbering.
- All `androidApp/`, `androidMain/`, `iosApp/Configuration/Version.xcconfig` changes — platform-specific to the upstream mobile app.

## Other upstream branches — no change

`upstream/copilot/refactor-project-structure` still stale at `cbc9fc4f` (March 2026), no merge-base with `cmp-rewrite` — treat as abandoned unless it resurfaces.

## For Claude Code (this session)

1. Apply **Item A** now — trivial, isolated, safe.
2. Investigate and decide on **Item B** (realtime sync removal) — check for any tvOS-specific dependency on `RealtimeSyncInvalidationService` before touching it; this is a judgment call, not a mechanical port.
3. For **Item C**, don't write code yet — first get Christian's product decision on Simkl support, then treat Phase 1 (tracking abstraction + Trakt adapter wrap, zero behavior change) as its own scoped session with its own plan, verified independently before Phase 2 (Simkl backend) is touched. This doc has the full file inventory and architecture map needed to scope that Phase 1 session; re-fetch the actual file contents from `upstream/cmp-rewrite` at `3ba9cfd4` (or later) when starting, since this doc doesn't embed the full diff.

## Next scheduled check

- Re-verify Item A landed (`grep isFullyWatchedSeries shared/src/commonMain/kotlin/com/nuvio/app/features/watching/application/WatchingActions.kt`).
- Re-check `cmp-rewrite` tip movement past `3ba9cfd4`.
- Check whether Phase 1 of Item C has been scoped/started in a Claude Code session; if so, stop re-reporting the full Item C breakdown each day and just track phase progress instead.

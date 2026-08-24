# Upstream port check — 2026-08-24

## Summary

`upstream/cmp-rewrite` (`NuvioMedia/NuvioMobile`) moved `e27b9195` → `4a0be3c1`, 20 new commits (2026-08-23 21:40 through 2026-08-24 11:20). Every touched file lives in `composeApp/` or upstream's own `iosApp/iosApp/` (their mobile SwiftUI companion, not this fork's `iosApp/NuvioTV/`) — **nothing in `shared/`**, same pattern as the last several checks.

Fork state at check time: outer `main` @ `399a9ea0`. Submodule `NuvioMobile` recorded pointer `e0b9ef9d` (`tvos-shared-extraction`) — but the submodule is currently checked out on branch `claude/beta15` @ `207b1298` (in-progress beta.15 work, not yet merged back to `tvos-shared-extraction`; this is expected per `docs/beta15-implementation-plan-2026-08-23.md`, not pointer drift).

**Two items from the 2026-08-23 report are now resolved — verified by reading current file contents, not just commit messages:**

- **Addon delete-confirmation** — `iosApp/NuvioTV/Screens/AddonsView.swift` now has `addonPendingRemoval` + a destructive `.alert()` ("Remove ‑ its catalogs and streams will no longer appear") gating `model.remove(addon)`, wired from the row's `onRemove` closure (line 108). Matches CLAUDE.md's note that this landed as `23079774` on `claude/beta15`. **Drop from open items.**
- **Simkl anime-movie fix comparison** — done (see §1 below). tvOS's `shared/` logic is already at parity with, and in one respect ahead of, upstream's newest fix. **Drop from open items — no port needed.**

## New upstream commits (`e27b9195..4a0be3c1`)

### 1. `15df9555` — "Last fixes for anime movies in Simkl" (resolves the standing comparison item)

Upstream's `composeApp/.../simkl/SimklProjections.kt` now computes `isAnimeMovie` as `type == "movie" || (library cross-reference on animeType == "movie")` — i.e. it converged to using **both** signals this fork's `shared/` version already combines (the session's explicit `type` marker, per this fork's earlier "Codex review of 6e5e41f3" divergence, OR a library cross-reference when no type marker is present).

Diffed against tvOS's current `shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklProjections.kt:402-409`:

```kotlin
val isAnimeMovie = mediaType == SimklMediaType.ANIME && type == null && libraryEntries.any { entry ->
    entry.mediaType == SimklMediaType.ANIME &&
        entry.animeType == "movie" &&
        entry.media?.toTrackingExternalIds()?.sharesIdentityWith(sessionIds) == true
}
val isMovie = mediaType == SimklMediaType.MOVIES ||
    (mediaType == SimklMediaType.ANIME && type == "movie") ||
    isAnimeMovie
```

tvOS's version is functionally equivalent to upstream's newest combined check, **plus one refinement upstream still lacks**: tvOS only consults the library cross-reference when `type == null` (an explicit `type == "episode"` marker always wins), whereas upstream's library cross-reference runs unconditionally alongside the type check. tvOS's gating is strictly safer — it can't have a library-detected "movie" override an explicit episode session.

**No action. tvOS's divergence already covers upstream's latest fix and is arguably more correct.** Close out the standing investigation item.

### 2–8. Sync/network reliability batch — `8be6fa9e`, `ecae8ac3`, `0e9a1ebe`, `67b865a7`, `f9c13a9b`, `d0c7bff7`, `eb8fce23` (+ merge commit `c47f99ba`)

Seven related perf/reliability fixes to composeApp's sync stack, all merged together 2026-08-23 21:56–2026-08-24 09:17:

- `8be6fa9e` **fix(network): honor backend retry delays** — new `BackendRateLimit.kt` (+test) in `composeApp/core/network/`, patches `SupabaseProvider.kt` to respect a 429/Retry-After-style backend delay instead of hammering the endpoint.
- `ecae8ac3` **perf(sync): suppress duplicate full profile pulls** — `SyncManager.kt` gains a guard against redundant full-profile-pull calls.
- `0e9a1ebe` **perf(sync): throttle plugin and addon requests** — `AddonRepository.kt` + `PluginRepository.kt`/`PluginModels.kt` gain request throttling.
- `67b865a7` **perf(sync): seed only missing provider credentials** — `ProviderCredentialSync.kt`/`Models.kt` skip re-seeding credentials that are already present.
- `f9c13a9b` **perf(home): remove legacy catalog sync reads** — `HomeCatalogSettingsSyncService.kt` drops a stale read path.
- `d0c7bff7` **perf(progress): deduplicate terminal sync writes** — `WatchProgressRepository.kt` gains dedup logic for "terminal" (finished/stopped) progress writes, new `RemoteProgressWriteDeduplicatorTest.kt`.
- `eb8fce23` **perf(sync): reduce foreground polling requests** — `AppForegroundMonitor.kt` (+ android/ios actuals) and `SyncManager.kt` reduce how often foreground re-entry triggers a sync poll.

**All land in `composeApp/`, none in `shared/` — but this is the batch worth real investigation, not a "no action" like most composeApp-only items.** Checked whether `shared/`'s parallel implementations (which is what tvOS's native app actually depends on for sync) already have equivalent protections:

- `shared/src/commonMain/kotlin/com/nuvio/app/core/sync/SyncManager.kt` — grepped for `throttle|dedup|duplicate|debounce|minInterval|retryAfter|429|backoff`: **zero matches.** No duplicate-profile-pull guard, no foreground-polling throttle.
- `shared/src/commonMain/kotlin/com/nuvio/app/features/watchprogress/WatchProgressRepository.kt` — no terminal-write dedup logic (one unrelated comment matched "duplicate").
- `shared/src/commonMain/kotlin/com/nuvio/app/features/addons/AddonRepository.kt` — has manifest-URL dedup (`dedupeManifestUrls`) but no request-throttling.
- `shared/src/commonMain/kotlin/com/nuvio/app/core/network/SupabaseProvider.kt` — has a basic Ktor `HttpRequestRetry` plugin (retries on `SupabaseEndpointConfig.shouldRetryWithFallback`) but nothing that parses/honors a backend-supplied retry delay (no 429-specific handling).
- Plugins: `shared/` has no `PluginRepository.kt` at all (only `PluginModels.kt`, `PluginContentIds.kt`, `PluginScraperHost.kt`, `PluginSync.kt`) — tvOS's plugin request pattern isn't a structural match for `0e9a1ebe`, so that specific throttle likely doesn't map 1:1.

Since `composeApp`'s sync stack and `shared`'s sync stack appear to be sibling implementations from a common ancestor (same class names — `SyncManager`, `AddonRepository`, `WatchProgressRepository`, `SupabaseProvider` — different packages), it's plausible `shared/`'s versions carry the *same underlying bugs* upstream just fixed in their copy: hammering the backend during 429s, redundant full-profile pulls, duplicate terminal watch-progress writes, and excessive foreground-triggered polling. These would manifest on tvOS as unnecessary backend load / possible rate-limit throttling on shared infrastructure, not as a UI bug — likely why nothing has surfaced as a visible complaint yet.

**This is the top actionable item this run.** See action items below.

### 9. `c2df2c11` — fix(search): preserve state across tab changes

`composeApp` search screen was losing its query/results when the user switched tabs and came back; `SearchRepository.kt` now retains state across `AppShellComponents.kt`/`MainAppContent.kt` tab transitions.

Not a mechanical port (tvOS's tab navigation is native SwiftUI `TabView`, not Compose). Worth a quick spot-check: does tvOS's Search tab lose its query/results when the user tabs away and back? If tvOS's `SearchView`/view-model already holds state at the `@StateObject` level scoped above the tab switch, this is likely already fine — but not verified this run.

### 10. `f02ef3c3` + `e8350ca0` — refactor(app): modularize navigation and profile gate

Large mechanical refactor splitting `composeApp/App.kt` (was ~4000 lines) into `AppGate.kt`, `AppGateController.kt`, `AppGateOverlay.kt`, `AppNavigationSupport.kt`, `AppScreenTab.kt`, `AppShellComponents.kt`, `CatalogDestination.kt`, `DetailsDestinations.kt`, `MainAppContent.kt`, `MainTabsDestination.kt`, `PlayerDestination.kt`, `SettingsDestinations.kt`, `StreamDestination.kt`. Pure code organization, upstream's mobile Compose app only.

**No action** — internal composeApp restructuring, no behavior change, no `shared/` touch.

### 11. `fbb64124` — perf(membership): restore cached member assets instantly

Membership/supporter-perks caching improvement (`MemberAssetStorage`, `MemberAccessRepository`, `ProfileBackgroundRepository`).

**No action — folds into the parked Supporter perks v1 item** (same family as `bd88760e`/`38e6ea28`/`b80ee5ab`/`52e28562`). Parked by product decision 2026-08-20; no new decision needed.

### 12. `17a44ad4` — fix(sync): use scoped iOS application state

One-line fix in `AppForegroundMonitor.ios.kt`, part of the same sync-reliability batch as items 2–8 above. Mobile-iOS-specific plumbing (composeApp's iOS actual), not shared code.

**No action** — captured under the sync batch investigation above; no separate port needed.

### 13–20. Translations + version bumps — `84285fc4`(already logged 2026-08-23), version bump commits `4a828bfb`/`4a0be3c1`, merge commits

Routine version bumps and merge commits with no independent content. No action.

## Action items for Claude Code

> **OUTCOME (2026-08-24, same day):** the sync-stack audit item below was **DONE — ported end-to-end** on NuvioMobile branch `claude/sync-reliability` (off `claude/beta15` @ `207b1298`, tip `9221cc5d`, 6 commits, unpushed pending merge decision). All 7 upstream fixes landed as logic ports: 429/Retry-After rate limiting (`BackendRateLimit.kt` + `SupabaseProvider` wiring), terminal watch-progress write dedup, addon push debounce + no-op guards, plugin repository 6h refresh throttle (adapted into `TvOsPluginRepository` — upstream throttles `initialize`/`pullFromServer`, leaves user-initiated `refreshAll` alone; matched), conditional credential seeding (pull-first), home-catalog push cache + full legacy-read deletion (history-verified: the fork never wrote `"mobile"`/`"tv"` home-catalog rows — that namespace was upstream's own Android TV app), and the SyncManager Activity/Full split (2-min foreground activity gate, periodic 4→15 min, 10s full-pull suppression, settings/credentials before addons). tvOS has no `AppForegroundMonitor` — the visibility half landed in `ContentView.swift` scenePhase (stop periodic on background, unforced foreground pull) + `ProfilesViewModel.select` (start periodic at profile entry; **tvOS never started periodic polling at all before this**). Codex review: 6 rounds → clean; 5 real findings fixed (same-round application of just-seeded legacy credentials; P1 failed-scrobble-push dedup rollback + freshest-entry retry — upstream `d0c7bff7` carries this latent gap, upstream-report candidate; periodic polling stop on profile-picker exit; foreground escalation to full sync when forced/never-completed — protects composeApp's `App.kt` reconnect handler; clock-rollback guards in `ProfilePullFreshness`/`isPluginRepositoryRefreshDue`, also upstream-report candidates) and 2 documented upstream-parity tradeoffs (complete-no-op write dedup, cached-blob push merge). Gates: `:shared:jvmTest` + `:shared:tvosSimulatorArm64Test` green (6 new/extended test classes), NuvioTV sim build green, sim smoke on FA87 (profile-entry full pull populates Home/CW/Upcoming; two background/foreground cycles, no crash, same PID).
> **Search-tab spot-check also resolved during this session's exploration:** tvOS's `SearchViewModel` is a `@StateObject` inside a persistent `Tab` subtree — query/results survive tab switches; no port needed. Only the player pause-description spot-check still carries.

- [x] **[NEW 2026-08-24, MEDIUM priority] Audit `shared/` sync stack for the same reliability bugs upstream just fixed in `composeApp/`.** Upstream's `composeApp/core/sync/` batch (commits `8be6fa9e`, `ecae8ac3`, `0e9a1ebe`, `67b865a7`, `f9c13a9b`, `d0c7bff7`, `eb8fce23`) fixed: backend 429/retry-delay handling, duplicate full-profile pulls, addon request throttling, redundant provider-credential seeding, a legacy catalog-sync read path, duplicate terminal watch-progress writes, and excessive foreground-triggered polling. Confirmed via grep that `shared/src/commonMain/kotlin/com/nuvio/app/core/sync/SyncManager.kt`, `shared/.../features/watchprogress/WatchProgressRepository.kt`, and `shared/.../core/network/SupabaseProvider.kt` (the versions tvOS actually depends on) have none of this — no throttle/dedup/backoff logic present. Read upstream's actual diffs (`git show 8be6fa9e`, `ecae8ac3`, `d0c7bff7`, `eb8fce23` in the submodule) and decide, function by function, whether `shared/`'s sibling implementations need the same fixes ported (logic port, not code copy — package/class shapes differ). Start with the 429/retry-delay handling in `SupabaseProvider.kt` and the terminal watch-progress write dedup in `WatchProgressRepository.kt` — those two are the most likely to cause real user-visible or backend-cost impact if missing.
- [x] ~~**[NEW 2026-08-24, LOW priority, spot-check only] Search state across tab changes.**~~ **RESOLVED 2026-08-24 (same-day port session):** `SearchView` holds `@StateObject private var model = SearchViewModel()` inside a `Tab`-declared subtree that tvOS keeps alive across tab switches (`ContentView.swift:224-227`) — state survives; no port needed.
- [x] ~~Add delete-confirmation to tvOS addon removal~~ — **RESOLVED**, verified landed in `AddonsView.swift` (`addonPendingRemoval` + `.alert`).
- [x] ~~Compare Simkl anime-movie fixes~~ — **RESOLVED, no port needed.** tvOS's `shared/` logic already matches (and slightly improves on) upstream's final fix (`15df9555`).
- [ ] **[carried, low priority, spot-check only] Player pause-description staleness.** Still open from 2026-08-23 (upstream `c4934bce`) — tvOS uses a native player, not the Compose files upstream touched. Verify next time the tvOS player/pause-overlay UI gets touched.

## No action needed

- Membership asset caching (`fbb64124`) — folds into parked Supporter perks v1.
- Navigation/profile-gate refactor (`f02ef3c3`, `e8350ca0`) — internal composeApp reorg, no behavior change.
- iOS foreground-state scoping fix (`17a44ad4`) — captured under the sync-batch audit item above.
- Version bumps, merge commits (`4a828bfb`, `4a0be3c1`, `31bea789`, `c99637514`) — no content.

## Standing decision items (unchanged since 2026-08-20)

1. **[PARKED] Supporter perks v1** (upstream `bd88760e`/`38e6ea28`/`b80ee5ab`/`52e28562`/`fbb64124`). Membership tiers, theme accents, custom backgrounds, membership status card, cached member assets. `composeApp/`-only. Park until re-raised.
2. **[DEFERRED] Subtitle minimum font size** (upstream `d50f84fc`). tvOS's native subtitle renderer differs; 10-foot UI likely wants a larger floor, not smaller. Decide next time player styling gets a pass.

## Next scheduled check

Re-fetch `upstream/cmp-rewrite`, diff past `4a0be3c1`. If the `shared/` sync-stack audit above was done, note the outcome (ported / not needed / partially ported) here instead of re-investigating from scratch. Verify search-tab-state spot-check if it was done.

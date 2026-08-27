# Upstream port check — 2026-08-26

## Summary

`upstream/cmp-rewrite` (`NuvioMedia/NuvioMobile`) moved `f62de092` → `582ae863`, 16 new commits + 2 merges (2026-08-25). Every touched file is in `composeApp/`, `iosApp/iosApp/` (upstream's own **mobile** iOS target, not this fork's `iosApp/NuvioTV/`), `.github/`, or build scripts — no `shared/`-path hits. Same "path-only looks like nothing, but `shared/` is an extraction of `composeApp/`'s business logic" pattern as the last several runs applies again: three of the sixteen commits touch files with confirmed, still-unshared-only `shared/` counterparts.

Fork state at check time: outer `main`. Submodule on `claude/beta15` @ `9bc0421d` ("Merge claude/sync-reliability into claude/beta15"), 11 commits ahead of `origin/claude/beta15` (unpushed). One dirty submodule pointer (`MPVKit` untracked content) — pre-existing, unrelated to this check.

## New upstream commits (`f62de092..582ae863`), grouped by portability

### Group A — real `shared/` port candidates, confirmed unported

**A1. Respect anime type when adding titles to Simkl library (`5003d298`).** Fixes the *list-mutation* path (`SimklResolvedListMutation`/`toListMutationReceipt`/`withListMutations` in `SimklMutationReceipt.kt`/`SimklMutationReconciliation.kt`): the API response's `anime_type` field is now read and used to resolve `mediaType` as `ANIME` when adding/moving titles into a Simkl list, instead of falling back to the request's own guessed `kind`.

Confirmed unported: the fork's `shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklMutationReceipt.kt` already carries `animeType` on `SimklResolvedHistoryMutation` (the *scrobble/history* path — a separate, earlier port, still correct and matching upstream's final state per the 2026-08-24 check) but **`SimklResolvedListMutation` has no `resolvedMediaType`/`animeType` fields at all**, and `SimklMutationReconciliation.kt`'s `withListMutations` still does `existing?.mediaType ?: mutation.request.kind.toSimklMediaType()` — exactly upstream's pre-fix code. So anime titles added via *list add/move* (watchlist, plan-to-watch, etc.) can still get misclassified as a regular show/movie on tvOS, while history/scrobble-driven anime classification is already correct.

**Port target:** `shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklMutationReceipt.kt` (add `resolvedMediaType`/`animeType` to `SimklResolvedListMutation`, populate from `response.stringValue("anime_type")` in `toListMutationReceipt`) and `SimklMutationReconciliation.kt` (`withListMutations`: prefer `mutation.resolvedMediaType`, also copy `animeType` onto the entry — mirror the pattern already used in `withResolvedHistoryStatus`). Small, mechanical, no UI work.

**A2. Persist discover catalog selection across restarts (`ab57cf1b`).** New `resolveDiscoverCatalog()` pure function in `SearchRepository.kt` plus a new `DiscoverSelectionStorage` `expect object` (android/ios actuals) that saves/loads the last-picked Discover catalog key and restores it (falling back to current-in-memory, then first-available) instead of always defaulting to `sources.first()` on cold start.

Confirmed unported: `shared/src/commonMain/kotlin/com/nuvio/app/features/search/SearchRepository.kt` has neither `resolveDiscoverCatalog` nor any `DiscoverSelectionStorage` reference — its `refreshDiscoverAvailability`-equivalent still picks `catalogOptions.firstOrNull { it.key == current.selectedCatalogKey } ?: catalogOptions.first()`, i.e. in-memory only, reset on every cold launch. tvOS's `SearchView`/`SearchViewModel` (confirmed to depend on shared `SearchRepository`/`DiscoverUiState`) inherits this: whichever Discover catalog the user last had open is forgotten every time the app restarts.

**Port target:** add `resolveDiscoverCatalog()` to `shared/.../search/SearchRepository.kt`; add `DiscoverSelectionStorage` `expect`/`actual` (apple actual → `UserDefaults`, matching how other tvOS-facing `shared/` storage objects persist — check `PlayerTrackPreferenceStorage`'s apple actual for the existing pattern); wire `loadCatalogKey()`/`saveCatalogKey()` into the discover-refresh and catalog-selection paths the way upstream's diff shows. Upstream also wires a `SearchRepository.reset()` call into **mobile's own `composeApp/features/profiles/ProfileRepository.kt`** on profile switch — that file doesn't exist in `shared/` (profile-switch cache invalidation is orchestrated differently per-platform: tvOS's own `ProfilesViewModel.swift` per project memory). If this port lands, separately check whether `ProfilesViewModel.swift` needs a matching `SearchRepository` reset call on profile switch so a stale Discover catalog selection doesn't leak across profiles — `shared/SearchRepository` already exposes a `reset()` function (added earlier, currently unused for this purpose), so this is likely a one-line wiring addition, not new logic.

**A3. Guard against season-switch episode-highlight leaking to the wrong season (`aa67e069`).** New pure function `preferredEpisodeNumberForSeason(displayedSeasonNumber, preferredSeasonNumber, preferredEpisodeNumber)` in `composeApp`'s `SeriesSeasonSupport.kt`, used at the `DetailSeriesContent.kt` call site so the "jump to/highlight this episode" hint (e.g. continue-watching) only applies when the season being displayed actually matches the season the hint was computed for — previously it could get applied to whatever season the user switched to.

`shared/src/commonMain/kotlin/com/nuvio/app/features/details/SeriesSeasonSupport.kt` exists and is otherwise in sync (`normalizeSeasonNumber`, `seasonSortKey`, `metaVideoSeasonEpisodeComparator` all present) but has no `preferredEpisodeNumberForSeason`. However, a grep of `iosApp/NuvioTV` for `preferredEpisodeNumber`/`preferredSeasonNumber`/`scrollToEpisode`/`continueEpisode` found **no matches** — tvOS's season/episode UI doesn't appear to use this exact "preferred episode to highlight" concept under any name, so it's unclear whether tvOS's season-switch flow has the same bug or just doesn't have the feature this guards. This needs a manual look at tvOS's season-picker → episode-list code (likely in `DetailView.swift`/`DetailViewModel.swift`) before deciding whether this is "port the guard function" or "not applicable, no equivalent feature."

**Port target (pending investigation):** if tvOS has an equivalent continue-watching-episode-highlight concept, add `preferredEpisodeNumberForSeason` to `shared/.../details/SeriesSeasonSupport.kt` (trivial, upstream's implementation is a 5-line pure function) and apply the same guard at tvOS's season/episode list-building call site.

### Group B — not portable / no action needed

- **`582ae863` "keep controls hidden on playback start"** — Compose mobile player fix (`PlayerScreenRuntimeState.kt` `controlsVisible` default `true`→`false`). **Already correct on tvOS**: `iosApp/NuvioTV/Screens/MPVPlayerView.swift:34` already declares `@Published var controlsVisible: Bool = false`. No action.
- **`fd87fe33` "Make landscape posters 16:9 in discover/catalogs"** — Compose constant change (`PosterShape.Landscape` aspect ratio `1.2f` → `1.78f`) in `CatalogScreen.kt`/`PosterGrid.kt`. tvOS derives its landscape card aspect from `PosterStyle.width`/`height` config (see `BrowseComponents.swift`), not a single hardcoded ratio constant — not a mechanical port. Worth a design spot-check (is tvOS's landscape card already ~16:9, or does it need its own width/height adjustment?) next time card styling gets a pass, but no unported bug here.
- **`04ca1226` "feat(details): add tappable expandable descriptions"** — new `ExpandableDescription.kt` Compose component, tap-to-expand on touch. No `isExpanded`/`expandable` concept found anywhere in `iosApp/NuvioTV`. tvOS's remote/focus interaction model doesn't have "tap" — this would need its own native design (e.g. focus-and-hold, or just showing full text) rather than a port. Product idea, not a bug fix; leave parked unless raised.
- **`a3e1c18f` build(kotlin) 2.4.10 / `04f6cea5` build(compose) 1.12.0** — the Compose Multiplatform bump was reverted same-day by `eee5e34c` ("revert(compose): restore multiplatform 1.11.1"), net no-op for that one; the Kotlin 2.4.10 bump is upstream's own tooling decision, independent of this fork's build config — not something to blindly mirror without its own verification pass.
- **`560e5a28` "correct launch screen configuration"** — touches `iosApp/iosApp/Info.plist`/`.pbxproj`, upstream's **mobile** iOS app target (`iosApp/iosApp/`), not this fork's tvOS target (`iosApp/NuvioTV/`). No shared surface.
- CI/build scripts: `b75fa052`, `41eb637c`, `be6beca2`, `1c92795c`, `4e838e47`, `071fc431` — upstream's own Android/iOS release CI and version bump, not this fork's pipeline.
- Merge commits (`e8ae73f2`, `a29b2f09`) — no independent content.

## Action items for Claude Code

- [ ] **[MEDIUM, NEW 2026-08-26] Port Simkl list-mutation anime-type fix (Group A1).** Add `resolvedMediaType`/`animeType` to `SimklResolvedListMutation` in `shared/.../simkl/SimklMutationReceipt.kt`, populate from `anime_type` in `toListMutationReceipt`, and use it in `withListMutations` (`SimklMutationReconciliation.kt`) the same way `withResolvedHistoryStatus` already does. Confirmed the list-mutation path is the one gap; history/scrobble path already has correct anime-type handling from an earlier port.
- [ ] **[MEDIUM, NEW 2026-08-26] Port Discover catalog-selection persistence (Group A2).** Add `resolveDiscoverCatalog()` + `DiscoverSelectionStorage` (expect/apple-actual via `UserDefaults`) to `shared/.../search/SearchRepository.kt`, wire into the discover-refresh/selection paths. Then separately check `ProfilesViewModel.swift` for whether it needs a `SearchRepository.reset()` call added on profile switch (function already exists in `shared/SearchRepository`, just unused for this).
- [ ] **[LOW, NEW 2026-08-26, investigate before porting] Season-switch episode-highlight guard (Group A3).** First determine whether tvOS's season-picker/episode-list flow (`DetailView.swift`/`DetailViewModel.swift`) has an equivalent "highlight/scroll to this episode" concept that could leak across a season switch. If yes, port `preferredEpisodeNumberForSeason` (5-line pure function) into `shared/.../details/SeriesSeasonSupport.kt` and apply the guard at the tvOS call site. If no such concept exists on tvOS, close this out as not applicable.
- [ ] **[carried, low priority, spot-check only] Player pause-description staleness** (upstream `c4934bce`) — still open, tvOS uses a native player. Verify next time the tvOS player/pause-overlay UI gets touched.
- [ ] **[carried from 2026-08-25, unstarted] Subtitle/player-engine batch (HIGH), crash-cluster fixes (MEDIUM), two one-line wins (LOW)** — see `docs/upstream-port-plan-2026-08-25.md` Groups A1–A3. Re-check `grep -rl "StartupMode" shared/src` before starting; if it's gone, that batch landed since — update this doc's status instead of re-scoping it.

## No action needed

- Player controls-hidden-on-start — tvOS's `MPVPlayerView` already defaults to hidden.
- Landscape poster 16:9 constant — tvOS doesn't use a single hardcoded ratio; spot-check only if a card-styling pass happens.
- Tappable expandable descriptions — touch-only UX concept, no tvOS equivalent interaction model; product idea, not a fix.
- Kotlin/Compose Multiplatform version bumps — upstream's own tooling churn (Compose bump was same-day reverted).
- Mobile iOS launch-screen fix — wrong `iosApp/` target (mobile, not tvOS).
- CI workflow / release-script changes — upstream's own mobile CI pipeline.
- Merge commits — no independent content.

## Standing decision items (unchanged since 2026-08-20)

1. **[PARKED] Supporter perks v1** (upstream `bd88760e`/`38e6ea28`/`b80ee5ab`/`52e28562`/`fbb64124`). `composeApp/`-only. Park until re-raised.
2. **[DEFERRED] Subtitle minimum font size** (upstream `d50f84fc`). tvOS's native subtitle renderer differs; decide next time player styling gets a pass.

## Next scheduled check

Re-fetch `upstream/cmp-rewrite`, diff past `582ae863`. Quick status checks to run first: `grep -rl "StartupMode" shared/src` (2026-08-25's A1 batch — should be gone if ported); `grep -n "resolvedMediaType" shared/.../simkl/SimklMutationReceipt.kt` (today's A1 — should show up on `SimklResolvedListMutation` if ported); `grep -n "DiscoverSelectionStorage" shared/.../search/SearchRepository.kt` (today's A2 — should exist if ported). If any of the three carried HIGH/MEDIUM batches (2026-08-25's subtitle engine + crash clusters, today's Simkl + Discover persistence) landed, record the outcome here instead of re-investigating.

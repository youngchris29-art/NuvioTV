# Library L1 grid (2026-10-04)

**Status: CODE WRITTEN, NOT YET COMPILED.** NuvioMobile branch `claude/library-l1-grid`, off `tvos-shared-extraction` `7e71ba87` (beta.19-rc2). Written in a cloud session on Christian's go ("start the Library L1 grid work"). The container has no Xcode, so the Swift has never been compiled. The Kotlin compiled, and `:shared:jvmTest` passed (1,395 tests, 0 failures). A Mac session owes the builds, tests, review fixes and the device pass below. Nothing is merged.

L1 is the first step of direction **L3 · Split Library** on the revamp board (`docs/research/search-library-revamp-2026-10-04.html`, "Recommendation"). It finishes the grid that the list column will later sit beside.

## What changed

| Area | Before | L1 |
|---|---|---|
| Data | The flat union of every list (`LibraryUiState.items`). The shared sections were ignored. | The shared `buildLibraryVerticalProjection`, the same call mobile's grid uses. It handles the chosen list, the type filter, de-duplication and the shared sort. |
| Lists | None. | A **List** pill: Trakt's watchlist and lists, Simkl's statuses, MDBList's lists. It shows only with more than one list. The local library has none. |
| Type | None. | **All / Movies / Series / Anime** chips, shown only with more than one type. Anime comes from `mediaCategory`. |
| Sort | Five chips. DEFAULT was labelled "Trakt Order" on every provider. | A **Sort** pill (native `Menu { Picker }`, the Settings control). DEFAULT reads "Trakt Order" on Trakt and "List Order" on Simkl and MDBList. The pill shows the effective sort: a stored DEFAULT on the local library sorts as Recently Added, and now says so. |
| Smart filters | None. | **Unwatched / In Progress / Watched** (VortX): they combine with AND. Turning on Watched turns off the two it can never combine with. A chip shows only when it would split the grid, or when it is on. |
| Cards | No state. | A watched tick (movie marker, or a fully watched / title-marked series: the hold menu's own test), or a progress bar from the newest progress entry for the title (2–97 %). |
| Header | "Library". | "Library", a count line ("31 movies · 17 series") and a source badge (TRAKT / SIMKL / MDBLIST). |
| States | Any empty list read "Your library is empty", even while a provider library was loading or after it failed. | Loading; failed with **Retry**; provider-aware empty; an empty list with the pills kept, so the viewer can switch lists; no matches with **Clear Filters**. |
| Hold menu | Remove only, via `toggleSaved`. | **Mark as Watched / Unwatched** (the catalog menu's items), then **Remove from ‹list›**. On a provider list this removes from that list. `toggleSaved` flipped the provider's watchlist, so on any other list it would have **added** the title to the watchlist. |

Shared (`LibraryRepository.kt`): `removeFromListAsync(item, listKey)` and `retryLoadAsync()`. Both are non-suspending and catch their own failures, like `toggleSaved`. `removeFromList` rethrows the first provider failure, and a Kotlin exception that escapes a `suspend` call into Swift without `@Throws` terminates the app. A failed remove shows the same toast `toggleSaved` shows.

Swift:
- `LibraryGridPolicy.swift` (new) holds every rule as pure functions.
- `LibraryViewModel.swift` and `LibraryView.swift` are rewritten.
- `TitleHoldMenu.swift` gains `libraryHoldMenu(preview:extra:)` and `includesLibraryAction`.
- `LibraryGridPolicyTests.swift` (new) has 16 tests.

## Defaults chosen (change any of them)

- Count line and smart-filter chips are computed on the list after the type filter.
- Picks reset when the Library Source changes in Settings. They persist while the tab stays mounted, but not across launches. Mobile doesn't persist them either.
- Type chips show "All" first. A pick that no longer exists falls back to All, which is the projection's own rule.
- Progress-bar thresholds: below 2 % or from 97 % no bar is drawn, and the title doesn't count as In Progress.
- Badges only on the Library grid for now. Catalog grids elsewhere are unchanged.

## Deferred (not in L1)

- **New sort options** (Recently Watched, Year, Rating). `LibrarySortOption` is a shared, persisted enum that mobile's `when` blocks switch over, so new cases need a mobile pass as well.
- **Move to list** in the hold menu (`applyMembershipChanges` exists).
- **List management** on the TV (create, rename, delete). `LibraryListManagementController` exists in shared.
- **Letter rail** for long lists, and per-list remembered filters.
- **Translations.** The new strings are English only. Earlier batches carried de/es/fr/it/vi, so a translation pass is owed before a public cut.
- **Paging.** `LazyVGrid` already only builds visible cards, and the data is in memory. Revisit only if a very large library (BUG-69 class) scrolls badly.
- **L3's list column**, the next step.

## Gates owed on the Mac

1. Check out `claude/library-l1-grid` in a throwaway clone of the submodule, or fetch it into the submodule. Fix compile errors and record each fix here.
2. Debug and Release tvOS simulator builds.
3. `NuvioTVTests` (includes the 16 new `LibraryGridPolicyTests`), with the sandbox off.
4. `:shared:jvmTest` (1,395 here), `:shared:tvosSimulatorArm64Test` and `:composeApp:iosSimulatorArm64Test`. The shared change is additive.
5. Review: an independent read-only review ran in the cloud session (findings and fixes below). Run a second round on the Mac after the compile fixes. Codex is over its quota until 2026-10-29, so use an Opus read-only round.

## Device pass (Living Room Apple TV, **Test profile**)

Set the Test profile's Library Source to each provider it has connected.

1. **Local library** (Library Source: Nuvio): no List pill or source badge. Type chips appear only with both movies and series saved. The Sort pill reads Recently Added on a fresh profile.
2. **Trakt**: TRAKT badge. The List pill lists Watchlist, Collection and personal lists, and switching it changes the grid. Sort shows Trakt Order.
3. **Simkl or MDBList**: List Order label, and each status or list is selectable.
4. **Loading and failure**: cold-launch with Wi-Fi off on a provider library. You should see "Loading your library…", then the failed card with Retry. Turn Wi-Fi on and press Retry: the grid fills.
5. **Smart filters**: mark one title watched and leave one half-way. All three chips appear. Watched turns off the other two. A combination with no matches shows Clear Filters.
6. **Badges**: the tick sits on the artwork's top-right and the bar along the artwork's bottom, not over the title. Both lift with the card on focus in all three focus modes (default, Accent Ring, No Zoom).
7. **Hold menu on a personal Trakt list**: Mark as Watched toggles the tick. "Remove from ‹list›" removes the title from that list only, and it does **not** appear in the watchlist.
8. **Hold menu on the local library**: "Remove from Library" removes it.
9. **Debrid Cloud** still works: the Saved / Debrid Cloud chips and the cloud list are unchanged.
10. **Focus**: Left from the first pill and Up from the grid behave as before (tab bar, sidebar mode). The pill row is one focus section.

## Review record

See "Cloud review round" below.

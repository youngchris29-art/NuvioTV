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
| Cards | No state. | A watched tick (movie marker, or a fully watched / title-marked series: the hold menu's own test), or a progress bar from the newest progress entry for the title. Below 2 % no bar; the shared completion rule (90 %) ends bars, with a 97 % backstop. Drawn inside `PosterCard` (`watchBadge`), so they lift with the artwork. |
| Header | "Library". | "Library", a count line ("31 movies · 17 series") and a source badge (TRAKT / SIMKL / MDBLIST). |
| States | Any empty list read "Your library is empty", even while a provider library was loading or after it failed. | Loading; failed with **Retry** (forces a network-status refresh, then pulls, as on mobile); provider-aware empty; no matches with **Clear Filters**. Every provider drops empty lists, so an empty list never shows. |
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
- Progress-bar thresholds: below 2 % no bar is drawn and the title doesn't count as In Progress. The shared completion rule ends bars at 90 %; the 97 % ceiling is only a backstop.
- Badges only on the Library grid for now. Catalog grids elsewhere are unchanged.

## Deferred (not in L1)

- **New sort options** (Recently Watched, Year, Rating). `LibrarySortOption` is a shared, persisted enum that mobile's `when` blocks switch over, so new cases need a mobile pass as well.
- **Move to list** in the hold menu (`applyMembershipChanges` exists).
- **List management** on the TV (create, rename, delete). `LibraryListManagementController` exists in shared.
- **Letter rail** for long lists, and per-list remembered filters.
- **Translations.** About 22 new strings are English only. Earlier batches carried de/es/fr/it/vi, so a translation pass is owed before a public cut. It should also turn the hand-made plurals ("1 movie" / "%lld movies") into one plural-variant key per noun.
- **Simkl removes.** Removing a title that has Simkl watch history or a rating is refused by the provider's destructive-removal guard. The shared wrapper shows that as a toast and nothing is lost. Hiding or relabelling Remove there needs a Swift-visible `membershipRemovalConfirmation`.
- **A provider that never finishes loading** (MDBList's default snapshot when its scope fails) leaves Loading up with no Retry. This is mobile's order too, but the TV has no pull-to-refresh to escape it.
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
6. **Badges**: the tick sits on the artwork's top-right and the bar along the artwork's bottom edge, not over the title. Both lift and scale with the artwork on focus in all three focus modes (default, Accent Ring, No Zoom), and stay inside the ring band.
7. **Hold menu on a personal Trakt list**: Mark as Watched toggles the tick. "Remove from ‹list›" removes the title from that list only, and it does **not** appear in the watchlist.
8. **Hold menu on the local library**: "Remove from Library" removes it. On Simkl, removing a watched or rated title shows the destructive-removal toast and leaves it in place (known gap).
9. **Debrid Cloud** still works: the Saved / Debrid Cloud chips and the cloud list are unchanged.
10. **Focus**: Left from the first pill and Up from the grid behave as before (tab bar, sidebar mode). The pill row is one focus section.

## Review record

### Cloud round 1 (2026-10-04, read-only Opus; Codex over quota until 10-29)

Reviewed `c358a4e` against `7e71ba8`. **0 P1 / 1 P2 / 9 P3.** No compile problems found: every SharedCore call and SwiftUI construct was checked against the Kotlin source and existing Swift call sites. Fixes landed in `aa8d1a6`. `:shared:jvmTest` passes after the Kotlin change: 1,395 tests, 0 failures.

| # | Finding | Result |
|---|---|---|
| P2-1 | The badges were an overlay on the whole `PosterCard`, outside `CardArtworkFocusLift`. They stayed put or were covered on focus (the FEAT-14 finding) and ignored the ring band. | **Fixed.** `PosterCard.watchBadge` draws them before the ring overlay and the lift, padded by `ringInset`. |
| P3-2 | Accent on the tick and the bar broke the HIG contract (accent is for selection only; progress uses `Palette.progress`). | **Fixed.** LandscapeCard's bar; white tick. |
| P3-3 | The "empty list, keep the pills" branch could never run, since every provider drops empty lists. | **Fixed:** removed, with its policy function and test. |
| P3-4 | Local Remove used a toggle, so a stale menu could re-add a removed title. | **Fixed:** guarded by `isSaved`, the catalog menu's rule. |
| P3-5 | Simkl's destructive-removal guard refuses some removes. | **Deferred** (toast, nothing lost; mobile behaves the same). Recorded above. |
| P3-6 | Retry skipped mobile's network refresh. Loading has no focusable view. A provider that never loads spins forever. | **Partly fixed:** the network refresh is added. The rest is deferred and recorded above. |
| P3-7 | The 97 % ceiling never takes effect (completion at 90 % comes first). | **Fixed in docs**; the ceiling stays as a backstop. |
| P3-8 | Translations are missing, and the plurals are hand-made. | **Deferred** to the translation pass. |
| P3-9 | Default MainActor isolation could trip the tests. | **Fixed:** `LibraryGridPolicy` and its nested types are `nonisolated` and `Sendable`. |
| P3-10 | Nits: the badge corner token, the `kinds` doc, Simkl empty-state copy, and a remove that empties the open list jumps to the first list. | **Fixed**, except the last, which is the projection's own fallback. |

# Library L1 grid (2026-10-04)

**Status: READY TO MERGE ON CHRISTIAN'S GO (2026-10-04). Built, gated, reviewed (no open P1/P2) and device-passed on every step the Test profile can run; steps 2, 3, 4 and 7 (provider libraries) NOT WALKED by his call. NOT MERGED, not cut.** NuvioMobile branch `claude/library-l1-grid`, off `tvos-shared-extraction` `7e71ba87` (beta.19-rc2), tip `422bb0c4` (pushed). It fast-forwards onto `tvos-shared-extraction` as long as nothing lands there first. Written in a cloud session on Christian's go ("start the Library L1 grid work"), then compiled, fixed, tested and reviewed in a Mac session: see "Mac session (2026-10-04)" below. Merging, the build bump, a cut and any DM wait for Christian's go.

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

Shared (`LibraryRepository.kt`): `removalNeedsConfirmation(item, listKey)`, `removeFromListAsync(item, listKey, destructiveRemovalConfirmed, onFinished)` and `retryLoadAsync()`. All are non-suspending and catch their own failures, like `toggleSaved`: a Kotlin exception that escapes a `suspend` call into Swift without `@Throws` terminates the app. `removeFromListAsync` touches only the provider that owns the list (the Mac round 1 change; `removeFromList` re-applies every connected provider) and hands a failure's message back to Swift, which shows it in an alert, because the shared toast controller is a no-op on tvOS.

Swift:
- `LibraryGridPolicy.swift` (new) holds every rule as pure functions.
- `LibraryViewModel.swift` and `LibraryView.swift` are rewritten.
- `TitleHoldMenu.swift` gains `libraryHoldMenu(preview:extra:)` and `includesLibraryAction`.
- `LibraryGridPolicyTests.swift` (new) has 18 tests.
- `PosterCard.swift` gains `watchBadge` (cloud round 1), drawn inside the artwork container so it rides the focus lift.

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
- **Translations.** About 30 new strings are English only (the Mac rounds added the Simkl confirmation and failure-alert copy). Earlier batches carried de/es/fr/it/vi, so a translation pass is owed before a public cut. It should also turn the hand-made plurals ("1 movie" / "%lld movies") into one plural-variant key per noun.
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
8. **Hold menu on the local library**: "Remove from Library" removes it. On Simkl, removing a watched or rated title first asks "Remove from ‹status›?" (Simkl also clears its watched history and rating); Remove takes it out, Cancel leaves it.
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

## Mac session (2026-10-04)

Throwaway clone `~/Claude/Projects/NuvioMobile-library-l1` (MPVKit symlinked from the main checkout, `local.properties` copied). Commits added on top of the cloud's `c358a4ed` and `aa8d1a69`, all pushed to `claude/library-l1-grid`:

- `f670413d` Mac review round 1: Simkl confirmation, one-provider remove, cheaper republish.
- `a1096a6c` Mac review round 2: remove reporting and list capture.
- `062e13a9` Mac review round 3: keep "This list is no longer available".
- `8bc17387` Mac review round 4: never show a subclass's message (token leak).
- `422bb0c4` device pass step 10: Up from the right half of the pill row reaches Saved / Debrid Cloud.

### Compile fixes

**None.** `c358a4ed` built clean in Debug and Release on the first try, and so did the cloud's `aa8d1a69` (built together with `f670413d`; it was never compiled on its own). No new warnings in the touched files. The build log's other warnings (`CloudLibraryUI.swift` Sendable captures and the like) were there before.

### Gates

| Tip | Debug sim | Release sim | NuvioTVTests | `:shared:jvmTest` | `:shared:tvosSimulatorArm64Test` | `:composeApp:iosSimulatorArm64Test` | Debug device |
|---|---|---|---|---|---|---|---|
| `c358a4ed` (cloud, as received) | green | green | 988 / 0 (16 new) | 1,395 / 0 | 1,413 / 0 | 435 / 0 | |
| `f670413d` | green | green | 988 / 0 | 1,395 / 0 | 1,413 / 0 | 435 / 0 | green |
| `a1096a6c` | green | green | 990 / 0 (18 L1) | 1,395 / 0 | 1,413 / 0 | 435 / 0 | green |
| `062e13a9` (Kotlin copy only) | green | | | 1,395 / 0 | 1,413 / 0 | | green |
| `8bc17387` (Kotlin copy only; device pass steps 1–9) | green | | | 1,395 / 0 | 1,413 / 0 | | green |
| `422bb0c4` (one SwiftUI modifier; device pass step 10 re-check) | green | green | 990 / 0 | | | | green |

`xcodebuild` ran with the Bash sandbox off (in-sandbox it exits 70); the `NuvioTV` scheme has no test action, so the unit tests run through the `NuvioTVTests` scheme. powerd was healthy this session.

### Review rounds (Mac, read-only Opus; Codex over quota until 10-29)

**Round 1** over `7e71ba87..c358a4ed`: **0 P1 / 2 P2 / 9 P3.** It ran in parallel with the cloud's own round, which pushed `aa8d1a69` while the Mac fixes were being written; the Mac changes were rebased onto it, keeping the cloud's version wherever both fixed the same thing.

| # | Finding | Result |
|---|---|---|
| P2-1 | Badges outside `CardArtworkFocusLift`: they stayed at rest geometry on focus. | Already fixed by the cloud's `aa8d1a69` (`PosterCard.watchBadge`). Confirmed on the simulator in all three focus modes (frames 04, 06, 10–13). |
| P2-2 | "Remove from ‹Simkl status›" silently did nothing for any title with history or a rating: `applyStatusMembership` refuses without `destructiveRemovalConfirmed`, nothing ever passed it (mobile neither), and the failure went to the shared toast, a no-op on tvOS. | **Fixed** (`f670413d`): `removalNeedsConfirmation` asks the owning provider, the grid shows "Remove from ‹status›?", and the confirmation is passed through. Failures come back to Swift and show in an alert. This supersedes the cloud's P3-5 deferral. |
| P3-1 | `removeFromList` reads and re-applies every connected provider: an MDBList library that failed to load aborts a Trakt removal, and every remove refreshes all of them. | **Fixed:** only the provider that owns the list key. |
| P3-2 | Local Remove used a toggle. | Already fixed by the cloud (`isSaved` guard). |
| P3-3 | The "empty list, keep the pills" branch can't run. | Already fixed by the cloud. |
| P3-4 | The Library hold menu still read `isSaved` (its `ensureLoaded` kicks a provider refresh on every hold). | **Fixed.** |
| P3-5 | `republish` called `isWatched` per title on every emission, and rewrote every published value. | **Fixed:** watched state cached per title until the watched flows emit; published values written only when they change. |
| P3-6 | The stock `Menu` pills' focus lift could be clipped by the horizontal scroll view. | **Fixed:** `.scrollClipDisabled()` (frame 03). |
| P3-7 | Wrong comments (badge lift, toast on tvOS). | **Fixed.** |
| P3-8 | "List Order" sorts like Recently Added on Simkl (and first by date on MDBList). | **Declined:** shared sort semantics that mobile shows too; revisit with the deferred new sort options. |
| P3-9 | Progress bar colour. | Already fixed by the cloud (`Palette.progress`). |

**Round 2** over `7e71ba87..f670413d`: **0 P1 / 0 P2 / 4 P3**, all fixed in `a1096a6c` except one case.

| # | Finding | Result |
|---|---|---|
| P3-1 | MDBList throws its own `CancellationException` when the profile or account changes mid-write; rethrowing it skipped `publish()` and the result callback. | **Fixed:** rethrown only when the coroutine is really cancelled, otherwise logged as abandoned. |
| P3-2 | The failure alert showed raw error text (`AUTHORIZATION_REVOKED`, `HTTP 429`) and a Trakt-only fallback. | **Fixed:** MDBList errors through `localizedMdbListMessage()`; an empty message reads "Something went wrong. Try again." |
| P3-3 | The confirmation check and the apply could disagree: a sync while the menu is open, or a Simkl title in two statuses. | **Partly fixed:** the menu now captures the list when it is built. The two-status Simkl case is **declined** (rare, and nothing is written: the apply refuses or does nothing). |
| P3-4 | No tests for the new copy. | **Fixed:** two tests (18 in all). |

The round also confirmed the round 1 fixes per provider: list keys are provider-prefixed, Trakt diffs the full membership map (a map with only the target key would have removed the title from every other Trakt list, so the full map matters), MDBList skips unchanged keys, and `membership()` keys match each snapshot's tabs.

**Round 3** over `f670413d..a1096a6c`: **0 P1 / 0 P2 / 1 P3.** The MDBList mapping turned the writer's own "This list is no longer available" into "Could not sync with MDBList. Please try again.", and the no-owning-provider case showed an internal list key. **Fixed** in `062e13a9`.

**Round 4** over `062e13a9`: **0 P1 / 0 P2 / 1 P3.** Letting `IllegalArgumentException` messages through also let its subclasses through, and Ktor's illegal-header exception is one whose message holds the header value: a malformed MDBList token (say, with a trailing newline) would have put the bearer token on screen. Theoretical (it needs a bad token from MDBList's server), but a credential. **Fixed** in `8bc17387`: only exactly `IllegalArgumentException` (what `require` throws) passes through; subclasses, `SerializationException` included, stay mapped. The round also traced every MDBList `require` reachable on the remove path: the texts that can now reach the alert are already user copy ("This list is no longer available", "An external movie or show ID is required"). The review loop ends here: rounds 2, 3 and 4 found no P1 or P2.

### Simulator check (FA87, guest profile)

The fixture's guest library was empty (frame 01: the empty state renders). Six local titles were seeded into the guest container's library payload file, plus one progress entry for Inception; Dune and Breaking Bad were already marked watched in the fixture. This is a local guest container, not an account. Driven with an untracked XCUIRemote scratch driver. Frames from the final build are in `docs/research/library-l1-sim-evidence/`.

- Grid, count line ("4 movies · 2 series"), All / Movies / Series chips, the Sort pill and all three smart filters render; ticks on the two watched titles, the bar on Inception (02).
- The Sort pill lifts on focus without clipping (03).
- Hold menu on the local library: Mark as Watched, then Remove from Library (05).
- In Progress leaves Inception only; Watched turns In Progress off and leaves the two watched titles; a second press clears it (07–09).
- Badges sit inside the artwork and ride the focus in default (04, 06), Accent Ring (10, 11) and No Zoom (12, 13). On the focused card in default mode the bar looks a little thinner where the lift's rounded edge crops it, the same as Continue Watching cards.
- Not checkable on the simulator: default-mode parallax on hardware, provider lists, Wi-Fi off.

### Device pass (Living Room Apple TV, Test profile, dev build `com.youngchris29.NuvioTV` 134)

Walked by Christian on 2026-10-04 (about 13:10–13:45 ET), one step at a time, console streamed over `devicectl --console` (it dropped three times with Mercury error 1001, the TV's connection timing out: no crash logs from the pass). Built from `8bc17387`, then `422bb0c4` for the step 10 re-check. The Test profile is in sidebar mode, has six local titles (one watched, two in progress) and TorBox, and no Trakt, Simkl or MDBList. Photos in `docs/research/library-l1-device-evidence/`.

| Step | Result |
|---|---|
| 1. Local library | **PASS.** No List pill, no source badge; "3 movies · 3 series"; All / Movies / Series; Sort reads Recently Added; all three smart filters; tick on Nemesis, bars on Jack Ryan and The Crash (photo 01). |
| 2. Trakt | **NOT WALKED** (Test has no Trakt; Christian chose to skip). |
| 3. Simkl or MDBList | **NOT WALKED** (same). |
| 4. Loading and failure, Wi-Fi off, Retry | **NOT WALKED** (needs a provider library: the local one loads from disk). |
| 5. Smart filters | **PASS.** In Progress leaves the two in-progress titles; Watched turns In Progress off; Watched plus the other type shows "No titles match these filters"; Clear Filters restores the grid. |
| 6. Badges in three focus modes | **PASS.** Default: the tick rides the lifted card (02) and the bar stays on the lifted artwork (03). No Zoom (04) and Accent Ring (05): both inside the ring. |
| 7. Remove on a personal Trakt list | **NOT WALKED** (needs Trakt). |
| 8. Hold menu, local library | **PASS.** Mark as Watched adds the tick, the label flips to Mark as Unwatched and back, Remove from Library removes the title and the count drops by one. |
| 9. Debrid Cloud (TorBox) | **PASS.** Saved / Debrid Cloud unchanged; the grid's pills hide on Debrid Cloud and come back on Saved. |
| 10. Focus | **FAILED, then PASS after `422bb0c4`.** Up from the Sort pill or any chip right of it did nothing: the focus engine searches straight up, and the Saved / Debrid Cloud row is two chips wide. That row is now one full-width focus section, like the pill row. Re-check on the device: Up from Sort and from Watched lands on Saved / Debrid Cloud, Down returns, Up from the grid still lands on the pills. Probably present before L1 (the old sort-chip row also ran past those two chips). Everything else in step 10 passed first time: Right walks every pill, Left from All does nothing, Down from Watched lands in the grid, the Sort menu lists Recently Added / Oldest First / A–Z / Z–A with no provider order on the local library, Menu opens the sidebar. |

The steps not walked cover the provider-only code: the List pill, the Trakt Order / List Order labels, the loading and failed states, list-aware Remove (incl. the Simkl confirmation and the failure alert). Those paths are covered by the unit tests and the four review rounds, not by a device run.

### New bugs

None open. Step 10's Up gap was fixed and device-confirmed in the same session (`422bb0c4`).

### Still owed

- Christian's go to fast-forward `tvos-shared-extraction` to `422bb0c4`. The build bump, a cut and any DM come after, each on his go.
- A device run of steps 2, 3, 4 and 7 on a profile with a provider library (a tester, or a later pass).
- The translation pass (about 30 English-only strings), before a public cut.

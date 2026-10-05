# Search S1 · Native Search (2026-10-04)

**Status: W1, W2, W4, W5 BUILT 2026-10-04 (night); device pass in the Test profile next, then Christian's merge/cut call.** D1, D3 and D5 were approved by Christian after Wave 0 ("D1, D3, D5 approved, start W1"; "start W2, W4 and W5"). The branch is NuvioMobile `claude/search-s1` in the clone `~/Claude/Projects/NuvioMobile-search-s1`, off `dad2bed5`. It has six commits, `8b0710b6` (W1) through `d68b9d61` (reviews r3–r6), committed locally and not pushed or merged. Review r6 was CLEAN. Gates on the tip: NuvioTVTests 1042 / 0, every migrated UI leg plus test92 and test93 on FA87, and a Release simulator build. Details are in [Build record](#build-record-2026-10-04-night). Wave 0 settled D2 and D4 and the tvOS 26 rule (see [Wave 0 outcome](#wave-0-outcome-2026-10-04) below), and the W1–W4 specs here are revised to match. Written from:

- the search-field spike, run 2026-10-04 on the Living Room Apple TV (`docs/research/search-field-spike-2026-10-04/README.md`, its logs and photos);
- the revamp board's S1 direction (`docs/research/search-library-revamp-2026-10-04.html`, "S1 · Native Search" and "Recommendation");
- code maps of `SearchView`, `SearchViewModel`, the Search UI tests, and the sidebar / tab-bar machinery at `tvos-shared-extraction` `422bb0c4`.

## What this batch is

Swap Search's plain `TextField` for tvOS's system search field (`.searchable`), built the way the spike's variant A proved on tvOS 27.2. As a result:

- rows update under the keyboard while you type (FEAT-37);
- Siri dictation works;
- you can type from an iPhone;
- the viewer's own Linear or Grid keyboard is used.

The spike measured 0.47–0.58 s from a keystroke to the first row, mostly the existing 350 ms debounce.

**Proposed split (D1).** This plan builds **S1-a, the native field**, and leaves the page's content as it is today: per-add-on result rows, Recent Searches and Discover's chip rows. The board's other Search pieces become **S1-b**, outlined at the end. S1-b is planned once Christian answers the board's open questions 2 and 3 (group by type by default? what goes on the empty page?):

- type grouping and ranking;
- TMDB people;
- suggestion chips;
- specific empty states;
- Discover D1/D2.

S1-a ships FEAT-37 on its own and needs none of those answers.

## What the spike settled (don't re-test)

- **The ban's bug is gone on tvOS 27.2** when `.searchable` sits on the results `ScrollView` inside the Search tab's own `NavigationStack`. The walk covered:
  - 11 Detail opens, a See All grid and a person page, with no keyboard left over any of them;
  - Home switches with no keyboard there;
  - both keyboard layouts, plus Sidebar mode;
  - five quick open/close rounds.
- **Two structures fail.** `.searchable` on the `TabView` wraps the whole app in the search controller (variant C). A second `NavigationStack` nested inside Search's stops every push (variant B as built). `Tab(role: .search)` changes nothing visible on tvOS.
- **Layout follows the viewer's keyboard setting.** Grid puts a 432 × 750 pt keyboard on the left with the rows on the right. Linear puts a one-line strip under the field (a 1920 × 245 pt band) with full-width rows below.
- **Focus.** In Tabs mode focus stays on the tab bar when Search opens, and the field is one press down. In Sidebar mode focus lands on the keyboard. Back from Detail returns to the card in Tabs mode and to the keyboard in Sidebar mode.
- **Menu.** From the keyboard in Tabs mode, Menu goes to the tab bar; a second Menu leaves the app. That's the system behaviour from any tab bar.
- **Look.** The system field has its own style and won't take Open Sans. Christian accepted it.

## Decisions for Christian

| # | Question | Options | Recommendation |
|---|---|---|---|
| D1 | Scope | (a) S1-a now, S1-b after the board's questions 2–3. (b) Everything on the board's Search step in one batch. | **(a).** S1-a is self-contained and answers FEAT-37 now. S1-b rebuilds the page's content and needs a design spec and a critique. |
| D2 | Sidebar mode (the Test profile's default) | (a) Build a Menu router now: Menu pressed while focus is in the system keyboard opens the sidebar. The FEAT-45 rail reuses it. (b) Sidebar mode keeps today's `TextField` until the rail replaces Sidebar mode. (c) Hold all of S1 until the rail lands. | **(a), falling back to (b) if Wave 0 can't make the router work.** The rail hides the system tab bar for good. The spike showed that `HiddenTabBarFocusBlocker` does not stop the search container from sending Menu-focus to that hidden bar, so the rail has to solve the same press anyway. Solving it here gives the rail's P4 spec a proven mechanism. It's one new file and doesn't touch `ContentView.swift`. **→ Wave 0: (a), but as a focus redirect, not a press router** (U3). |
| D3 | Tab bar while the keyboard is up | (a) Leave it visible (spike-tested). (b) Hide it while the keyboard has focus (board, bobsupra). | **(a).** (b) adds a new tab-bar visibility trigger (BUG-66 territory) for a look nobody has seen yet. Revisit in S1-b. |
| D4 | With Grid, the bar stays pinned on Search instead of scrolling off (`y=46` while the scroll latch reads `sd=1`) | (a) Accept. (b) Link it to the results with `TabBarContentScrollLink`. | **Let Wave 0 decide.** Ship (b) only if the controller chain under `.searchable` links cleanly (U4); otherwise (a), and log it. **→ Wave 0: (a) accept.** Neither link mode moved the bar (U4). |
| D5 | When a query joins Recent Searches (the inline keyboard has no Search/Done key) | (a) When a result is opened from it. (b) After it rests with results. (c) Both. | **(a)**, plus the iPhone keyboard's return key through `.onSubmit(of: .search)`. (b) would save partial words like "dun". This matches VortX and the board's "saved on intent". |

One rule rather than a decision: **if tvOS 26 still bleeds (U1), tvOS 26 keeps today's `TextField`** behind `#available(tvOS 27, *)`. The deployment target is 26.0. **→ Wave 0: no bleed on tvOS 26.5, so no fallback path** (U1).

## Unknowns Wave 0 must answer

Wave 0 runs in a throwaway clone with the spike patch applied, because it already has the file-backed probe. It needs one device session of about 40 minutes, in the **Test profile**. Never `git worktree` the submodule.

| # | Question | How | Decides |
|---|---|---|---|
| U1 | Does `.searchable` still bleed on **tvOS 26**? | FA87, the UI-test simulator, runs tvOS 26.5. Build the spike's variant A for the simulator and walk L4 (open a title, Back) and L6 (switch to Home and back) with XCUIRemote/osascript. Read `Library/Caches/search-spike.log` straight from the simulator's data container. A keyboard line while `screen=detail` that isn't within ~0.6 s of the pop, or any keyboard line on `tab=0`, is a bleed. | Whether tvOS 26 keeps the `TextField`. |
| U2 | What fixes the **iPhone echo**? | Variant A2 keeps the text in its own small `ObservableObject`. `.searchable` is applied in a parent view that observes only that object, and the results live in a child that observes `SearchViewModel`, so a results update can't re-render the view carrying `.searchable`. Device L9 (type "severance" on the phone), A against A2, reading the `query` lines. | W1's view structure. If A2 still echoes, see Risks. |
| U3 | Can a **Menu router** beat the search container? | Prototype `SystemKeyboardMenuRouter` (W2) in the rig. Log every press that ends in `focus UITabBarButton`, plus `HiddenTabBarFocusBlocker`'s state (`blocker=`). On device in Sidebar mode: Menu from the keyboard; Up from the keyboard's top row; Right/Menu back out of the sidebar. | D2 (a) or (b), and whether Up also needs blocking. |
| U4 | Can the bar follow the results under `.searchable`? | Mount `TabBarContentScrollLinkAttacher` on Search's results stack with a per-tab slot (W3). Read the `[TabBarLink] linked chain=` line: a presented search container in the chain, or a search container as a link target, means no. Device: scroll the results with Grid. | D4. |
| U5 | How do UI tests see and drive the field? | On FA87: is the field `app.searchFields` or `app.textFields`? Does `app.typeText` work with focus in the inline keyboard? Which keyboard layout does the simulator default to? | W4's test helpers. |
| U6 | Does holding the old rows look right? | In the rig's view model, keep the previous rows while the next query's first row loads (W1 item 3). Device: type "dune" one letter at a time on Grid and on Linear. | W1 item 3. |

U7, low priority: in Sidebar mode, Back from Detail returns focus to the keyboard, not the card. Check whether the shell focus scope (`ShellFocusScopeModifier`, Sidebar mode only) causes it. Fix it in W2 if it's cheap; otherwise log it.

## Wave 0 outcome (2026-10-04)

Rig: throwaway clone `~/Claude/Projects/NuvioMobile-search-w0` at `tvos-shared-extraction` `dad2bed5` with the spike patch, then the probes below. It was deleted after the run. The full rig is `docs/research/search-s1-wave0-2026-10-04/wave0-rig.patch` (applies to `dad2bed5`), with logs in `logs/`. It ran on the FA87 simulator (tvOS 26.5, XCUITest) and on the Living Room Apple TV (tvOS 27.2, **Test profile**, Grid keyboard, Christian at the remote). Device runs: 1 = A + rows mode 1; 2 = A2 + rows mode 2 + top-down tab link; 3 = A0; 4 and 4b = Sidebar mode, A2 + the Menu router.

| # | Answer | Evidence |
|---|---|---|
| U1 | **No bleed on tvOS 26.5.** No `TextField` fallback is needed for tvOS 26. | XCUITest `testW0SearchableSimA` and `…A2` on FA87: `keyboards=0 searchFields=0` while Detail and Home show. Probe: `kb none` from 0.06 s after Detail opens until 0.56 s before it closes (the pop), and on tabs 0 and 2. Query and focus kept after Back. |
| U2 | **The echo comes from keeping the query in the view's `@State`.** Moving it into an `ObservableObject` query box cures it. Isolating the `.searchable` layer from results updates (A2) also cuts re-renders, so W1 takes the A2 shape. | iPhone, "severance". **A0** (the morning spike's structure, verbatim): 75 query changes, **31 backward steps**, flicker seen. **A** (query box, `.searchable` still inside the model-observing view): monotonic, 0 backward. **A2** (query box + `.searchable` in a layer that observes only the query): monotonic, 0 backward. In A2 the field layer re-rendered only on query changes (20 times against 107 for the content). |
| U3 | **A press recognizer can't stop the search container's Menu → hidden-tab-bar move; a focus redirect can.** In Sidebar mode, when focus lands on a `UITabBarButton`, call `requestReveal()`: the sidebar opens with focus on its row. Picking a row hands focus back to the keyboard. Up from the keyboard's top row never reaches the hidden bar. **Right from the sidebar can't reach the system keyboard**: it isn't a geometric neighbour. Menu inside the sidebar leaves the app, which is today's FEAT-30 behaviour. | Run 4: the consuming, exclusive window recognizer took the press (`router gate take=1 … inKeyboard=1`) but never recognized, and focus hit `UITabBarButton` 62 ms later with `blocker=1`. So `HiddenTabBarFocusBlocker` doesn't stop it. Run 4b: simultaneous, the recognizer does fire, but the system moves focus anyway. `router redirect hiddenTabBar prev=UIKeyboard -> requestReveal` 25 ms later, and the sidebar is focused (`chromeFocused=1`). |
| U4 | **The bar can't be made to follow `.searchable`'s results on Grid.** Accept it (D4 (a)). | The existing attacher's parent walk from inside `.searchable` stops at `TVSearchController` and never reaches the tab controller. Linking from the top (window root → `UITabBarController` → selected tab: `TabHostingController > NavigationStackHostingController > SearchContainerViewWrapper > UISearchContainerViewController`) attached (`trk=other`), but the bar still sat at `y=46` while `sd=1` (Christian's video `IMG_0379.MOV`, run 2). |
| U5 | **XCUITest sees the field as `app.searchFields`** (`textFields` = 0). `app.typeText` works with focus in the inline keyboard. The empty field's `value` reads "Search movies & shows, Press ￼ to change keyboards"; after typing it reads the query. **The simulator defaults to Linear** (keyboard frame 1760 × 66), and Down goes from the keyboard into the results. While Detail or Home shows, `app.keyboards.count == 0` and `app.searchFields.count == 0`, which is the assertion test92 needs. | Same two XCUITests, `W0 [...]` lines in `logs/xcuitest-*.log`. |
| U6 | **Mode 2:** hold the old rows until the new search finishes, or 1 s after its first row. Christian: "rows stayed put". Mode 1 (swap on the first new row) made the page collapse to one row and regrow on every letter. | Run 1 (mode 1) against run 2 (mode 2: swaps at 0.12–0.27 s with `loading=0` for "dune"). |
| U7 | Not tested (low priority). Logged. | — |

Also learned:

- A new file declaring `ObservableObject`s needs `import Combine` (`MemberImportVisibility`); W1's SearchView does.
- The press logger must read the scene from the window itself, because a `UIWindow`'s own `window` is nil.
- tvOS kills a running app when the keyboard layout changes in Settings (`signal 9`).
- After this run, the FA87 simulator and the Apple TV dev app (`com.youngchris29.NuvioTV`) both hold the rig build. It is inert without its launch flags apart from the A2-shaped SearchView, and the next build replaces it on both.

## Build (S1-a)

NuvioMobile clone `~/Claude/Projects/NuvioMobile-search-s1`, branch `claude/search-s1` off the `tvos-shared-extraction` tip at the start (`dad2bed5` at Wave 0). Waves are cut by file ownership. W1 owns `SearchView.swift` and `SearchViewModel.swift`. W2 owns `SidebarOverlay.swift` and doesn't touch `SearchView`. W3 is dropped. **No `shared/` changes**: `SearchRepository.kt` is an upstream extraction, so everything here stays on the Swift side. No `ContentView.swift` changes either.

### W1 · Field swap (`SearchView.swift`, `SearchViewModel.swift`)

1. **The field.** Delete the `HStack` field block (`SearchView.swift` L30–40). Put `.searchable(text:prompt:)` with the existing key `"Search movies & shows"` (already translated into de/es/fr/it/vi) on the results `ScrollView`, after `.sidebarMenuReveal()`, inside the existing `NavigationStack`. Never put it on the `TabView`, and never add a second `NavigationStack`.
2. **Structure for the echo (U2: settled, A2 shape).** The query must not live in `@State`.
   - `SearchView` owns a `SearchViewOwner` (`@StateObject`) that never publishes and holds the `SearchViewModel` and a `SearchQueryBox` (`@Published text`), so `SearchView`'s body never re-runs on a results update.
   - A `SearchFieldLayer` observes only the query box. It applies `.searchable(text: $queryBox.text, …)` and `.onChange(of: text)` → `model.queryChanged`.
   - `SearchContent` observes the model and draws everything inside the `ScrollView`.
   - `import Combine`. The rig's `SearchView` in `wave0-rig.patch` is the reference.
3. **Keep the old rows while the next ones load.**
   - `SearchRepository` publishes `isLoading = true` with empty sections at the start of every new query (`SearchRepository.kt` L150), so live typing would blank the page on every letter.
   - `SearchViewModel`'s `uiState` watcher keeps the current `sections` while a newer query is loading. It swaps in the new rows when that search finishes (U6 mode 2), and clears to the empty message only when the newer query settles empty. Swapping on the first new row (mode 1) collapsed the page on every letter.
   - *As built (reviews r1/r2):* another query's rows stay at most 1 s after the new search starts, released by a timer even when nothing more is emitted. A same-query restart (manifest refresh, Retry) keeps its rows until the new emission contains every shown section or the search settles. The view model passes the relation (same search, same-query restart, other query) from the query on screen and section-key containment.
   - "Searching…" shows only when there are no rows to keep.
   - The rule goes in a pure `SearchRowsHold` helper so it can be unit-tested.
4. **Recent Searches on open (D5).**
   - Bind the stack: `NavigationStack(path: $path)` with a `NavigationPath`.
   - When the path grows while the trimmed query is non-empty, call `model.recordSearch(query)`. That covers result rows, See All and person pages, from both the results and the Discover grid.
   - Keep `.onSubmit(of: .search)` for the iPhone keyboard's return key.
   - The rule ("record on the first push per query") is a pure `SearchHistoryOnOpen` helper. The repository already ignores queries under 2 characters and dedupes.
   - BUG-47/48 and UX-13 (See All query threading, grid focus on pop) must stay fixed; test23/test24 cover them.
5. ~~tvOS 26 fallback~~ **Dropped:** U1 found no bleed on tvOS 26.5. Today's `TextField` path is deleted, not kept.
6. **Comments.**
   - Rewrite the header's ban (L4–7) as the rule in item 1.
   - Drop the stale "root TextField keeps this screen focusable" note (L228) and `CatalogRowView`'s stale `onSelect` doc (`BrowseComponents.swift` L4927–4929).

### W2 · Sidebar mode (D2 = a, revised by U3: a focus redirect)

**Revised after Wave 0.** No press recognizer can stop the search container's Menu → hidden-tab-bar move, so W2 redirects that focus instead:

- **The redirect.** `HiddenTabBarFocusBlocker` (`DesignSystem/SidebarOverlay.swift`) already observes every `UIFocusSystem.didUpdateNotification` in Sidebar mode. Teach it one more rule, behind a callback the overlay passes in: when the next focused item is a `UITabBarButton` and the sidebar doesn't hold focus, call `chrome.requestReveal()`.
  - This is app-wide, not Search-only: any path into the hidden bar now opens the sidebar instead of stranding focus on an invisible button.
  - The rail plan keeps `HiddenTabBarFocusBlocker`, so the FEAT-45 rail inherits the redirect and only needs it to focus the rail instead.
  - Wave 0's prototype is `SearchMenuRouter.focusUpdated` in `wave0-rig.patch`.
- **Back to the keyboard.** Picking a sidebar row already lands focus on the keyboard (`handOffFocusToContent`). Right from the sidebar does nothing, because the system keyboard isn't its geometric neighbour. Add an app-handled Right on the panel that calls `handOffFocusToContent()`, the same exit the rail plan specifies. Otherwise "pick a row" is the only way back. Small, in `SidebarOverlay.swift`.
- **No `SearchView` change, no new file.** The Home Stage & Strip plan's W2-D, which retires the rest of `SidebarOverlay.swift`, must carry the redirect into the rail. Add one line to its P4 notes.

The original router design is kept below for the record; **do not build it**:

- **Shape.** A zero-size `UIViewRepresentable` that installs a press recognizer on the **window** in `didMoveToWindow` and removes it when it leaves the window or is dismantled. This is `HomeUpSwipeCatcher`'s install/teardown pattern. Search's root leaves the window on every tab switch and push, so the router only exists while Search is on screen.
- **Recognizer.** A `UITapGestureRecognizer` with `allowedPressTypes = [.menu]` and `allowedTouchTypes = []`, left at the default `cancelsTouchesInView = true` so a recognised press is consumed. That is unlike the passive Home catcher. The in-repo precedent for consuming Menu is `NativePlayerHostController.pressesBegan`.
- **Gate.** `gestureRecognizerShouldBegin` requires all of:
  - Sidebar mode on (`SidebarChrome.isEnabled()`);
  - the sidebar not holding focus (`!sidebarChrome.isFocusedChrome`);
  - the focused item inside the system keyboard, found by walking up from `UIFocusSystem.focusedItem` for a `UIKeyboard` or `_UISearchControllerTVKeyboardContainerView`. That class-name heuristic is the spike probe's, and it held on tvOS 27.2. Keep it in one function with a unit test over a fake view tree, and fail closed: if nothing matches, the system default runs.
- **Action.** `sidebarChrome.requestReveal()`, the same path `.sidebarMenuReveal()` takes. Leaving the sidebar reuses `handOffFocusToContent()`.
- **Up from the keyboard** into the hidden bar: fix only if U3 shows it happens. Use the same gate and a blocker re-assert, not a second mechanism.
- **Hand-off to the rail.** Add one line to the Home Stage & Strip plan's P4 notes: the rail's "Menu at a tab root" must cover focus inside the system keyboard, and should adopt this router. That plan also retires `SidebarOverlay.swift`; whichever batch merges second adapts the `requestReveal()` call.

### W3 · Tab bar on Search — DROPPED (U4: the bar can't follow `.searchable`'s results; D4 = accept)

- Replace `TabBarContentScrollLink.homeRowsScrollView`, a single global slot named for Home, with a per-tab slot, and keep `TabBarStateProbe`'s `trk=rows` reading Home's.
- Mount `TabBarContentScrollLinkAttacher(pinnedContainer: false)` in the background of Search's results `VStack`. It stays inert in Sidebar mode, as it already is.
- `TabBarContentScrollLinkTests` grows a Search case.

### W4 · Tests

Six UI tests and two helpers assume today's full-screen keyboard. They find the field with `app.textFields.firstMatch`, Select it to open the keyboard, Menu to dismiss it, then press Down into results:

- **UI tests:** `test19DiscoverSurvivesSearch`, `test23SearchSeeAllBackNoCrash`, `test24CatalogGridFocusRestore`, `test29HideDiscoverToggle`, `test31HeroCommitsOnce` (its Search leg), and `test52SidebarOverlay`.
- **Helpers:** `typeOnKeyboard`, and `DetailScrollProbeTests`'s `typeIntoSearchField` and `openFirstSearchResult`.

Migrate them to the U5 answers:

- find the field with `app.searchFields.firstMatch`. An empty field's `value` is the prompt plus "Press ￼ to change keyboards", so test for the query with `value == "dune"`, not "non-empty";
- `openTab("Search")` already ends with a Down, which lands in the keyboard; type with `app.typeText`;
- no Menu-to-dismiss. test19's Menu ×2 would now leave the app, so it needs a rewrite, not a tweak;
- FA87 is on **Linear**: Down goes from the keyboard into the results. Keep a Grid branch (Right ×7) keyed on `app.keyboards.firstMatch.frame.width < 900`, as the Wave 0 test does.

New tests:

- **UI · `test92SearchLiveResults`.** Type "dune" without submitting; a results row appears. Open it, and no keyboard element exists while Detail shows. Press Menu, and the query is intact and "dune" is now a Recent chip. Run it on FA87 (tvOS 26.5) and once on a tvOS 27.0 simulator.
- **Unit:** `SearchRowsHold` (mode 2 timing), `SearchHistoryOnOpen`, and the hidden-tab-bar redirect rule (pure: given the sidebar state and the next item's class name, reveal or not).

### W5 · Docs and copy

- `docs/design/hig-hybrid-contract.md` L35: take `.searchable` out of "Explicitly out". Add a MUST under "Where the system wins": `.searchable` on the results container inside the tab's own `NavigationStack`; never on the `TabView`; never a nested `NavigationStack`; keep the typed text in an `ObservableObject`, never in `@State` (U2's echo); in Sidebar mode the hidden tab bar's focus is redirected into the sidebar (W2). Verified on tvOS 26.5 (simulator) and 27.2 (device).
- **Settings copy.** Re-read the strings that mention "the search field" (`SettingsDescriptions.swift` L324, `SourcesSettingsPane.swift` L298–299). New strings, if any, go through the localization pipeline for de/es/fr/it/vi.
- **Tracker.** FEAT-37 → BUILT, pointing at this plan.
- **Release notes / Steven's DM.** "Search shows results while you type; dictation and typing from your iPhone work; a search is saved to Recent when you open one of its results." Say how Sidebar mode behaves, whichever D2 path ships. Run SlopMonster before showing either.

**W5 done 2026-10-04 (night):**

- **Design contract.** A **Search** row added to "Where the system wins", spelling out the structure. The `.searchable` line in "Explicitly out" now says why the ban went.
- **Tracker.** FEAT-37 is 🛠 BUILT (not merged or cut).
- **Settings copy.** Re-read, and both strings are still accurate with the system field, so they're unchanged. S1 adds no new strings: the prompt reuses the existing translated key.
- **Release-note line, deslop 5/5.** The Codex cleanse was skipped: the line is short and clean, and Codex is over quota until 10-29. Use it in the cut's highlights, and adapt it for Steven's DM through the loop again:

  > Search shows results while you type. It now uses the Apple TV's own search field, so the rows update under the keyboard after each letter, with no Done to press. Siri dictation works (hold the mic button), you can type from your iPhone, and the keyboard follows your Apple TV's Linear or Grid setting. A search goes into Recent Searches when you open one of its results. In Sidebar mode, Menu from the keyboard opens the sidebar, and Right takes you back.

## Build record (2026-10-04, night)

NuvioMobile `claude/search-s1` in the clone `~/Claude/Projects/NuvioMobile-search-s1`, off `dad2bed5`. It is local and not pushed. ⚠️ MPVKit is a symlink over the gitlink in this clone, so stage by explicit paths and never `git add -A`; `git status` errors there for the same reason.

| Commit | What |
|---|---|
| `8b0710b6` | **W1.** `.searchable` on the results `ScrollView` in Search's own `NavigationStack(path:)`. The query lives in `SearchQueryBox`, with `SearchViewOwner` holding the model and the box (A2 shape). `SearchRowsHold` and `SearchHistoryOnOpen` are in `SearchPolicies.swift`, and Recent is recorded on push. The `TextField` and the stale comments are gone. |
| `c0a33cae` | **W2.** `HiddenTabBarRedirect.shouldReveal` is a pure rule with 4 tests. The blocker's focus observer calls `onFocusLandedInHiddenBar` when the next item is in the blocked bar or is a `UITabBarButton`, and the overlay calls `chrome.requestReveal()`. The panel gets an app-handled Right, `onMoveCommand(.right)` → `handOffFocusToContent()`, which lands on the tab's default focus. |
| `7ebe0b6a` | **W4.** test19/23/24/29/31 (Search leg)/52 and `DetailScrollProbeTests`' helpers drive `app.searchFields` and the inline keyboard. There are new helpers for the keyboard's late arrival and the field value's ", Press ￼ to change keyboards" hint. New `test93SidebarMenuFromSearchKeyboard`. test92 rotates queries that aren't already Recent. |
| `b51a4bb2` | **Review r1** (Opus, read-only, over `dad2bed5..7ebe0b6a`): 0 P1, 1 P2, 10 P3. P2: the hold's 1 s limit was only checked on an emission, and a catalog with no matches emits nothing, so a slow add-on kept the old rows up for 60 s. Now a generation-guarded tick fires at the deadline. P3-5 is accepted: Right lands on the tab's default focus, not where focus was. Every other P3 is fixed. |
| `2a374e0c` | **Review r2** (over `b51a4bb2`): 0 P1, 1 P2, 6 P3. P2: the loop guard was stamped on every redirect, so a second Menu within 1.5 s stranded focus again. Now only a failed rescue stamps it, and test93 gained a second-Menu leg. The P3s: a same-query restart keeps its rows, the relation comes from the view model instead of parsing keys, the tick reschedules only while its deadline is ahead, and test19 asserts its typing. P3-6 was notes only. The gate's own find: after picking Search in the sidebar, the hand-off gave up at 1.0 s and re-armed the panel before the system keyboard arrived (1–2 s), so the ladder now runs to 2.5 s. The UI helper also no longer mistakes a sidebar row for the tab bar, since they share labels. |
| `d68b9d61` | **Reviews r3–r6** (one commit). The hold went through three more P2s, all one race family. When a Kotlin job is cancelled, it can still write after the next search starts: a `StateFlow` write isn't a suspension point, and `activeJob?.cancel()` is cooperative.<br>• **r3 P2:** the hold labelled the shown rows with the query that was active when they were taken, so a deadline tick or a late write could pass the previous query's rows off as the new one's, with no bound. Now the label is read off the rows themselves (each search section's `CatalogTargetAddon.search`, put there by BUG-48).<br>• **r4 P2:** a late write could still reach the screen, or be what a hold released to. Now emissions labelled with another query are dropped, and the tick releases to nothing ("Searching…") when the last accepted emission is stale.<br>• **r5 P2:** with no hold running, a swallowed start state meant no hold ever began. Now the typing debounce reports each search start to the hold (`searchStarted`), and the bound runs from there.<br>• **P3s:** a restart hold that turns into another query's hold starts its clock then; `searchStarted` keeps the clock while typing continues; queries compare trimmed like Kotlin's `trim()` (U+001C–1F) and case-insensitive; the long hand-off ladder applies to Search only (`SidebarHandOffLadder`); the failed-rescue guard is a tested `StrandedRescueGuard`; stale test comments are fixed, and test93 now settles 3 s.<br>• **Accepted:** a late settled-empty write from a cancelled search has no rows to label, so it can flash "No results." until the active search's next write (microseconds of window; it corrects itself). The root fix is a request id on `SearchUiState` with compare-and-set writes in `SearchRepository`, which is `shared/`, outside this batch.<br>• **r6: CLEAN** (0 P1, 0 P2). Fixed P3s: a dropped stale emission re-arms the hold's tick (a tab switch inside the 1 s window could leave it unarmed), plus two more policy tests. Two clarity-only P3s were declined: a narrower `searchStarted` signature, and a helper for the tick's stale substitution. |

**Gates on `d68b9d61` (the tip):**

- NuvioTVTests 1042 / 0: 990 at the base plus 52 new (26 hold, 9 hold relation, 2 row label, 7 history, 4 redirect, 2 rescue guard, 2 hand-off ladder).
- On FA87 (tvOS 26.5): test19/23/24/29/52/93 PASS. test92 PASS 2/2 after its Recent check changed to "the query is the first chip": the gate run before that skipped it, because every fixed candidate was already a Recent Search on the reused fixture. test31 SKIPs at Leg C because the guest fixture has no collection folder. That is environmental and happens before its Search leg.
- Release simulator build (FA87 destination) is green.
- The earlier tips' gates (`2a374e0c` and the round 3–5 trees) were also green. The `2a374e0c` gate found the Sidebar hand-off giving up before Search's keyboard arrived, and test52/test93 passed 2/2 once the hand-off wait was longer; the sim log showed the redirect firing on both Menus with no re-arm.
- **Not run:** test92 on a tvOS 27.0 simulator. The build stalled for 16 min in `CompileAssetCatalogVariant thinned` for 406CA4AC and was stopped. Two 27.0 runtimes are installed (24J5305f and 24J360), which may be the cause. It is still owed and treated as environmental.
- Debug device build: at the device pass.

## Gates

- `NuvioTVTests`, all green, including the new unit tests.
- Migrated UI legs plus test92 on FA87 (tvOS 26.5); test92 on a tvOS 27.0 simulator.
- Debug and Release simulator builds; a Debug device build (`com.youngchris29.NuvioTV`).
- Review: read-only Opus rounds until no P1/P2 remain. Codex is over quota until 10-29.

## Device pass (Living Room Apple TV, **Test profile**)

The TV's keyboard is on **Grid**. Changing the layout in tvOS Settings terminates the app (`signal 9`), so relaunch after switching. The Test profile is in **Sidebar** mode; switch it to Tabs for steps 1–7 and back for step 8.

1. **Grid typing.** Type "dune" one letter at a time. Rows update without blanking.
2. **Open and return.** Open a result, then press Back. The query is intact and focus is on the card.
3. **Linear.** Repeat 1–2 on Linear.
4. **iPhone keyboard.** Type "severance" on the phone. **No flicker** (gate), with each letter appearing once in the probe or log.
5. **Dictation.** Say "the bear".
6. **Recent Searches.** Opening a "dune" result adds the chip. Partial queries never appear.
7. **Tabs mode.** Menu from the keyboard goes to the tab bar. Home shows no keyboard. Search is intact on return. On Grid the bar stays put while the results scroll (D4: accepted); on Linear it scrolls off.
8. **Sidebar mode.** Menu from the keyboard opens the sidebar with focus on its row. Right, or picking the Search row, comes back to Search (picking the row can take up to 2 s while the keyboard arrives; the sidebar must not reopen over it). A second Menu right after opens the sidebar again. Nothing invisible ever holds focus, on Search or any other tab.
9. **Stress.** Open and close Detail five times quickly.
10. **Regressions.** See All → grid → Back (UX-13, BUG-47/48); Hide Discover on and off; Search Sources toggles; Retry on the error state.

## Risks

- ~~tvOS 26 bleeds~~ and ~~the echo fix doesn't hold~~: **retired by Wave 0** (U1: no bleed on 26.5; U2: the A0/A/A2 comparison isolates the cause and the fix). The tvOS 26 check was the simulator, not a 26 device; any tvOS 26 tester report of a keyboard over Detail reopens it.
- **Rail overlap.** Home Stage & Strip's W2-D retires most of `SidebarOverlay.swift` but keeps `HiddenTabBarFocusBlocker`, where W2's redirect lives. The merge order decides who adapts; the rail only changes the redirect's target.
- **UI tests driving an inline keyboard** are new ground for the harness. The tvOS 27.0 simulator never reports `hasFocus`, so the primary UI legs stay on FA87 (26.5).
- **Class-name detection** depends on private UIKit names: `UITabBarButton` for the redirect. If a tvOS update renames it, the redirect stops firing and Menu from the keyboard strands focus on the hidden bar again (Wave 0 run 4's state), with no crash. `test93SidebarMenuFromSearchKeyboard` is the canary.
- **Cancelled-search writes** (reviews r3–r5). The Swift side now drops or bounds them, but a settled-empty late write can still flash "No results." for a moment. The root fix, a request id on `SearchUiState`, belongs in a `shared/` batch, and it's an upstream-report candidate too: mobile's search has the same cancel-then-write shape.

## S1-b outline (separate plan, after the board's questions 2–3)

From the board's S1 direction and its mix-and-match pieces:

- **Results by type.** Top result, Movies, Series, Collections, then People from TMDB opening the existing person page. Merge by id; metadata add-ons first, stream-only add-ons capped (Orivio: 40 per catalog, 8 per stream-only add-on). Per-add-on rows ("Cinemeta · Movies") become a setting. FEAT-10's Search Sources toggles still apply. Prefer a new `shared/` file over editing `SearchRepository.kt`.
- **Suggestion chips:** the typed text in quotes, then title completions. They're ours to draw; the system list only takes plain text.
- **Specific empty states:** "None of your add-ons can search", "All search sources are off", "No results for '…'".
- **Menu goes to the top first** in a long grid.
- **Discover:** D1's pill bar (Movies ▾ · Popular · Cinemeta ▾ · Drama ▾ · Filters) and D2's landing tiles (genres, decades, collection folders, Trending).
- **Power-user chips** (play a link or magnet, Debrid Cloud) wait on the board's question 6.
- **Revisit D3** (hide the bar while typing) once the page has its new content.

## Effort and delegation

- **Wave 0:** done 2026-10-04 evening: three FA87 simulator runs plus one device session (runs 1–4b, about 25 minutes of Christian's time).
- **W1–W5:** about a day of agent work plus gates, then the review rounds and the device pass. Delegation follows the playbook:
  - W1 to Opus (the A2 structure, `NavigationPath`, rows hold), working from the rig patch;
  - W2 to Opus (the redirect and the Right exit in `SidebarOverlay.swift`);
  - W4 to Sonnet, from the U5 facts above;
  - W5 in the main session.
- **Concurrency.** Nothing here overlaps Home Stage & Strip's Wave 0/1 files (`HomeView.swift`, the strip and stage). The overlap is W2 and that batch's W2-D, both in `SidebarOverlay.swift`.

**Next step:** the device pass above in the **Test** profile (a Debug device build of `claude/search-s1` under `com.youngchris29.NuvioTV`), then Christian's call on merging into `tvos-shared-extraction` and cutting. Nothing is pushed until he says so.

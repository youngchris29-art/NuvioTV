# Search S1 · Native Search (2026-10-04)

**Status: DRAFT PLAN, NOT APPROVED. No code written.** Needs Christian's calls on D1–D5 below; after that, Wave 0 (a throwaway rig plus one short device session) settles the six unknowns before any production code. Written from:

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
| D2 | Sidebar mode (the Test profile's default) | (a) Build a Menu router now: Menu pressed while focus is in the system keyboard opens the sidebar. The FEAT-45 rail reuses it. (b) Sidebar mode keeps today's `TextField` until the rail replaces Sidebar mode. (c) Hold all of S1 until the rail lands. | **(a), falling back to (b) if Wave 0 can't make the router work.** The rail hides the system tab bar for good. The spike showed that `HiddenTabBarFocusBlocker` does not stop the search container from sending Menu-focus to that hidden bar, so the rail has to solve the same press anyway. Solving it here gives the rail's P4 spec a proven mechanism. It's one new file and doesn't touch `ContentView.swift`. |
| D3 | Tab bar while the keyboard is up | (a) Leave it visible (spike-tested). (b) Hide it while the keyboard has focus (board, bobsupra). | **(a).** (b) adds a new tab-bar visibility trigger (BUG-66 territory) for a look nobody has seen yet. Revisit in S1-b. |
| D4 | With Grid, the bar stays pinned on Search instead of scrolling off (`y=46` while the scroll latch reads `sd=1`) | (a) Accept. (b) Link it to the results with `TabBarContentScrollLink`. | **Let Wave 0 decide.** Ship (b) only if the controller chain under `.searchable` links cleanly (U4); otherwise (a), and log it. |
| D5 | When a query joins Recent Searches (the inline keyboard has no Search/Done key) | (a) When a result is opened from it. (b) After it rests with results. (c) Both. | **(a)**, plus the iPhone keyboard's return key through `.onSubmit(of: .search)`. (b) would save partial words like "dun". This matches VortX and the board's "saved on intent". |

One rule rather than a decision: **if tvOS 26 still bleeds (U1), tvOS 26 keeps today's `TextField`** behind `#available(tvOS 27, *)`. The deployment target is 26.0.

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

## Build (S1-a)

NuvioMobile clone `~/Claude/Projects/NuvioMobile-search-s1`, branch `claude/search-s1` off the `tvos-shared-extraction` tip at the start (`422bb0c4` today). Waves are cut by file ownership. `SearchView.swift` belongs to W1; W2 and W3 each add one mount line to it after W1 lands. **No `shared/` changes**: `SearchRepository.kt` is an upstream extraction, so everything here stays on the Swift side. No `ContentView.swift` changes either, which keeps clear of Home Stage & Strip.

### W1 · Field swap (`SearchView.swift`, `SearchViewModel.swift`)

1. **The field.** Delete the `HStack` field block (`SearchView.swift` L30–40). Put `.searchable(text:prompt:)` with the existing key `"Search movies & shows"` (already translated into de/es/fr/it/vi) on the results `ScrollView`, after `.sidebarMenuReveal()`, inside the existing `NavigationStack`. Never put it on the `TabView`, and never add a second `NavigationStack`.
2. **Structure for the echo**, as U2 settles it. The default from the hypothesis:
   - `SearchView` owns a `SearchQueryBox` (`@StateObject`, `@Published text`) and applies `.searchable` and `.onChange(of: text)` → `model.queryChanged`.
   - A child, `SearchContent`, owns or observes `SearchViewModel` and draws everything inside the `ScrollView`.
   - A results update then re-renders only the child.
3. **Keep the old rows while the next ones load.**
   - `SearchRepository` publishes `isLoading = true` with empty sections at the start of every new query (`SearchRepository.kt` L150), so live typing would blank the page on every letter.
   - `SearchViewModel`'s `uiState` watcher keeps the current `sections` while a newer query is loading and has no section yet. It swaps in the first new section when it arrives, and clears to the empty message only when the newer query settles empty.
   - "Searching…" shows only when there are no rows to keep.
   - The rule goes in a pure `SearchRowsHold` helper so it can be unit-tested.
4. **Recent Searches on open (D5).**
   - Bind the stack: `NavigationStack(path: $path)` with a `NavigationPath`.
   - When the path grows while the trimmed query is non-empty, call `model.recordSearch(query)`. That covers result rows, See All and person pages, from both the results and the Discover grid.
   - Keep `.onSubmit(of: .search)` for the iPhone keyboard's return key.
   - The rule ("record on the first push per query") is a pure `SearchHistoryOnOpen` helper. The repository already ignores queries under 2 characters and dedupes.
   - BUG-47/48 and UX-13 (See All query threading, grid focus on pop) must stay fixed; test23/test24 cover them.
5. **tvOS 26 (only if U1 bleeds).** Move today's field into a `LegacySearchField` view, used under `if #available(tvOS 27, *) { … } else { … }`. Both paths share the same `query` and view model.
6. **Comments.**
   - Rewrite the header's ban (L4–7) as the rule in item 1.
   - Drop the stale "root TextField keeps this screen focusable" note (L228) and `CatalogRowView`'s stale `onSelect` doc (`BrowseComponents.swift` L4927–4929).

### W2 · Sidebar mode (D2 = a)

New `DesignSystem/SystemKeyboardMenuRouter.swift`, mounted once in `SearchView`'s root:

- **Shape.** A zero-size `UIViewRepresentable` that installs a press recognizer on the **window** in `didMoveToWindow` and removes it when it leaves the window or is dismantled. This is `HomeUpSwipeCatcher`'s install/teardown pattern. Search's root leaves the window on every tab switch and push, so the router only exists while Search is on screen.
- **Recognizer.** A `UITapGestureRecognizer` with `allowedPressTypes = [.menu]` and `allowedTouchTypes = []`, left at the default `cancelsTouchesInView = true` so a recognised press is consumed. That is unlike the passive Home catcher. The in-repo precedent for consuming Menu is `NativePlayerHostController.pressesBegan`.
- **Gate.** `gestureRecognizerShouldBegin` requires all of:
  - Sidebar mode on (`SidebarChrome.isEnabled()`);
  - the sidebar not holding focus (`!sidebarChrome.isFocusedChrome`);
  - the focused item inside the system keyboard, found by walking up from `UIFocusSystem.focusedItem` for a `UIKeyboard` or `_UISearchControllerTVKeyboardContainerView`. That class-name heuristic is the spike probe's, and it held on tvOS 27.2. Keep it in one function with a unit test over a fake view tree, and fail closed: if nothing matches, the system default runs.
- **Action.** `sidebarChrome.requestReveal()`, the same path `.sidebarMenuReveal()` takes. Leaving the sidebar reuses `handOffFocusToContent()`.
- **Up from the keyboard** into the hidden bar: fix only if U3 shows it happens. Use the same gate and a blocker re-assert, not a second mechanism.
- **Hand-off to the rail.** Add one line to the Home Stage & Strip plan's P4 notes: the rail's "Menu at a tab root" must cover focus inside the system keyboard, and should adopt this router. That plan also retires `SidebarOverlay.swift`; whichever batch merges second adapts the `requestReveal()` call.

### W3 · Tab bar on Search (only if U4 links cleanly)

- Replace `TabBarContentScrollLink.homeRowsScrollView`, a single global slot named for Home, with a per-tab slot, and keep `TabBarStateProbe`'s `trk=rows` reading Home's.
- Mount `TabBarContentScrollLinkAttacher(pinnedContainer: false)` in the background of Search's results `VStack`. It stays inert in Sidebar mode, as it already is.
- `TabBarContentScrollLinkTests` grows a Search case.

### W4 · Tests

Six UI tests and two helpers assume today's full-screen keyboard. They find the field with `app.textFields.firstMatch`, Select it to open the keyboard, Menu to dismiss it, then press Down into results:

- **UI tests:** `test19DiscoverSurvivesSearch`, `test23SearchSeeAllBackNoCrash`, `test24CatalogGridFocusRestore`, `test29HideDiscoverToggle`, `test31HeroCommitsOnce` (its Search leg), and `test52SidebarOverlay`.
- **Helpers:** `typeOnKeyboard`, and `DetailScrollProbeTests`'s `typeIntoSearchField` and `openFirstSearchResult`.

Migrate them to the U5 answers:

- find the field the new way;
- type with focus already in the keyboard;
- no Menu-to-dismiss. test19's Menu ×2 would now leave the app, so it needs a rewrite, not a tweak;
- go Right into the results on Grid and Down on Linear, reading the layout from the screen or pinning it on FA87.

New tests:

- **UI · `test92SearchLiveResults`.** Type "dune" without submitting; a results row appears. Open it, and no keyboard element exists while Detail shows. Press Menu, and the query is intact and "dune" is now a Recent chip. Run it on FA87 (tvOS 26.5) and once on a tvOS 27.0 simulator.
- **Unit:** `SearchRowsHold`, `SearchHistoryOnOpen`, and the router's focus-in-keyboard walk.

### W5 · Docs and copy

- `docs/design/hig-hybrid-contract.md` L35: take `.searchable` out of "Explicitly out". Add a MUST under "Where the system wins": `.searchable` on the results container inside the tab's own `NavigationStack`; never on the `TabView`; never a nested `NavigationStack`; tvOS 26 keeps the `TextField` if U1 says so.
- **Settings copy.** Re-read the strings that mention "the search field" (`SettingsDescriptions.swift` L324, `SourcesSettingsPane.swift` L298–299). New strings, if any, go through the localization pipeline for de/es/fr/it/vi.
- **Tracker.** FEAT-37 → BUILT, pointing at this plan.
- **Release notes / Steven's DM.** "Search shows results while you type; dictation and typing from your iPhone work; a search is saved to Recent when you open one of its results." Say how Sidebar mode behaves, whichever D2 path ships. Run SlopMonster before showing either.

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
7. **Tabs mode.** Menu from the keyboard goes to the tab bar. Home shows no keyboard. Search is intact on return. The bar's scroll behaviour on Grid matches what D4 shipped.
8. **Sidebar mode.** Menu from the keyboard opens the sidebar. Right and Menu come back into Search, and nothing invisible ever holds focus.
9. **Stress.** Open and close Detail five times quickly.
10. **Regressions.** See All → grid → Back (UX-13, BUG-47/48); Hide Discover on and off; Search Sources toggles; Retry on the error state.

## Risks

- **tvOS 26 bleeds (U1).** tvOS 26 keeps the `TextField`, and S1-a's live search is tvOS 27+ only. Say so in the release notes.
- **The echo fix doesn't hold (U2).** Options for Christian:
  - ship with a release-note caveat ("typing from an iPhone may flicker");
  - drop iPhone typing's promise from the copy;
  - hold S1-a.

  Dictation is unaffected.
- **Rail overlap.** Home Stage & Strip's W2-D retires `SidebarOverlay.swift` and moves Menu routing into the shell. The router is one file with one `requestReveal()` call. The merge order decides who adapts.
- **UI tests driving an inline keyboard** are new ground for the harness. The tvOS 27.0 simulator never reports `hasFocus`, so the primary UI legs stay on FA87 (26.5).
- **Class-name keyboard detection** depends on private UIKit names. The router fails closed: no match means the system default, which is today's spike behaviour, not a crash.

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

- **Wave 0:** about half a day, including the ~40-minute device session.
- **W1–W5:** about a day of agent work plus gates, then the review rounds and the device pass. Delegation follows the playbook:
  - W1 and W2 to Opus (judgment: the echo structure, `NavigationPath`, the router gate);
  - W3 and W4 to Sonnet, from exact specs written after Wave 0;
  - W5 in the main session.
- **Concurrency.** Nothing here overlaps Home Stage & Strip's Wave 0/1 files (`HomeView.swift`, the strip and stage). The overlap is W2 and that batch's W2-D.

**Next step:** Christian's answers on D1–D5, then Wave 0.

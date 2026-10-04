# Search-field spike (2026-10-04)

**Status: PREPARED, NOT RUN.** The code was written in a cloud session, which has no Mac, Xcode or Apple TV, so it has **never been compiled**. Building it and walking the legs below needs a session on Christian's Mac with the Living Room Apple TV. Throwaway: build it in a throwaway clone and never merge it.

## The question

Can tvOS 26/27's system search field (`.searchable`) replace Search's plain `TextField` without the bug that got it banned?

- The ban is in `SearchView.swift`'s header and `docs/design/hig-hybrid-contract.md`: "`.searchable` inside a `TabView` leaves a persistent keyboard panel that bleeds over results and pushed screens."
- If the ban can go, Search gets results under the keyboard as you type (FEAT-37), Siri dictation, typing on an iPhone, and the viewer's own Linear or Grid keyboard. That is direction **S1 · Native Search** on the revamp board (`docs/research/search-library-revamp-2026-10-04.html`).
- If the ban stays, live search means drawing our own keyboard: direction **S2 · Split Search**.

Two other Apple TV clients ship the system field on tvOS 26:

- **VortX** (`app/SourcesTV/SearchView.swift`) puts `.searchable` straight on the results `ScrollView` inside the tab's `NavigationStack`, which is the structure the ban describes. Titles push Detail with `NavigationLink`. It also carries a `TabBarHealer`, because after the system keyboard the tab bar could end up "parked offscreen".
- **bobsupra NuvioTVOS** (`UI/Search/NativeSearchView.swift`) puts `.searchable` in its own small `NavigationStack` that holds only `Color.clear`, clipped to a fixed frame (220 pt band for the Linear keyboard, 780 × 780 pt column for Grid). Results are drawn outside that stack, and titles open from the outer screen. It detects Linear vs Grid by looking for the keyboard's views in the window.

## What the patch does

`search-field-spike.patch` applies on `tvos-shared-extraction` `7e71ba87` (beta.19-rc2), checked with `git apply --check`. It adds `Screens/SearchFieldSpike.swift` and makes small edits to `SearchView.swift` and `ContentView.swift`. With no launch flag, every spike path is inert and Search is today's screen.

Launch flag `-debug.searchFieldSpike`:

| Value | Variant | Built like |
|---|---|---|
| unset | **Control**: today's `TextField` and full-screen keyboard | today |
| `A` | **Plain**: `.searchable` on the results `ScrollView`, Detail pushed as today | VortX; exactly what the ban describes |
| `B` | **Host**: `.searchable` in its own clipped `NavigationStack`; results below it (Linear) or to its right (Grid); Detail pushed by the outer stack | bobsupra |
| `C` | **Search tab**: `Tab(role: .search)` and `.searchable` on the `TabView` | Apple's WWDC25 pattern |

In every variant, today's field is hidden and the results, history chips and Discover below it are unchanged.

### Log lines

Every observation is logged as `[SearchSpike] t=<seconds> …` through `NSLog`:

| Line | Meaning |
|---|---|
| `scanner armed variant=X` | The probe is running. |
| `query '<text>'` | Each change of the typed text. |
| `results sections=N loading=…` | Results arrived. The gap from the last `query` line is the keystroke-to-results latency (350 ms debounce plus the add-on fan-out). |
| `kb <ViewClass> linear\|grid x,y WxH screen=… tab=…` | A keyboard view is visible in the window (polled every 250 ms, logged on change). `kb none` means no keyboard. |
| `layout linear\|grid` | Which keyboard the probe saw. Variant B lays out around it. |
| `screen detail\|grid\|person appear/disappear` | A screen was pushed from Search, or popped. |
| `tab N` | Tab switch (0 Home, 1 Search, 2 Library). |
| `focus <Type> screen=… tab=…` | The focused item's type changed. |
| `tabbar y=… h=… onscreen=0\|1` | The system tab bar's frame. `onscreen=0` while you expect the bar is VortX's "parked offscreen" symptom. |

**The bug in one line:** any `kb …` line that is not `none` while `screen=detail`, `screen=grid`, `screen=person`, or `tab=` anything but 1.

The keyboard detector looks for views whose class name contains "Keyboard", the same heuristic bobsupra uses. If L1 shows the keyboard on screen but the log only ever says `kb none`, the detector missed Apple's class names: trust the photos for L4–L6 and note it in the results.

## How to run it

1. **Throwaway clone** (never `git worktree` on the submodule; see CLAUDE.md "Branch hygiene"):
   ```sh
   git clone ~/Claude/Projects/Nuvio-tvOS/NuvioMobile ~/Claude/Projects/NuvioMobile-search-spike
   cd ~/Claude/Projects/NuvioMobile-search-spike
   git checkout 7e71ba87
   git apply ~/Claude/Projects/Nuvio-tvOS/docs/research/search-field-spike-2026-10-04/search-field-spike.patch
   ```
2. **Build** a Debug device build with the usual dev-build recipe (bundle-ID override to `com.youngchris29.NuvioTV`, as for the Home Stage spike) and install it on the Living Room Apple TV. If it doesn't compile, see "Compile risks" below.
3. **Profile:** the **Test** profile, never "Chris" (standing rule). Cinemeta's search catalog is enough; a second add-on with a search catalog makes the results more realistic.
4. **Launch** one variant at a time, streaming the console to a log. App arguments go after `--`:
   ```sh
   xcrun devicectl device process launch --console --terminate-existing --device <id> \
     com.youngchris29.NuvioTV -- -debug.searchFieldSpike A -debug.tabBarStateProbe YES \
     > ~/Downloads/search-spike-A.log 2>&1
   ```
   Run the control (no `-debug.searchFieldSpike`), then `A`, `B` and `C`. Expect about 15 minutes per variant, or about 2 hours with the Grid repeat and the write-up.
5. **Photos:** take one photo per variant of L1 (the empty screen with the keyboard up) and L2 (results while typing). The log can't show how it looks.

## The legs

Run L1–L9 for each variant (L1–L4 also for the control, as the baseline). Then run L10 (Grid keyboard) for whichever variants passed L4 and L6. Run L11 once on the best variant.

| Leg | Do | Watch | Pass |
|---|---|---|---|
| **L1 Open** | Select the Search tab. | Where the field sits, whether the keyboard is already up, and what is focused. | The field is reachable in one press and nothing overlaps the tab bar. |
| **L2 Type** | Type `d`, `u`, `n`, `e` one letter at a time, pausing about 1 s between letters. | Do results appear **under the keyboard** while it is still up? Check the `query` → `results` gaps. | Results are visible while typing, and each pause shows updated rows within about 1.5 s. |
| **L3 Into results** | Press Down into the results, walk a row, then press Up. | Does the keyboard stay, shrink or scroll away? Can every row be reached? Does Up return to the keyboard? | Every row is reachable, Up returns to typing, and focus never gets stuck. |
| **L4 Open a title** | Select a result to push Detail, look around, then press Menu to go back. | **Any keyboard drawn over Detail?** The log shows `kb …` while `screen=detail`. After Back: is the query still there, and where is focus? | `kb none` for the whole time Detail is up. Back returns to the result you opened, with the query intact. |
| **L5 See All and person** | Open a row's See All, go back, then open a person (cast) from Detail, go back. | Same as L4, with `screen=grid` and `screen=person`. | No keyboard on either. |
| **L6 Switch tabs** | With the keyboard up, press Menu to reach the tab bar, open Home, scroll Home, then return to Search. | Any keyboard on Home? (`kb …` with `tab=0`) What is the Search field's state when you return? | No keyboard outside Search. Search comes back usable. |
| **L7 Tab bar health** | After L4–L6, press Menu from content on Home and on Search, and scroll Home. | Does the bar appear, and does it minimize on scroll as it does in the control? (`tabbar … onscreen=`) | The same behaviour as the control. No `onscreen=0` when the bar should show. |
| **L8 Dictation** | Focus the field, hold the Siri button and say "the bear". | Does the text land in the field, and do results follow? | Text appears and results update. |
| **L9 iPhone keyboard** | With the field focused, accept the keyboard notification on the iPhone and type `severance`. | Does the TV update live as you type on the phone? | Live updates, same as L2. |
| **L10 Grid keyboard** | Switch Apple TV Settings › General › Keyboard Layout to Grid (if it is offered), then repeat L1–L4. | `layout grid` in the log. Where do results sit, and how wide are they? (Apple keeps the full-width results for its own apps.) | Results are readable beside the keyboard and L4 still passes. |
| **L11 Sidebar mode** | Settings → Look → Appearance → Navigation: Sidebar. Repeat L1, L4 and L6 on the best variant. | Does Menu from the keyboard bring up the sidebar? Does Left from the keyboard enter it? This stands in for the FEAT-45 rail, which isn't built yet. | The sidebar is reachable and nothing bleeds. |

Also note for each variant:

- **Recent searches:** does pressing the keyboard's search/Done key save the query to Recent (`onSubmit(of: .search)`)?
- **Menu with an empty field:** what does Menu do from the keyboard? Leave Search, reveal the tab bar, or exit the app?
- **Stress:** open and close Detail five times quickly from results. Any stuck keyboard, lost focus, or doubled field?
- **Look:** the system field draws its own Liquid Glass style and won't take Open Sans. Is that acceptable next to the rest of the app?

## Deciding

| Result | What it means for the revamp |
|---|---|
| **A passes L4–L7** | The original bug is gone on tvOS 26/27. Lift the ban and build S1 the simple way (VortX's structure). |
| **A fails L4 or L6, B passes** | The bug still exists, but the host pattern contains it. Build S1 with bobsupra's host and lift the ban with that pattern spelled out. |
| **C passes and its tab-bar look is acceptable** | Possible alternative to A or B. Check how the search-role tab sits in the tab bar and with the sidebar. |
| **A, B and C all fail L4, L6 or L7** | Keep the ban. Live search means S2 (our own keyboard). |
| **L2 fails everywhere** (results only after Done) | The system field doesn't stream text on tvOS. S2 is the only live route. |
| **L8 or L9 fails in a passing variant** | Still worth S1, but the board's "dictation and iPhone typing for free" claim needs correcting. |

Fill in the results here once the walk is done:

| Leg | Control | A | B | C |
|---|---|---|---|---|
| L1 Open | | | | |
| L2 Type (latency) | | | | |
| L3 Into results | | | | |
| L4 Open a title | | | | |
| L5 See All / person | | | | |
| L6 Switch tabs | | | | |
| L7 Tab bar health | | | | |
| L8 Dictation | | | | |
| L9 iPhone keyboard | | | | |
| L10 Grid keyboard | | | | |
| L11 Sidebar mode | | | | |

## Compile risks

The patch was written without a compiler. The places most likely to need a touch:

1. **`Tab(…, role: SearchFieldSpike.variant == .c ? .search : nil)`** in `ContentView.swift` assumes `role:` takes a `TabRole?`. If it doesn't, declare the Search tab twice under `if SearchFieldSpike.variant == .c { … } else { … }` inside the `TabView` builder.
2. **`.toolbar(.hidden, for: .navigationBar)`** in `SpikeSearchFieldHost`: bobsupra uses the same call on tvOS. If it doesn't compile, delete it, since it only hides an empty bar.
3. **`scene.focusSystem?.focusedItem`** in the probe: if it doesn't compile, drop the `focus` line. The other probes don't depend on it.
4. **Default MainActor isolation:** the probe's 250 ms loop is a `Task` started from a `UIView`, so it inherits the main actor. In Swift 5 mode, anything Xcode flags here should be a warning, not an error.

## Cleanup

Delete `~/Claude/Projects/NuvioMobile-search-spike` once the results are written into the table above. Nothing from the patch merges. The real S1 or S2 build starts from a plan written from these results.

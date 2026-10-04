# Search-field spike (2026-10-04)

**Status: RUN 2026-10-04** on the Living Room Apple TV (Apple TV 4K 3rd gen, **tvOS 27.2**, build 24K5093g), Test profile, built with Xcode 27.0. **Verdict: variant A passes L4–L7, so the ban can go and S1 is the route** (see [Outcome](#outcome)). The kit was written in a cloud session without a compiler; it needed one compile fix plus four probe changes on the Mac, all listed under [Changes made on the Mac run](#changes-made-on-the-mac-run). The patch in this folder was regenerated from the clone that ran, so it builds as-is. Logs are in `logs/`, photos in `photos/`. Throwaway: build it in a throwaway clone and never merge it.

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

`-debug.searchFieldSpikeProbe YES` (added on the Mac run) runs the probe on the control too, with the control's UI unchanged. That gives a baseline for the keyboard detector and the latency lines.

### Log lines

Every observation is logged as `[SearchSpike] t=<seconds> …` through `NSLog` **and** appended to `Library/Caches/search-spike.log` in the app container, with a `=== launch <date> variant=<X|control>` header per launch. The file is the reliable copy: the `devicectl --console` stream to the Apple TV dropped eight times in this run (`Mercury error 1001`, or the app being suspended). Pull it with:

```sh
xcrun devicectl device copy from --device <id> --domain-type appDataContainer \
  --domain-identifier com.youngchris29.NuvioTV \
  --source Library/Caches/search-spike.log --destination search-spike-device.log
```

| Line | Meaning |
|---|---|
| `scanner armed variant=X` | The probe is running (`-` = the control). |
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

On tvOS 27.2 the detector works. It sees `UIKeyboard` (Grid: 432×750 pt) and the search controller's band `_UISearchControllerTVKeyboardContainerView` (1920×135 pt over Grid, 1920×245 pt for Linear). It also sees the control's full-screen keyboard (`UIKeyboard grid 298,165 432x750`). On Linear only the band is seen, so `layout linear` never fires. The scanner sits on the tab shell, so it keeps sampling while another tab is on screen. The screen tag is a stack, so Detail → person is labelled `person`.

## How to run it

1. **Throwaway clone** (never `git worktree` on the submodule; see CLAUDE.md "Branch hygiene"). The outer checkout's folder name has a space:
   ```sh
   OUTER="$HOME/Claude/Projects/Nuvio tvOS"
   git clone --no-checkout "$OUTER/NuvioMobile" ~/Claude/Projects/NuvioMobile-search-spike
   cd ~/Claude/Projects/NuvioMobile-search-spike
   git remote set-url --push origin DISABLED-throwaway-spike
   git checkout 7e71ba87
   ln -s "$OUTER/NuvioMobile/MPVKit" MPVKit && cp "$OUTER/NuvioMobile/local.properties" .
   git apply "$OUTER/docs/research/search-field-spike-2026-10-04/search-field-spike.patch"
   mkdir -p iosApp/build
   ```
2. **Build** a Debug device build with the usual dev-build recipe and install it on the Living Room Apple TV (sandbox off for `xcodebuild`; the first build links the Kotlin framework, about 10 minutes):
   ```sh
   cd iosApp && xcodebuild -project iosApp.xcodeproj -scheme NuvioTV -configuration Debug \
     -destination 'generic/platform=tvOS' -derivedDataPath build/DerivedDataDevice -allowProvisioningUpdates \
     'PRODUCT_BUNDLE_IDENTIFIER=$(PRODUCT_BUNDLE_IDENTIFIER_$(TARGET_NAME):default=$(inherited))' \
     PRODUCT_BUNDLE_IDENTIFIER_NuvioTV=com.youngchris29.NuvioTV \
     PRODUCT_BUNDLE_IDENTIFIER_NuvioTopShelf=com.youngchris29.NuvioTV.NuvioTopShelf build
   xcrun devicectl device install app --device <id> build/DerivedDataDevice/Build/Products/Debug-appletvos/NuvioTV.app
   ```
3. **Profile:** the **Test** profile, never "Chris" (standing rule). Cinemeta's search catalog is enough; a second add-on with a search catalog makes the results more realistic.
4. **Launch** one variant at a time, streaming the console to a log. App arguments go after `--`:
   ```sh
   xcrun devicectl device process launch --console --terminate-existing --device <id> \
     com.youngchris29.NuvioTV -- -debug.searchFieldSpike A -debug.tabBarStateProbe YES \
     > ~/Downloads/search-spike-A.log 2>&1
   ```
   Run the control (no `-debug.searchFieldSpike`; add `-debug.searchFieldSpikeProbe YES` for its log), then `A`, `B` and `C`. Expect about 15 minutes per variant, or about 2 hours with the keyboard-layout repeat and the write-up. Wake the TV before each launch: a launch into a sleeping TV fails, and its console drops. Changing the keyboard layout in tvOS Settings terminated the app (`signal 9`), so relaunch after it.
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

## Results (2026-10-04)

Walked by Christian with the remote, logs read live. The Apple TV's keyboard layout was already **Grid**, so L1–L9 ran on Grid and L10 became the **Linear** repeat. Latency is from the `query` line to the first non-empty `results` line ("first row") and to `loading=false` ("all rows"). The control ran first, so its numbers are cold-cache; A and B re-searched the same words with the add-ons' caches warm. The first-row figure is mostly the 350 ms debounce either way.

| Leg | Control | A | B | C |
|---|---|---|---|---|
| L1 Open | **Pass.** Field at the top, focused on its own (`TVTextField` 0.36 s after the tab opened), no keyboard until clicked. | **Pass.** The inline Grid keyboard is already drawn on the left with Discover on the right; focus stays on the tab bar, one press down to type. Nothing overlaps the bar. | **Pass.** Same arrangement inside the host. One layout jump: the host draws the Linear band first and switches to Grid 0.27 s after the probe sees the keyboard. | **Fail.** From launch, on Home: tvOS wraps the **whole tab shell** in the search controller. Keyboard and field top-left on every tab, the app (with its own tab bar) shrunk into the results area, focus taken by the keyboard (`kb … tab=0` at 0.08 s). |
| L2 Type (latency) | Text streams into the field live, but results are only visible blurred behind the full-screen keyboard. First row 0.47–0.64 s, all rows 1.3–2.2 s (cold). | **Pass.** Rows update beside the keyboard while typing. First row 0.47–0.58 s, all rows 0.64–0.78 s (warm). | **Pass** on timing (first row 0.47–0.61 s, all rows 0.62–0.73 s, warm), with a visible stutter: the host slid ~400 pt sideways and back over 0.5 s when the results column changed state (kit layout bug, below). | Not run. |
| L3 Into results | **Pass.** Every row reachable; Up lands on the field, no keyboard. | **Pass.** Right into the results, every row reachable, the keyboard stays put, Left returns to typing. | **Pass.** Same as A. | Not run. |
| L4 Open a title | **Pass.** No keyboard on Detail; query kept; focus back on the card. | **Pass.** `kb none` for the whole 32 s Detail was up; query kept; focus back on the card. The keyboard reappears ~0.5 s before Detail's `disappear`, which is the pop animation bringing Search back. | **Could not run.** Selecting a card does nothing: the kit nests the host's `NavigationStack` inside Search's, and the value links (`NavigationLink(value: TitleRoute…)`) never push. Kit defect, not the pattern's. | Not run. |
| L5 See All / person | — | **Pass.** No keyboard on the See All grid or the person page; Search intact after. | Could not run (same defect). | Not run. |
| L6 Switch tabs | — | **Pass** by eye: Menu → tab bar, nothing on Home, Search intact on return. The scanner still lived in SearchView in that build and sampled Home once (`kb none`, 70 ms after the switch). | **Pass.** Scanner on the shell: `kb none` the whole time on Home; Search intact on return. | **Fail.** The keyboard never left: no `kb none` through tab switches 1 → 0 → 2 → 1 → 0. |
| L7 Tab bar health | Baseline: the bar scrolls off with the results (to `y=-3067`) and slides back at the top; hidden on Detail. | **Healthy**, but different on Search: with Grid the bar stays pinned while the results scroll: `[TabBarStateProbe] y=46 … sd=1` seven times, so the scroll latch says scrolled down while the bar sits at rest. Menu brings it back; Home normal. | Same as A (`y=46 … sd=1` four times on Search; Home scrolls and restores). | Not run (the bar lives inside the wrapped shell). |
| L8 Dictation | — | **Pass.** Hold mic, "the bear": `T` → `The` → `The bear` in 0.26 s; first row 0.61 s after, all rows 2.97 s (cold). | Not run. | Not run (C shows "Hold 🎤 to dictate"). |
| L9 iPhone keyboard | **Pass, clean.** Live, no flicker: each of the 9 letters once, in order. | **Live, with an echo.** Phone and TV fight over the text: `Sev`↔`Seve` four times in 0.3 s; the final letter `Severanc`↔`Severance` 22 times over 3.6 s. Visible flicker. Settles on the right text; first row 0.44 s after it settles. | Not run. | Not run. |
| L10 Other layout (Linear) | (Grid is this TV's default, so L1–L4 above are Grid.) | **Pass** L1–L4 on Linear: a one-line strip under the field (band 1920×245 pt), results full-width beneath, first row 0.46–0.52 s; `kb none` for the 16 s on Detail; query and focus kept. On Linear the bar scrolls off with the results again, like the control. | Not run (L4 not passed). | Not run (failed L6). |
| L11 Sidebar mode | — | **Fail on reachability, no bleed.** L1 pass (focus lands on the keyboard, nothing touches the pill); L4 pass (no keyboard on Detail; Back returns focus to the keyboard). But **the sidebar can't be reached from the keyboard**: Menu sends focus to the hidden, still-focusable system tab bar (`focus UITabBarButton`, nothing visible on screen), a second Menu suspends the app, and Left from the keyboard does nothing. From a Discover chip, Menu opens the sidebar, and a Home round trip leaves Search intact. | — | — |

Per-variant notes:

- **Recent searches.** A: nothing saved. The inline keyboard has no Search/Done key, so `onSubmit(of: .search)` never fires. The control saved "Severance" through its full-screen keyboard's Done.
- **Menu with an empty field.** A: first Menu → tab bar, second → exits the app (same as from any tab bar). C: Menu exits the app; there is no way back to an unwrapped shell.
- **Stress (open/close Detail five times quickly).** A: pass, no stuck keyboard, focus kept, no doubled field.
- **Look.** A: Christian finds the system field (large "Search movies & shows" title, thin rule, system font) acceptable next to the rest of the app.
- **Search role (C).** On tvOS the search role changed nothing visible in the tab bar: Search keeps its place and style.

## Outcome

**Row 1 of the Deciding table applies: A passes L4–L7.** On tvOS 27.2, `.searchable` on Search's results `ScrollView` inside the tab's `NavigationStack` (VortX's structure) does not leave a keyboard over pushed screens or other tabs. The walk covered 11 Detail opens (five of them the quick-fire stress run), a See All grid and a person page, in both keyboard layouts and in Sidebar mode. All 10 keyboard lines logged while a pushed screen was tagged fall 0.41–0.57 s before that screen's `disappear`, so each one is the pop back to Search. On Home the keyboard was gone every time. **The ban can go, and S1 · Native Search is the route; S2 isn't needed.** B (the clipped host) isn't needed either. C (`.searchable` on the TabView) is a dead end on tvOS: it wraps the entire app.

What S1 has to handle, from this walk:

1. **tvOS 26.x is untested.** The deployment target is 26.0 and this pass is tvOS 27.2. Rerun L4 and L6 on a tvOS 26 simulator or device before lifting the ban for everyone; keep the TextField path if 26 still bleeds.
2. **Recent searches need a new trigger.** The inline keyboard has no submit key. Record the query when a result is opened from it, or after it has rested.
3. **iPhone typing echoes** with `.searchable`, and doesn't with today's TextField (L9 control vs A). A likely cause to test first: each results update re-renders SearchView, re-applies `.searchable(text:)`, and writes the current text back into the system field, which the phone's keyboard session answers with its own buffered text. Keep the search text in a small view that result updates don't re-render, and rerun L9. Until then the board's "iPhone typing for free" claim needs that caveat; dictation (L8) works as claimed.
4. **Sidebar mode.** Menu from the keyboard must open the sidebar (intercept the press before UIKit's search container, e.g. a window-level press recognizer like the Home ones), and the hidden `UITabBar` must not take focus. A failed Left from the keyboard's first column is exactly the FEAT-45 rail's arming event (`movementDidFailNotification`, from the Home Stage spike).
5. **Tab bar on Search.** With Grid the bar stays pinned instead of scrolling off (`y=46` while `sd=1`); with Linear it scrolls as before (`y=-275`, `-524`). Accept it, or relink it with `TabBarContentScrollLink`. (Corrected after the run: `trk=` only reports a scroll view the app linked explicitly, and Search has never been linked, so it reads `trk=none` in every variant, including the ones where the bar scrolled. It is not evidence either way.)
6. **Focus after Back** goes to the card in tabs mode and to the keyboard in sidebar mode.
7. Lift the `.searchable` ban in `SearchView.swift`'s header and `docs/design/hig-hybrid-contract.md` with the pattern spelled out: `.searchable` on the results container inside the tab's own `NavigationStack`, never on the `TabView`, and never a second `NavigationStack` nested inside Search's.

## Changes made on the Mac run

The regenerated `search-field-spike.patch` is exactly what ran on the TV (3 files, +343/−1; `git apply --check` clean on `7e71ba87`).

1. **Compile fix (the only one):** `import Combine` in `SearchFieldSpike.swift`. The target builds with `MemberImportVisibility`, so `ObservableObject` and `@Published` need the explicit import. The four risks listed under "Compile risks" all compiled as written.
2. **File sink:** every `[SearchSpike]` line is also appended to `Library/Caches/search-spike.log`, because the console stream kept dropping.
3. **`-debug.searchFieldSpikeProbe YES`:** runs the probe on the control.
4. **Scanner on the shell:** moved from `SearchView` to `MainTabView`, so it samples while another tab is on screen. Installed before B; A's L6 was walked on the earlier build.
5. **Screen tag as a stack:** Detail's `onDisappear` used to reset the tag to `search` while the person page sat on top. Installed before B.

Build per leg: control L1–L4 and A L1–L9 ran with changes 1–3; B, C, the control's L9, and A's L10–L11 ran with all five.

Known kit defects, left as they ran:

- **B's nested `NavigationStack`** stops every push from Search. A real B would open titles outside any navigation stack, as bobsupra's screen does.
- **B's Grid `HStack`** isn't pinned to the leading edge, so the pair re-centres when the results column narrows. `.frame(maxWidth: .infinity, alignment: .topLeading)` on it would fix the stutter.
- **B lays out Linear first** and jumps once the probe reports Grid.

## Logs and photos

- `logs/search-spike-device.log`: the file log from the app container, all 7 launches (control, A, B, C, control for L9, A on Linear, A in Sidebar mode).
- `logs/console-*.log`: the `[SearchSpike]`, `[TabBarStateProbe]` and `[TabBarLink]` lines from each `devicectl --console` stream (partial where the stream dropped; the rest of the app's console is left out).
- `photos/`: L1 and L2 for the control, A and B; L1 for C; A on Linear (L2) and A in Sidebar mode (L1). Downscaled to 1400 px.

## Compile risks

The patch was written without a compiler. The places most likely to need a touch (on the 2026-10-04 run all four compiled as written; the one real error was the missing `import Combine`, now in the patch):

1. **`Tab(…, role: SearchFieldSpike.variant == .c ? .search : nil)`** in `ContentView.swift` assumes `role:` takes a `TabRole?`. If it doesn't, declare the Search tab twice under `if SearchFieldSpike.variant == .c { … } else { … }` inside the `TabView` builder.
2. **`.toolbar(.hidden, for: .navigationBar)`** in `SpikeSearchFieldHost`: bobsupra uses the same call on tvOS. If it doesn't compile, delete it, since it only hides an empty bar.
3. **`scene.focusSystem?.focusedItem`** in the probe: if it doesn't compile, drop the `focus` line. The other probes don't depend on it.
4. **Default MainActor isolation:** the probe's 250 ms loop is a `Task` started from a `UIView`, so it inherits the main actor. In Swift 5 mode, anything Xcode flags here should be a warning, not an error.

## Cleanup

Done 2026-10-04: the clone `~/Claude/Projects/NuvioMobile-search-spike` was deleted after its logs were copied into `logs/`. Nothing from the patch merged into `tvos-shared-extraction` or was pushed to NuvioMobile. The dev build with the spike is still installed on the Living Room Apple TV as `com.youngchris29.NuvioTV`; it shows today's Search unless launched with `-debug.searchFieldSpike`, and the next dev build replaces it. The S1 build plan written from these results is `docs/search-s1-native-search-plan-2026-10-04.md`.

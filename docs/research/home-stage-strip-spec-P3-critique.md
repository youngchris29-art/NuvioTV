# Home Stage & Strip · P3 critique of P1, P2, P4 (2026-10-05)

**Read against:** plan `docs/home-stage-strip-plan-2026-10-03.md` (spike verdict binding), `docs/design/hig-hybrid-contract.md`, Steven's handoff, the decisions doc, code at `d68b9d61` (clone `NuvioMobile-home-stage`), spike `035095a4`.

**Spot-check:** every load-bearing `file:line` I opened holds at the base (one slip: `HeroCrossfadeImage` is `HomeView:5572`, not `:5627`). The APIs the specs lean on exist as used: I1's `.pixels(256)` and `ImageFallbackPlan.load`, `RowRestSource.custom`, `TextSwapTiming.stage`, `HeroArtResolver` and `HomeHeroFocusModel` (both internal), the `InlineTrailerCardModel` and `TrailerHeroPlayer(surfaceTag:)` members, `TabBarContentScrollLinkAttacher(pinnedContainer:)`, `FolderDetailRepository` loading every source, and the guest collections seed on FA87. P1's swap timeline (cases A–H) re-derives correctly, and its invariants hold.

**HIG contract:** no MUST violations. Focus is system-only everywhere, P4 drops the FEAT-30 custom `ButtonStyle` for `.borderless` with glass behind, custom fades gate on Reduce Motion (except finding 20), and P4's R4 is what the remote grammar requires (Q2).

## Findings

| # | Sev | Spec § | Finding | Fix |
|---|---|---|---|---|
| 1 | **P1** | P1 §1.4/§9.1 · P2 §3.1/§4.1 | `Screens/Home/HomeLayout.swift` is created by both W1-A and W1-C, which run in parallel. The APIs differ: `storageKey` vs `defaultsKey`, and P2 adds `label`. | W1-C owns the file with P2's API. P1's E1 reads `HomeLayout.defaultsKey`, and W1-A creates no copy. |
| 2 | **P1** | P1 §9.1 vs P2 §2.9 | W1-A's scope has none of P2's seams S2/S3/S4/S7, and no reusable stage controller: the focus → resolver → swap → signal wiring sits inside `StageStripHome`. W2-B would then edit `StageView.swift`, `StripPager.swift` and `StageStripHome.swift` while W2-A edits them in parallel. | Add to W1-A: a `StageController` (focusModel, resolver, swap driver, strip signal, the focus-report funnel), `StageView(controller:hidesLogoWhenDisplaying:)`, the S4 pager API, S2 publishers and S7 tokens (seam list). W2-B only consumes them. |
| 3 | P2 | P1 D4, §3.4 | Turning the clip off and fading pages by opacity lets the outgoing row's heading and captions sweep up through the stage synopsis during every Down glide. At Medium the heading enters the synopsis slot after 24 pt of travel, at 0.92 opacity, and is still 0.5 at 155 pt. At rest, row i−1 sits at 2 % over the whole stage. This departs from the device-measured spike and adds the 0.02-floor focus risk. | Keep the spike's clip. Soften the edge with a gradient mask that lets the strip draw only into the stage's 24 pt bottom gutter. Keep `pageOpacity` for minY ≥ 0 only (peek 0.6). This removes P1 risk 2 and `-debug.stripTopFade`. |
| 4 | P2 | P1 §4.1 | Stage drops two warm-ups Classic has: `reportRowFocus`'s per-row backdrop prefetch and title-logo lookup, and `prefetchCollectionHeroArt` on collection-row appear. Only the seed is warmed. That means more cold presents: swaps up to 0.4 s later (folders up to 1.5 s), and logo-less first commits. This is the "late" complaint. | Move both bodies with E6 into `HomeRowPreviews` (or the StageController funnel), and wire every strip row's focus callback through them, as Classic does. |
| 5 | P2 | P1 §4.3 · P2 §1.3 | Re-render boundary (the BUG-126 class): `@StateObject swap` in `StageStripHome`, and P2's value-taking `AmbientWashLayer(displayed:pending:)`, re-evaluate every mounted strip row on each swap phase (about 4 per swap) and on each pending change. | Follow `HeroTextLayer`: `StageStripHome` holds the driver without observing it, and `StageTextBlock`, `StageArtLayer` and the wash observe it themselves (`AmbientWashLayer(feed:)`). |
| 6 | P2 | P1 §4.4 | Right → new text complete takes 0.80 s; today's Classic M5 does it in 0.44 s (0.2 + 0.12 + 0.12). Down (0.85 s) beats Steven's measured ~1.5 s, but horizontal browsing gets slower. Only the page length can be tuned on device. | Add launch-latched `-debug.stageSwapPause / stageFadeOut / stageFadeIn` beside `stripPageSeconds`. See Q3. |
| 7 | P2 | P2 §2.5 | On Up to folder row 0, the logo re-docks only at the swap (0.65 s) and descends until 1.15 s: a title moving 0.65 s after the strip rests, Steven's "late title step" class. | Q1's recommendation removes re-docking. If row-0 docking stays: the folder target is local, so skip the pause at row 0 (text out 0–0.15, logo descends 0.15–0.5 with the glide, folder text in after). |
| 8 | P2 | P4 §5.2 | Hide While Browsing in Stage: the hide slides 0.25 s against a 0.5 s glide. The show waits the 0.35 s resting settle, then slides 0.25 s, ending ≈ 0.1 s after the strip rests. | In Stage, drive the rail from `onPageStart` with the page's own curve and duration, and drop the resting settle: the row index is discrete. |
| 9 | P2 | P2 §2.8 | The folder Rows page sets `linksTabBar: false`. In Tabs mode the pushed page then falls back to UIKit's scroll heuristic, the BUG-66 half-shown class. At row ≥ 1 the compact folder logo (y 22–112) also shares the bar's band. | Set `linksTabBar: true` (the attacher already unlinks Home's view on push), and add a folder leg asserting `st=` is never `part`. |
| 10 | P2 | Plan device pass · P1 §6 | The Test profile on the Living Room ATV runs Sidebar mode, which migrates to Rail, so steps 1–3 and 10 never show the system tab bar. The spike's device walks never had it either. "Offset 0 at the top, never half shown" has no device evidence in Stage. | Device pass: Navigation → Top Tabs for steps 1–13, with `-debug.tabBarStateProbe YES` added to the launch command; Rail for 14–15. |
| 11 | P2 | Gate 1 · P1 testS13 · Wave 0 | Poster Size is synced, there is no launch override, and W5a's Settings walk is stale. So Gate 1's 16 geometry screenshots, testS13 and test47/48 can't run on FA87, which is Medium. | W1-A adds a DEBUG `-debug.posterSizeOverride small\|medium\|mediumPlus\|large`, read where `posterStyle` resolves. Confirm the Hide Titles and No Zoom keys take launch args. |
| 12 | P2 | Plan Wave 2b | W2-D edits `StageStripHome.swift` (W2-A), `SettingsDescriptions.swift` (W2-C) and, after seam R2, `FolderRowsPage.swift` (W2-B). The plan orders it only after W2-C. | W2-D starts after W2-A, W2-B and W2-C have all landed. |
| 13 | P2 | P1 §1.4 · P4 §5.1 | Rail inset never reaches Stage. | Seam R1. |
| 14 | P2 | P1 §3.3 · P4 §2.5 | Restore mechanisms differ; the folder page has no route. | Seam R2. |
| 15 | P3 | P1 §3.1/§4.2 | `pageEndsAt` is the press plus a nominal 0.5 s, but device glides measured 0.51–0.73 s, so the fade-out can start in the glide's tail. | End the page from `withAnimation(_:completionCriteria:_:completion:)`, and also require `RowsMotionClock` to be quiet for ≥ 0.05 s in `gateTime`. |
| 16 | P3 | P1 §6 | On the device spike, Menu from row 1 → row 0 was one 1.36 s motion: the engine's scroll won. | W2-A measures it. If it is still slow, issue the focus write and the position animation in one transaction. |
| 17 | P3 | P1 §7, D5 | The background trailer survives focus leaving the strip (to the tab bar or the rail). The plan says it stops on any focus change. | Treat strip focus loss (every row `owns == false`) as a teardown. |
| 18 | P3 | P1 §9.4 | testS01 asserts PRESS summaries, which the spike found mis-assign segments. testS08 reads `sidebar_state`, which W2-D deletes. There is no held-Down leg (plan W2-A, device step 5). | Assert per-segment lines. Change testS08 to `rail_state reason=menu`. Add `testS14_HeldDown`: `XCUIRemote.press(.down, forDuration: 3)` → one segment, `swaps` +1. |
| 19 | P3 | P2 §1.4 | P2 says held Down skips wash renders, but device hops come ~0.5 s apart, longer than the 0.15 s debounce, so every passed row renders one. That is cheap; the claim is wrong. | Prepare only once `restPending` clears, or correct the text. |
| 20 | P3 | P4 §1.2 | The 0.2 s expand animation isn't gated on Reduce Motion (only the slide is). | Gate it. |
| 21 | P3 | P4 §2.5 | The table says the Settings root returns to `.defaultFocus` = lastCategory. `SettingsRootView`'s own doc records a tvOS `List` ignoring that without its one-shot landing correction, and a rail exit doesn't arm it. | Arm the correction on rail exit, or write "first row". |
| 22 | P3 | P2 risk 8 · P1 risk 7 | Two Classic-only settings misbehave in Stage: Hide Hero Artwork has no meaning, and the hero fan-out still fetches. | W2-D hides that Appearance row in Stage. W1-A skips the fan-out in Stage if it is Swift-side. |
| 23 | P3 | P1 §2 | With `fits=false` (≥ 165 dp, phone-synced), rows overflow onto the next heading. | Scale the art down to fit in Stage. |

## Seam mismatches

**P2's S1–S8 against what P1 provides:**
- **S1** — P1's geometry has no `stageBlockTop` / `stageBlockLeading`. Add them (top 120; leading 140 + rail inset).
- **S2** — P1 publishes only `output.shown`. Add a separate `pending` publisher (item + identity) that only the wash observes (finding 5).
- **S3** — missing. Add `hidesLogoWhenDisplaying` to `StageView`.
- **S4** — `StripPager`'s exit handler always pages to row 0 at row > 0, so a folder at row 2 would page instead of popping.
  - Add `menuPagesToTop: Bool`; when false, the strip installs no exit handler.
  - Add an external `requestFocus(rowKey:itemId:)` handle for P2's initial focus.
  - Non-focusable rows need nothing: the engine skips them, and `onRowChange` follows focus.
- **S5** — met: P1 uses an alpha mask, and E4 removes the scrim.
- **S6** — P1's E6 renames it `HomeRowPreviews.folder(collection:folder:)`. P2 calls that, not `HomeView.folderHeroPreview`.
- **S7** — `row=`, `fitem=` and `disp=` live on `debug_strip` (`row=`, `foc=`) and `debug_stage` (`shown=`). Append all three to `debug_stage`, as P2's tests read them.
- **S8** — P1's placeholder `AmbientWashLayer(presentation:)` doesn't match P2's `(displayed:pending:probeID:)`. Use the driver feed instead (finding 5).

**Rail seams:**
- **R1, inset.** P1's root is `.ignoresSafeArea()`, so P4's `.safeAreaPadding(.leading, 36)` never reaches Stage. P1's `leadingChromeInset` is never passed, and both specs set `\.rowEdgeMargins`. Fix: `.railTabRoot` publishes `\.railLeadingInset` (36 or 0), which `StageStripHome` and `FolderRowsPage` read for the stage block, the rows and `rowEdgeMargins`. Delete the init parameter.
- **R2, restore and gate.** P1 restores through a `.stageStripRestoreFocus` notification and a `contentGated` parameter; P4 uses a `RailReturnRoute` registry and a UIKit gate that never tells Stage anything. Fix:
  - Adopt P4's routes. Stage's `capture` records the row key; `restore` calls `requestRowFocus(row, itemId: memory[row])`. Delete the notification and `contentGated`.
  - Tear the background trailer down from `onReceive(navigationChrome.$isFocusedChrome)`, which adds no body dependency.
  - `FolderRowsPage` registers the same route. Without it, Right lands on default focus (the Edit band, or row 0), and the strip pages away from where the user was.
- **R3, Menu.** Consistent on Home: row > 0 pages to row 0; row 0 goes to the rail (or sidebar) handler, or the system. The folder pops, which needs S4's flag. Inside the rail, R4 applies (Q2).
- **R4, `isScrolledDown` and hide-while-browsing.** There are two writers (P1's binding plus the `reportsScrollToTabBar` mirror, and P4's `setScrolledDown(tab: 0, rowIndex > 0)`), and they agree at rest. Make P4's row-index write the rail's owner, and keep the mirror for the probe.
- **R5, tab bar link vs Rail.** Consistent: the attacher is gated by `isRail()`, and Up at row 0 never reveals (BUG-98).
- **R6, the wash's input.** Finding 5 and S2.

## File ownership (parallel waves)

| File | W1-A | W1-B | W1-C | W2-A | W2-B | W2-C | W2-D | Status |
|---|---|---|---|---|---|---|---|---|
| `Screens/Home/HomeLayout.swift` | new | | new | | | | | **CONFLICT** (#1) |
| `StageView` · `StripPager` · `StageSwapModel` `.swift` | new | | | edit | needs S2–S4 | | | **CONFLICT unless #2** |
| `StageStripHome.swift` | new | | | edit | (controller) | | edit | W2-D after W2-A (#12) |
| `StageCopy.swift` | new | | | edit | | | | sequential |
| `HomeView.swift` | edit | | | | | | edit | sequential |
| `BrowseComponents.swift` | edit | | | edit | | | | sequential |
| `PinnedRowUpFallback.swift` | edit | | | | | | | ok |
| `AmbientWash*.swift` · `ArtworkColorStore.swift` | | own | | | | | | ok |
| `HomeScreenSettingsPane.swift` | | | edit | | | | | ok |
| `SettingsDescriptions.swift` | | | edit | | | edit | edit | sequential (W2-D after W2-C) |
| `CollectionsUI.swift` · `FolderRows*.swift` | | | | | own | | route (R2) | W2-D after W2-B |
| Shell, TabBar\*, Sidebar\*, Appearance, Detail, Search/Library/Add-ons/Settings roots | | | | | | | own | ok |
| `NuvioTVUITests.swift` | | | | | | | test93 + helpers | W3 after W2-D |
| `Localizable.xcstrings` | | | | | | scripts | scripts (main) | sequential |

## Questions for Christian

1. **What does the folder stage show on row 0?** P2 shows the folder there and re-docks its logo on every return. The plan text says "then the focused item as you browse".
   - *Recommend:* show the folder on open, follow focus from the first move, and keep the compact logo up from then on (no re-dock). That matches the plan text and removes finding 7's late motion.
2. **Menu inside a rail that Menu opened suspends the app (P4 R4).** The plan says Menu closes the rail. Together with "Menu at a tab root opens it", that would leave no way out of the app with Menu.
   - *Recommend:* accept R4.
3. **Stage swap pause.** At the approved 450 ms, Right → new title complete takes 0.80 s; today's Classic takes 0.44 s.
   - *Recommend:* ship 450 ms with the knobs from finding 6, and tune it from the device pass and Steven's video. If Right reads as late, try 300 ms.
4. **The peek heading sits in the bottom 60 pt overscan band.**
   - *Recommend:* accept it as a hint. Lifting it out (54 pt) puts Large's stage at 393, under the 420 floor.
5. **Focus memory (P1 gate G-F).** If `.defaultFocus` doesn't hold in the lazy rows on the simulator, ship the fallback?
   - *Recommend:* yes. Down/Up land geometrically, as the spike measured, and memory serves only Menu and rail restores.
6. **Rail geometry (P4 Q2/Q3):** a 36 pt content shift, and the pill 16 pt from the bezel.
   - *Recommend:* keep both for this beta, and decide from the Gate 2 screenshots and a look on his TV.
7. **Hide While Browsing also hides the rail on Search and on Detail (P4 R7).** This goes beyond the plan.
   - *Recommend:* accept. The keyboard sits on the left edge, and FEAT-30 already hides on Detail.

**Resolved here:** keep D2 and D5; R1 is P4's remit per the spike verdict; P4 Q4 is fine for this beta (amend device step 14); P4 Q5 waits for Probe G and Q6 for the device; wash tuning and P1 risk 6 are device measurements.

VERDICT: FIX FIRST

# Home Stage & Strip — P1 spec: Stage + Strip (2026-10-05)

**Inputs:** `docs/home-stage-strip-plan-2026-10-03.md` (H1–H9, Defaults, Spike verdict = binding), `docs/home-redesign-decisions-2026-10-03.md`, Steven's handoff, `docs/design/hig-hybrid-contract.md`, spike `035095a4` (`Screens/StageStripSpike.swift`).
**Base:** `d68b9d61`, clone `~/Claude/Projects/NuvioMobile-home-stage`. Paths are relative to `iosApp/NuvioTV/`; every `file:line` was re-read at the base (the plan's 10-03 numbers have moved).
**Scope:** Stage, Strip, paging, focus memory, swap model, stage copy, chrome, trailers, probes, W1-A/W2-A ownership, unit + UI tests. Not here: wash (P2/W1-B), Home Screen pane (P2/W1-C), folder Rows page (P2/W2-B), rail (P4/W2-D). The seams those consume are listed in §1.5.

**Corrections after the P3 critique (2026-10-05)**
- #1: `HomeLayout.swift` is W1-C's (P2 §3.1 API); E1 reads `HomeLayout.defaultsKey`; W1-A creates no copy (§1.1, §1.4, §9.1).
- #2: W1-A builds the reusable `StageController`, `StageView`, the S4 pager API, the S2 wash feed and the S7 tokens, listed in the new §1.5; W2-B only consumes them (§3.1, §4.1, §4.3).
- #3: the spike's clip stays, with a 24 pt gradient edge in the stage's bottom gutter; `pageOpacity` only below the top. D4's clip-off, `-debug.stripTopFade` and the old risk 2 are gone (§0, §3.4).
- #4: Classic's per-row warm-ups (row backdrops, title logos, collection art, `rowAppeared`) run for every strip row through the controller's report funnel (E6, §4.1).
- #5: `StageStripHome` holds the controller without observing it; the text, art, wash and trailer layers observe their own sources (§4.3, §7).
- #6 / Q3: launch-latched swap-timing knobs (§4.2, §8).
- #8 / R4: the rail's Hide While Browsing runs from `onPageStart` with the page's curve; that write owns the rail, and the probe mirror stays (§6).
- #10, #12: tab bar device evidence comes from the Top Tabs device pass (§6); W2-D runs after W2-A, W2-B and W2-C (§9.2).
- #11: DEBUG poster size and Hide Titles overrides; No Zoom already takes `-no_zoom_on_focus YES` (§8).
- #13 / R1: the rail inset arrives as `\.railLeadingInset`; `leadingChromeInset` is deleted (§1.3, §2).
- #14 / R2: rail restores use P4's `RailReturnRoute`; `.stageStripRestoreFocus` and `contentGated` are deleted (§3.3, §6, §7). R3: Menu routing (§6).
- #15: a page ends at its animation's completion, and the gate also needs 0.05 s without rows motion; Down swaps at ≈ 0.70 s (§3.1, §3.5, §4.2, §4.4).
- #16, #17: Menu row → 0 is measured by W2-A (§6); strip focus loss stops the background trailer (§3.1, §7).
- #18: testS01 per segment, testS08 on the rail, new testS14 (§9.4).
- #22: the hero fan-out is Kotlin-side, so it stays; a Swift-side prewarm is flagged (§10). #23: a too-large poster is laid out at the largest size that fits (§2).
- Q4, Q5 decided (§3.3, §10). `HeroCrossfadeImage` is `HomeView:5572`.

The Xcode project uses synchronized folder groups (`PBXFileSystemSynchronizedRootGroup`), so new files need no `project.pbxproj` edit.

## 0. Where this spec departs from the plan text (each is deliberate)

| # | Plan said | Spec does | Why |
|---|---|---|---|
| D1 | `heroFocusTrailerMode || stage` (`HomeView:540`) | Leave it alone; `StageStripHome` computes its own `backgroundTrailerMode` and sets `\.trailerPlaysInHero` on the strip | The stage's rows are not inside `rowsScroll`, so HomeView's value never reaches them; one fewer Classic edit |
| D2 | Strip height from the catalog row only | `rowH = max(catalogRow, collectionRowMax)` | With Hide Titles, a poster-shaped collection folder (per-folder caption) is 11 pt taller than a catalog row; with landscape catalog rows it is ~95 pt taller. A data-independent rule keeps the stage from jumping when collections load |
| D3 | 450 ms pause after the commit | Pause anchored on the **last raw focus report**, and never before the strip's page animation reports completion and the rows have been still for 0.05 s (#15) | HomeHeroFocusModel already spends 200 ms of the 450 ms on its commit; anchoring on the raw report gives "450 ms after you stop", and one motion at a time on a Down press |
| D4 | Strip clips (spike) | The spike's clip, with its top edge feathered across the stage's 24 pt bottom gutter; pages below the top read by position (peek 0.6) (§3.4, #3) | Steven's "row sliced by a hard mask line" complaint, without letting an outgoing row sweep through the synopsis |
| D5 | Stage reverts when focus leaves items | Stage target is **sticky** (See All, tab bar, rail keep the last title) | Reverting to a resting title on See All would swap the stage to an unrelated title |

## 1. View tree and switch point

### 1.1 `HomeView.swift` edits (the complete list; Classic is otherwise untouched)

| # | Where (base line) | Edit |
|---|---|---|
| E1 | after `@AppStorage("accent_focus_ring")` `:115` | `@AppStorage(HomeLayout.defaultsKey) private var homeLayoutRaw = HomeLayout.defaultValue.rawValue` and `private var isStageLayout: Bool { HomeLayout.resolve(homeLayoutRaw) == .stage }` (`HomeLayout` is W1-C's, P2 §3.1) |
| E2 | `heroItems` `:251` | `isStageLayout ? [] : Array(model.heroItems.prefix(8))` — the carousel, its 8 s timer, `prefetchHeroArt`'s page warm-up and the `heroSurfaceSeen` latch all go dormant in Stage |
| E3 | `displayHero` `:372` | first line `if isStageLayout { return nil }` — Classic's resolver presents nil, so it fetches nothing |
| E4 | backdrop `:819` | `if !isStageLayout, let presentation = heroResolver.presented {` (HomeHeroBackdrop + HomeHeroScrim stay Classic-only) |
| E5 | `ScrollViewReader { … }` `:881–1067` | wrap: `if isStageLayout { StageStripHome(…) } else { ScrollViewReader { …unchanged… } }`. The BUG-27 `.onExitCommand` (`:982`) is inside the else, so it never sees Stage |
| E6 | `folderHeroPreview` `:2949`, `previewFromEntry` `:3006`, `collectionHeroPrefetchURLs` `:2837`, and the warm-up halves of `reportRowFocus` `:2890–2896` and `prefetchCollectionHeroArt` `:2848` | bodies move verbatim to `Screens/Home/HomeRowPreviews.swift` (`enum HomeRowPreviews { static func folder(collection:folder:) -> MetaPreview?; static func entry(_:) -> MetaPreview; static func collectionArtURLs(_:) -> [String]; static func warmRow(source:item:done:logoCandidates:prefetch:); static func warmCollection(_:done:) }`, `done: inout Set<String>` being the per-row dedup set); the private funcs become one-line forwards, so Classic is unchanged (#4) |

E5 call site:

```swift
StageStripHome(model: model,
               actions: StageHomeActions(resume: { resume = $0 }, push: { homePath.append($0) }),
               cover: StageCover(pushed: !homePath.isEmpty, resume: resume != nil),
               isScrolledDown: $isScrolledDown)
```

Everything else on HomeView's body still applies to Stage and is wanted: the `NavigationStack(path: $homePath)`, the five `.navigationDestination`s, `.fullScreenCover(item: $resume)`, `model.acquire()/release()`, `startUpcoming`. `StageStripHome` must **not** call `model.acquire()` (the spike did, because it replaced HomeView).

### 1.2 Classic-only machinery the Stage branch never mounts or calls

`handleRowsMove` `:1728` · `handleUpSwipe` `:1792` · `handleHeroUp` `:1861` · `handleRowFocusOwnership` `:1931` · `revealTopAfterUpIntoHero` `:1974` / `HomeUpIntoHeroGate` (`HomeUpIntoHeroGate.swift:8`) · `beginUpFallback` `:2129` / `PinnedRowUpFallback` ladder · `forcedUpFallbackTrigger` `:2308` · `HomeUpSwipeCatcher` `:1608` · `PinnedRowSettleRevealModifier` (`BrowseComponents:4588`, used `:1684`) · `pinnedPlan` `:2785` / `PinnedRowGeometry` · `pinnedHeroHeader` `:2529` / `heroCarousel` `:2360` · `rowsInsets` `:2549` · `pinnedShortRowLinkFrameFloor` `:2706` / `pinnedLastRowLinkFrameFloor` `:2688` · `HomeScrollEdgeStyleModifier` `:1690` · `HomeScrollProbeModifier` `:3087` · `rowsScrolledPastTop` / `upInput` / `.coordinateSpace(PinnedRowTitle.rowsScrollSpace)` `:1668` · `heroTrailerModel` + `HomeHeroBackdrop` `:5301` · `HeroTextLayer` `:6491` / `HomeHeroForeground` `:6085` (its memberwise init is file-private anyway).

Rows mounted in the strip get **no** pinned env values, so `rowCardTopReach/BottomReach/LinkFrameFloor` stay 0 and `pinnedRowIsLast` false: `pinnedRowSettleTracking`, `pinnedRowTitleTracking` and the short-row compensation are inert (they gate on `cardTopReach > 0`, `BrowseComponents:4547`). The headings render as the plain Classic `Text` above the shelf.

### 1.3 `StageStripHome` tree (`Screens/Home/StageStripHome.swift`)

```
StageStripHome                                   ZStack(alignment: .topLeading).ignoresSafeArea()
├─ layer 0  Color.clear  // the main session wires AmbientWashLayer(feed: stage.swap.washFeed) at the W1 merge (S8)
├─ StageView(controller: stage, geometry: geo)   // art (full screen, masked), scrim, text block (§4.3)
├─ VStack(spacing: 0)
│   ├─ Color.clear.frame(height: geo.stageHeight)                        // the stage block's place; nothing focusable
│   └─ StripPager(rowKeys:…, controller: stage, linksTabBar: true, reportsTab: "Home",
│                 menuPagesToTop: true, atTopExit: …) .frame(height: geo.stripHeight)
│       └─ ScrollView(.vertical) { LazyVStack(spacing: 0) {
│             ForEach(rows) { page(row).frame(height: geo.pageHeight, alignment: .top).id(row.key) }
│             Color.clear.frame(height: geo.peek) }
│           .scrollTargetLayout()
│           .background(.topLeading) { if linksTabBar { TabBarContentScrollLinkAttacher(pinnedContainer: false) } }
│           .background(.topLeading) { StageStripMarker() }   // probe only
│        }
│        .scrollPosition(id: $positionId, anchor: .top)
│        .scrollTargetBehavior(.viewAligned)
│        .scrollClipDisabled() .mask(alignment: .top) { StripEdgeMask(gutter: 24) }   // D4, §3.4
│        .rowsMotionStamp(.vertical)
│        .reportsScrollToTabBar(tab: reportsTab)                // when non-nil; no isScrolledDown binding (§6)
│        .onExitCommand(perform: …)                             // §6; not installed when !menuPagesToTop
└─ DEBUG: StripDebugLabel (leaf); `debug_stage` lives in StageView
```

The VStack is the spike's structure, which measured exact page rests on the device; the stage block above the strip is now a fixed `Color.clear` spacer, since `StageView` draws the text in its own layer. Keep `.ignoresSafeArea()` on the root exactly as the spike did. P4's `.safeAreaPadding` therefore never reaches Stage, which reads `@Environment(\.railLeadingInset)` instead (R1: W1-A declares it, default 0; `.railTabRoot` sets 36 in Always Visible). Rows are padded inside the ScrollView content, leading `geo.contentLeading` (140 + inset), trailing 140, so they line up with Classic's rows. Stage never sets `\.rowEdgeMargins`; it inherits `.railTabRoot`'s, which matches.

Strip environment (set once on the ScrollView): `\.trailerPlaysInHero = backgroundTrailerMode` (settings only: `inline_trailers_enabled && trailer_playback_location == "hero"`, never per focus — BUG-19 rule), `\.rowRestSource = .custom(stage.signal)`, `\.pinnedRowFocusRequest`, `\.pinnedRowFocusOwnership`, `\.stripFocusMemory` (§3.3).

Row order and keys are Classic's: `"continue-watching"` (if non-empty), `"upcoming"` (if `home_upcoming_row_enabled` and non-empty), then `model.rows` as `section.key` / bare `collection.id`. Before any row exists the strip shows `StageStripPlaceholder(model:)`, a copy of HomeView's private `placeholder` `:3030` (loading / error / add-on error with the focusable Retry chip / setting up).

### 1.4 Types and init

```swift
struct StageHomeActions { let resume: (ResumeTarget) -> Void; let push: (TitleRoute) -> Void }
nonisolated struct StageCover: Equatable { var pushed: Bool; var resume: Bool }

struct StageStripHome: View {
    @ObservedObject var model: HomeViewModel
    let actions: StageHomeActions
    let cover: StageCover
    @Binding var isScrolledDown: Bool
    @StateObject private var stage = StageController()   // held, never observed (§4.1)
    @Environment(\.railLeadingInset) private var railLeadingInset   // R1
}
```

`HomeLayout` is W1-C's file (P2 §3.1: `defaultsKey`, `defaultValue`, `resolve(_:)`, `current(_:)`, `label`); W1-A reads it by that signature (#1). `-home_layout classic|stage` lands in the argument domain, which `@AppStorage` reads. The rail needs no parameters: inset by environment (R1), restore by route (R2), and P4's UIKit content gate, which Stage never sees.

### 1.5 Seams for W2-B and W2-D (W1-A provides; the others only consume)

| # | What W1-A provides | Consumer |
|---|---|---|
| S1 | `StripGeometry`'s `stripHeight`, `stageHeight`, `logoSlot`, `stageBlockTop` (120) and `stageBlockLeading` (140 + `railLeadingInset`) (§2) | P2 folder page, logo docking |
| S2 | `controller.swap.washFeed` (`StageWashFeed`, observed only by the wash) and `StageController.seed(_:washFallback:)`, which takes a synthetic folder preview (§4.1, §4.3) | P2 wash, folder first paint |
| S3 | `StageView(controller:geometry:hidesLogoWhenDisplaying:probeID:)` (§4.3) | P2 folder page |
| S4 | `StripPager(…, menuPagesToTop: false)`, no exit handler; `StageController.requestFocus(rowKey:itemId:)`, `currentRowKey`, `memory` (§3.1, §3.3). Up at row 0 is never consumed; non-focusable rows need nothing (the engine skips them, `onRowChange` follows focus) | P2 folder page, P4 routes |
| S5 | met: alpha-masked art (§4.3), Classic's scrim Classic-only (E4), nothing opaque over the wash | P2 wash |
| S6 | `HomeRowPreviews.folder(collection:folder:)` (E6) | P2 folder preview |
| S7 | `debug_stage … row= fitem= disp=`, id = `StageView.probeID` (§8) | P2 tests 102–106 |
| S8 | `AmbientWashLayer(feed:)` at layer 0, wired by the main session at the W1 merge | W1-B |
| R1 | `EnvironmentValues.railLeadingInset`, default 0, declared in `StripGeometry.swift` | P4 `.railTabRoot` |
| R2 | `currentRowKey`, `memory`, `requestFocus(rowKey:itemId:)` | P4 Stage and folder routes |

## 2. `StripGeometry` (`Screens/Home/StripGeometry.swift`)

```swift
nonisolated struct StripGeometry: Equatable, Sendable {
    struct Inputs: Equatable, Sendable {
        var posterHeight: CGFloat; var posterWidth: CGFloat
        var titlesShown: Bool; var landscapeCatalogRows: Bool; var noZoom: Bool
        var titleHeight: CGFloat = Theme.Font.sectionTitleLineHeight            // 38 system, ≈38.84 Open Sans
        var folderCaptionHeight: CGFloat = Theme.Font.uiFont(for: .caption2).lineHeight.rounded(.up) // 23
        var synopsisLineHeight: CGFloat = Theme.Font.synopsisLineHeight         // ≈30 system, ≈31.32 Open Sans
        var screenHeight: CGFloat = 1080
        var leadingInset: CGFloat = 0                                           // \.railLeadingInset (R1)
    }
    let rowHeight, focusLift, pageHeight, peek, stripHeight, stageHeight: CGFloat
    let logoSlot, synopsisSlot: CGFloat
    let synopsisLines: Int
    let stageBlockTop: CGFloat                    // 120 (S1)
    let contentLeading: CGFloat                   // 140 + leadingInset; also `stageBlockLeading` (S1)
    let fits: Bool                                // the requested poster size fits
    let layoutPosterHeight: CGFloat               // what the strip lays out with: the request, or the clamp (#23)
    static func make(_ i: Inputs) -> StripGeometry
    static func catalogRowHeight(art: CGFloat, titles: Bool, titleHeight: CGFloat) -> CGFloat
    static func collectionRowHeightMax(posterHeight: CGFloat, titleHeight: CGFloat, captionLine: CGFloat) -> CGFloat
    static func pageOpacity(minY: CGFloat, pageHeight: CGFloat) -> Double       // §3.4
    static func pixelCeil(_ x: CGFloat) -> CGFloat { (x * 2).rounded(.up) / 2 }
}
```

**Formulas** (constants are the ones the rows actually lay out with):

- `catalogRow = titleH + md 16 + lg 24 + art + (titles ? cardLockupCaptionChrome 43.5 : 0) + lg 24` (`CatalogRowView` `BrowseComponents:5110/5209`; 43.5 = `PinnedRowTitle.cardLockupCaptionChrome` `:490`). `art = landscapeCatalogRows ? 203 : posterHeight`.
- `collectionRowMax = titleH + md 16 + sm 12 + posterHeight + sm 12 + captionLine 23 + sm 12` (`CollectionRowView.body`, `CollectionsUI:281–340`; poster-shaped folder with its caption, the tallest tile).
- `rowHeight = pixelCeil(max(catalogRow, collectionRowMax))`; `focusLift = noZoom ? 0 : 20` (`heroPinnedRowFocusLiftAllowance`); `pageHeight P = rowHeight + 2·focusLift` (spike: row top-aligned, the slack below); `peek = pixelCeil(titleH + 6)` (44 system, 45 Open Sans); `stripHeight H = P + peek`.
- `stageRaw = 1080 − H`; `fits = stageRaw ≥ 420`. When `!fits`, `make` lays the strip out at the largest poster height that leaves the stage at 420 and recomputes everything from it. Each row type's height is the poster height plus a constant, so that height is one subtraction: 660 − 2·lift − peek − the dominant row's constant. `stageHeight = max(420, stageRaw)`.
- Stage block: top inset `stageBlockTop` 120 (`heroForegroundTopPadNuvio`), leading `contentLeading`, `logoSlot = stage < 480 ? 110 : 150` (`heroLogoSlotHeightPinned` / `heroLogoSlotHeight`), gap 12 (`heroPinnedSlotGap`), meta 32 (`heroMetaSlotHeight`), gap 12, bottom gap 24 (`Spacing.lg`). `synopsisSlot = stage − 120 − logo − 12 − 32 − 12 − 24` (= stage − 350, or − 310 with the 110 logo). `synopsisLines = min(5, max(1, floor((slot + 1) / synLH)))` (the `+1` is `HomeHeroForeground`'s `lineTolerance`; 5 is the hero-off panel's cap).

The lift fits inside the row itself: catalog shelves carry 24 pt padding against a 20 pt lift; collection tiles (12 pt padding) rise 8 pt into the 16 pt gap under the heading. The 2·lift slack below the row is breathing room that the spike measured with; keep it.

**Table** (system font, titleH 38, peek 44, synLH ≈ 30; dp → pt = 220/126; h = 1.5·w):

| Size (dp) | Titles | Zoom | catalog | coll. max | **rowH** | **P** | **H strip** | **Stage** | logo | syn slot | lines |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Small 105 (h 275.0) | on | on | 420.5 | 388 | 420.5 | 460.5 | 504.5 | 575.5 | 150 | 225.5 | 5 (cap) |
| | on | No Zoom | | | 420.5 | 420.5 | 464.5 | 615.5 | 150 | 265.5 | 5 |
| | off | on | 377 | 388 | 388 | 428 | 472 | 608 | 150 | 258 | 5 |
| | off | No Zoom | | | 388 | 388 | 432 | 648 | 150 | 298 | 5 |
| Medium 126 (h 330.0) | on | on | 475.5 | 443 | 475.5 | **515.5** | **559.5** | **520.5** | 150 | 170.5 | 5 |
| | on | No Zoom | | | 475.5 | 475.5 | 519.5 | 560.5 | 150 | 210.5 | 5 |
| | off | on | 432 | 443 | 443 | 483 | 527 | 553 | 150 | 203 | 5 |
| | off | No Zoom | | | 443 | 443 | 487 | 593 | 150 | 243 | 5 |
| Medium+ 134 (h 350.95) | on | on | 496.45 | 463.95 | 496.5 | 536.5 | 580.5 | 499.5 | 150 | 149.5 | 5 ⚠ |
| | on | No Zoom | | | 496.5 | 496.5 | 540.5 | 539.5 | 150 | 189.5 | 5 |
| | off | on | 452.95 | 463.95 | 464 | 504 | 548 | 532 | 150 | 182 | 5 |
| | off | No Zoom | | | 464 | 464 | 508 | 572 | 150 | 222 | 5 |
| Large 154 (h 403.33) | on | on | 548.83 | 516.33 | 549 | 589 | 633 | **447** | **110** | 137 | 4 |
| | on | No Zoom | | | 549 | 549 | 593 | 487 | 150 | 137 | 4 |
| | off | on | 505.33 | 516.33 | 516.5 | 556.5 | 600.5 | 479.5 | **110** | 169.5 | 5 |
| | off | No Zoom | | | 516.5 | 516.5 | 560.5 | 519.5 | 150 | 169.5 | 5 |

Bold Medium/on/on reproduces the spike exactly (P 515.5, H 559.5, stage 520.5). Open Sans spot checks: Medium on/on → rowH 476.5, P 516.5, H 561.5, stage 518.5, 5 lines; Large on/on → 550 / 590 / 635 / 445, 4 lines. Landscape catalog rows at Medium → rowH 443 (collection rule), stage 553.

**Shorter rows sit top-aligned in a page of height P;** the rest of the page shows the wash. At Medium on/on: Continue Watching and Upcoming 348.5 (167 pt below), a square-tile folder row 333 (182.5), a hidden-title square "genres" row 298 (217.5). At Large these gaps grow by 73.5 pt. The Upcoming subtitle overlay hangs into its own 24 pt shelf padding and doesn't change the row frame.

**What doesn't fit:**
- ⚠ Medium+ / titles on / zoom: 150.5 / 30 = 5.02, so a measured synopsis line above 30.1 pt gives 4 lines. Harmless, but the Gate 1 screenshot should be read with that in mind.
- A synced custom width ≥ 165 dp (titles on, zoom) gives stage < 420 → `fits = false`. 164 dp is the largest that fits, all four presets fit, and `PosterCardStyleRepository` has no clamp, so a phone-side setting can reach this. Stage then scales the art down to fit (#23): `.environment(\.posterStyle, style.withHeight(geo.layoutPosterHeight))` on the strip only, a re-layout, not a `scaleEffect`. Every row reads `\.posterStyle` (`BrowseComponents:5051`, `CollectionsUI:72`), so nothing overflows onto the next heading. 165 dp lays out at 430.5 pt tall (≈ 164.4 dp): stage 420, strip 660, logged `geometry fits=0 posterH=430.5`. Classic is untouched.

## 3. Paging and focus memory

### 3.1 Mechanism (spike a2, unchanged)

`StripPager` (`Screens/Home/StripPager.swift`) owns `@State positionId: String?`, `@State focusRequest = PinnedRowFocusRequest.none`, `@State atTop = true` (flips only between row 0 and row 1, so the parent doesn't re-render per hop), and a reference box `StripPagerBox { rowIndex, focusedRowKey, owners: Set<String>, programmaticTarget, programmaticDeadline, restoreGeneration }` (no view-state write per hop beyond `positionId`). On appear it installs its `requestRowFocus` into `controller.pagerHandle`, the S4 external handle.

```swift
struct StripPager<Row: View>: View {
    let rowKeys: [String]; let geometry: StripGeometry
    let controller: StageController            // signal, memory, pager handle; tells the swap driver about pages
    let linksTabBar: Bool                      // tab bar content-scroll link: Home and the folder Rows page (P2, #9)
    let reportsTab: String?                    // "Home" → .reportsScrollToTabBar (probe mirror); nil on the folder page
    let menuPagesToTop: Bool                   // S4: false → no .onExitCommand at all (the folder page pops)
    let atTopExit: (() -> Void)?               // host's Menu-at-row-0 handler (nil = system)
    let onRowChange: (_ index: Int, _ key: String) -> Void
    let onPageStart: (_ toIndex: Int, _ seconds: TimeInterval) -> Void   // rail Hide While Browsing (#8, §6)
    let onStripFocusLost: () -> Void           // #17
    @ViewBuilder let row: (_ key: String) -> Row
}
```

Ownership (`\.pinnedRowFocusOwnership`, fired off each row's own `@FocusState`): on `owns == true` for key K: insert K into `box.owners`; clear a completed request for K (F5 rule); ignore other rows while a programmatic target is in flight (deadline 1.5 s, spike rule); if K is new, set `box.rowIndex` and `controller.currentRowKey`, call `CollectionFocusFrameSampler.shared.arm(rowKey: K, gif: false)` (frame-time window per hop, no-op unless its probe is on), `page(to: K, index:)`, update `atTop`, call `onRowChange`. On `owns == false`: remove K; if `owners` is still empty one runloop turn later, focus left the strip (tab bar, rail, sidebar), so set `focusedRowKey = nil` and call `onStripFocusLost()`. A row-to-row move never trips it, in either report order (#17).

```swift
func page(to key: String, index: Int) {
    guard positionId != key else { return }
    let d = reduceMotion ? 0 : StageStripTuning.pageSeconds          // 0.5; -debug.stripPageSeconds 0.3…1.0
    let gen = controller.signal.pageStarted(duration: d)             // the controller tells the swap driver
    onPageStart(index, d)
    if d == 0 { positionId = key; controller.signal.pageEnded(generation: gen) }
    else { withAnimation(.easeOut(duration: d), completionCriteria: .logicallyComplete) { positionId = key }
               completion: { controller.signal.pageEnded(generation: gen) } }   // #15
}
```

The focus engine moves focus; the app's position animation overrides the engine's slower scroll (device: one 0.51–0.73 s glide, exactly on the boundary, nothing after). The page ends at its animation's completion (the API `InlineTrailerCard.swift:1026` already uses), not at a nominal 0.5 s (#15). Content height = n·P + peek, viewport H = P + peek, so the last row rests at (n−1)·P exactly.

### 3.2 Held Down

No extra code. Each hop re-targets the same `positionId` animation (device: one 2-page glide in 1.0 s) as a new page generation; only the latest one's completion ends the page. Every row report is a focus activity for the swap model (§4). Intermediate titles commit (HomeHeroFocusModel, 0.2 s) and replace `pending`, but nothing fades until the hand stops and the glide ends. One swap per held Down.

### 3.3 Per-row focus memory

`UIFocusSystem.requestFocusUpdate(to:)` doesn't stick on SwiftUI items (spike), so memory is SwiftUI-side, through the one modifier every Home row already applies to its own `@FocusState` (`PinnedRowUpFallbackTarget`, `PinnedRowUpFallback.swift:76`, called by `CatalogRowView` `BrowseComponents:5286`, `ContinueWatchingRow` `HomeView:5227`, `UpcomingRow` `UpcomingRow.swift:115`, `CollectionRowView` `CollectionsUI:399`). Classic stays byte-identical: every new path is gated on a new environment value that only the strip sets.

**Changes in `Screens/PinnedRowUpFallback.swift`:**

```swift
nonisolated struct PinnedRowFocusRequest: Equatable, Sendable {
    var rowKey: String?
    var generation: Int
    var itemId: String? = nil          // NEW: Stage only; nil everywhere Classic builds one
    static let none = PinnedRowFocusRequest(rowKey: nil, generation: 0)
    nonisolated static func target(for r: PinnedRowFocusRequest, rowKey: String,
                                   firstId: String?, remembered: String?) -> String? {
        guard r.rowKey == rowKey else { return nil }
        return r.itemId ?? remembered ?? firstId          // Classic: itemId nil, remembered nil → firstId
    }
}
```

In `PinnedRowUpFallbackTarget`: read `@Environment(\.stripFocusMemory) private var memory` (default nil). `applyIfMatching` uses `target(for:rowKey:firstId:remembered: memory?.itemId(for: rowKey))` behind the existing `focus.wrappedValue == nil` anti-theft guard. When `memory != nil`: `.onChange(of: focus.wrappedValue)` records non-nil ids with `memory.remember(rowKey:itemId:)`, and the content gets `.defaultFocus(focus, memory.itemId(for: rowKey) ?? firstId, priority: .userInitiated)`. With `memory == nil` the modifier body is exactly today's.

```swift
@MainActor final class StripFocusMemory {                 // Screens/Home/StripFocusMemory.swift
    private var byRow: [String: String] = [:]
    func remember(rowKey: String, itemId: String)
    func itemId(for rowKey: String) -> String?
    func prune(keeping keys: Set<String>)                  // on row-set change
}
// EnvironmentKey `stripFocusMemory: StripFocusMemory?`, default nil.
```

A reference box, not observed: rows re-evaluate on their own focus changes, so `.defaultFocus` reads a fresh value whenever it matters, and Home never re-renders per horizontal step (BUG-126 rule).

**Remounted rows.** `LazyVStack` may cull a row far from the current page and lose its horizontal offset, leaving the remembered card unrealized. `CatalogRowView` (inside its `ScrollViewReader`, `BrowseComponents:5130`) and `ContinueWatchingRow` (`HomeView:5116`) gain one `.onAppear` that, only when `stripFocusMemory` is non-nil and the remembered id isn't the first item, does `DispatchQueue.main.async { withTransaction(no animation) { proxy.scrollTo(id) } }` (anchor nil = minimal scroll; nothing moves if it's already visible). Upcoming and collection rows are short and have no proxy, so they're left alone.

**Where memory is restored:**

| Trigger | Mechanism |
|---|---|
| Down / Up | `.defaultFocus(…, priority: .userInitiated)`: the engine lands on the remembered card (first card for an unvisited row) |
| Menu at row > 0 | `pageToTop()` (§6), request `{rowKey: rows[0], itemId: memory[rows[0]]}` |
| Rail exit (P4) | the Stage `RailReturnRoute` W2-D registers (R2, P4 §2.5). `capture` records `controller.currentRowKey`. `restore` returns false while Home is covered (a push or the stream picker); otherwise it calls `controller.requestFocus(rowKey: row, itemId: memory.itemId(for: row))` and returns true |
| Pop from Detail / folder | native restoration (the card keeps its `.id`); `.defaultFocus` names the same card |

`requestRowFocus` (the pager's; `controller.requestFocus` forwards to it) rungs: issue at the next runloop, then re-issue at 0.3 s and 0.7 s while `box.focusedRowKey != key`, then at 1.0 s with `itemId: nil` (first card). The rungs are generation-guarded, and each one logs `[StageStrip] restore row= item= rung= landed=`.

**Gate G-F (end of W1, simulator):** `testS07` must show Down into an unvisited row landing on card 0, and Up returning to the card left. If `.defaultFocus` is ignored inside the `LazyVStack`, ship `-debug.stripFocusMemory off` as the default (decided 2026-10-05, Q5): Down/Up land geometrically (what the spike measured), and memory serves Menu and rail restores only.

### 3.4 Top edge and page opacity (D4)

The strip keeps the spike's clip with a soft top edge (#3): `.scrollClipDisabled()` plus `.mask(alignment: .top) { StripEdgeMask(gutter: 24) }`, a full-width mask from 24 pt above the strip's top to its bottom, whose top 24 pt ramp clear → opaque. Those 24 pt are the stage block's bottom gutter (`Theme.Spacing.lg`, `Theme.swift:517`), so a row leaving upward softens there and never draws over the synopsis. At rest the gutter holds only page i−1's bottom padding (the 2·lift slack, or the shelf's 24 pt with No Zoom). Gate 1's screenshots check the edge.

Pages get `.visualEffect { c, p in c.opacity(StripGeometry.pageOpacity(minY: p.frame(in: .scrollView(axis: .vertical)).minY, pageHeight: P)) }`, a render-time effect with no state writes. `pageOpacity`: `minY ≥ 0 → 1 − 0.4·min(minY/P, 1)` (the peek row at rest reads 0.6, the plan's "secondary text"); `minY < 0 → 1` (the mask handles it). The current page at rest is exactly 1, so the focused card's lift renders untouched, and a clip never touches focusability (Up works as in the spike's device walks).

### 3.5 `StripMotionSignal` (`Screens/Home/StripMotionSignal.swift`)

```swift
@MainActor final class StripMotionSignal: RowRestSignal {
    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }   // test seam
    private(set) var pageInFlight = false
    private(set) var generation = 0
    var onPageStarted: (() -> Void)?; var onPageEnded: (() -> Void)?        // the controller → swap driver
    func pageStarted(duration: TimeInterval) -> Int   // generation += 1; in flight; RowsMotionClock.stamp();
                                                      // a fallback ends this generation at duration + 0.5 s (logs pageEnd=timeout)
    func pageEnded(generation: Int)                   // ignored unless it is the latest generation
    var restPending: Bool { pageInFlight }
    var secondsSinceMotion: TimeInterval { RowsMotionClock.secondsSinceMotion() } // strip + row h-scrolls stamp it (TrailerStartGate.swift:23)
}
```

Feeds `.custom(signal)` to the rows (`\.rowRestSource`, M3), to the stage resolver's sharpen (`resolver.restSource`), and to the background trailer model.

## 4. Stage swap state machine (`Screens/Home/StageSwapModel.swift`)

### 4.1 What it wraps

The upstream pipeline is reused unchanged: row report → `HomeHeroFocusModel.reportFocus` (`HomeView:3382`; 0.2 s commit, cross-row nil rule, 0.3 s revert grace, cover freeze, logo lookup, TMDB gap-fill) → sticky `stageTarget` → `HeroArtResolver.present(_:isFolder:)` (`:3953`; warm commit is synchronous, cold ≤ 400 ms, folders ≤ 1.5 s; one payload with text and decoded art; sharpen at the same identity) → `resolver.$presented` → **`StageSwapDriver`** → `StageTextBlock` + `StageArtLayer`.

All of it lives in one reusable controller, which the folder Rows page builds too (#2):

```swift
@MainActor final class StageController: ObservableObject {     // Screens/Home/StageController.swift; NO @Published
    let focusModel = HomeHeroFocusModel(); let resolver = HeroArtResolver()
    let swap = StageSwapDriver()          // .output: text/art leaves observe it; .washFeed: only the wash (§4.3)
    let signal = StripMotionSignal(); let memory = StripFocusMemory(); let pagerHandle = StripPagerHandle()
    var progressLookup: ((MetaPreview) -> WatchProgressEntry?)?   // W2-A's CW copy (§5); nil = plain copy
    var currentRowKey: String?                                    // written by StripPager (§3.1)
    func start()                          // setSharpenForm(.classic), restSource = .custom(signal), wiring below
    func seed(_ item: MetaPreview?, washFallback: String? = nil)  // first paint; ignored after the first real commit
    func report(_ item: MetaPreview?, source: String,             // the focus-report funnel (table below)
                logoCandidates: () -> [MetaPreview] = { [] }, prefetch: () -> [String])
    func rowAppeared(collection: NuvioCollection)                 // HomeRowPreviews.warmCollection, shared dedup set
    func setCovered(_ covered: Bool, restoresFocus: Bool)
    func requestFocus(rowKey: String, itemId: String?)            // S4 handle → the pager's rungs (§3.3)
}
```

`StageStripHome` holds it as `@StateObject` for lifetime only: it publishes nothing, so no swap phase, pending change or commit re-evaluates the strip (#5, the BUG-126 class). HomeView's own pair stays idle (E3). `start()` wires the pipeline with Combine sinks on `DispatchQueue.main` (nothing runs inside a `willSet`): `focusModel.$focusedItem` → the sticky target (nil keeps it, D5) → `resolver.present`, including same-identity payload changes as HomeView's `heroPayloadSignature` does; `resolver.$presented` → `swap.receive`; the signal's page start and end → `swap.notePageStarted()` / `notePageEnded()`. The ~100 commit/art/logo unit tests keep covering the wrapped path.

**The report funnel (#4).** `report` does Classic's `reportRowFocus` warm-up (`HomeView:2887–2903`, via `HomeRowPreviews.warmRow`, once per row against the controller's own dedup set), then `focusModel.reportFocus(item, from: source)` and `swap.noteFocusActivity()`. Strip rows are wired as Classic wires them:

| Row | `report(…)` | `prefetch` / extra (Classic call site) |
|---|---|---|
| Continue Watching | `entry.map(StageCopy.preview(from:))`, source `"continue-watching"` | first 8 entries' `heroBackdropPrefetchURLs` (`:1382`) |
| Upcoming | `item?.toMetaPreview()`, source `"upcoming"` | first 8 (`:1397`) |
| Catalog | `item`, source `section.key`; `logoCandidates` = the first 18 items that are lookup candidates | first 8 (`:1416`); `.onAppear { model.rowAppeared(sectionKey:) }` (BUG-35, `:1428`) |
| Collection | `folder.flatMap(HomeRowPreviews.folder)`, source `collection.id` | `collectionArtURLs` (`:1458`); `.onAppear { stage.rowAppeared(collection:) }` (`:1497`) |

Only these are new: the pause anchor, the strip gate, and the art following the text.

### 4.2 Pure core

```swift
nonisolated protocol StageSwapPayload: Equatable { var swapIdentity: String { get } }
extension HeroPresentation: StageSwapPayload { var swapIdentity: String { identity } }

nonisolated struct StageSwapCore<P: StageSwapPayload>: Equatable {
    var timing: TextSwapTiming = StageStripTuning.swapTiming   // .stage: 0.45 / 0.15 / 0.20 (Home/HeroTextSwap.swift:31), or the knobs (#6)
    static let quiet: TimeInterval = 0.05                      // rows still this long before a fade-out (#15)
    var reduceMotion = false
    private(set) var phase: TextSwapPhase = .idle  // idle | pausing | fadingOut | fadingIn (reused tokens)
    private(set) var shown: P?                     // text AND art draw this
    private(set) var pending: P?
    private(set) var textOpacity: Double = 1
    private(set) var fade: Fade = .none            // .none | .out(fadeOut) | .in(fadeIn): the curve for the latest opacity write
    private(set) var lastActivity: TimeInterval = -.infinity
    private(set) var pageInFlight = false
    private(set) var pageEndedAt: TimeInterval = -.infinity
    private(set) var lastMotion: TimeInterval = -.infinity     // RowsMotionClock's last stamp, fed by the driver
    private(set) var stepDue: TimeInterval?
    private(set) var resting: String?              // identity settled at/after the gate → background trailer may arm
    private(set) var swaps = 0
    func gateTime() -> TimeInterval? {             // nil while a page is in flight
        pageInFlight ? nil : max(lastActivity + timing.pause, pageEndedAt, lastMotion + Self.quiet) }
    var nextDeadline: TimeInterval? { phase == .pausing ? gateTime() : (stepDue ?? (resting == nil && shown != nil && phase == .idle ? gateTime() : nil)) }

    mutating func seed(_ p: P?)
    mutating func present(_ p: P?, now: TimeInterval)
    mutating func focusActivity(now: TimeInterval)
    mutating func pageStarted(now: TimeInterval)
    mutating func pageEnded(now: TimeInterval)
    mutating func motion(at t: TimeInterval)
    mutating func tick(now: TimeInterval)
}
```

**Rules:**

| Input | State | Result |
|---|---|---|
| `present(nil)` | any | clear: shown/pending nil, opacity 1, idle |
| `present(p)` | shown nil | shown = p at once, no fade (seed path) |
| `present(p)`, same identity as shown | idle / fadingIn | silent gap-fill: shown = p (late synopsis, sharpened art), pending nil |
| ″ | pausing, text visible | pending nil → idle |
| ″ | pausing hidden / fadingOut | pending nil → fadingIn (fade .in) — text returns, no swap |
| `present(p)`, new identity | idle → pausing; pausing → stay; fadingOut → stay (the swap takes the newest); fadingIn → stay (pausing at fade end) | pending = p; if pausing and the gate is non-nil and passed, tick at once (cold arrival) |
| `focusActivity` | any | `lastActivity = now`, `resting = nil` |
| ″ | fadingOut | **cancel**: phase pausing, text stays hidden (opacity target already 0), `stepDue` nil |
| `pageStarted` | any | `pageInFlight = true`, `resting = nil`; in fadingOut, same cancel as above |
| `pageEnded` | any | `pageInFlight = false`, `pageEndedAt = now` |
| `motion(at:)` | any | `lastMotion = max(lastMotion, t)`; the driver feeds `now − RowsMotionClock.secondsSinceMotion()` before every tick |
| `tick` | pausing, gate non-nil, `now ≥ gate` | pending nil: hidden → fadingIn, else idle. pending: hidden or reduceMotion → **swap**; else fadingOut (opacity 0, `.out`, stepDue + fadeOut) |
| ″ | fadingOut, `now ≥ stepDue` | **swap** |
| ″ | fadingIn, `now ≥ stepDue` | pending ? pausing : idle |
| ″ | idle, gate non-nil, `now ≥ gate`, shown non-nil | `resting = shown.swapIdentity` |

**swap:** `shown = pending; pending = nil; swaps += 1`, then reduceMotion ? (opacity 1, `.none`, idle) : (opacity 1, `.in`, fadingIn, stepDue + fadeIn).

**Invariants (asserted in every test):** I1, `shown`'s identity changes only inside swap, and only when `textOpacity == 0` or reduceMotion. I2, `gateTime() ≥ lastActivity + timing.pause`. I3, no fade-out starts while a page is in flight, or within `quiet` of the last rows motion.

**Tuning knobs (#6, Q3):** `StageStripTuning.swapTiming` is launch-latched beside `pageSeconds` (§8), defaulting to `TextSwapTiming.stage`. Ship 450 ms; Right → new text complete takes 0.80 s against Classic M5's 0.44 s, so the device pass and Steven's video tune it, trying 300 ms first if Right reads late.

### 4.3 Driver and rendering

`@MainActor final class StageSwapDriver: ObservableObject` holds a `StageSwapCore<HeroPresentation>`, an injected `now` and `Schedule` (`TextSwapModel.mainQueueSchedule` shape), and ONE scheduled wake at `core.nextDeadline`, replaced and never stacked. It publishes `@Published private(set) var output: StageSwapOutput { shown, art (== shown), textOpacity, animation: Animation?, restingKey }`, assigned only when it changes, inside `withTransaction(Transaction())`. The resolver's 0.3 s commit transaction must not leak in (the M5 lesson, `HeroTextSwap.swift` type doc).

API: `noteFocusActivity()`, `notePageStarted()`, `notePageEnded()`, `receive(_ p: HeroPresentation?)`, `seed(_:washFallback:)`, `setReduceMotion(_:)`.

**The wash feed (S2, S8).** `let washFeed = StageWashFeed()`, a separate object, so the wash's inputs never touch `output`'s observers:

```swift
nonisolated struct StageFeedItem: Equatable { let item: MetaPreview; let identity: String; let washFallback: String? }
@MainActor final class StageWashFeed: ObservableObject {
    @Published private(set) var pending: StageFeedItem?     // the core took a new pending identity (its pause began)
    @Published private(set) var displayed: StageFeedItem?   // the swap point, or the seed
}
```

The driver writes `pending` when `core.pending`'s identity changes and `displayed` at each swap or seed; `washFallback` comes from `seed` (the folder page passes its cover).

**Who observes what (#5, the `HeroTextLayer` pattern, `HomeView:6491`).** `StageView(controller:geometry:hidesLogoWhenDisplaying:probeID:)` holds the controller as a plain `let`. `StageTextBlock` and `StageArtLayer` take `@ObservedObject var swap` (the art layer also observes the background trailer, §7), the wash observes `washFeed`, and each DEBUG label its own source, so a swap phase re-renders those leaves and never the strip. S3: the logo slot is at opacity 0 while `output.shown?.identity == hidesLogoWhenDisplaying`.

`StageTextBlock` follows the M5 render contract exactly:

```swift
ZStack(alignment: .topLeading) {
  VStack(alignment: .leading, spacing: 12) {
    HeroLogo(item:, image: shown.logo, maxHeight: geo.logoSlot, ink: shown.logoInk)
        .frame(height: geo.logoSlot, alignment: .bottomLeading)
        .opacity(shown.identity == hidesLogoWhenDisplaying ? 0 : 1)            // S3
    Text(copy.meta).font(Theme.Font.metaStrong).foregroundStyle(Theme.Palette.textPrimary.opacity(0.9))
        .lineLimit(1).frame(height: 32, alignment: .leading)
    Text(copy.synopsis).font(Theme.Font.synopsis).foregroundStyle(Theme.Palette.textPrimary.opacity(0.85))
        .lineLimit(geo.synopsisLines).frame(height: geo.synopsisSlot, alignment: .topLeading)
        .animation(nil, value: copy.synopsis)
  }
  .frame(width: Theme.Size.heroInfoPanelWidth, alignment: .leading)       // 680
  #if DEBUG .onAppear { HeroInfoLiveCounter.appear() } .onDisappear { HeroInfoLiveCounter.disappear() } #endif
  .id(shown.identity).transition(.identity)
  .animation(output.animation) { $0.opacity(output.textOpacity) }
  .accessibilityElement(children: .combine).accessibilityIdentifier("stage_info")
}
.frame(width: 680, height: geo.stageHeight − geo.stageBlockTop − 24, alignment: .topLeading)   // fixed: "stage_text_slot"
.padding(.top, geo.stageBlockTop).padding(.leading, geo.contentLeading)
```

The stage frame changes only with a settings change (geometry, animated `.easeInOut(0.28)` like Classic's plan animation), never with a swap. Folder heroes use the same three-slot column: logo, collection title as meta (`releaseInfo`), `folderHeroDescription` as synopsis.

`StageArtLayer`: `HeroCrossfadeImage(image: art?.backdrop, identity: art?.identity ?? "-")` (`HomeView:5572`, 0.3 s easeInOut in place) plus the background trailer (§7), framed at 1920×1080 aspect-fill. Mask: leading stops clear 0 → black 0.35 at 0.30 → black at 0.55 of the width; bottom stops black until `stage − 40` → clear at `stage + 200`. The art fades into layer 0 (wash, or `Theme.Palette.background` when Ambient is off). `.accessibilityHidden(true)`. Classic's Nuvio art already uses a gradient mask, so this isn't a new cost class.

**Seed:** once `model.rowsGateOpen`, `stage.seed(_:)` with the first strip row's first item (a CW entry goes through `StageCopy.preview(from:)`, which carries `entry.logo`). That's the card tvOS focuses at launch, so the first commit has the seed's identity and lands as a silent gap-fill: no double paint at launch. Warm it with `ArtworkStore.prefetch(heroArtPrefetchItems(for:))`. The seed is ignored after the first real commit.

**Cover:** `.onChange(of: cover, initial: true)` and `.onReceive(tabBarVisibility.$homeSurfaceCovered)` → `stage.setCovered(pushed || resume || shell, restoresFocus: pushed || resume)` (HomeView's `syncHeroFocusCover` rule, `:409`).

### 4.4 Timeline (warm cache unless noted; t = 0 is the press)

Page ends below are nominal (a 0.5 s glide completing at press + 0.50). The device measured 0.51–0.73 s, and the gate follows the real completion plus 0.05 s without rows motion (#15).

| Case | Events (s) | Swaps |
|---|---|---|
| A. Right, no page | 0 activity → 0.20 commit/present (pausing, gate 0.45) → 0.45 fade-out → **0.60 swap** (art cross-fade 0.60–0.90) → 0.80 idle, `resting`. A row scroll still moving at 0.45 holds the fade-out until 0.05 s after it stops | 1 |
| B. Down, page 0.5 s | 0 activity + page start → 0.20 present (pausing; no gate while in flight) → 0.50 page completion → 0.55 rows still → fade-out → **0.70 swap** → 0.90 idle | 1 |
| C. Two Rights 0.3 s apart | gate moves to 0.75; P1 pending at 0.20, replaced by P2 at 0.50 → 0.75 out → **0.90 swap to P2** | 1 (P1 never shown) |
| D. Activity during fade-out | out 0.45; activity 0.52 → hidden pause, gate 0.97; P2 present 0.72 → **0.97 swap (already hidden)** → 1.17 idle | 1 |
| E. Held Down 3 s, last hop 2.9 | completion 3.40 → 3.45 out → **3.60 swap** → 3.80 idle | 1 |
| F. Cold art (≤ 400 ms) | present at ≤ 0.60, past the gate → out at arrival → swap ≤ 0.75 | 1 |
| G. Right then Left within 0.4 s | the second report cancels the 0.2 s commit, or the present is the same identity → no fade | 0 |
| H. Reduce Motion | same gates; at the gate an instant cut, no fades; art cut (HeroCrossfadeImage honours RM) | 1 |

## 5. Stage copy and row headings

`Screens/Home/StageCopy.swift`, pure, unit-tested:

```swift
nonisolated struct StageCopy: Equatable { let meta: String; let synopsis: String }
extension StageCopy {
    static func make(item: MetaPreview, progress: WatchProgressEntry?) -> StageCopy
    static func preview(from entry: WatchProgressEntry) -> MetaPreview   // HomeRowPreviews.entry + logo: entry.logo
    static func remainingLabel(positionMs: Int64, durationMs: Int64) -> String?
}
```

- **W1-A:** `progress` is ignored. `meta` = Classic `metaLine` (release · first three genres, U+00B7, the `HomeHeroForeground` `:6468` rule duplicated); `synopsis` = `item.description_ ?? ""`.
- **W2-A, CW-aware:** `progress` = `stage.progressLookup?(item)`. `StageStripHome` sets it to a `cwIndex["\(type):\(id)"]` lookup built from `model.continueWatching` (keyed `parentMetaType:parentMetaId`), so it applies wherever the in-progress title is focused, in any Home row. Folder previews never get CW copy, and the folder page leaves the lookup nil.
  - `meta` = [`"S\(s) E\(e)"` when both are set] + [`episodeTitle` if non-blank and ≠ title] + [`remainingLabel`]. `remainingLabel` is nil when `durationMs ≤ 0` (Trakt/Simkl percent-only rows) or under 60 s left; otherwise `"%lldm left"` under an hour, `"%lldh %lldm left"` from an hour, both via `String(localized:)`. Join with `" · "`; empty → Classic meta.
  - `synopsis` = `pauseDescription` if non-blank, else `item.description_` (TMDB gap-fill fills the series text later; it lands silently).
  - Example: "S1 E3 · The Hunt · 45m left".
- **Add-on name after headings (W2-A, Stage only):** env key `rowHeadingShowsAddon: Bool` (default false) in `BrowseComponents.swift`, set true on the strip. In `CatalogRowView`'s `cardTopReach == 0` branch (`:5124`), when the flag is set and `addonName` (`HomeCatalogSection.addonName`, `HomeModels.kt:40`) is non-blank and not already in the title (case-insensitive), render `(Text(title).foregroundStyle(textPrimary) + Text(" · \(addon)").foregroundStyle(textSecondary)).font(Theme.Font.sectionTitle).lineLimit(1)`. Otherwise the existing `Text`, unchanged. `lineLimit(1)` keeps rowH honest.

## 6. Chrome

| Behaviour | Spec |
|---|---|
| Menu, row > 0 (Home) | `StripPager.pageToTop()`: programmatic target = rows[0] (1.5 s guard), `page(to: rows[0], index: 0)`, `swap.noteFocusActivity()`, `requestRowFocus(rows[0], itemId: memory[rows[0]], reason: "menu")` with the rungs in §3.3. The device spike did this as one 1.36 s motion (the engine's scroll won): W2-A measures it, and if it is still slow, writes the focus request and `positionId` in one `withAnimation` transaction (#16) |
| Menu, row 0 (Home) | `atTopExit`: in sidebar mode `{ guard !sidebarChrome.isFocusedChrome else { return }; sidebarChrome.requestReveal() }` (HomeView `:2922` rule); in Tabs mode nil, so the system default applies (focus to the tab bar, then exit). W2-D swaps in `railMenuRevealHandler`; inside the rail, Menu suspends the app if Menu opened it and closes it if Left did (R3, Q2) |
| Menu, folder Rows page | `menuPagesToTop: false`: no `.onExitCommand` at all, so Menu pops from any row (S4, R3) |
| Handler | `.onExitCommand(perform: atTop ? atTopExit : { pageToTop() })` on the strip, installed only when `menuPagesToTop` |
| Up from row 0 | no code: the stage has no focusable view, so the engine goes to the tab bar (sidebar mode: `moveFail up`, or the S1 hidden-bar redirect; rail mode: no target and never a reveal, BUG-98) |
| Tab bar | `TabBarContentScrollLinkAttacher(pinnedContainer: false)` in the LazyVStack background when `linksTabBar` (`TabBarContentScrollLink.swift:146`, as the spike). Row 0 rests at offset 0 (bar shown); row k ≥ 1 rests at k·P ≥ 388 pt, more than the 68 pt bar (fully hidden). a2 rests exactly on multiples of P, so the bar is never half shown at rest. T1's legs are inert here (no settle corrector). The Test profile runs Sidebar, so the plan's device pass uses Top Tabs for steps 1–13 with `-debug.tabBarStateProbe YES`, the only device evidence for this row (#10) |
| `isScrolledDown` | written from `onRowChange`: `isScrolledDown = index > 0`, only when it changes. `reportsScrollToTabBar(tab: "Home")` stays on the strip without the binding, so TabBarStateProbe keeps its mirror. Its hysteresis (hide > 300, show < 160) agrees at rest because P ≥ 388 |
| Rail (P4) | inset from `\.railLeadingInset` (R1), restores through the Stage route (R2, §3.3), content gating by P4's UIKit flag (no Stage parameter). Hide While Browsing: W2-D's `onPageStart` calls `navigationChrome.setScrolledDown(tab: 0, index > 0, motion: .page(seconds:))`, so the rail moves with the page's curve and duration and no resting settle (#8). That write owns the rail; the mirror's later crossing writes the same value, a no-op under write-on-change (R4) |

## 7. Trailers

**Background** (`trailer_playback_location == "hero"`, shown as "Background"). `bgTrailer = InlineTrailerCardModel()` (`InlineTrailerCard.swift:365`, `hostsTile = false`), `restSource = .custom(stage.signal)`, on the `StageController` (W2-A adds it); only `StageArtLayer` observes it (#5), and arming runs from `.onReceive(stage.swap.$output)`, never a body read.

- **Arm:** on `swap.output.restingKey` changing to non-nil → `bgTrailer.reset(); bgTrailer.focusChanged(true, item: shown.item)`. This needs `backgroundTrailerMode`, `systemVideoAutoplayEnabled` (mirrored as HomeView does, `:144`/`:1130`), `scenePhase == .active`, `!cover.pushed && !cover.resume && !homeSurfaceCovered`, a strip row owning focus, the chrome not holding focus (`sidebarChrome.isFocusedChrome` read at arm time; `navigationChrome` after W2-D's rename), and the shown item not a folder (`isCollectionHero`).
- **Delay:** M4's dwell applies unchanged (`TrailerStartGate.step`): Automatic = strip rest + 1 s (first start ≈ press + 1.9 s on a Down, plus resolve). A fixed N counts from the stage settle, not the press.
- **Tear down** (`reset()`) on: any `noteFocusActivity` or page start (restingKey → nil), any cover, a scenePhase change, the mode turning off, strip focus loss (`onStripFocusLost`, #17), and the chrome taking focus: `.onReceive(sidebarChrome.$isFocusedChrome)` with `true`, no body dependency. W2-A writes it against `\.sidebarChrome` (it exists at the base); W2-D's rename carries it to `navigationChrome` (R2).
- **Render:** in `StageArtLayer`, `TrailerHeroPlayer(urlString:, onFailure: bgTrailer.playbackFailed, zoomKey: TrailerResolutionCache.key(type:id:), loops: false, onPlaybackEnded: bgTrailer.playbackFinished, surfaceTag: "stage-bg")`, `.transition(.asymmetric(insertion: .opacity, removal: .identity))`, under the art mask and the text. Muted through `HeroTrailerAudioState` (default muted). Play/Pause on the focused card toggles it through `CatalogRowView.muteToggle`, because the hero model claims the coordinator with the card's own key (the `rowPlayingKey` doc, `BrowseComponents:4962`).
- Log `[TrailerPipeline] trailerLocation stage=bg|row` once on mount and on change.

**In Row** (`"poster"`). Rows get `trailerPlaysInHero = false` and `rowRestSource = .custom(stage.signal)`, so M3's gate holds the morph until `!restPending && sinceMotion ≥ 0.12`, i.e. after the strip settles. The morph widens the card only (`InlineTrailerCard` keeps `artworkHeight` constant; its morph scroll is horizontal-only, so it can't move the strip). The poster-colour ring (the fix batch's R1) stays inside the card. W2-A verifies this and adds no code unless the test fails.

## 8. Probes and launch arguments

| Arg | Effect |
|---|---|
| `-home_layout classic\|stage` | §1.4 |
| `-debug.homeScrollProbe YES` (`HomeGeometryProbe.enabled`, `BrowseComponents:107`) | arms `StageStripProbe` |
| `-debug.stripPageSeconds 0.3…1.0` | page animation length (default 0.5) |
| `-debug.stageSwapPause 0.2…0.8`, `-debug.stageFadeOut 0.05…0.4`, `-debug.stageFadeIn 0.05…0.4` | swap timing, defaults 0.45 / 0.15 / 0.20 (§4.2, #6) |
| `-debug.stripFocusMemory off` | no `.defaultFocus` (§3.3 fallback; the default if G-F fails, Q5) |
| `-debug.posterSizeOverride small\|medium\|mediumPlus\|large`, `-debug.posterHideTitles YES\|NO` | **DEBUG only**, app-wide, read in `PosterStyle.init(from:)` (`DesignSystem/PosterStyle.swift:22–29`): 105 / 126 / 134 / 154 dp, and titles. Both settings are synced (`PosterCardStyleRepository`, `hideLabelsEnabled`) with no UserDefaults key, so FA87 (Medium) needs these for Gate 1, testS13 and test47/48 (#11). No Zoom takes `-no_zoom_on_focus YES` already (`@AppStorage`, `PosterCard.swift:217`) |
| `-debug.tabBarStateProbe YES`, `-debug.collectionFrameProbe YES` | existing; unchanged |

All of these except the two poster overrides are launch-latched statics in `StageStripTuning` and not `#if DEBUG`, so Christian's device pass can set them on the Debug/Release binary, the same house rule as `TabBarRestFix`.

`Screens/Home/StageStripProbe.swift` ports the spike's `StageSpikeProbe` + `StageSpikeMarker` verbatim (CADisplayLink, presentation-layer y, segments ≥ 0.25 pt ended by 6 still frames, `seg p= k= start= dur= from= to= travel=` lines, press windows, `focus →`/`moveFail` lines), renamed, with prefix `[StageStrip]`. It adds:
- `geometry rowH= P= H= stage= logo= synL= fits= posterH= font=`, logged on change;
- `swap phase=out|in|cancel|idle id= sinceAct=<ms> pageEnd=<ms|timeout>`, from the driver;
- `restore row= item= rung= landed=`;
- `trailer arm|reset|start key= via=` (W2-A).

DEBUG leaf labels (each observes only its own sources):
- `debug_stage phase= shown= pending= swaps= maxLive= stageH= stripH= P= fits= rest= row= fitem= disp=` (append-only; S7): `row` the strip's row index, `fitem` the last reported item id (`nuvio-folder://…` for a folder tile), `disp` the shown identity. The id is `StageView.probeID`, so a folder page pushed over Home never yields two `debug_stage` elements;
- `debug_strip <last PRESS summary> row= key= foc=<rowKey>/<itemId> atTop= segs=<n> seg=<last travel>/<dur ms>`. `segs` and `seg` update at each segment end, never per frame (#18).

## 9. Ownership and tests

### 9.1 W1-A (Opus): the stage and the strip

- **New** (`Screens/Home/`): `HomeRowPreviews.swift`, `StripGeometry.swift` (plus the `railLeadingInset` env key), `StripMotionSignal.swift`, `StripFocusMemory.swift`, `StripPager.swift` (plus `StripPagerHandle`), `StageSwapModel.swift` (core, driver, payload, `StageWashFeed`), `StageController.swift`, `StageCopy.swift` (plain copy), `StageView.swift` (StageView, StageArtLayer, StageTextBlock, StageScrim, `StripEdgeMask`, debug labels), `StageStripHome.swift`, `StageStripProbe.swift`. **Not** `HomeLayout.swift`: that is W1-C's (#1).
- **Edits:**
  - `HomeView.swift`: E1–E6, plus `ContinueWatchingRow`'s remount `.onAppear`;
  - `PinnedRowUpFallback.swift`: `itemId`, `target(for:…)`, memory env, `.defaultFocus`;
  - `BrowseComponents.swift`: `CatalogRowView`'s remount `.onAppear` only;
  - `DesignSystem/PosterStyle.swift`: the DEBUG poster overrides (#11) and `withHeight(_:)` (#23).
- **Tests (NuvioTVTests):** `StripGeometryTests`, `StageSwapModelTests`, `StripFocusMemoryTests`, `StripMotionSignalTests`.
- Leaves a `Color.clear` layer 0 for W1-B's wash; the main session wires `AmbientWashLayer(feed: stage.swap.washFeed)` there at the W1 merge (S8).
- W1-A, W1-B and W1-C touch disjoint files. W1-A reads `HomeLayout` (W1-C) by its P2 §3.1 signature, and W1-B reads `StageWashFeed` by §4.3's.

### 9.2 W2-A (Opus): motion polish and trailers

- **Edits** (each after W1-A, sequential):
  - `StageCopy.swift`: CW-aware copy (`StageController.progressLookup`, set by `StageStripHome`; the folder page leaves it nil);
  - `StageStripHome.swift`, `StageView.swift`, `StageController.swift`: background trailer, `trailerLocation` log, trailer probe lines, the chrome-focus teardown (§7);
  - `BrowseComponents.swift`: `rowHeadingShowsAddon` env + `CatalogRowView` heading branch.
- **Device tuning:** `pageSeconds` and the swap knobs (record P, press and swap numbers in OUTCOME); Menu row → 0 (#16).
- **Optional, only if device logs show resolver fetch churn on held Down:** defer `resolver.present` while `stage.signal.restPending`.
- **Tests:** `StageCopyTests`, plus the In Row assertions in testS09.
- **File order (P3 matrix):** W1-B, W1-C and W2-B never touch W1-A's files; W2-B consumes §1.5 in its own files, so W2-A and W2-B never co-edit. `HomeView.swift` is W1-A's, then W2-D's. W2-D starts after W2-A, W2-B and W2-C have all landed (#12), since it edits `StageStripHome.swift`, `FolderRowsPage.swift` and `SettingsDescriptions.swift` (W1-C → W2-C → W2-D). `Localizable.xcstrings` changes only through the scripts, once, at the end.

### 9.3 Unit tests (concrete)

**`StripGeometryTests`**
- The 16-row table in §2: rowH, P, H, stage, logo, lines, inputs titleH 38 / caption 23 / synLH 30.
- Medium/on/on == spike (515.5, 559.5, 520.5).
- Open Sans (38.84 / 31.32): Medium → 516.5 / 561.5 / 518.5; Large → 590 / 635 / 445, 4 lines.
- Landscape rows at Medium → rowH 443.
- 164 dp fits (stage 420.5); 165 dp → `fits == false`, `layoutPosterHeight` 430.5, rowH 576, P 616, stage 420, stripHeight 660 (#23).
- `stageBlockTop` 120; `contentLeading` 140, and 176 with `leadingInset` 36.
- `pixelCeil(496.452) == 496.5`; `peek(38.84) == 45`.
- `pageOpacity`: minY 0 → 1.0 exactly; P → 0.6; 0.5P → 0.8; −0.6P → 1; −P → 1.

**`StageSwapModelTests`** (pure core, explicit times; every test asserts I1–I3)
- seed (no fade, swaps 0);
- cases A–H from §4.4, each asserting phase / opacity / fade / swaps at every listed time;
- same-identity sharpen while idle (shown replaced, no phase change, swaps unchanged);
- new identity during fadingIn (pausing at the fade end, gate respected);
- page in flight: no gate until `pageEnded`; a page started while pausing removes the deadline;
- rows motion 0.03 s before the gate holds the fade-out until 0.05 s after it;
- knob timing (pause 0.3) moves case A's swap to 0.45;
- `present(nil)` clears;
- `resting` set only at/after the gate and cleared by activity or a page start.
- **Driver test** (fake schedule): one wake outstanding at a time; outputs written in an animation-free transaction (`Transaction().animation == nil` probe); `washFeed.pending` set on a new pending identity and `displayed` at the swap, and a pending-only change leaves `output` unwritten.

**`StripFocusMemoryTests`**
- `target(for:)` table: Classic request → firstId; Stage `itemId` wins; no `itemId` → remembered → first; another row → nil.
- `remember` / `itemId` / `prune`.

**`StripMotionSignalTests`**
- `restPending` from `pageStarted(0.5)` until the latest generation's `pageEnded`; a stale generation's completion is ignored; with no completion, the fallback ends the page at 1.0 s.

**`StageCopyTests`** (W2-A)
- "S1 E3 · The Hunt · 45m left";
- no episode title → "S1 E3 · 45m left";
- movie 65 min left → "1h 5m left";
- `durationMs == 0` → no time;
- under 60 s → no time;
- `pauseDescription` beats `description_`;
- folder → plain;
- no progress → Classic meta.

### 9.4 Stage UI tests (W3 writes `NuvioTVUITests/StageStripUITests.swift`)

Named, not numbered, to avoid clashing with P2/P4 numbers. Launch args: `-home_layout stage -debug.homeScrollProbe YES`, FA87, Test profile fixture.

| Test | Steps | Assertions |
|---|---|---|
| `testS01_DownPagesOneRow` | Down ×4, 2 s apart, then Up ×4 | per segment, not the PRESS summary (the spike found summaries can assign a segment to the wrong press): each press adds exactly one segment (`debug_strip segs` +1) whose travel is ±P (±0.5), and `segs` doesn't move during the 2 s rest; `row=` steps by exactly 1 |
| `testS02_NextHeadingPeeks` | rest at row 0 and row 1 | `debug_strip`/`debug_stage` P and H from the label; the next row's heading element `minY` in [stageH + P, 1080]; no card of row i+1 with `minY < 1080` |
| `testS03_NeverTwoTitles` | Right ×6 fast, Down ×3, wait 2 s | `debug_stage maxLive=1`, `phase=idle`; `swaps` ≤ number of rests (fast hops add none) |
| `testS04_StageFrameConstant` | read the `stage_text_slot` frame, Right ×3 with rests | frame identical (±0.5) before, during and after swaps; `stageH=` unchanged |
| `testS05_UpFromRow0ToTabBar` | at row 0, Up | a tab bar button is focused; `debug_strip atTop=1` |
| `testS06_TabBarHiddenRow1ShownRow0` (Stage test75) | `-debug.tabBarStateProbe YES`; Down, rest; Up, rest | row 1: bar fully hidden; row 0: shown at y 0; never `st=part` at rest |
| `testS07_FocusMemory` | row 0 Right ×3, Down, Up; Down to an unvisited row | back on row 0 card 3 (`foc=`); the unvisited row lands on card 0 (G-F) |
| `testS08_MenuRow3ToRow0ThenChrome` | Down ×3, Menu; Menu again with `-sidebar_style rail` (W3 runs after W2-D, which deletes `sidebar_state`) | `row=0` and `foc=` = row 0's remembered card; second Menu → `rail_state … reason=menu`. Never press Menu again: in a Menu-opened rail it suspends the app (Q2) |
| `testS09_InRowMorphAfterRest` (Stage test01/41) | `-inline_trailers_enabled YES -trailer_playback_location poster`; Down, wait | `debug_trailerMorph event=gate host=card … src=custom` with start ≥ page end + 1.0; skips on extraction `LOGIN_REQUIRED` like test51 |
| `testS10_BackgroundTrailer` (Stage test37) | `…location hero`; rest, then Right; rest again at row 0, then Up to the tab bar | gate `host=hero` after `resting`; `event=reset` within 0.1 s of the Right, and again after the Up (strip focus loss, #17); skips on extraction |
| `testS11_HoldMenuOnStripPoster` (Stage test71) | long-press Select on a strip poster | the hold-menu items appear |
| `testS12_ClassicArg` | `-home_layout classic` | no `debug_stage`; `debug_hero mode=` present |
| `testS13_LargeGeometry` | `-debug.posterSizeOverride large` (#11) | `debug_stage fits=1 stageH=447 P=589` |
| `testS14_HeldDown` | from row 0, `XCUIRemote.shared.press(.down, forDuration: 3)`, then wait 2 s | one segment (`segs` +1) across the whole hold, and `swaps` +1 |

Every Classic leg in W3's list gains `-home_layout classic` (FA87 defaults to Stage once this lands).

## 10. Risks and open questions

1. **`.defaultFocus(priority: .userInitiated)` inside a lazy, focus-sectioned row is unproven here.** Gate G-F decides. Decided 2026-10-05 (Q5): if G-F fails, ship the fallback, geometric Down/Up as measured in the spike, with memory only for Menu and rail restores.
2. **The top-edge mask has to reach 24 pt outside the strip's frame** (§3.4). The Gate 1 screenshots check that the outgoing row softens in the gutter and never shows over the synopsis. A clip doesn't touch focusability, so Up is unaffected.
3. **The peek heading sits in the bottom 60 pt title-safe band.** A TV that overscans crops it. Decided 2026-10-05 (Q4): accept it as a hint. Lifting it out (54 pt) would put Large's stage at 393, under the 420 floor.
4. **D2 costs stage height that may be unused:** 11 pt with Hide Titles, ~95 pt with landscape catalog rows, even when Home has no collection rows. The alternative is a data-dependent height, which jumps once at load.
5. **Down swaps at ≈ 0.70 s, Right at 0.60 s:** the gate waits for the glide's real completion plus 0.05 s of stillness (D3, #15). The knobs in §8 tune the pause and fades on device (Q3). If Steven reads it as late, the pause is the first lever.
6. **Held Down still commits and resolves intermediate titles** (TMDB gap-fill, art fetch), the same as Classic. W2-A measures it before adding the defer.
7. **The hero fan-out isn't Swift-side** (#22): Hero Sources are fetched and selected in Kotlin (`HomeRepository`, gated by `effectiveHeroEnabled`, `HomeCatalogSettingsRepository.kt:172–174`), so W1-A leaves it and the batch stays out of `shared/`. A Swift-side cost remains with Show Hero on (the default): `HomeViewModel` holds the rows until the hero head's art prewarms (`heroCommitCoordinator.prepare`, `HomeViewModel.swift:668–700`, 1.5 s budget), so Stage's first paint can wait on a hero it never shows. Gate 1 measures it on a Stage cold launch (`LaunchTrace` `first_hero` `:718` against `first_rows` `:1175`); the main session decides whether Stage skips that await.

# Home Stage & Strip — P1 spec: Stage + Strip (2026-10-05)

**Inputs:** `docs/home-stage-strip-plan-2026-10-03.md` (H1–H9, Defaults, Spike verdict = binding), `docs/home-redesign-decisions-2026-10-03.md`, Steven's handoff, `docs/design/hig-hybrid-contract.md`, spike `035095a4` (`Screens/StageStripSpike.swift`).
**Base:** `d68b9d61`, clone `~/Claude/Projects/NuvioMobile-home-stage`. Paths are relative to `iosApp/NuvioTV/`; every `file:line` was re-read at the base (the plan's 10-03 numbers have moved).
**Scope:** Stage, Strip, paging, focus memory, swap model, stage copy, chrome, trailers, probes, W1-A/W2-A ownership, unit + UI tests. Not here: wash (P2/W1-B), Home Screen pane (P2/W1-C), folder Rows page (P2/W2-B), rail (P4/W2-D). Hooks for those are named in §1.4.

The Xcode project uses synchronized folder groups (`PBXFileSystemSynchronizedRootGroup`), so new files need no `project.pbxproj` edit.

## 0. Where this spec departs from the plan text (each is deliberate)

| # | Plan said | Spec does | Why |
|---|---|---|---|
| D1 | `heroFocusTrailerMode || stage` (`HomeView:540`) | Leave it alone; `StageStripHome` computes its own `backgroundTrailerMode` and sets `\.trailerPlaysInHero` on the strip | The stage's rows are not inside `rowsScroll`, so HomeView's value never reaches them; one fewer Classic edit |
| D2 | Strip height from the catalog row only | `rowH = max(catalogRow, collectionRowMax)` | With Hide Titles, a poster-shaped collection folder (per-folder caption) is 11 pt taller than a catalog row; with landscape catalog rows it is ~95 pt taller. A data-independent rule keeps the stage from jumping when collections load |
| D3 | 450 ms pause after the commit | Pause anchored on the **last raw focus report**, and never before the strip's page animation ends | HomeHeroFocusModel already spends 200 ms of the 450 ms on its commit; anchoring on the raw report gives "450 ms after you stop", and one motion at a time on a Down press |
| D4 | Strip clips (spike) | Strip clip disabled + position-driven page opacity (outgoing row fades, peek reads secondary), launch-latched fallback to the spike's hard clip | Steven's "row sliced by a hard mask line" complaint; the fallback keeps the measured look one flag away |
| D5 | Stage reverts when focus leaves items | Stage target is **sticky** (See All, tab bar, rail keep the last title) | Reverting to a resting title on See All would swap the stage to an unrelated title |

## 1. View tree and switch point

### 1.1 `HomeView.swift` edits (the complete list; Classic is otherwise untouched)

| # | Where (base line) | Edit |
|---|---|---|
| E1 | after `@AppStorage("accent_focus_ring")` `:115` | `@AppStorage(HomeLayout.storageKey) private var homeLayoutRaw = HomeLayout.defaultValue.rawValue` and `private var isStageLayout: Bool { HomeLayout.resolve(homeLayoutRaw) == .stage }` |
| E2 | `heroItems` `:251` | `isStageLayout ? [] : Array(model.heroItems.prefix(8))` — the carousel, its 8 s timer, `prefetchHeroArt`'s page warm-up and the `heroSurfaceSeen` latch all go dormant in Stage |
| E3 | `displayHero` `:372` | first line `if isStageLayout { return nil }` — Classic's resolver presents nil, so it fetches nothing |
| E4 | backdrop `:819` | `if !isStageLayout, let presentation = heroResolver.presented {` (HomeHeroBackdrop + HomeHeroScrim stay Classic-only) |
| E5 | `ScrollViewReader { … }` `:881–1067` | wrap: `if isStageLayout { StageStripHome(…) } else { ScrollViewReader { …unchanged… } }`. The BUG-27 `.onExitCommand` (`:982`) is inside the else, so it never sees Stage |
| E6 | `folderHeroPreview` `:2949`, `previewFromEntry` `:3006`, `collectionHeroPrefetchURLs` `:2837` | bodies move verbatim to `Screens/Home/HomeRowPreviews.swift` (`enum HomeRowPreviews { static func folder(collection:folder:) -> MetaPreview?; static func entry(_:) -> MetaPreview; static func collectionArtURLs(_:) -> [String] }`); the private funcs become one-line forwards |

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
├─ layer 0  Color.clear  // W1-B: AmbientWashLayer(presentation: swap.output.art) — main session wires it at the W1 merge
├─ layer 1  StageArtLayer(art: swap.output.art, trailer: bgTrailer)     // full screen 1920×1080, masked
├─ layer 2  StageScrim                                                   // top 0.45→0 black over 220 pt (tab bar legibility)
├─ VStack(spacing: 0)
│   ├─ StageTextBlock(...)   .frame(height: geo.stageHeight)              // no focusable descendant
│   └─ StripPager(rowKeys:…) .frame(height: geo.stripHeight)
│       └─ ScrollView(.vertical) { LazyVStack(spacing: 0) {
│             ForEach(rows) { page(row).frame(height: geo.pageHeight, alignment: .top).id(row.key) }
│             Color.clear.frame(height: geo.peek) }
│           .scrollTargetLayout()
│           .background(.topLeading) { TabBarContentScrollLinkAttacher(pinnedContainer: false) }
│           .background(.topLeading) { StageStripMarker() }   // probe only
│        }
│        .scrollPosition(id: $positionId, anchor: .top)
│        .scrollTargetBehavior(.viewAligned)
│        .scrollClipDisabled(StageStripTuning.topFade)          // D4
│        .rowsMotionStamp(.vertical)
│        .reportsScrollToTabBar(tab: "Home")                    // no isScrolledDown binding (§6)
│        .onExitCommand(perform: …)                             // §6
└─ DEBUG: StageDebugLabel, StripDebugLabel (leaf views)
```

The VStack is the spike's structure, which measured exact page rests on the device; keep `.ignoresSafeArea()` on the root exactly as the spike did. Rows are padded inside the ScrollView content: leading `contentLeading = RowSoftEdgeMask.margin + leadingChromeInset` (= 140 + rail), trailing 140, so they line up with Classic's rows and `RowEdgeMargins.standard` stays correct. When `leadingChromeInset > 0` the strip also sets `.environment(\.rowEdgeMargins, RowEdgeMargins(leading: 140 + inset, trailing: 140))`.

Strip environment (set once on the ScrollView): `\.trailerPlaysInHero = backgroundTrailerMode` (settings only: `inline_trailers_enabled && trailer_playback_location == "hero"`, never per focus — BUG-19 rule), `\.rowRestSource = .custom(stripSignal)`, `\.pinnedRowFocusRequest`, `\.pinnedRowFocusOwnership`, `\.stripFocusMemory` (§3.3).

Row order and keys are Classic's: `"continue-watching"` (if non-empty), `"upcoming"` (if `home_upcoming_row_enabled` and non-empty), then `model.rows` as `section.key` / bare `collection.id`. Before any row exists the strip shows `StageStripPlaceholder(model:)`, a copy of HomeView's private `placeholder` `:3030` (loading / error / add-on error with the focusable Retry chip / setting up).

### 1.4 Types and init

```swift
nonisolated enum HomeLayout: String, CaseIterable, Sendable {      // Screens/Home/HomeLayout.swift (W1-A owns)
    case stage, classic
    static let storageKey = "home_layout"
    static let defaultValue: HomeLayout = .stage
    static func resolve(_ raw: String?) -> HomeLayout                 // trim + lowercase; unknown/nil → .stage
    static func current(_ d: UserDefaults = .standard) -> HomeLayout // for non-view readers (W2-B, P4)
}
struct StageHomeActions { let resume: (ResumeTarget) -> Void; let push: (TitleRoute) -> Void }
nonisolated struct StageCover: Equatable { var pushed: Bool; var resume: Bool }

struct StageStripHome: View {
    @ObservedObject var model: HomeViewModel
    let actions: StageHomeActions
    let cover: StageCover
    @Binding var isScrolledDown: Bool
    var leadingChromeInset: CGFloat = 0   // P4: rail Always Visible
    var contentGated: Bool = false        // P4: rail holds focus → strip .disabled(contentGated)
}
```

`-home_layout classic|stage` lands in the argument domain, which `@AppStorage` reads, so no extra code. W1-C's picker writes the same key through `HomeLayout`; it must not define a second enum (flag for P3 to reconcile with P2).

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
    }
    let rowHeight, focusLift, pageHeight, peek, stripHeight, stageHeight: CGFloat
    let logoSlot, synopsisSlot: CGFloat
    let synopsisLines: Int
    let fits: Bool
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
- `stageRaw = 1080 − H`; `fits = stageRaw ≥ 420`; `stageHeight = max(420, stageRaw)`; when `!fits`, `stripHeight = 660` and `P = 660 − peek` (degraded, logged).
- Stage block: top inset 120 (`heroForegroundTopPadNuvio`), `logoSlot = stage < 480 ? 110 : 150` (`heroLogoSlotHeightPinned` / `heroLogoSlotHeight`), gap 12 (`heroPinnedSlotGap`), meta 32 (`heroMetaSlotHeight`), gap 12, bottom gap 24 (`Spacing.lg`). `synopsisSlot = stage − 120 − logo − 12 − 32 − 12 − 24` (= stage − 350, or − 310 with the 110 logo). `synopsisLines = min(5, max(1, floor((slot + 1) / synLH)))` (the `+1` is `HomeHeroForeground`'s `lineTolerance`; 5 is the hero-off panel's cap).

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
- A synced custom width ≥ 165 dp (titles on, zoom) gives stage < 420 → `fits = false`: stage pinned at 420, rows overflow their page into the peek, and `[StageStrip] geometry fits=0` is logged. 164 dp is the largest that fits; all four presets fit. There is no clamp in `PosterCardStyleRepository`, so a phone-side setting can reach this.

## 3. Paging and focus memory

### 3.1 Mechanism (spike a2, unchanged)

`StripPager` (`Screens/Home/StripPager.swift`) owns `@State positionId: String?`, `@State focusRequest = PinnedRowFocusRequest.none`, `@State atTop = true` (flips only between row 0 and row 1, so the parent doesn't re-render per hop), and a reference box `StripPagerBox { rowIndex, focusedRowKey, programmaticTarget, programmaticDeadline, restoreGeneration }` (no view-state write per hop beyond `positionId`).

```swift
struct StripPager<Row: View>: View {
    let rowKeys: [String]; let geometry: StripGeometry
    let signal: StripMotionSignal; let memory: StripFocusMemory
    let leadingInset: CGFloat; let linksTabBar: Bool
    let onRowChange: (_ index: Int, _ key: String) -> Void
    let onPageStart: (_ endsAt: TimeInterval) -> Void
    let atTopExit: (() -> Void)?               // host's Menu-at-row-0 handler (nil = system)
    @ViewBuilder let row: (_ key: String) -> Row
}
```

Ownership (`\.pinnedRowFocusOwnership`, fired off each row's own `@FocusState`): on `owns == true` for key K: clear a completed request for K (F5 rule); ignore other rows while a programmatic target is in flight (deadline 1.5 s, spike rule); if K is new, set `box.rowIndex`, call `CollectionFocusFrameSampler.shared.arm(rowKey: K, gif: false)` (frame-time window per hop, no-op unless its probe is on), `page(to: K)`, update `atTop`, call `onRowChange`.

```swift
func page(to key: String) {
    guard positionId != key else { return }
    let d = reduceMotion ? 0 : StageStripTuning.pageSeconds          // 0.5; -debug.stripPageSeconds 0.3…1.0
    signal.pageStarted(duration: d); onPageStart(signal.pageEndsAt)
    if d == 0 { positionId = key } else { withAnimation(.easeOut(duration: d)) { positionId = key } }
}
```

The focus engine moves focus; the app's position animation overrides the engine's slower scroll (device: one 0.51–0.73 s glide, exactly on the boundary, nothing after). Content height = n·P + peek, viewport H = P + peek, so the last row rests at (n−1)·P exactly.

### 3.2 Held Down

No extra code. Each hop re-targets the same `positionId` animation (device: one 2-page glide in 1.0 s) and extends `signal.pageEndsAt`; every row report is a focus activity for the swap model (§4), whose gate is `max(lastActivity + 0.45, pageEndsAt)`. Intermediate titles commit (HomeHeroFocusModel, 0.2 s) and replace `pending`, but nothing fades until the hand stops and the glide ends. One swap per held Down.

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
| Rail exit (P4) | `NotificationCenter` `.stageStripRestoreFocus` → `requestRowFocus(current, itemId: memory[current], reason:)` |
| Pop from Detail / folder | native restoration (the card keeps its `.id`); `.defaultFocus` names the same card |

`requestRowFocus` rungs: issue at the next runloop, then re-issue at 0.3 s and 0.7 s while `box.focusedRowKey != key`, then at 1.0 s with `itemId: nil` (first card). The rungs are generation-guarded, and each one logs `[StageStrip] restore row= item= rung= landed=`.

**Gate G-F (end of W1, simulator):** `testS07` must show Down into an unvisited row landing on card 0, and Up returning to the card left. If `.defaultFocus` is ignored inside the `LazyVStack`, ship `-debug.stripFocusMemory off` as the default: Down/Up land geometrically (what the spike measured), and memory serves Menu and rail restores only. That is Christian's call (§10).

### 3.4 Page opacity (D4)

Each page gets `.visualEffect { c, p in c.opacity(StripGeometry.pageOpacity(minY: p.frame(in: .scrollView(axis: .vertical)).minY, pageHeight: P)) }`, a render-time effect with no state writes.

`pageOpacity`: `minY ≥ 0 → 1 − 0.4·min(minY/P, 1)` (the peek row at rest reads 0.6, the plan's "secondary text"); `minY < 0 → max(0.02, 1 + minY/(0.6·P))` (the outgoing row is gone at 60 % of its travel). The 0.02 floor keeps rows above the strip focusable for Up (UIKit skips near-zero alpha). At rest the current page is exactly 1, the identity, so the focused card's lift renders untouched.

`StageStripTuning.topFade` is launch-latched (`-debug.stripTopFade 0` → no `visualEffect`, `.scrollClipDisabled(false)` = the spike's hard clip). G-F also checks Up from row 2 reaches row 1 with the fade on.

### 3.5 `StripMotionSignal` (`Screens/Home/StripMotionSignal.swift`)

```swift
@MainActor final class StripMotionSignal: RowRestSignal {
    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }   // test seam
    private(set) var pageEndsAt: TimeInterval = -.infinity
    func pageStarted(duration: TimeInterval)       // pageEndsAt = now()+duration; RowsMotionClock.stamp()
    var restPending: Bool { now() < pageEndsAt }
    var secondsSinceMotion: TimeInterval { RowsMotionClock.secondsSinceMotion() } // strip + row h-scrolls stamp it
}
```

Feeds `.custom(signal)` to the rows (`\.rowRestSource`, M3), to the stage resolver's sharpen (`resolver.restSource`), and to the background trailer model.

## 4. Stage swap state machine (`Screens/Home/StageSwapModel.swift`)

### 4.1 What it wraps

The upstream pipeline is reused unchanged: row report → `HomeHeroFocusModel.reportFocus` (`HomeView:3382`; 0.2 s commit, cross-row nil rule, 0.3 s revert grace, cover freeze, logo lookup, TMDB gap-fill) → sticky `stageTarget` → `HeroArtResolver.present(_:isFolder:)` (`:3953`; warm commit is synchronous, cold ≤ 400 ms, folders ≤ 1.5 s; one payload with text and decoded art; sharpen at the same identity) → `resolver.$presented` → **`StageSwapDriver`** → `StageTextBlock` + `StageArtLayer`.

`StageStripHome` owns its own instances (`@StateObject focusModel`, `resolver`, `swap`), so HomeView's pair stays idle (E3). Setup on appear: `resolver.setSharpenForm(.classic)` (full-bleed 1920 pt → 3840 px), `resolver.restSource = .custom(stripSignal)`. The ~100 commit/art/logo unit tests keep covering this path as-is.

Only these are new: the pause anchor, the strip gate, and the art following the text.

### 4.2 Pure core

```swift
nonisolated protocol StageSwapPayload: Equatable { var swapIdentity: String { get } }
extension HeroPresentation: StageSwapPayload { var swapIdentity: String { identity } }

nonisolated struct StageSwapCore<P: StageSwapPayload>: Equatable {
    var timing: TextSwapTiming = .stage            // pause 0.45, fadeOut 0.15, fadeIn 0.20 (HeroTextSwap.swift)
    var reduceMotion = false
    private(set) var phase: TextSwapPhase = .idle  // idle | pausing | fadingOut | fadingIn (reused tokens)
    private(set) var shown: P?                     // text AND art draw this
    private(set) var pending: P?
    private(set) var textOpacity: Double = 1
    private(set) var fade: Fade = .none            // .none | .out(0.15) | .in(0.20): the curve for the latest opacity write
    private(set) var lastActivity: TimeInterval = -.infinity
    private(set) var pageEndsAt: TimeInterval = -.infinity
    private(set) var stepDue: TimeInterval?
    private(set) var resting: String?              // identity settled at/after the gate → background trailer may arm
    private(set) var swaps = 0
    func gateTime() -> TimeInterval { max(lastActivity + timing.pause, pageEndsAt) }
    var nextDeadline: TimeInterval? { phase == .pausing ? gateTime() : (stepDue ?? (resting == nil && shown != nil && phase == .idle ? gateTime() : nil)) }

    mutating func seed(_ p: P?)
    mutating func present(_ p: P?, now: TimeInterval)
    mutating func focusActivity(now: TimeInterval)
    mutating func page(endsAt: TimeInterval, now: TimeInterval)
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
| `present(p)`, new identity | idle → pausing; pausing → stay; fadingOut → stay (the swap takes the newest); fadingIn → stay (pausing at fade end) | pending = p; if pausing and `now ≥ gate`, tick at once (cold arrival) |
| `focusActivity` | any | `lastActivity = now`, `resting = nil` |
| ″ | fadingOut | **cancel**: phase pausing, text stays hidden (opacity target already 0), `stepDue` nil |
| `page(endsAt:)` | any | `pageEndsAt = max(…)`; in fadingOut, same cancel as above |
| `tick` | pausing, `now ≥ gate` | pending nil: hidden → fadingIn, else idle. pending: hidden or reduceMotion → **swap**; else fadingOut (opacity 0, `.out`, stepDue +0.15) |
| ″ | fadingOut, `now ≥ stepDue` | **swap** |
| ″ | fadingIn, `now ≥ stepDue` | pending ? pausing : idle |
| ″ | idle, `now ≥ gate`, shown non-nil | `resting = shown.swapIdentity` |

**swap:** `shown = pending; pending = nil; swaps += 1`, then reduceMotion ? (opacity 1, `.none`, idle) : (opacity 1, `.in`, fadingIn, stepDue +0.20).

**Invariants (asserted in every test):** I1, `shown`'s identity changes only inside swap, and only when `textOpacity == 0` or reduceMotion. I2, `gateTime() ≥ lastActivity + 0.45`. I3, no fade-out starts before `pageEndsAt`.

### 4.3 Driver and rendering

`@MainActor final class StageSwapDriver: ObservableObject` holds a `StageSwapCore<HeroPresentation>`, an injected `now` and `Schedule` (`TextSwapModel.mainQueueSchedule` shape), and ONE scheduled wake at `core.nextDeadline`, replaced and never stacked. It publishes `@Published private(set) var output: StageSwapOutput { shown, art (== shown), textOpacity, animation: Animation?, restingKey }`, assigned only when it changes, inside `withTransaction(Transaction())`. The resolver's 0.3 s commit transaction must not leak in (the M5 lesson, `HeroTextSwap.swift` type doc).

API: `noteFocusActivity()`, `notePage(endsAt:)`, `receive(_ p: HeroPresentation?)`, `seed(_:)`, `setReduceMotion(_:)`.

`StageTextBlock` follows the M5 render contract exactly:

```swift
ZStack(alignment: .topLeading) {
  VStack(alignment: .leading, spacing: 12) {
    HeroLogo(item:, image: shown.logo, maxHeight: geo.logoSlot, ink: shown.logoInk)
        .frame(height: geo.logoSlot, alignment: .bottomLeading)
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
.frame(width: 680, height: geo.stageHeight − 120 − 24, alignment: .topLeading)   // fixed: "stage_text_slot"
.padding(.top, 120).padding(.leading, contentLeading)
```

The stage frame changes only with a settings change (geometry, animated `.easeInOut(0.28)` like Classic's plan animation), never with a swap. Folder heroes use the same three-slot column: logo, collection title as meta (`releaseInfo`), `folderHeroDescription` as synopsis.

`StageArtLayer`: `HeroCrossfadeImage(image: art?.backdrop, identity: art?.identity ?? "-")` (`HomeView:5627`, 0.3 s easeInOut in place) plus the background trailer (§7), framed at 1920×1080 aspect-fill. Mask: leading stops clear 0 → black 0.35 at 0.30 → black at 0.55 of the width; bottom stops black until `stage − 40` → clear at `stage + 200`. The art fades into layer 0 (wash, or `Theme.Palette.background` when Ambient is off). `.accessibilityHidden(true)`. Classic's Nuvio art already uses a gradient mask, so this isn't a new cost class.

**Seed:** once `model.rowsGateOpen`, `stageSeed` = the first strip row's first item (a CW entry goes through `StageCopy.preview(from:)`, which carries `entry.logo`). That's the card tvOS focuses at launch, so the first commit has the seed's identity and lands as a silent gap-fill: no double paint at launch. Warm it with `ArtworkStore.prefetch(heroArtPrefetchItems(for:))`. The seed is ignored after the first real commit.

**Cover:** `.onChange(of: cover, initial: true)` and `.onReceive(tabBarVisibility.$homeSurfaceCovered)` → `focusModel.setCovered(pushed || resume || shell, restoresFocus: pushed || resume)` (HomeView's `syncHeroFocusCover` rule, `:409`).

### 4.4 Timeline (warm cache unless noted; t = 0 is the press)

| Case | Events (s) | Swaps |
|---|---|---|
| A. Right, no page | 0 activity → 0.20 commit/present (pausing, gate 0.45) → 0.45 fade-out → **0.60 swap** (art cross-fade 0.60–0.90) → 0.80 idle, `resting` | 1 |
| B. Down, page 0.5 s | 0 activity + page end 0.50 → 0.20 present → gate = max(0.45, 0.50) → 0.50 fade-out → **0.65 swap** → 0.85 idle | 1 |
| C. Two Rights 0.3 s apart | gate moves to 0.75; P1 pending at 0.20, replaced by P2 at 0.50 → 0.75 out → **0.90 swap to P2** | 1 (P1 never shown) |
| D. Activity during fade-out | out 0.45; activity 0.52 → hidden pause, gate 0.97; P2 present 0.72 → **0.97 swap (already hidden)** → 1.17 idle | 1 |
| E. Held Down 3 s, last hop 2.9 | page end 3.40 → 3.40 out → **3.55 swap** → 3.75 idle | 1 |
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
- **W2-A, CW-aware:** `progress` = `cwIndex["\(type):\(id)"]`, built from `model.continueWatching` (keyed `parentMetaType:parentMetaId`), so it applies wherever the in-progress title is focused, any row. Folder previews never get CW copy.
  - `meta` = [`"S\(s) E\(e)"` when both are set] + [`episodeTitle` if non-blank and ≠ title] + [`remainingLabel`]. `remainingLabel` is nil when `durationMs ≤ 0` (Trakt/Simkl percent-only rows) or under 60 s left; otherwise `"%lldm left"` under an hour, `"%lldh %lldm left"` from an hour, both via `String(localized:)`. Join with `" · "`; empty → Classic meta.
  - `synopsis` = `pauseDescription` if non-blank, else `item.description_` (TMDB gap-fill fills the series text later; it lands silently).
  - Example: "S1 E3 · The Hunt · 45m left".
- **Add-on name after headings (W2-A, Stage only):** env key `rowHeadingShowsAddon: Bool` (default false) in `BrowseComponents.swift`, set true on the strip. In `CatalogRowView`'s `cardTopReach == 0` branch (`:5124`), when the flag is set and `addonName` (`HomeCatalogSection.addonName`, `HomeModels.kt:40`) is non-blank and not already in the title (case-insensitive), render `(Text(title).foregroundStyle(textPrimary) + Text(" · \(addon)").foregroundStyle(textSecondary)).font(Theme.Font.sectionTitle).lineLimit(1)`. Otherwise the existing `Text`, unchanged. `lineLimit(1)` keeps rowH honest.

## 6. Chrome

| Behaviour | Spec |
|---|---|
| Menu, row > 0 | `StripPager.pageToTop()`: programmatic target = rows[0] (1.5 s guard), `page(to:)`, `swap.noteFocusActivity()`, `requestRowFocus(rows[0], itemId: memory[rows[0]], reason: "menu")` with the rungs in §3.3 |
| Menu, row 0 | `atTopExit`: in sidebar mode `{ guard !sidebarChrome.isFocusedChrome else { return }; sidebarChrome.requestReveal() }` (HomeView `:2922` rule); in tabs mode nil, so the system default applies (focus to the tab bar, then exit). P4 swaps in the rail reveal |
| Handler | `.onExitCommand(perform: atTop ? atTopExit : { pageToTop() })` on the strip |
| Up from row 0 | no code: the stage has no focusable view, so the engine goes to the tab bar (sidebar mode: `moveFail up`, or the S1 hidden-bar redirect) |
| Tab bar | `TabBarContentScrollLinkAttacher(pinnedContainer: false)` in the LazyVStack background (`TabBarContentScrollLink.swift:146`, as the spike). Row 0 rests at offset 0 (bar shown); row k ≥ 1 rests at k·P ≥ 388 pt, more than the 68 pt bar (fully hidden). a2 rests exactly on multiples of P, so the bar is never half shown at rest. T1's legs are inert here (no settle corrector) |
| `isScrolledDown` | written from `onRowChange`: `isScrolledDown = index > 0`, only when it changes. `reportsScrollToTabBar(tab: "Home")` stays on the strip without the binding (TabBarStateProbe and the sidebar chrome's per-tab state keep working). Its hysteresis (hide > 300, show < 160) agrees at rest because P ≥ 388 |
| Rail (P4) | `contentGated` → `.disabled(contentGated)` on the StripPager; the restore notification in §3.3; `leadingChromeInset`; `onRowChange` drives Hide While Browsing |

## 7. Trailers

**Background** (`trailer_playback_location == "hero"`, shown as "Background"). `@StateObject bgTrailer = InlineTrailerCardModel()` (`InlineTrailerCard.swift:365`, `hostsTile = false`), `restSource = .custom(stripSignal)`.

- **Arm:** on `swap.output.restingKey` changing to non-nil → `bgTrailer.reset(); bgTrailer.focusChanged(true, item: shown.item)`. This needs `backgroundTrailerMode`, `systemVideoAutoplayEnabled` (mirrored as HomeView does, `:144`/`:1130`), `scenePhase == .active`, `!cover.pushed && !cover.resume && !homeSurfaceCovered`, `!contentGated`, and the shown item not a folder (`isCollectionHero`).
- **Delay:** M4's dwell applies unchanged (`TrailerStartGate.step`): Automatic = strip rest + 1 s (first start ≈ press + 1.8 s on a Down, plus resolve). A fixed N counts from the stage settle, not the press.
- **Tear down** (`reset()`) on: any `noteFocusActivity`/`notePage` (restingKey → nil), any cover, scenePhase change, mode off, `contentGated`.
- **Render:** in `StageArtLayer`, `TrailerHeroPlayer(urlString:, onFailure: bgTrailer.playbackFailed, zoomKey: TrailerResolutionCache.key(type:id:), loops: false, onPlaybackEnded: bgTrailer.playbackFinished, surfaceTag: "stage-bg")`, `.transition(.asymmetric(insertion: .opacity, removal: .identity))`, under the art mask and the text. Muted through `HeroTrailerAudioState` (default muted). Play/Pause on the focused card toggles it through `CatalogRowView.muteToggle`, because the hero model claims the coordinator with the card's own key (the `rowPlayingKey` doc, `BrowseComponents:4962`).
- Log `[TrailerPipeline] trailerLocation stage=bg|row` once on mount and on change.

**In Row** (`"poster"`). Rows get `trailerPlaysInHero = false` and `rowRestSource = .custom(stripSignal)`, so M3's gate holds the morph until `!restPending && sinceMotion ≥ 0.12`, i.e. after the strip settles. The morph widens the card only (`InlineTrailerCard` keeps `artworkHeight` constant; its morph scroll is horizontal-only, so it can't move the strip). The R1 ring stays inside the card. W2-A verifies this and adds no code unless the test fails.

## 8. Probes and launch arguments

| Arg | Effect |
|---|---|
| `-home_layout classic\|stage` | §1.4 |
| `-debug.homeScrollProbe YES` (`HomeGeometryProbe.enabled`, `BrowseComponents:107`) | arms `StageStripProbe` |
| `-debug.stripPageSeconds 0.3…1.0` | page animation length (default 0.5) |
| `-debug.stripTopFade 0` | spike hard clip (§3.4) |
| `-debug.stripFocusMemory off` | no `.defaultFocus` (§3.3 fallback) |
| `-debug.tabBarStateProbe YES`, `-debug.collectionFrameProbe YES` | existing; unchanged |

All of these are launch-latched statics in `StageStripTuning` and not `#if DEBUG`, so Christian's device pass can set them on the Debug/Release binary, the same house rule as `TabBarRestFix`.

`Screens/Home/StageStripProbe.swift` ports the spike's `StageSpikeProbe` + `StageSpikeMarker` verbatim (CADisplayLink, presentation-layer y, segments ≥ 0.25 pt ended by 6 still frames, press windows, `focus →`/`moveFail` lines), renamed, with prefix `[StageStrip]`. It adds:
- `geometry rowH= P= H= stage= logo= synL= fits= font=`, logged on change;
- `swap phase=out|in|cancel|idle id= sinceAct=<ms> pageEnd=<ms>`, from the driver;
- `restore row= item= rung= landed=`;
- `trailer arm|reset|start key= via=` (W2-A).

DEBUG leaf labels (each observes only its own source):
- `debug_stage phase= shown= pending= swaps= maxLive= stageH= stripH= P= fits= rest=` (append-only);
- `debug_strip <last PRESS summary> row= key= foc=<rowKey>/<itemId> atTop=`.

## 9. Ownership and tests

### 9.1 W1-A (Opus): the stage and the strip

- **New** (`Screens/Home/`): `HomeLayout.swift`, `HomeRowPreviews.swift`, `StripGeometry.swift`, `StripMotionSignal.swift`, `StripFocusMemory.swift`, `StripPager.swift`, `StageSwapModel.swift` (core + driver + payload), `StageCopy.swift` (plain copy), `StageView.swift` (StageArtLayer, StageTextBlock, StageScrim, debug labels), `StageStripHome.swift`, `StageStripProbe.swift`.
- **Edits:**
  - `HomeView.swift`: E1–E6, plus `ContinueWatchingRow`'s remount `.onAppear`;
  - `PinnedRowUpFallback.swift`: `itemId`, `target(for:…)`, memory env, `.defaultFocus`;
  - `BrowseComponents.swift`: `CatalogRowView`'s remount `.onAppear` only.
- **Tests (NuvioTVTests):** `StripGeometryTests`, `StageSwapModelTests`, `StripFocusMemoryTests`, `StripMotionSignalTests`.
- Leaves a `Color.clear` layer 0 for W1-B's wash; the main session wires it at the W1 merge.

### 9.2 W2-A (Opus): motion polish and trailers

- **Edits:**
  - `StageCopy.swift`: CW-aware copy;
  - `StageStripHome.swift` + `StageView.swift`: background trailer, `trailerLocation` log, trailer probe lines;
  - `BrowseComponents.swift`: `rowHeadingShowsAddon` env + `CatalogRowView` heading branch.
- **Device tuning:** `pageSeconds` (record P/press numbers in OUTCOME).
- **Optional, only if device logs show resolver fetch churn on held Down:** defer `resolver.present` while `stripSignal.restPending`.
- **Tests:** `StageCopyTests`, plus the In Row assertions in testS09.
- W1-B, W1-C and W2-B never touch these files; HomeView edits are W1-A only.

### 9.3 Unit tests (concrete)

**`StripGeometryTests`**
- The 16-row table in §2: rowH, P, H, stage, logo, lines, inputs titleH 38 / caption 23 / synLH 30.
- Medium/on/on == spike (515.5, 559.5, 520.5).
- Open Sans (38.84 / 31.32): Medium → 516.5 / 561.5 / 518.5; Large → 590 / 635 / 445, 4 lines.
- Landscape rows at Medium → rowH 443.
- 164 dp fits (stage 420.5); 165 dp → `fits == false`, stage 420, stripHeight 660.
- `pixelCeil(496.452) == 496.5`; `peek(38.84) == 45`.
- `pageOpacity`: minY 0 → 1.0 exactly; P → 0.6; −0.6P → 0.02; −P → 0.02; 0.5P → 0.8.

**`StageSwapModelTests`** (pure core, explicit times; every test asserts I1–I3)
- seed (no fade, swaps 0);
- cases A–H from §4.4, each asserting phase / opacity / fade / swaps at every listed time;
- same-identity sharpen while idle (shown replaced, no phase change, swaps unchanged);
- new identity during fadingIn (pausing at the fade end, gate respected);
- page extended while pausing (deadline follows);
- `present(nil)` clears;
- `resting` set only at/after the gate and cleared by activity.
- **Driver test** (fake schedule): one wake outstanding at a time; outputs written in an animation-free transaction (`Transaction().animation == nil` probe).

**`StripFocusMemoryTests`**
- `target(for:)` table: Classic request → firstId; Stage `itemId` wins; no `itemId` → remembered → first; another row → nil.
- `remember` / `itemId` / `prune`.

**`StripMotionSignalTests`**
- `restPending` across `pageStarted(0.5)` with the injected clock.

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
| `testS01_DownPagesOneRow` | Down ×4, 2 s apart, then Up ×4 | each `debug_strip` PRESS: `moves=1 afterRest=0 residual=0.0` (±0.5); `row=` steps by exactly 1 |
| `testS02_NextHeadingPeeks` | rest at row 0 and row 1 | `debug_strip`/`debug_stage` P and H from the label; the next row's heading element `minY` in [stageH + P, 1080]; no card of row i+1 with `minY < 1080` |
| `testS03_NeverTwoTitles` | Right ×6 fast, Down ×3, wait 2 s | `debug_stage maxLive=1`, `phase=idle`; `swaps` ≤ number of rests (fast hops add none) |
| `testS04_StageFrameConstant` | read the `stage_text_slot` frame, Right ×3 with rests | frame identical (±0.5) before, during and after swaps; `stageH=` unchanged |
| `testS05_UpFromRow0ToTabBar` | at row 0, Up | a tab bar button is focused; `debug_strip atTop=1` |
| `testS06_TabBarHiddenRow1ShownRow0` (Stage test75) | `-debug.tabBarStateProbe YES`; Down, rest; Up, rest | row 1: bar fully hidden; row 0: shown at y 0; never `st=part` at rest |
| `testS07_FocusMemory` | row 0 Right ×3, Down, Up; Down to an unvisited row | back on row 0 card 3 (`foc=`); the unvisited row lands on card 0 (G-F) |
| `testS08_MenuRow3ToRow0ThenChrome` | Down ×3, Menu; Menu again with `-sidebar_style sidebar` | `row=0` and `foc=` = row 0's remembered card; second Menu → `sidebar_state` present |
| `testS09_InRowMorphAfterRest` (Stage test01/41) | `-inline_trailers_enabled YES -trailer_playback_location poster`; Down, wait | `debug_trailerMorph event=gate host=card … src=custom` with start ≥ page end + 1.0; skips on extraction `LOGIN_REQUIRED` like test51 |
| `testS10_BackgroundTrailer` (Stage test37) | `…location hero`; rest, then Right | gate `host=hero` after `resting`; `event=reset` within 0.1 s of the Right; skips on extraction |
| `testS11_HoldMenuOnStripPoster` (Stage test71) | long-press Select on a strip poster | the hold-menu items appear |
| `testS12_ClassicArg` | `-home_layout classic` | no `debug_stage`; `debug_hero mode=` present |
| `testS13_LargeGeometry` | a Large fixture (W3 seeds it, §Wave 0 note) | `debug_stage fits=1 stageH=447 P=589` |

Every Classic leg in W3's list gains `-home_layout classic` (FA87 defaults to Stage once this lands).

## 10. Risks and open questions

1. **`.defaultFocus(priority: .userInitiated)` inside a lazy, focus-sectioned row is unproven here.** Gate G-F decides. The fallback is geometric Down/Up, as measured in the spike, with memory only for Menu and rail. Ship the fallback if G-F fails? Christian.
2. **Opacity-floor rows (0.02) must stay focusable for Up.** G-F checks it; the fallback is the spike's hard clip (`-debug.stripTopFade 0`).
3. **The peek heading sits in the bottom 60 pt title-safe band.** A TV that overscans crops it. Accept as a hint, or lift the strip by a gutter (costs stage height)? Christian.
4. **D2 costs stage height that may be unused:** 11 pt with Hide Titles, ~95 pt with landscape catalog rows, even when Home has no collection rows. The alternative is a data-dependent height, which jumps once at load.
5. **Down swaps at 0.50 s, not 0.45 s,** because the gate waits for the glide (D3). If Steven reads that as late, drop the page term and accept a 50 ms overlap.
6. **Held Down still commits and resolves intermediate titles** (TMDB gap-fill, art fetch), the same as Classic. W2-A measures it before adding the defer.
7. **`HomeViewModel`'s hero fan-out keeps fetching in Stage** while Show Hero is on. P2/settings decide whether Stage forces it off.

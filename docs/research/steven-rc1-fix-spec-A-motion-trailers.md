# Spec P-A: motion and trailers (M3, R2, R1, M4/FEAT-52, M5, B2), revision r2

Batch: Steven's beta.19-rc1 verdict fix batch (`docs/steven-beta19-rc1-verdict-batch-plan-2026-10-02.md`, APPROVED 2026-10-03).
Code base: clone `~/Claude/Projects/NuvioMobile-steven-rc1`, branch `claude/steven-beta19-rc1-verdict` at `284fd764`. Every `file:line` below is at `284fd764`, under `iosApp/` unless noted.

**r2 (2026-10-03):** revised against `docs/research/steven-rc1-fix-spec-critique.md`. The per-finding decisions are in §11.
- Agent names and waves follow the critique's merged wave plan (§9).
- Christian's answers are folded in (§10):
  - fixed delays count from focus, never before rest;
  - TMDB title logos move to `original` (spec B owns that change).

Companion spec: P-B (`docs/research/steven-rc1-fix-spec-B-images-rows-detail.md`, owns I1, F, C, T1, A, Detail items, P overlay copy, and every `SettingsDescriptions.swift` edit). The next batch builds on this one (`docs/home-stage-strip-plan-2026-10-03.md`) and reuses two pieces written here:
- the trailer rest gate (§1, `RowRestSource`);
- the text swap model (§5, `TextSwapModel`).

Approved calls this spec follows:
- Trailer Start Delay default is **Automatic (rest + 1 s)**.
- M2 and N1 are dropped; Classic Home keeps today's settle and slide motion.
- M5 is kept.

---

## 0. House rules every executor follows

- **No per-frame state writes.** No `@State` writes per frame during scroll (BUG-19/41). Per-frame scroll data goes into a reference box held in `@State` (the `SettleWorkBox` / `TitleTrackingCache` pattern, `BrowseComponents.swift:4635`, `:4651`) or into a static.
- **No app-root `.tint`.**
- **Debug knobs.** Launch-arg debug knobs are read once from `UserDefaults.standard` into a `static let` (`-debug.x YES`). DEBUG-only knobs sit behind `#if DEBUG`.
- **Comments** match the file around them: dense, tagged with the item, in the house form `beta.19-rc1 verdict (M3): …`. The main session fills in tracker IDs (BUG-130+, FEAT-52).
- **Swift settings.** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, Swift 5 mode, tvOS 26 deployment target.
  - New pure helpers that run off-main are `nonisolated`.
  - `NuvioTV/` and `NuvioTVTests/` are synchronized folders, so new files need no `project.pbxproj` edit.
- **Strings.** English in code (`String(localized:)` / `LocalizedStringResource`). **Never edit `Localizable.xcstrings`.**
- **Roles.** Agents edit; the main session builds, tests and commits.

---

## 1. M3: trailer morph versus settle

### 1.1 Root cause, confirmed in code

1. **The dwell is a wall clock from focus, blind to row motion.**
   - `InlineTrailerCardModel.startDwell` sleeps `dwellSeconds = 1.0` (`InlineTrailerCard.swift:377`, `:463-478`) and then calls `expand`. Nothing asks whether the rows are still moving.
   - Steven's video measures the engine's row slide at about 1.15 s to settle, so on a Down press the morph starts while the row is still sliding.
2. **The morph's scrolls bypass the settle corrector.**
   - `CatalogRowView.expansionChanged` (`BrowseComponents.swift:5085-5109`) calls `proxy.scrollTo` twice, at 0 ms and 450 ms (`scrollToExpanded`, `:5111-5119`), with no `PinnedRowSettle.noteExternalScroll` (`:3027`).
   - The anchor is `nil` (minimal scroll) for most cards and `.trailing` = `UnitPoint(x: 1, y: 0.5)` for the last card (`:5093`).
   - The scrolled view is the card's `.id(item.id)` Group, whose frame includes the 88 pt transparent top reach (`:4919`, `:4932`). Pinned rows rest with the reach top about 7–10 pt above the viewport.
   - **If** the row's `ScrollViewProxy` propagates to the enclosing vertical rows `ScrollView`, a "minimal" scroll pulls the rows vertically, and the `.trailing` anchor asks for vertical centring. Any such sample re-arms the corrector (`noteScroll`, `:3152`).
   - **Unverified half:** whether the spill happens on tvOS 26. Its signature is a `[HomeScrollProbe] settle … armSrc=scroll` line 0.05–0.5 s after a `[CatalogGridProbe] expansionChanged fire` line, with no remote input. The fix makes it moot.
3. **Every row re-renders on every trailer claim and release (the BUG-126 class).**
   - `InlineTrailerCoordinator` is an `ObservableObject` with `@Published playingKey` (`InlineTrailerCard.swift:186`, `:194`), written on every claim and release (`:237`, `:249`).
   - Every mounted `CatalogRowView` observes it (`BrowseComponents.swift:4784`), only to build `muteToggle(for:)` (`:5124-5129`).
   - That toggle has TWO producers that must both keep working:
     - the card's own model, when the card plays;
     - **the HERO model in Trailer Location: Hero**. There, every card is `InlineTrailerCard(enabled: false)` (`inlineTrailersActive`, `:4800-4812`), and the hero's `claimPlayback` publishes the focused card's own key (`InlineTrailerCard.swift:1002`; the path is described at `HomeView.swift:2223-2229`).
   - `HomeView.heroTrailerHolding` reads the key as a plain value on the carousel tick (`HomeView.swift:561`).

### 1.2 Design overview

- A new file holds the reusable rest gate. The card model waits on it instead of the 1 s timer.
- The row's morph scroll is horizontal-only and is dropped when the tile already fits.
- The coordinator publishes the key through a subject. Each row subscribes with `.onReceive` and writes its own `@State` only when the key belongs to one of its items: one producer path for card, hero and Stage background trailers, and only the affected row re-renders.

### 1.3 New file `NuvioTV/Screens/TrailerStartGate.swift` (owner: W1-A)

```swift
// beta.19-rc1 verdict (M3 + M4/FEAT-52): when may a focus-dwelled trailer start?

/// Rows motion stamp for hosts with no settle corrector (Search, classic Home, and the
/// horizontal scroll of every catalog row). Main-actor static, written from
/// `onScrollGeometryChange` actions: a timestamp write, never view state.
enum RowsMotionClock {
    private static var lastMotion: TimeInterval = -.greatestFiniteMagnitude   // systemUptime
    static func stamp(now: TimeInterval = ProcessInfo.processInfo.systemUptime)
    static func secondsSinceMotion(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> TimeInterval
    #if DEBUG
    static func resetForTesting()
    #endif
}

extension View {
    /// Stamps `RowsMotionClock` whenever this scroll view's offset on `axis` moves by more than
    /// 0.5 pt. Attach to a ScrollView. Transform → CGFloat; the action compares old/new and stamps.
    func rowsMotionStamp(_ axis: Axis) -> some View
}

/// What a host publishes so a dwelling trailer knows when the rows are at rest.
/// The Stage & Strip batch feeds `.custom` from its strip's own paging signal.
@MainActor protocol RowRestSignal: AnyObject {
    /// True while a rest decision is still to come (a page or settle animation in flight).
    var restPending: Bool { get }
    /// Seconds since the rows last moved; `.greatestFiniteMagnitude` when they never did.
    var secondsSinceMotion: TimeInterval { get }
}

enum RowRestSource: Equatable {
    /// `RowsMotionClock` only (Search, classic Home, any host that sets nothing).
    case motionClock
    /// Pinned Home: pending = `PinnedRowSettle.isRestPending` (`BrowseComponents.swift:4296`);
    /// sinceMotion = min(`PinnedRowSettle.secondsSinceMotion()` (`:3489`),
    /// `RowsMotionClock.secondsSinceMotion()`). Horizontal row scrolls are not in the settle's clock.
    case pinnedHome
    /// Any other host; `==` compares by `ObjectIdentifier`.
    case custom(RowRestSignal)
    func isAtRest() -> Bool   // TrailerStartGate.isAtRest(sinceMotion:restPending:) over the above
}
// + EnvironmentKey `RowRestSourceKey` (default `.motionClock`) and `EnvironmentValues.rowRestSource`.

/// FEAT-52 "Trailer Start Delay": a device-local `@AppStorage` key, like every Home Screen trailer key.
enum TrailerStartDelay: String, CaseIterable {
    case automatic = "auto"     // rest + 1 s, the default
    case oneSecond = "1"
    case twoSeconds = "2"
    case threeSeconds = "3"
    nonisolated static let storageKey = "trailer_start_delay"
    /// Read once per dwell; missing or unknown → `.automatic`.
    nonisolated static func current(_ defaults: UserDefaults = .standard) -> TrailerStartDelay
    var label: String           // "Automatic" / "1 s" / "2 s" / "3 s" (PlayerSettingsPane.swift:148's "30 s" spelling)
    var fixedSeconds: TimeInterval?   // nil for .automatic
}

/// The pure planner, unit-tested as a table.
nonisolated enum TrailerStartGate {
    static let restQuiet: TimeInterval = 0.12          // = RowStepAB.restThreshold
    static let automaticAfterRest: TimeInterval = 1.0
    static let restCeiling: TimeInterval = 3.0         // focus → start cap; start anyway (via=ceiling)
    static let artPrefetchAfter: TimeInterval = 0.3    // §2.3: tile-art prefetch starts at first rest or here
    static let poll: TimeInterval = 0.05
    static func isAtRest(sinceMotion: TimeInterval, restPending: Bool) -> Bool { !restPending && sinceMotion >= restQuiet }
    enum Step: Equatable { case wait(TimeInterval), start(via: String) }
    /// focusAge: s since focus landed. restAge: s since the current rest began (nil while not at rest).
    /// Automatic: start at rest + 1 s. Fixed N: start at max(focus + N, rest), never before rest
    /// (Christian 2026-10-03: fixed values count from focus).
    static func step(delay: TrailerStartDelay, focusAge: TimeInterval, restAge: TimeInterval?) -> Step
}

#if DEBUG
/// One line per trailer event for the UI legs, rendered by a HomeView LEAF view (§5.6, never by
/// HomeView's body). DEBUG-only, a handful of writes per dwell.
final class InlineTrailerDebugLog: ObservableObject {
    static let shared = InlineTrailerDebugLog()
    @Published private(set) var last = "-"
    private(set) var abortCount = 0
    /// e.g. "event=gate host=card key=movie:tt… delay=auto rest=1.42 start=2.43 via=rest",
    /// "event=reveal|wide|shrink|dissolve|abort style=instant|defer|play|mute muted=0|1 …"
    func note(_ line: String)
}
#endif
```

`step` rules, exactly:
- `restAge == nil`: return `.start(via: "ceiling")` when `focusAge >= restCeiling`, else `.wait(poll)`.
- Automatic: `need = automaticAfterRest - restAge`.
- Fixed N: `need = N - focusAge`.
- Return `need <= 0 ? .start(via: "rest") : .wait(min(need, poll))`.

### 1.4 `InlineTrailerCardModel` changes (`InlineTrailerCard.swift`, W1-A)

**New stored properties.**
- `var restSource: RowRestSource = .motionClock`.
- `var hostsTile = false`. The catalog card sets it to true in `.onAppear`, BEFORE any `focusChanged(true…)` (`:1193-1196`). The hero model (`HomeView.swift:136`) leaves it false.
- `#if DEBUG` gate telemetry: `gateFocusAt`, `gateRestAt`, `gateStartAt`, `gateVia`, `gateDelay`.

**The dwell.** `dwellSeconds` (`:377`) is removed. `startDwell` (`:463-478`) keeps the generation and cancel discipline, and its task body becomes the gate loop:

```swift
let delay = TrailerStartDelay.current()
let focusAt = ProcessInfo.processInfo.systemUptime
var restBegan: TimeInterval?
loop: while true {
    let now = ProcessInfo.processInfo.systemUptime
    if restSource.isAtRest() { restBegan = restBegan ?? now } else { restBegan = nil }
    // §2.3 (critique #6): the tile-art prefetch starts at the first at-rest reading or 0.3 s into the dwell.
    if hostsTile, artTask == nil, restBegan != nil || now - focusAt >= TrailerStartGate.artPrefetchAfter { startArtPrefetch() }
    switch TrailerStartGate.step(delay: delay, focusAge: now - focusAt, restAge: restBegan.map { now - $0 }) {
    case .start(let via): /* telemetry; log; DEBUG note "event=gate …" */ break loop
    case .wait(let s): try? await Task.sleep(nanoseconds: UInt64(s * 1e9))
    }
    guard !Task.isCancelled, generation == generationAtStart else { return }
}
await expand(item)   // expand becomes async (the art wait in §2.3 needs it)
```

- Probe line, when `TrailerProbe.enabled`: `[TrailerPipeline] gate key=%@ delay=%@ focusToRest=%.2f restToStart=%.2f via=%@`.
- `restBegan` resets if motion returns before the start (a corrector nudge or a relayout), bounded by `restCeiling`.

### 1.5 Coordinator: publish through a subject, no `ObservableObject` (`InlineTrailerCard.swift:186-251`, W1-A)

- `InlineTrailerCoordinator` drops `ObservableObject`.
- Add `let playingKeySubject = CurrentValueSubject<String?, Never>(nil)`. `var playingKey: String? { playingKeySubject.value }` keeps `HomeView.swift:561` source-compatible.
- `claimPlayback` and `releasePlayback` send through the subject. The key semantics are unchanged: the card's own key, OR the hero's key, which in Trailer Location: Hero is the focused card's key.
- Doc comment: who produces the key (card model, hero model, the Stage batch's background trailer); who consumes it (each row via `.onReceive`, plus the carousel tick's plain read); and why it is not `@Published`/`ObservableObject` (BUG-126: one claim re-rendered every row).

### 1.6 `CatalogRowView` changes (`BrowseComponents.swift:4750-5130`, W1-A)

1. **Mute ownership (critique #1).**
   - Delete `@ObservedObject private var trailerCoordinator` (`:4784`). Add `@State private var rowPlayingKey: String?`.
   - Attach to the row's outer view, next to `.onChange(of: focusedItemId)` (`:5053`):

     ```swift
     .onReceive(InlineTrailerCoordinator.shared.playingKeySubject.removeDuplicates()) { key in
         let mine = Self.rowPlayingKey(key, itemKeys: section.items.lazy.map { TrailerResolutionCache.key(type: $0.type, id: $0.id) })
         if rowPlayingKey != mine { rowPlayingKey = mine }
     }
     ```

     A row that owns neither the old nor the new key writes nothing and does not re-render; the `onReceive` action alone does not invalidate the view. `CurrentValueSubject` delivers its current value on subscription, so a row mounting mid-playback syncs at once.
   - `nonisolated static func rowPlayingKey(_ key: String?, itemKeys: some Sequence<String>) -> String?` returns `key` when the sequence contains it, else nil. It is pure and unit-tested.
   - `muteToggle(for:)` (`:5124-5129`): `guard focusedItemId == item.id, rowPlayingKey == TrailerResolutionCache.key(type: item.type, id: item.id) else { return nil }`.
     - Under `#if DEBUG` the returned closure also calls `InlineTrailerDebugLog.shared.note("event=mute muted=… key=…")` after toggling (read the new value from `HeroTrailerAudioState.shared.muted`, the way `TrailerHeroPlayerView.swift:304` does).
     - This works unchanged for card playback and for Trailer Location: Hero (cards `enabled: false`).
2. **`card(for:proxy:)`** (`:5066-5070`) passes `onExpansionChange:` by label. It now fires on the **wide** edge (§2.3).
3. **Morph scroll, horizontal-only, dropped when it fits.**
   - Add `@State private var hScroll = RowHScrollBox()`: a `final class` with `var sample: RowHScrollSample?` holding `offsetX`, `viewportWidth`, `contentWidth` and `insetLeading`.
   - Feed it from `.onScrollGeometryChange(for: RowHScrollSample.self)` on the row's horizontal `ScrollView`, after `.scrollClipDisabled()` (`:5009`).
     - `offsetX` is `geo.visibleRect.minX`, the visible region in content coordinates, so content insets are accounted for (critique #24). `insetLeading = geo.contentInsets.leading` is kept for the probe.
     - The action writes the box. It calls `RowsMotionClock.stamp()` only when `offsetX` moved by more than 0.5 pt, not on content-width growth during a morph.
   - Add `@State private var rowPosition = ScrollPosition()` + `.scrollPosition($rowPosition)` on the same horizontal `ScrollView`.
   - Rewrite `expansionChanged(itemId:expanded:proxy:)` (`:5085-5109`):
     - return when `!expanded` or `posterStyle.landscapeCatalogRows`;
     - `index = section.items.firstIndex { $0.id == itemId }`;
     - `target = RowMorphScroll.target(...)`; if nil, do nothing (**the "dropped when already in view" half**);
     - else `withAnimation(InlineTrailerCardModel.morphAnimation) { rowPosition.scrollTo(x: target) }` (no animation under Reduce Motion);
     - keep the H3 task (`expansionScrollTask`, `:4853`) for one verification pass at `morphAnimation + 0.05` s, using the live sample (content has grown).
   - A horizontal `ScrollPosition` cannot move the vertical rows, so `PinnedRowSettle` sees nothing.
4. **Fallback, decided in the simulator by W1-A.** Take it if either check fails:
   - `.scrollPosition($rowPosition)` writes the binding per frame during focus-driven horizontal scrolling (one temporary `let _ = Self._printChanges()` in `CatalogRowView.body`, removed before handing back);
   - `scrollTo(x:)` lands short.

   The fallback is `proxy.scrollTo(itemId, anchor: nil)` once at morph end, only when `RowMorphScroll.target` reports an overflow, preceded by `PinnedRowSettle.noteExternalScroll(reason: "trailer-morph")`. Record which path shipped in the comment.
5. **Pure helper**, in `TrailerStartGate.swift` or beside `CatalogRowView`:

   ```swift
   nonisolated enum RowMorphScroll {
       /// Content-x offset that brings an expanding card's tile fully inside the row viewport, or nil
       /// when it fits. Card i's leading edge in content coordinates is insetLeading + i × (restingWidth + gap).
       static func target(index: Int, restingWidth: CGFloat, expandedWidth: CGFloat, gap: CGFloat,
                          visibleMinX: CGFloat, viewportWidth: CGFloat, contentWidth: CGFloat,
                          insetLeading: CGFloat, contentAlreadyGrown: Bool) -> CGFloat?
   }
   ```

   Rules:
   - nil when `expandedWidth <= restingWidth`, or when the tile's trailing edge ≤ `visibleMinX + viewportWidth + 0.5`.
   - Otherwise clamp `trailing − viewportWidth` to `[0, grownContent − viewportWidth]`, where `grownContent = contentWidth + (contentAlreadyGrown ? 0 : expandedWidth − restingWidth)`.

   `InlineTrailerCard.expandedWidth(_ style: PosterStyle) -> CGFloat` is a new static (`style.height * 16 / 9`, the expression at `InlineTrailerCard.swift:1424`). `artworkWidth` uses it.

### 1.7 Host hooks

- **SearchView** (`SearchView.swift:28`, W1-A): `.rowsMotionStamp(.vertical)` on the vertical `ScrollView`.
- **HomeView** (W2-E). Three anchored edits:
  1. In `rowsScroll`, next to `.environment(\.trailerPlaysInHero, …)` (`HomeView.swift:1474`): `.environment(\.rowRestSource, settleReveal ? .pinnedHome : .motionClock)`. Use `settleReveal`, the container constant (`:1234-1242`), never `pinned`.
  2. Unconditionally, next to `.scrollClipDisabled(!pinned)` (`:1507`): `.rowsMotionStamp(.vertical)`.
  3. In `.onAppear` (`:1163`) and `.onChange(of: heroContainerPinned)`: `heroTrailerModel.restSource = heroContainerPinned ? .pinnedHome : .motionClock`.
- **InlineTrailerCard** reads `@Environment(\.rowRestSource)` and assigns `model.restSource` in `.onAppear` and before every `model.focusChanged(true, …)` (`:1190`, `:1195`).

### 1.8 Contract for the Stage & Strip batch

- **In Row trailers** inside the paging strip set `.environment(\.rowRestSource, .custom(stripSignal))`. `restPending` is true while the strip's `scrollPosition` page animation is in flight; `secondsSinceMotion` counts from its end.
- **Background (stage) trailers** set `heroTrailerModel.restSource` the same way. Their Play/Pause mute works through §1.6.1 with no change: the background trailer's `claimPlayback` publishes the focused card's key, and that card's row matches it.
- **`TrailerStartDelay` is shared:** "Automatic" there means "strip at rest + 1 s".
- **Stage P1 brief note (critique #30):** `StageSwapModel` should wrap `TextSwapModel(timing: .stage)` (§5.2) and drive the stage ART from `shown`. In Stage the art swaps at the swap moment, unlike Classic, where the resolver swaps art and `TextSwapModel` only phases the text.

### 1.9 Edge cases

| Case | Behaviour |
|---|---|
| Horizontal step in a row | The row's scroll stamps `RowsMotionClock`; rest comes about 0.12 s after the focus scroll ends. |
| Up/Down into a pinned row | Rest needs the settle decision plus 0.12 s of quiet, typically 1.35–1.5 s after the press. Automatic starts about 2.4–2.5 s; "1 s" starts about 1.4 s. |
| Corrector nudge after the first rest | `restBegan` resets. |
| Phantom-armed corrector (rc13 class) | `restCeiling` 3 s starts anyway (`via=ceiling`). |
| Hero carousel autoplay | Nothing moves, so the trailer starts at 1 s (Automatic): today's timing. |
| Trailer Location: Hero, Play/Pause | §1.6.1: the hero's key reaches the focused card's row; mute works as today. |
| Same title in two rows | Both rows set `rowPlayingKey`. Only the row holding focus attaches the handler (`focusedItemId` test). |
| Reduce Motion | The gate is unchanged; the morph is instant (§2). |

### 1.10 Unit tests (new `NuvioTVTests/TrailerStartGateTests.swift`, W1-A)

- `testAutomaticWaitsForRestThenOneSecond`:
  - `step(.automatic, 0.5, nil) == .wait(0.05)`;
  - `step(.automatic, 1.6, 0.4) == .wait(0.05)`;
  - `step(.automatic, 2.6, 1.0) == .start(via: "rest")`.
- `testFixedDelayCountsFromFocusButNeverBeforeRest`:
  - `step(.twoSeconds, 2.5, nil)` is `.wait`;
  - `step(.twoSeconds, 2.5, 0) == .start(via: "rest")`;
  - `step(.oneSecond, 0.6, 0.3) == .wait(0.05)`;
  - `step(.threeSeconds, 2.98, 1.5) == .wait(0.02)` (± 1e-9).
- `testCeilingStartsWithoutRest`: every delay at `(3.0, nil)` returns `.start(via: "ceiling")`.
- `testIsAtRest`: `(0.2,false)` true; `(0.05,false)` false; `(10,true)` false; `(.greatestFiniteMagnitude,false)` true.
- `testDelayCurrentFallsBack`: scratch `UserDefaults(suiteName:)`. Missing → `.automatic`; `"bogus"` → `.automatic`; `"2"` → `.twoSeconds`.
- `testRestSourceCustomEquality`.
- `testRowMorphScroll`:
  - card 2 of 10 fits → nil;
  - card 5 overflows → exact value;
  - last card clamps to the grown content;
  - `expandedWidth == restingWidth` → nil;
  - **`insetLeading = 60` shifts the overflow decision by 60** (critique #24);
  - `contentAlreadyGrown: true` uses the live width.
- `testRowPlayingKeyFilter`:
  - a key in the row → the key;
  - a key not in the row → nil;
  - nil → nil;
  - a key present twice → the key.
- `testCoordinatorSubject`: `claimPlayback` sends the key; `releasePlayback` sends nil; a release by a non-owner sends nothing.

### 1.11 UI legs and proof

The UI legs live in the new `NuvioTVUITests/TrailerMotionUITests.swift` (W4-G, §8).
- **`test85TrailerStartsAfterRest`.**
  - Launch with `-inline_trailers_enabled YES -debug.trailerProbe YES -debug.trailerSmokeVideoId rNZ0xKaCdus -home_upcoming_row_enabled NO -trailer_playback_location poster`.
  - Down ×4, then poll `debug_trailerTile`.
  - Assert `via=rest` and `gateStart − gateRest ≥ 0.95`.
- **`test85BHeroLocationMuteToggle`** (critique #1).
  - Use test37's hero-leg arguments (`NuvioTVUITests.swift:3487-3500`): `-trailer_playback_location hero -hero_nuvio_style YES` with autoplay off.
  - Down ×4; wait for `debug_trailerMorph` to report `event=play host=hero`; press Play/Pause.
  - Assert an `event=mute` line within 2 s. Press again and assert the `muted=` value flips.
  - XCTSkip if `event=play` never arrives (extraction unavailable on this host).
- **Vertical spill, before and after** (W1-A, simulator): the same walk with `-debug.homeScrollProbe YES -debug.catalogGridProbe YES`, grepping for the §1.1.2 signature. After the fix: no `armSrc=scroll` settle within 0.5 s of `expansionChanged`.
- **Re-render check** (W1-A, simulator, sanity): with one temporary `_printChanges()`, a claim or release re-renders only the owning row.
- **Device:** "the morph starts after the row stops" on Steven's settings, in the Test profile.
  - Probes: `-debug.homeScrollProbe YES -debug.pinnedRowSettleProbe YES -debug.trailerProbe YES --console`.
  - Read `gate … via=` against `settle decided`.
  - Also test Play/Pause mute in both trailer locations.

---

## 2. R2: morph-abort glitches

### 2.1 Each glitch traced to code

| Triage | Mechanism at `284fd764` |
|---|---|
| **(a)** 2:10.6 GIGN: focus leaves as the morph starts; #2 pushed right; ghost logo across the gap for 0.2 s | `reset()` (`:496-510`) → `setPhase(.idle)` inside `withAnimation(morphAnimation)` (`:454-461`). The width animates back from its partial value, so #2 slides back. The tile fades from its partial opacity (`:1220`). The FEAT-18 in-tile logo (`:1313-1319`, Hide Labels on) leaves via `.transition(.opacity)` under the same 0.35 s animation: the ghost. |
| **(b)** 0:53.5: one empty dark frame at morph start | The tile art is `CachedAsyncImage` inserted `if model.isExpanded` (`:1252-1260`). `CachedImageLoader.load` runs in `.onAppear` (`CachedAsyncImage.swift:94`), so even a cached image draws `ShimmerView` (`:91`) on the first frame. The bar-crop zoom animates 1 → measured over 0.25 s (`:112-117`) when not memoized. |
| **(c)** 0:54.8: empty slot for 1–2 frames on collapse | The base poster animates 0 → 1 (`:1177`) while the art leaves through the `if model.isExpanded` removal and the video goes at once (`.identity`, `:1293`). In the first frames nothing is opaque. |
| **(d)** 1:31.2: poster and landscape side by side, "72 HEURES" doubled | One 0.35 s transaction runs the width growth, the base fade-out and the tile fade-in (`.animation(…, value: model.isExpanded)`, `:1189`). Mid-morph, a translucent tile wider than the poster sits over a half-visible poster. |
| **(e)** 4:34.7 Verity: morph starts and aborts in 0.4 s, focus unchanged | Cache-hit `.resolved` → `expand` morphs and plays at once (`:618-632`). The loopback listener is dead (§6), so AVPlayer fails fast → `collapse()` mid-expansion, then `.transient` (45 s) suppresses a refocus. Primary fix: B2. R2 adds the deferred collapse; B2's call sites add `servableURL` (§6.3). |

### 2.2 Choreography (replaces the single 0.35 s cross-fade)

| Stage | Visual | Transaction |
|---|---|---|
| `.none` | poster only; tile not drawn | — |
| expand 1: `.none → .reveal` | in-place dissolve **at the poster's width**: base 1 → 0, tile 0 → 1; art already decoded | `withAnimation(.easeOut(duration: revealDuration))`, `revealDuration = 0.12` (0 = cut; tune on device) |
| expand 2: `.reveal → .wide` | width grows to 16:9; neighbours slide; row scroll if needed | `withAnimation(morphAnimation)` (0.35 s), scheduled `revealDuration` later, generation-guarded |
| collapse 1: `.wide → .reveal` | width shrinks; tile opaque; video removed at once (art underneath) | `morphAnimation` |
| collapse 2: `.reveal → .none` | in-place dissolve tile → poster | `revealDuration` |
| abort | everything to `.none` in one frame | `var t = Transaction(animation: nil); t.disablesAnimations = true; withTransaction(t) { … }` |

Why this order:
- **(d):** the tile never grows while translucent.
- **(c):** the poster is drawn under an opaque tile in every collapse frame.
- **Lift:** ring mode's `CardArtworkFocusLift` scales the poster's art, not the tile (`PosterCard.swift:760-800`). Shrinking before the dissolve means a lifted poster never peeks out from under a tile narrower than itself.

**Abort rule.** `reset()` (focus lost or `onDisappear`) takes the abort path when `morphStage == .reveal`, or when `morphStage == .wide` and `now − stageChangedAt < abortWindowIntoWide` (0.2 s). Otherwise it runs the animated two-step collapse. Device-tune item (critique #26): read the `[CatalogGridProbe]` scroll lines around `style=instant`, and lower `abortWindowIntoWide` if the row shows a second correcting motion after an abort.

**Deferred collapse.** `collapse()` from `playbackFailed` / `playbackFinished` / `abandonExpansion` during an expansion in flight (`.reveal`, or `.wide` younger than `morphAnimation`) waits for the remainder, then runs the animated collapse. It is generation-guarded; a focus loss in between wins and aborts instead.

### 2.3 Model API (`InlineTrailerCardModel`, W1-A)

```swift
enum MorphStage: Equatable { case none, reveal, wide }
@Published private(set) var morphStage: MorphStage = .none
/// Decoded tile art, set BEFORE `.reveal`, cleared in the completion of the final collapse
/// transaction (`withAnimation(_:completionCriteria: .logicallyComplete, _:completion:)`),
/// generation-guarded so a re-expansion during the collapse keeps it.
@Published private(set) var tileArt: InlineTileArt?
var layoutExpanded: Bool { morphStage == .wide }
var tileVisible: Bool { morphStage != .none }
private var stageChangedAt: TimeInterval?
static let revealDuration: TimeInterval = 0.12
static let abortWindowIntoWide: TimeInterval = 0.2
static let artAwaitDeadline: TimeInterval = 1.0      // beginMorph's await, NOT a request timeout
/// Set by the catalog card in `.onAppear` (with `hostsTile = true`); nil on the hero model.
var tileArtSource: (primary: String?, fallback: String?)?
private var artTask: Task<InlineTileArt?, Never>?
```

**Hero model.** `hostsTile == false` (`HomeView.swift:136`) keeps today's phase-only behaviour: no art, no stages, today's collapse.

**One morph entry point.** Every place that morphs today goes through `func beginMorph(key:) async -> Bool` (false if focus left during the art wait):
- `setPhase(.expandedStatic)` in the cache-hit branch of `expand` (`:631`);
- the same call in `resolve()` after `beginExtraction` (`:785`);
- the `.dwelling → .expandedStatic` refocus path in `startPlayback` (`:992-998`), which becomes a `Task` that awaits `beginMorph`, then claims and plays, with the same `activeKey`/generation guards.

`beginMorph` does, in order:
1. Await `artTask` for at most `artAwaitDeadline` (critique #6: the deadline lives here, and the fetch itself keeps running to warm the cache).
2. Re-check `activeKey == key`.
3. Set `phase = .expandedStatic` (no animation of its own), set `tileArt`, run stage 1, schedule stage 2, then log `[TrailerPipeline] morph stage=reveal key=` and `InlineTrailerDebugLog`.
4. If no art arrived, use the poster already in memory (see the loader). Failing that, the tile draws `Theme.Palette.surface`, never a shimmer.

**Art prefetch (critique #6).** `startArtPrefetch()` is called by the gate loop at the first at-rest reading, or `artPrefetchAfter` (0.3 s) into the dwell, never at focus. A horizontal scrub therefore never fires a fetch per card passed. It uses `.normal` admission and **no request timeout**, so a coalesced in-flight fetch shared with the hero or Detail is never failed early.

**Art loader**, same file:

```swift
struct InlineTileArt { let image: UIImage; let barZoom: CGFloat; let url: String }
enum InlineTileArtLoader {
    /// W1-A (today's API, which spec B keeps source-compatible): `ArtworkStore.cached(url)` → `ArtworkStore.fetch(url)`
    /// for the primary (banner), then the fallback. Bar zoom: `ArtworkLetterbox.cachedZoom(forKey:)` or a
    /// `Task.detached(priority: .utility)` `ArtworkLetterbox.zoom(for:cacheKey:)`, the call shape at
    /// `CachedAsyncImage.swift:107-114`.
    /// W2-D (after W1-B's I1 API lands, critique #3): the primary fetch passes the tile's pixel decode
    /// (`ArtworkDecodeRequest(size: .points(CGSize(width: expandedWidth, height: artworkHeight)), fill: true,
    /// scale: ArtworkDecodeMath.screenScale)`), and the poster fallback uses `ArtworkStore.cachedLargest(posterURL)`
    /// (any bucket, so the card's own decode is found) before any fetch.
    static func load(primary: String?, fallback: String?) async -> InlineTileArt?
}
```

The card sets `model.tileArtSource = (InlineTrailerCard.landscapeArtworkURL(item), item.poster)` and `model.hostsTile = true` in `.onAppear`, before its `focusChanged(true…)` call.

### 2.4 View changes (`InlineTrailerCard`, W1-A)

- **`expandingCard`** (`:1171-1202`):
  - base opacity `fadesBaseCard && model.tileVisible ? 0 : 1`;
  - delete the blanket `.animation(…, value: model.isExpanded)` (`:1189`);
  - `.onChange(of: model.layoutExpanded)` drives `onExpansionChange` (`:1201`).
- **`expandedTile`**: opacity `model.tileVisible ? 1 : 0`.
- **`trailerSurface`**:
  - the art layer becomes `if let art = model.tileArt { Image(uiImage: art.image).resizable().aspectRatio(contentMode: .fill).scaleEffect(art.barZoom) }`, replacing `CachedAsyncImage` (`:1252-1260`). It stays in the tree until `tileArt` clears;
  - `showsInTileTitle` (`:1414`) uses `model.tileVisible`;
  - `artworkWidth` (`:1422-1425`) uses `model.layoutExpanded`.
- **`debug_trailerTile`** (`:1372-1388`): shown while `model.tileVisible`. Append-only fields: ` stage=<reveal|wide> gate=<auto|1|2|3> gateRest=<s> gateStart=<s> via=<rest|ceiling>`. W2-D adds ` ring=`.
- **DEBUG knobs (critique #7)**, read once. They make abort tests non-vacuous on the simulator:
  - `-debug.trailerMorphAbortAfterRevealMs <n>`: `reset()` n ms after stage 1;
  - `-debug.trailerMorphAbortAfterWideMs <n>`: `reset()` n ms after the `.wide` edge;
  - `-debug.trailerAbortWindowMs <n>`: overrides `abortWindowIntoWide`, so a test can abort "instantly" late enough to observe the pushed layout first.

### 2.5 Edge cases

- **Landscape rows:** no width change. The stages still run as a dissolve over the `LandscapeCard`, and the base card is not faded (`:1404`).
- **Reduce Motion:** all stage changes are instant.
- **Re-focus during a collapse:** the new `beginMorph` bumps the generation, so the pending completion must not clear the new `tileArt`.
- **Recycle mid-reveal:** abort, and `tileArt` clears at once.
- **Hero:** unaffected.
- **Abort while the engine scrolls to card #2:** device-tune item (critique #26, §2.2).

### 2.6 Unit tests (new `NuvioTVTests/InlineTrailerMorphPlanTests.swift`, W1-A)

Factor `nonisolated enum InlineTrailerMorphPlan` with two functions:
- `collapseStyle(stage:stageAge:abortWindow:)` → `.none | .abort | .animated`;
- `deferredCollapseDelay(stage:stageAge:)` → `TimeInterval?`.

Tests:
- `testAbortDuringReveal`: `(.reveal, 0.05)` → `.abort`.
- `testAbortEarlyInWide`: `(.wide, 0.1)` → `.abort`; `(.wide, 0.25)` → `.animated`; `(.wide, 1.0, abortWindow: 2.0)` → `.abort`.
- `testNoneIsNoop`.
- `testDeferredCollapseWaitsForExpansionEnd`: `(.wide, 0.2)` → 0.15; `(.wide, 0.5)` → nil; `(.reveal, 0.05)` → 0.42.
- `testArtCandidatesOrder`: a pure `InlineTileArtLoader.candidates(primary:fallback:)`. Blank and duplicate entries are dropped; the primary comes first.

### 2.7 UI legs and proof

**`test86MorphAbortIsInstant`** (critique #7). Launch with `-debug.trailerAbortWindowMs 2500 -debug.trailerMorphAbortAfterWideMs 1500` plus the inline arguments.
1. Down ×4 and wait for `debug_trailerMorph event=wide`.
2. Within the next 1.2 s take one `app.snapshot()` and read card #2's frame. XCUITest frames follow LAYOUT, which takes the final value at the `.wide` transaction. Assert a shift > 20 pt from the baseline taken before the dwell, using test37's neighbour oracle.
3. Wait for `event=abort style=instant`.
4. Snapshot: card #2 is at its baseline ± 2 pt, and `debug_trailerTile` is gone.

**`test86BRevealAbort`.** `-debug.trailerMorphAbortAfterRevealMs 60`: expect `event=abort style=instant stage=reveal`, and card #2 never moved.

**Simulator video** (main session): `xcrun simctl io <udid> recordVideo` around test86 and a normal morph, reviewed frame by frame for (a)–(d).

**Device:** (a)–(d) on Steven's settings, plus the real race (press Right on the morph's first frame). Tune `revealDuration` and `abortWindowIntoWide` there.

---

## 3. R1: morphed card ring keeps the poster colour

### 3.1 Root cause, confirmed

- The tile's ring overlay strokes `Theme.Palette.focusRingColor` (`InlineTrailerCard.swift:1345-1347`); No Zoom's still ring strokes `stillHighlight` (`:1348-1354`).
- `PosterCard` resolves `posterTint` from `ArtworkColorStore` under `focus_ring_poster_color` (`PosterCard.swift:894`, `:922-936`, `:1017`, `:1057`). The tile reads neither.
- In landscape rows the white tile ring covers the `LandscapeCard`'s tinted one (`PosterCard.swift:1117-1145`).
- The tile has no `nuvioCardDepth`.

### 3.2 Change (W2-D, after W1-A released `InlineTrailerCard.swift`)

- **New properties**, the same keys and independent-read pattern as `PosterCard`: `@AppStorage("focus_ring_poster_color")`, `@AppStorage("depth_rail_poster_color")`, `@Environment(\.cardDepthStyle)`, `@State private var posterRingTint: Color?`.
- **`tintSources`** = `posterStyle.landscapeCatalogRows ? [Self.landscapeArtworkURL(item)] : [item.poster, item.rawPosterUrl]`: the base card's sources (`BrowseComponents.swift:5183-5189`). `samplesPosterColor = ringTakesPosterColor && (accentFocusRing || noZoomOnFocus)`.
- **`posterTint`** = `ArtworkColorStore.shared.cachedColor(for: tintSources) ?? posterRingTint` while sampling and focused.
  - On the `tileVisible` true edge, if the peek missed, call `color(for:)` once and write `posterRingTint`.
  - `ArtworkColorStore`'s lookup goes through `ArtworkStore.cachedImage(for:)`, which spec B's I1 maps to `cachedLargest`, so the card's own decode is found.
- **Ring**: `.strokeBorder(posterTint ?? Theme.Palette.focusRingColor, lineWidth: 4)` / `.strokeBorder(posterTint ?? stillHighlight, lineWidth: ringWidth)`.
- **Depth**: `.nuvioCardDepth(RoundedRectangle(cornerRadius: geometry.radius), surface: .posters, railTint: depthRailTintResolved)` on the **art `Image` only** (inside the `ZStack`, under `TrailerHeroPlayer`), mirroring `PosterCard.swift:999-1000`.
  - BUG-110 suppresses the rail on a focused card (`CardDepthStyle.swift:353-358`). The playing tile therefore shows the sheen over the still art, which the video then covers. The coloured rail shows during the collapse dissolve, like the poster it turns back into.
- **Probe**: `debug_trailerTile` gains ` ring=<poster|accent|still|none>`.
- **Same agent, same wave (critique #3):** the tile-art loader's W2 upgrade (§2.3: tile pixel decode for the banner, `cachedLargest` for the poster fallback).

### 3.3 Tests

- New `NuvioTVTests/InlineTrailerTileTintTests.swift`: the pure `ringSource(settingOn:accentRing:noZoom:focused:hasPosterColor:)` table.
  - off → `accent`;
  - on, ring, colour → `poster`;
  - on, No Zoom, no colour → `still`;
  - ring off and zoom on → `none`.
- UI **`test87MorphedRingKeepsPosterColour`**: `-accent_focus_ring YES -focus_ring_poster_color YES` plus the inline arguments → `ring=poster`. Skip on `ring=accent`: grey art legitimately keeps the accent colour.
- **Device:** the pink and gold rings stay through the morph and playback (the 72 Heures / Elize triage).

---

## 4. M4: FEAT-52 "Trailer Start Delay"

### 4.1 Storage

- `trailer_start_delay`: device-local `@AppStorage` String, default `"auto"`. This matches `inline_trailers_enabled`, `trailer_playback_location` and `hero_trailer_autoplay` (`HomeScreenSettingsPane.swift:24/36/40`; `HomeView.swift:93-103`; `BrowseComponents.swift:4770`).
- No Kotlin, no sync. `-trailer_start_delay 2` works as a launch argument.

### 4.2 Read sites and semantics

- `TrailerStartDelay.current()` is read once per dwell (§1.4). That covers Home inline cards, Search inline cards (the same model), the hero-location focus trailer and the carousel autoplay.
- Detail keeps its own 4 s; `DetailViewModel` is untouched.
- **Semantics (confirmed by Christian 2026-10-03):**
  - Automatic = rows stopped + 1 s.
  - 1/2/3 s = that long after focus lands, never before the rows stop.

### 4.3 Settings row (W2-D) and description (W2-F, spec B side)

**W2-D**, `HomeScreenSettingsPane.swift`:
- Add `@AppStorage(TrailerStartDelay.storageKey) private var trailerStartDelay = TrailerStartDelay.automatic.rawValue`.
- After "Autoplay Hero Trailer" (`:198-205`), in the same `else` branch: `if inlineTrailersEnabled || heroTrailerAutoplay { trailerStartDelayRow }`.

```swift
SettingsPickerRow(
    title: String(localized: "Trailer Start Delay"),
    selection: Binding(get: { TrailerStartDelay(rawValue: trailerStartDelay) ?? .automatic },
                       set: { trailerStartDelay = $0.rawValue }),
    options: TrailerStartDelay.allCases,
    descriptionID: .homeTrailerStartDelay,     // exactly this literal form: SettingsDescriptionsTests scans for it
    label: { $0.label }
)
```

**W2-F** owns `SettingsDescriptions.swift` in W2 (critique #16) and adds, verbatim:
- In the `// MARK: Home Screen` block, after `case homeHeroTrailerAutoplay = "home.heroTrailerAutoplay"` (`:84`):
  `case homeTrailerStartDelay = "home.trailerStartDelay"`
- In `text(for:)`, after the `.homeHeroTrailerAutoplay` line (`:258`):
  `case .homeTrailerStartDelay: return LocalizedStringResource("Sets how long trailers on posters and in the hero wait before they start. Automatic waits until the rows stop moving, then one second. Default: Automatic.")`
  - deslop 5/5, checked 2026-10-03.

D's and F's builds meet only at Gate 2. `SettingsDescriptionsTests.testEveryIDIsUsedAndOnlyKnownIDsAreUsed` needs both halves; it fails if either is missing.

### 4.4 UI leg

**`test88TrailerStartDelaySetting`**:
1. Settings → Home Screen with inline on: the row exists with value "Automatic".
2. Relaunch with `-trailer_start_delay 2` and the inline arguments, then Down ×4.
3. Assert `debug_trailerTile` reads `gate=2` and `gateStart ≥ 2.0`.

**Device:** the four options feel right (Christian, Test profile).

---

## 5. M5: hero text fades out then in; stale hero after a folder; hero with no title

### 5.1 Root causes, confirmed

1. **Doubled title.**
   - `HeroArtResolver.commit` assigns `presented` inside `withAnimation(.easeInOut(duration: 0.3))` (`HomeView.swift:4033-4036`).
   - `HomeHeroForeground` keys the info block on `.id(presentation.identity)` + `.transition(.opacity)` (`:5474-5485`), so for 0.3 s two blocks cross-dissolve in one slot.
2. **Stale hero after a folder.**
   - The push takes focus off the row: `reportRowFocus(nil)` → `HomeHeroFocusModel.reportFocus(nil)` → after `revertGrace` 0.3 s (`:3205`, `:3274-3281`) `focusedItem = nil`. `displayHero` falls back to the carousel page (`:372-376`), painted behind the folder page.
   - On pop, the folder re-reports and pays a 0.2 s commit (`:3199`) plus a resolve (folder deadline 1.5 s, `:3552-3557`), so the carousel title shows for about 1 s (triage 2:57.5).
3. **No visible title.**
   - `HeroLogo` falls back to text only when `image == nil` (`:5841-5857`), so an invisible bitmap was on screen.
   - Two hypotheses: (i) blank/transparent; (ii) a near-black wordmark. The device token decides (§5.9).

### 5.2 New file `NuvioTV/Screens/Home/HeroTextSwap.swift` (W2-E): the reusable text phase

```swift
/// beta.19-rc1 verdict (M5): a text block that never shows two payloads at once: fade OUT, swap
/// while invisible, fade IN. Generic so the Stage & Strip batch's `StageSwapModel` can wrap it.
@MainActor
final class TextSwapModel<Payload: Equatable>: ObservableObject {
    struct Timing: Equatable {
        var pause: TimeInterval; var fadeOut: TimeInterval; var fadeIn: TimeInterval
        static let classic = Timing(pause: 0, fadeOut: 0.12, fadeIn: 0.12)
        static let stage = Timing(pause: 0.45, fadeOut: 0.15, fadeIn: 0.20)   // Stage & Strip plan's numbers
    }
    enum Phase: Equatable { case idle, pausing, fadingOut, fadingIn }
    typealias Schedule = (_ after: TimeInterval, _ work: @escaping @MainActor () -> Void) -> AnyCancellable
    /// A static FUNC, not a stored static (critique #25: generic types cannot hold stored statics).
    static func mainQueueSchedule(_ after: TimeInterval, _ work: @escaping @MainActor () -> Void) -> AnyCancellable
    @Published private(set) var shown: Payload?
    @Published private(set) var textOpacity: Double = 1
    private(set) var phase: Phase = .idle
    private(set) var pending: Payload?
    private(set) var swaps = 0
    init(timing: Timing, identity: @escaping (Payload) -> String, schedule: Schedule? = nil)   // nil → mainQueueSchedule
    func seed(_ payload: Payload?)
    func receive(_ next: Payload?, reduceMotion: Bool)
    #if DEBUG
    var debugLine: String     // "phase=out shown=<id> pending=<id|-> swaps=N maxLive=<HeroInfoLiveCounter.max>"
    #endif
}
typealias HeroTextSwapModel = TextSwapModel<HeroPresentation>

#if DEBUG
/// critique #8: the real "two titles at once" oracle. The info block increments on `.onAppear` and
/// decrements on `.onDisappear`. SwiftUI calls `.onDisappear` only after a removal transition
/// finishes, so a regression back to `.transition(.opacity)` keeps two blocks alive (max 2);
/// `.transition(.identity)` keeps it at 1.
enum HeroInfoLiveCounter { static var live = 0; static var max = 0; static func appear(); static func disappear(); static func resetForTesting() }
#endif
```

`receive` rules (all of them unit-tested):

| State | Input | Action |
|---|---|---|
| any | `next == nil` | Cancel all; `shown = nil`, opacity 1, `.idle` (instant). |
| any | `shown == nil` | `shown = next`, opacity 1, no animation. |
| any | same identity as `shown` | Silent gap-fill: `shown = next` with no animation. Cancel a pending swap; if fading out, fade back in → `.idle`. This also covers spec B's post-commit hero sharpen (critique #2): a same-identity backdrop upgrade never touches the text. |
| `.idle` | new identity | `pause > 0` → `pending`, `.pausing`, schedule the pause → fade out. `pause == 0` → fade out now. |
| `.pausing` | new identity | `pending = next`; restart the pause. |
| fade out | — | `withAnimation(.easeOut(duration: fadeOut)) { textOpacity = 0 }`, `.fadingOut`, schedule `fadeOut` → swap. |
| `.fadingOut` | new identity | `pending = next`. If `pause > 0`, cancel the swap → `.pausing` (text stays hidden, the pause restarts). If `pause == 0`, keep the scheduled swap. |
| swap | — | In a disables-animations transaction: `textOpacity = 0`, `shown = pending`, `swaps += 1`. Then `withAnimation(.easeIn(duration: fadeIn)) { textOpacity = 1 }`, `.fadingIn`, schedule → `.idle`. |
| `.fadingIn` | new identity | Fade out from the current opacity (full `fadeOut`), then continue as above. |
| any | `reduceMotion` | Instant swap: `shown = next`, opacity 1, `.idle`. |

### 5.3 Wiring: a child view owns and observes the model, never HomeView (critique #11)

**New `HeroTextLayer: View`**, in `HeroTextSwap.swift` or at the end of `HomeView.swift`:
- `@StateObject private var swap = HeroTextSwapModel(timing: .classic, identity: { $0.identity })`. The model is created and observed only here, so a hero swap re-renders this layer and `HomeHeroForeground`, never `HomeView`'s body.
- Inputs:
  - `presentation: HeroPresentation` (the resolver's committed one);
  - `heroFocused: FocusState<Bool>.Binding`;
  - `compact`, `showsCTA`, `forceNuvioLayout`, `compression`;
  - `folderRoutes: [String: FolderRoute]`.
- Lifecycle: `.onAppear { swap.seed(presentation) }`; `.onChange(of: presentation) { _, p in swap.receive(p, reduceMotion: reduceMotion) }`. `HeroPresentation` is `Equatable` (`:3458-3463`).
- Body: `let text = swap.shown ?? presentation`, then `HomeHeroForeground(textPresentation: text, textOpacity: swap.textOpacity, heroFocused: heroFocused, compact:…, showsCTA:…, forceNuvioLayout:…, folderRoute: isCollectionHero(text.item) ? folderRoutes[text.item.id] : nil, compression:…)`.
  - The CTA follows the visible text.
  - `#if DEBUG` overlay: the `debug_heroText` label from `swap.debugLine`, the existing invisible-label form.

**`heroCarousel`** (`HomeView.swift:2301-2308`): keep `if let presentation = heroResolver.presented`, the region-existence test. Replace the `HomeHeroForeground(…)` call with `HeroTextLayer(…)`. HomeView itself holds no swap model and observes nothing new.

**`HomeHeroForeground`** (`:5357-5538`):
- `presentation` becomes `textPresentation: HeroPresentation`, plus `var textOpacity: Double = 1`.
- Info block (`:5474-5485`): `.id(textPresentation.identity)`, then `.transition(.identity)` (was `.opacity`), then `.opacity(textOpacity)`, then `.accessibilityIdentifier("hero_info")`.
  - In `#if DEBUG`: `.onAppear { HeroInfoLiveCounter.appear() }` / `.onDisappear { HeroInfoLiveCounter.disappear() }`.
- The CTA (`:5513-5531`) is **not** faded.
- Rewrite the Wave H comment (`:5462-5473`); keep the `ZStack`.

**Resolver comment.** `HeroArtResolver.commit`'s comment (`:4010-4023`) about the transaction driving the info block's `.transition` is stale: rewrite it. The `withAnimation` stays. **The artwork cross-fade is untouched.**

Classic timeline (warm cache):
1. The commit lands at t0.
2. The art cross-fades over t0 → t0 + 0.3.
3. The old text fades out over t0 → t0 + 0.12.
4. The text swaps at t0 + 0.12 and is fully in by t0 + 0.24.

### 5.4 Stale hero after a folder: freeze the focus model while Home is covered (W2-E)

`HomeHeroFocusModel` (`:3188`) gains `private var covered = false` and `func setCovered(_:)`:
- **true:** cancel a pending nil-report revert (`:3274-3281`) and bump `generation`. `focusedItem` and `claimSource` are kept.
- **false:** arm a one-shot `uncoverVerify` (0.6 s, generation-guarded). If no `reportFocus` call arrives within 0.6 s, revert as a nil report would.

`reportFocus` (`:3218`) starts with `if item == nil && covered { generation &+= 1; pendingTask?.cancel(); pendingTask = nil; return }`. Any non-nil report clears `uncoverVerify`.

**HomeView.** `syncHeroFocusCover()` → `focusModel.setCovered(!homePath.isEmpty || resume != nil || tabBarVisibility.homeSurfaceCovered)`. Call it from:
- `.onChange(of: homePath.count)` (`:1209`, next to `PinnedRowSettle.setCovered`);
- `.onChange(of: resume != nil)`;
- `.onReceive(tabBarVisibility.$homeSurfaceCovered)`;
- `.onAppear`.

**Unchanged.** The CTA hand-back (`cancelAndRevert`, `:1075-1076`). The carousel stays still while covered (`:1046`), and the trailer gates stay closed while covered (`:469-472`).

### 5.5 Hero with no visible title: logo ink check (W2-E; thresholds per critique #10)

New file `NuvioTV/Screens/Home/HeroLogoInk.swift`:

```swift
nonisolated enum HeroLogoInk: String, Equatable {
    case legible, dark, blank
    static let side = 32
    /// Draw into 32×32 RGBA8 with `.medium` interpolation (area averaging, so a thin wordmark is not
    /// missed the way a point sample would miss it), then `verdict(rgba:)`.
    static func verdict(of image: UIImage) -> HeroLogoInk
    /// Over pixels with alpha > 0.1, un-premultiplied:
    ///   coverage = their fraction of all pixels; luma = mean Rec. 709 luminance; chroma = mean (max − min).
    /// coverage < 0.005                                   → blank  (transparent / placeholder)
    /// coverage > 0.9 && luma < 0.15 && chroma < 0.12     → blank  (opaque dark box: text wordmark instead)
    /// luma < 0.08 && chroma < 0.12                       → dark   (near-black, low-chroma ink: white silhouette)
    /// else                                               → legible (red, blue and every brand colour stay as drawn)
    static func verdict(rgba: [UInt8]) -> HeroLogoInk
    /// Per-URL memo (`NSCache<NSString, NSString>`).
    static func cachedVerdict(for url: String) -> HeroLogoInk?
    static func remember(_ v: HeroLogoInk, for url: String)
}
```

**Where the sample runs.**
- **Fetched logos:** in the resolver's two logo fetch tasks (`HomeView.swift:3903-3905`, `:3920-3928`), a `Task.detached(priority: .userInitiated)` computes and memoizes the verdict BEFORE `wait.resolveLogo(image)`.
- **Cache-warm logos** with no memo (prefetched by a row): sample synchronously and memoize. Log the cost once per process, `[HomeHero] logoInk sync-sample ms=`.
- **TMDB `original` logos.** Christian has approved moving TMDB logos to `original` (spec B owns that change). The source is then larger, but I1 decodes logos `.legacy`, ≤ 1920, so the 32×32 draw stays well under a millisecond-class cost; the device log confirms it.
  - The URL changes from `w500` to `original`, so the memo simply refills.
  - The thresholds do not depend on resolution.

**`HeroPresentation`** (`:3446`) gains `var logoInk: HeroLogoInk = .legible`. It is a `var` with a default, so the memberwise init keeps compiling `HeroCrossfadeLayoutTests.swift:135-166` (critique #25). `==` includes it.

**`HeroArtResolver.present`.** Before every commit (`:3847`, `:3966`) with `logo != nil`, read the memo (or sync-sample):
- `.blank` → commit `logo: nil`, `logoSource: "text"`, `logoOrigin: .none`;
- `.dark` → commit with `logoInk: .dark`.

`adoptLateBackdrop` and the gap-fill branch carry the current ink. `logPresent` (`:4168-4176`) appends ` logoInk=<…>` LAST.

**`HeroLogo`** (`:5827-5862`) gains `var ink: HeroLogoInk = .legible`. `.dark` renders `.renderingMode(.template)` + `.foregroundStyle(Theme.Palette.textPrimary)`. `HomeHeroForeground` passes `textPresentation.logoInk` at `:5624`, `:5639`, `:5676`, `:5685`.

Not in this batch: `InlineTrailerTitleOverlay` (`InlineTrailerCard.swift:1445`) has the same blind spot.

### 5.6 DEBUG harness labels: leaf views only (critique #11)

In HomeView's `#if DEBUG` block (`:694-767`), add two tiny leaf views, each observing its own source. HomeView's body observes neither.
- `TrailerMorphDebugLabel` (`@ObservedObject InlineTrailerDebugLog.shared`) → `Text("debug_trailerMorph \(log.last)")`.
- `TrailerListenerDebugLabel` (`@ObservedObject TrailerListenerDebug.shared`, §6.2 item 9) → `Text("debug_trailerListener \(listener.last) rebuilds=\(listener.rebuilds)")`.

`debug_heroText` lives in `HeroTextLayer` (§5.3).

### 5.7 M3's HomeView hooks (W2-E): the three edits in §1.7

### 5.8 Unit tests (W2-E)

**`HeroTextSwapModelTests`** (new). Use a fake `Schedule` and `TextSwapModel<String>` with `identity: { String($0.prefix(1)) }`.
- `testFirstPayloadShowsImmediately`.
- `testNewIdentityFadesOutSwapsFadesIn`.
- `testSameIdentityIsSilentGapFill`.
- `testRetargetDuringFadeOutKeepsOneSwap`.
- `testReturningToShownDuringFadeOutCancelsSwap`.
- `testRetargetDuringFadeInStartsNewFadeOut`.
- `testReduceMotionSwapsInstantly`.
- `testStagePauseRestartsOnRetarget`.
- `testNilClearsImmediately`.

**`HeroLogoInkTests`** (new), critique #10's table:
- all-transparent → `.blank`;
- black glyph on transparent → `.dark`;
- dark-grey (0.05) glyph → `.dark`;
- **pure red glyph → `.legible`**;
- **pure blue glyph → `.legible`**;
- Netflix red (229, 9, 20) → `.legible`;
- white glyph → `.legible`;
- opaque black box → `.blank`;
- opaque mid-grey → `.legible`.

**`HeroFocusCoverTests`** (new, four tests, ~0.8 s expectations):
- a covered nil report keeps the item;
- `setCovered(true)` cancels a pending revert;
- an uncover with no report reverts after 0.6 s;
- an uncover followed by the same item keeps it, with no `onRevert`.

### 5.9 UI legs and proof

**`test89HeroTextNeverDoubles`** (critique #8).
- Pinned Nuvio hero. Walk Right across 8 cards of the first catalog row at 0.9 s gaps.
- The oracle is the `debug_heroText` trace: `swaps ≥ 6` and **`maxLive=1`** (`HeroInfoLiveCounter`, the value a regression back to a cross-dissolve raises to 2).
- Also count `hero_info` elements after each press as a smoke check (≤ 1). That count alone proves nothing, because the old code had no `hero_info` and SwiftUI may drop a transitioning-out copy from the AX tree.

**`test90HeroHoldsFolderOnReturn`** (critique #8), seeded so it runs on FA87.
- Copy spec B's `launchToHomeWithSeededCollections` helper into `TrailerMotionUITests` per the house rule. It relies on W2-F's `applyCollectionsSeedIfRequested` guard fix, so it runs at W4.
- Seed JSON:
  ```json
  [{"id":"zzherofold-collection","title":"ZZHeroFold","pinToTop":true,"showAllTab":false,
    "folders":[{"id":"zzherofold-a","title":"ZZHeroFoldA",
      "heroBackdropUrl":"https://images.metahub.space/background/medium/tt0111161/img",
      "sources":[{"provider":"addon","addonId":"com.linvo.cinemeta","type":"movie","catalogId":"top"}]}]}]
  ```
  A folder with a `heroBackdropUrl` reports a hero preview (`folderHeroPreview`, `HomeView.swift:2865-2868`).
- Steps:
  1. Down until `debug_hero pitem=` starts with `nuvio-folder://`.
  2. Select; pause 2 s.
  3. Menu.
  4. Poll `pitem=` every 0.2 s for 1.6 s and assert it never leaves the folder identity.
- **Teardown:** a `defer` relaunch with the seed `[]` (`W10=`).

**No-title hero.** Unit tests on the simulator. **Device check:** focus Comme des frères with `-debug.homeHeroProbe YES` and read `present … logoInk=`.

**Device:** one title at a time across hero swaps; returning from the Netflix folder shows the folder hero at once.

---

## 6. B2: trailer listener lifecycle (P1)

### 6.1 Root cause, confirmed in code, with the two hypotheses B1 decides between

`TrailerLocalHLS` (`TrailerLocalHLS.swift:20-618`) serves repacked trailers' playlists from one `NWListener` on 127.0.0.1:8230+.
- `ensureStarted` (`:495-507`) returns the cached `port` with no liveness check and no deadline.
- `attemptStart`'s state handler (`:534-553`) ignores `.waiting` (`default: break`, `:550-551`).
- A death after `.ready` clears `port` only if a `.failed`/`.cancelled` callback arrives (`:539-549`), and nothing rebuilds it until the next repack.

Two shapes:
- **H1, silent death** (best fit for the video's end state). The app is suspended during Infuse and the socket is reclaimed with no callback, so `port` stays set.
  - Repacks return `http://127.0.0.1:8230/…` (`:252`). AVPlayer then fails with −1004 or hangs into the 6 s watchdog (`TrailerHeroPlayerView.swift:387-394`).
  - The resulting chain: `.transient`, one next-candidate retry against the same dead port, then a collapse. That gives the 6:16–6:34 end state; the cache-hit variant is the 0.4 s abort at 4:34.7.
- **H2, start hang.** A restart goes `.waiting` or never reports.
  - The waiters are never resolved, so `playbackURL(for:)` never returns.
  - `resolve()` parks after `setPhase(.expandedStatic)` (`:814`), and `resolvingKey` stays latched (`:707`).

### 6.2 Changes to `TrailerLocalHLS.swift` (W1-C)

**Listener seam.** A protocol with methods, not settable properties, to avoid the SDK's `@Sendable` handler signatures:

```swift
nonisolated enum TrailerListenerState: Equatable, Sendable { case setup, waiting(String), ready, failed(String), cancelled }
nonisolated protocol TrailerLoopbackListening: AnyObject, Sendable {
    func start(queue: DispatchQueue,
               onState: @escaping @Sendable (TrailerListenerState) -> Void,
               onConnection: @escaping @Sendable (NWConnection) -> Void)
    func cancel()
}
/// Real adapter: NWParameters.tcp, requiredLocalEndpoint 127.0.0.1:port, allowLocalEndpointReuse = true.
/// (SO_REUSEADDR does not allow a second LISTENING socket on a port, hence the cancel-wait and
/// same-port retries below, critique #4.)
nonisolated final class NWTrailerLoopbackListener: TrailerLoopbackListening, @unchecked Sendable { init(port: UInt16) throws }
```

**Init.** `private init()` becomes `init(listenerFactory: @escaping @Sendable (UInt16) throws -> TrailerLoopbackListening = { try NWTrailerLoopbackListener(port: $0) }, schedule: Scheduler? = nil, healthCheck: HealthCheck? = nil, basePort: UInt16 = 8230, observesLifecycle: Bool = true)`; `static let shared = TrailerLocalHLS()`. The defaults are `listenerQueue.asyncAfter` and a real NWConnection ping.

**State under `lock`:**
- `listener`, `port`, `startWaiters`;
- `startInFlight` (replaces the `!startWaiters.isEmpty` test at `:502`);
- `startGeneration`;
- `retiring: TrailerLoopbackListening?` (the cancelled listener whose `.cancelled` a rebuild waits for);
- `lastBoundPort`, `samePortRetries`, `backgroundedSinceActive`;
- `eagerRebuilds: [TimeInterval]` (budget 3 per 60 s), `liveConnections`.

**Never call out while holding `lock`** (the file's existing discipline, `:509-516`).

Behaviour:
1. **`ensureStarted(completion)`.**
   - A ready `port` answers at once.
   - Otherwise append the waiter. If no start is in flight: bump the generation; port order `[lastBoundPort] + (8230…8249 minus it)`; schedule a **per-attempt start deadline (2.0 s)**.
2. **State handling.** Stale generation or non-current listeners are ignored, except the `retiring` listener's `.cancelled`.
   - `.ready` → `port = p`, `lastBoundPort = p`, resolve waiters, log `ready`.
   - **`.waiting(e)` before ready → keep waiting** (log `waiting`). Path evaluation can settle; the attempt deadline decides (critique #4).
   - **`.failed(e)` before ready.**
     - When the port is the preferred `lastBoundPort` and `samePortRetries < 3`: cancel, then schedule a retry of the SAME port after 0.1 s (log `failed … retry=n`).
     - Otherwise cancel and try the next port.
   - `.waiting` / `.failed` / an un-requested `.cancelled` **after ready** → `markDead(reason:)`: clear `listener` and `port`, then an eager rebuild if the budget allows (else lazy; log `budget`).
   - Ports exhausted → resolve waiters nil (the existing "loopback bind FAILED → progressive" path, `:247-250`), `startInFlight = false`, log `exhausted`.
3. **Attempt deadline fired** (same generation, no port):
   - cancel the candidate and resolve the CURRENT waiters with nil, so their playback falls back to progressive at once;
   - log `start-timeout`;
   - continue with the next port under a fresh attempt deadline, so later callers find a listener;
   - a late `.ready` from the cancelled candidate is ignored (generation).
4. **Lifecycle** via `noteLifecycle(_ e: LifecycleEvent)`. Observers for `didEnterBackgroundNotification` / `didBecomeActiveNotification` are registered from a `@MainActor` helper the first time the server starts; tests call `noteLifecycle` directly.
   - `.background` sets `backgroundedSinceActive`.
   - `.active` after a background, with a ready `port` → **`verifyListener(reason: "active")` first** (critique #4).
     - Alive (the common case) → nothing, log `health alive=1`.
     - Dead → rebuild.
   - `.active` without a prior background → nothing.
5. **Rebuild** (dead verdict, or `markDead`):
   - move the listener to `retiring`, call `cancel()`, clear `port`, bump the generation, keep pending waiters;
   - wait for `retiring`'s `.cancelled`, or 0.5 s (scheduled), whichever is first;
   - then `ensureStarted` preferring `lastBoundPort`, with the same-port retries above;
   - log `rebuild reason=… prefer=… conns=`.
6. **`verifyListener(reason:)`.**
   - `healthCheck(port)`. The real check: an `NWConnection` to 127.0.0.1:port sends `HEAD /_ping HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n`; any bytes back within 1.0 s means alive.
   - Dead → `markDead` + rebuild. Log `health port= alive= ms=`.
   - `handle(head:on:)` (`:580-606`) answers `/_ping` with `204` before the playlist lookup.
7. **Connections** (B3):
   - `liveConnections += 1` on accept, `−1` on `.cancelled`/`.failed` (a `stateUpdateHandler` in the connection handler, `:554-558`);
   - a connection with no complete header after 5 s is cancelled.
8. **Outcome API.** The ITC call sites switch to it in W2. The legacy API keeps its old semantics (critique #5).

   ```swift
   nonisolated enum TrailerPlaybackURLOutcome: Equatable, Sendable {
       case playable(String)                 // local repack master, or the progressive/HLS URL
       case nothingPlayable                  // no repack and no progressive for this source
       case timedOut(progressive: String?)   // no answer in time: transient, never "unavailable"
   }
   static let inlinePlaybackURLTimeout: TimeInterval = 12   // ≥ 12 s (critique #5): cuts only pathological repacks
   func playbackOutcome(for source: TrailerPlaybackSource, timeout: TimeInterval = inlinePlaybackURLTimeout,
                        completion: @escaping @Sendable (TrailerPlaybackURLOutcome) -> Void)
   func playbackOutcome(for source: TrailerPlaybackSource) async -> TrailerPlaybackURLOutcome
   func readyPort() async -> UInt16?        // ensureStarted, bounded by the attempt deadline
   /// The URL to play for a cached loopback URL: unchanged when its port is the ready one; REBASED to the
   /// ready port when only the port moved and the token is still stored (no YouTube re-extraction,
   /// critique #4 / BUG-46); nil when the token is gone or no listener is ready. Non-loopback URLs return unchanged.
   func servableURL(_ urlString: String, readyPort: UInt16?) -> String?
   static func port(inPlaybackURL: String) -> UInt16?
   // Legacy, used by Detail (DetailViewModel.swift:375/:434, unchanged): NO outer timeout, exactly today's
   // semantics. The listener wait inside is still bounded by the 2 s attempt deadline (H2 fixed for Detail too).
   //   playbackURL(for:completion:)  /  playbackURL(for:) async
   ```

   - The race is a one-shot latch; the late completion is dropped.
   - Both APIs log `[TrailerRepack] playbackURL slow ms=` when a repack takes longer than 6 s. On a timeout, log `playbackURL timeout after=12.0s fallback=progressive|none`.
9. **Probes.**
   - Unconditional `NSLog`, prefix `[TrailerRepack] listener`: `start`, `ready`, `waiting`, `failed … retry=`, `start-timeout`, `exhausted`, `dead`, `rebuild`, `health`, `budget`, each with `port=`, `gen=` and `conns=` where meaningful.
   - **DEBUG harness sink (critique #9), owned by W1-C in this file:** `@MainActor final class TrailerListenerDebug: ObservableObject { static let shared; @Published private(set) var last = "-"; private(set) var rebuilds = 0 }`, updated by `DispatchQueue.main.async` from each probe event. W2-E renders it in a leaf (§5.6).
10. **DEBUG knobs**, read once:
    - `-debug.trailerListenerFault silent`: on `.background`, cancel the underlying `NWListener` without telling the class (handler detached first), keeping `port`. Reproduces H1. The `.active` health ping then fails, and the rebuild must recover.
    - `-debug.trailerListenerFault silent-norebuild`: the same, and `.active` skips verification. Use it once to prove the knob reproduces the symptom.
    - `-debug.trailerListenerFault waiting` (redefined per critique #4): EVERY listener created after a background reports `.waiting` and never `.ready`. Reproduces H2 and drives the attempt deadline.
    - `-debug.trailerListenerLifecycleCycleAfterS <n>` (critique #9): n s after the first `.ready`, in-process, call `noteLifecycle(.background)`, apply the `silent` fault, then `noteLifecycle(.active)`.

**`TrailerDebugProbes.swift`** (W1-C): add `var isConnectionClass: Bool` to `TrailerFailureCause` (`:251-310`):
- `.watchdogTimeout` → true;
- `.itemFailed` / `.failedToPlayToEnd` → `underlyingError?.domain == NSURLErrorDomain`;
- `.badURL` → false.

### 6.3 ITC call sites (W2-D; exact)

- **`resolve()`** (`:809-849`): use `let outcome = await TrailerLocalHLS.shared.playbackOutcome(for: source)`.
  - `.playable(u)` → store `.resolved(u)`, `startPlayback(u, key:)`.
  - `.timedOut(p?)` → with a progressive URL: `startPlayback(p, key:)` **without** storing `.resolved`. With none: store `.transient` (`causeSite: "playbackURLTimeout"`) and `abandonExpansion`. Never `.unavailable`.
  - `.nothingPlayable` → the existing Finding 3 hand-off (`retryOwnsResolution = retryNextCandidate(…)`).
  - No source → the existing `.unavailable notPlayable` branch (`:824-830`).
- **`retryNextCandidate`** (`:945-964`): the same mapping. `.nothingPlayable` recurses as today; `.timedOut` follows the rules above, then `releaseResolutionOwnership`.
- **`expand()` cache-hit** (`:619-632`, async since W1-A). Replace the `hasToken` check:

  ```swift
  if TrailerLocalHLS.token(inPlaybackURL: url) != nil {
      let ready = await TrailerLocalHLS.shared.readyPort()
      guard activeKey-and-generation still match else { return }
      guard let servable = TrailerLocalHLS.shared.servableURL(url, readyPort: ready) else {
          // log branch=resolvedStale; invalidate; startResolution; return
      }
      if servable != url { TrailerResolutionCache.shared.store(.resolved(servable, Date()), for: key) }  // rebased, no re-extraction
      url = servable
  }
  ```

- **`playbackFailed`** (`:533-583`): after the cache write, when `report.httpStatus == nil`, the URL is loopback and `report.cause.isConnectionClass` → `TrailerLocalHLS.shared.verifyListener(reason: "playback")`.

### 6.4 Unit tests

New `NuvioTVTests/TrailerLocalHLSListenerTests.swift` (W1-C). It uses a fake listener (records `start` closures, counts `cancel()`), a fake scheduler and a fake health check.
- `testConcurrentWaitersShareOneStart`.
- **`testWaitingHoldsUntilDeadlineThenNextPort`** (replaces `…TriesNextPort`, critique #4): `.waiting` → no new factory call; fire 2.0 s → waiters get nil, the candidate is cancelled, and the factory is called with 8231.
- `testLateReadyAfterDeadlineIsIgnored`.
- **`testFailedOnPreferredPortRetriesSamePortThreeTimes`**: `.failed("addrinuse")` → after 0.1 s the factory is called with 8230 again, three times, then 8231.
- **`testActiveAfterBackgroundAliveDoesNothing`**: health true → no cancel, no factory call.
- **`testActiveAfterBackgroundDeadRebuildsAfterCancelled`**: health false → the old listener is cancelled; the factory is NOT called until the old fake emits `.cancelled` (or the 0.5 s schedule fires), then it is called with 8230.
- `testActiveWithoutBackgroundDoesNothing`.
- `testDeathAfterReadyRebuildsPreferringSamePort`.
- `testEagerRebuildBudget`.
- **`testServableURL`**:
  - same port → unchanged;
  - port moved and token stored → rebased to 8231;
  - unknown token → nil;
  - no ready port → nil;
  - googlevideo URL → unchanged.
- **`testOutcomeTimeout`**, on a factored `race(timeout:schedule:work:onTimeout:completion:)`:
  - never completes → `.timedOut` at 12 s;
  - completes first → `.playable`;
  - completes late → ignored.
- **`testLegacyAPIHasNoOuterTimeout`**: a completion arriving 20 s later still reaches the legacy callback.
- `testHealthCheckDeadMarksDeadAndRebuilds`, `testPortInPlaybackURL`, `testIsConnectionClass`.

W2-D adds `InlineTrailerResolveOutcome.action(for:)` and `testOutcomeMapping`:
- `.playable` → `.storeResolvedAndPlay`;
- `.timedOut("p")` → `.playUncached`;
- `.timedOut(nil)` → `.storeTransient`;
- `.nothingPlayable` → `.tryNextCandidate`.

### 6.5 B1: simulator repro recipe (main session)

1. FA87 clone booted, Debug build installed. `BUNDLE` is the simulator bundle id (`com.nuvio.media.NuvioTV`; check with `xcrun simctl listapps`).
2. Launch:
   ```
   xcrun simctl launch --console-pty $UDID $BUNDLE -inline_trailers_enabled YES -debug.trailerProbe YES \
     -debug.trailerSmokeVideoId rNZ0xKaCdus -home_upcoming_row_enabled NO -trailer_playback_location poster \
     -trailer_start_delay 1 | tee ~/Downloads/b1-sim.log
   ```
3. Chris profile, Down ×4, dwell 4 s. Expect `[TrailerRepack] serving … 127.0.0.1:8230`, `attach live=1`, and no `fail`.
4. Background: `xcrun simctl launch $UDID com.apple.TVSettings`; wait 30 s.
5. Foreground: `xcrun simctl launch $UDID $BUNDLE` (no `--terminate-running-process`); confirm no new `home_appear` line.
6. Right ×2 and dwell (a new title); Left ×2 and dwell (the cache hit).
7. **Pass:** both play. **Signatures:**
   - H1: `fail cause=itemFailed … NSURLErrorDomain code=-1004`, or `watchdogTimeout`, against 127.0.0.1;
   - H2: `resolve candidate=` with no `serving` after it.
8. **Pre-fix:** the simulator probably does not reproduce, because suspended simulator processes keep their sockets. Record "no repro"; the baseline is the device leg.
9. **Fixed build:**
   - `silent-norebuild` reproduces H1;
   - `silent` → `health … alive=0` → `rebuild reason=active` → `ready port=8230` → both play;
   - `waiting` → `start-timeout` → progressive playback now, a later `exhausted` (all ports wait) and a fresh start on the next dwell.

**Device leg** (Christian, Living Room Apple TV, **Test profile**): Debug build, `-debug.trailerProbe YES --console` → `~/Downloads/steven-rc1-b1.log`.
1. Play one inline trailer.
2. Open a title → Play via Infuse → 60 s → back to Detail → Home.
3. Dwell on a new title and on the earlier one.
4. Pre-fix expect the signature; post-fix expect either `health alive=1` (socket survived) or `rebuild reason=active`, then playback.
5. Repeat after 30 minutes of browsing.

### 6.6 B3: leak check (main session)

- **Counters** (`-debug.trailerProbe YES`, 30 minutes with inline on):
  - every `attach live=N` returns to `teardown live=0` (1 while a hero trailer plays);
  - `[TrailerRepack] listener … conns=N` stays ≤ 3 at rest.
- **Instruments on device** (Allocations + Leaks, generation every 10 minutes): persistent `AVPlayer`/`AVQueuePlayer`/`AVPlayerItem`/`AVPlayerLayer`/`NWConnection`/`nw_listener` counts plateau.
- A leak becomes its own fix item.

---

## 7. New probes and knobs (summary)

| Name | Kind | Owner | Where |
|---|---|---|---|
| `[TrailerPipeline] gate …`, `morph stage= …` | NSLog, `TrailerProbe.enabled` | W1-A | ITC model |
| `debug_trailerTile … stage= gate= gateRest= gateStart= via= ring=` | AX label, DEBUG, append-only | W1-A (+W2-D `ring=`) | ITC |
| `debug_trailerMorph` (`event=gate/reveal/wide/shrink/dissolve/abort/defer/play/mute`, `host=card|hero`) | AX label, DEBUG | W1-A writes / W2-E leaf renders | `InlineTrailerDebugLog` |
| `debug_trailerListener` | AX label, DEBUG | W1-C writes / W2-E leaf renders | `TrailerListenerDebug` |
| `debug_heroText … maxLive=` | AX label, DEBUG | W2-E | `HeroTextLayer` |
| `hero_info` | accessibility identifier (all builds) | W2-E | `HomeHeroForeground` |
| `present … logoInk=`; `logoInk sync-sample ms=` | `[HomeHero]` probe (append-only last field); one-shot | W2-E | `HeroArtResolver` |
| `[TrailerRepack] listener …`, `playbackURL slow/timeout …` | NSLog, unconditional | W1-C | `TrailerLocalHLS` |
| `-debug.trailerMorphAbortAfterRevealMs`, `…AfterWideMs`, `-debug.trailerAbortWindowMs` | DEBUG launch knobs | W1-A | ITC model |
| `-debug.trailerListenerFault`, `-debug.trailerListenerLifecycleCycleAfterS` | DEBUG launch knobs | W1-C | `TrailerLocalHLS` |
| `trailer_start_delay` | user setting, device-local | W1-A enum, W2-D row, W2-F description | — |

---

## 8. UI legs (W4-G)

All new legs go in the new file `NuvioTVUITests/TrailerMotionUITests.swift`, with the helpers copied per the house rule (`InlineTrailerTileProbeTests.swift:12-14`). They use the numbers test85–test91, plus house-style `…B` suffixes. P-B starts at test92.

| Leg | Item | Proves |
|---|---|---|
| test85TrailerStartsAfterRest | M3 | `via=rest`, start ≥ rest + 0.95 s (Automatic) |
| test85BHeroLocationMuteToggle | M3 / #1 | Play/Pause mutes the hero-location trailer (`event=mute`, `muted=` flips) |
| test86MorphAbortIsInstant | R2 / #7 | card #2 shifted > 20 pt, then `style=instant`, then back to baseline ± 2 |
| test86BRevealAbort | R2 / #7 | a reveal-stage abort is instant and card #2 never moved |
| test87MorphedRingKeepsPosterColour | R1 | `ring=poster` (skips on grey art) |
| test88TrailerStartDelaySetting | M4 | row present; `gate=2`, start ≥ 2.0 s |
| test89HeroTextNeverDoubles | M5 / #8 | `maxLive=1`, `swaps ≥ 6`; `hero_info` ≤ 1 as a smoke check |
| test90HeroHoldsFolderOnReturn | M5 / #8 | seeded folder; `pitem=` holds after a pop; `[]` teardown |
| test91TrailersSurviveBackground | B2 / #9 | `-debug.trailerListenerFault silent -debug.trailerListenerLifecycleCycleAfterS 8`; then `debug_trailerListener` shows `rebuild reason=active`, and a new card's `debug_trailerMorph event=play` arrives within 12 s. No `press(.home)` / `activate()`. |

**Existing legs pinned to `-trailer_start_delay 1`** (arguments only, critique #19):
- `NuvioTVUITests.swift` test01, test28, test37 and test41;
- `TrailerSoakTests.launchArguments`;
- `InlineTrailerTileProbeTests.launchArguments` (`:66-77`);
- `GuestTrailerRevealScratchTests`;
- `RowLeadingEdgeTests`.

test41's window is 20 × 0.5 s = 10 s (`NuvioTVUITests.swift:3790-3800`). That is longer than `restCeiling` (3 s) plus the 1 s delay, so the gate always fires inside it and the pin alone keeps it meaningful (see §11 #19).

**Harness facts:**
- Frames ignore `.offset` / `.opacity`, so opacity facts come from DEBUG labels. LAYOUT changes do show in frames (test86 relies on that).
- `hasFocus` is unreliable.
- FA87 is a signed-out guest (Cinemeta, local "Chris") with no collections unless seeded.
- YouTube extraction may answer `LOGIN_REQUIRED`: every trailer leg XCTSkips with "trailer extraction unavailable on this host" when no `event=play` / `debug_trailerTile` appears.
- Reboot the simulator after about 6 UI runs.

---

## 9. File ownership and waves (the critique's merged plan, P-A side)

### 9.1 P-A agents

| Wave | Agent | Tier | Items | Files (exclusive in the wave) | Depends on |
|---|---|---|---|---|---|
| W1 | **W1-A** | Opus | M3 (gate, subject + per-row `rowPlayingKey` mute fix, horizontal-only morph scroll, motion stamps) + R2 (stages, tile art per #6, abort, knobs) | `Screens/TrailerStartGate.swift` (new), `InlineTrailerCard.swift`, `BrowseComponents.swift` (`CatalogRowView` only, `:4750-5130`), `SearchView.swift`, `NuvioTVTests/TrailerStartGateTests.swift`, `InlineTrailerMorphPlanTests.swift` | — |
| W1 | **W1-C** | Sonnet | B2 listener core (#4, #5), outcome and legacy APIs, `servableURL`, probes, `TrailerListenerDebug`, fault knobs incl. the #9 cycle knob | `TrailerLocalHLS.swift`, `TrailerDebugProbes.swift`, `NuvioTVTests/TrailerLocalHLSListenerTests.swift` | — |
| W1 | (W1-B) | — | spec B: I1 core | spec B's files | — |
| Gate 1 | main | — | Debug build, NuvioTVTests. Simulator probe lines (critique #27): `gate … via=`, `morph stage=`, a Play/Pause mute in both locations on a manual walk, and the B1 knob recipe. No UI legs yet. | — | W1 |
| W2 | **W2-D** | Sonnet | R1; B2's ITC call sites (§6.3); tile-art decode size + `cachedLargest` poster fallback (#3); M4 row (id only, #16) | `InlineTrailerCard.swift`, `Settings/HomeScreenSettingsPane.swift`, `NuvioTVTests/InlineTrailerTileTintTests.swift`, outcome-mapping tests | W1-A, W1-B, W1-C |
| W2 | **W2-E** | Opus | M5 (`TextSwapModel` + `HeroTextLayer` leaf observation #11, cover freeze, logo ink #10, #25) + the three M3 HomeView hooks + DEBUG leaf labels | `HomeView.swift`, `Screens/Home/HeroTextSwap.swift` (new), `Screens/Home/HeroLogoInk.swift` (new), `HeroTextSwapModelTests`, `HeroLogoInkTests`, `HeroFocusCoverTests` | W1-A, W1-C (`TrailerListenerDebug`) |
| W2 | (W2-F) | — | spec B: F + C + **all `SettingsDescriptions.swift` edits, including M4's case and copy exactly as §4.3** | spec B's files | — |
| Gate 2 | main | — | build, NuvioTVTests (incl. `SettingsDescriptionsTests`, which needs D's literal and F's case together) | — | W2 |
| W4 | **W4-G** | Sonnet | UI legs test85–91 (+85B/86B), pins per #19 | `NuvioTVUITests/TrailerMotionUITests.swift` (new), `NuvioTVUITests.swift` (arguments only: test01/28/37/41), `TrailerSoakTests`, `InlineTrailerTileProbeTests`, `GuestTrailerRevealScratchTests`, `RowLeadingEdgeTests` | W2-D, W2-E, W2-F |

W3 holds only spec B agents (T1 / Detail / A). W4-H (spec B's I1 hero work) edits `HomeView.swift` after W2-E.

### 9.2 Cross-spec notes the main session sequences

1. **`BrowseComponents.swift`.** W1-A owns `CatalogRowView` in W1. W2-F's two edge lines and W3-T's `PinnedRowSettle` come later. W1-A's fallback path only CALLS `noteExternalScroll`.
2. **`HomeView.swift`.** W2-E in W2; W4-H (spec B's hero sharpen) in W4.
   - W4-H's post-commit sharpen is a same-identity `presented` update; `TextSwapModel` treats it as a silent gap-fill (§5.2).
   - W4-H must carry `logoInk` through any new commit path it adds.
3. **`SettingsDescriptions.swift`.** W2-F only, with §4.3's text.
4. **`ArtworkStore`.** W1-A codes the tile-art loader against today's API (source-compatible in spec B). W2-D upgrades it to spec B's `ArtworkDecodeRequest` / `cachedLargest` after W1-B lands (critique #3).
5. **Stage & Strip batch:** reuses `RowRestSource.custom`, the subject-based mute path, `TrailerStartDelay`, `TextSwapModel(timing: .stage)`, and R1/R2 unchanged.

---

## 10. Christian's answers (2026-10-03) and remaining questions

- **Trailer Start Delay fixed values count from focus, never before the rows stop.** Kept exactly as §1.3/§4.2. Automatic is rest + 1 s. The consequence the critique noted, that "2 s" can start sooner than Automatic after a Down press, is accepted by this answer.
- **TMDB title logos move to `original`** (spec B owns the URL change). Impact on M5: none on the thresholds; the per-URL ink memo refills for the new URLs. The sync-sample cost on a cache-warm logo is logged once on device (§5.5).
- **Nothing open for Christian in spec A.**

---

## 11. Revision r2

| Critique # | Decision | Where in the spec |
|---|---|---|
| 1 (P1) | **Fixed** as proposed. The key is published through `CurrentValueSubject`; each row `.onReceive`s and writes `rowPlayingKey` only for its own items. `onPlayingChange` was dropped. A new leg checks hero-location mute. That leg is test85B in the new file rather than a change to test37's body, because W4-G is limited to argument changes in `NuvioTVUITests.swift`. | §1.1.3, §1.5, §1.6.1, §1.8, §1.9, §1.10, §1.11, §8 |
| 2 (P1, spec B) | Not spec A. Noted: the post-commit sharpen is a same-identity silent gap-fill for the text model, and W4-H must carry `logoInk`. | §5.2, §9.2.2 |
| 3 (P2) | **Fixed** on A's side. W1-A uses today's API. W2-D switches the poster fallback to `cachedLargest` and the banner to the tile pixel decode. R1's colour lookup goes through `cachedImage(for:)` → `cachedLargest`. | §2.3, §3.2, §9.2.4 |
| 4 (P2) | **Fixed.** Verify before rebuild on `.active`. The rebuild waits for `.cancelled` (≤ 0.5 s) and retries the same port 3× at 100 ms. `.waiting` holds until the 2 s attempt deadline, then moves to the next port. The `waiting` knob is redefined. Tests and B1 are aligned. Added `servableURL` port rebasing, so a port drift never forces YouTube re-extraction. | §6.2 items 2–5, 10; §6.3; §6.4; §6.5 |
| 5 (P2) | **Fixed.** The legacy API has no outer timeout (Detail unchanged). The ITC timeout is 12 s. Both log `slow` > 6 s. | §6.2 item 8, §6.4 |
| 6 (P2) | **Fixed.** The prefetch starts at the first rest reading or 0.3 s in, with `.normal` admission and no request timeout. The 1 s deadline is `beginMorph`'s await. | §1.3, §1.4, §2.3 |
| 7 (P2) | **Fixed.** Abort knobs count from the `.wide` edge, and the abort-window override makes the shift observable first. A separate reveal-abort leg was added. | §2.4, §2.7, §8 |
| 8 (P2) | **Fixed.** test89's oracle is `maxLive` from the info block's appear/disappear counter, a value a cross-dissolve regression raises. `hero_info` is kept as a smoke check. test90 is seeded through spec B's helper, with the `[]` teardown. | §5.2, §5.3, §5.9, §8 |
| 9 (P2) | **Fixed.** An in-process lifecycle cycle knob replaces `press(.home)` + `activate()`. `TrailerListenerDebug` gives the leg an AX oracle. | §6.2 items 9–10, §5.6, §8 |
| 10 (P2) | **Fixed.** `.dark` only for luma < 0.08 and chroma < 0.12. Red, blue and Netflix red stay legible (tests). Sampling is now 32×32 area-averaged. | §5.5, §5.8 |
| 11 (P2) | **Fixed.** The model is owned and observed by the `HeroTextLayer` child. DEBUG labels render in leaf views. HomeView's body observes nothing new. | §5.3, §5.6 |
| 12–15 (P2, spec B) | Not spec A. | — |
| 16 (P2) | **Fixed.** W2-F adds the case and copy verbatim (§4.3). W2-D writes only `descriptionID: .homeTrailerStartDelay`. | §4.3, §9.1 |
| 17 (P2) | **Fixed.** Adopted the merged wave plan and its agent names. | §9 |
| 18 (P3, spec B) | Not spec A. | — |
| 19 (P3) | **Fixed with one partial decline.** test28, test41 and `RowLeadingEdgeTests` are pinned. test41's window is NOT re-derived from the gate line: its 10 s window already exceeds the 3 s gate ceiling plus the delay, and W4-G is arguments-only in that file. | §8 |
| 20 (P3, plan doc) | Not spec A. Main session to rewrite plan device-pass items 1 and 7. | — |
| 21–23 (P3, spec B) | Not spec A. | — |
| 24 (P3) | **Fixed.** Uses `visibleRect.minX` + `insetLeading`; unit case with a 60 pt inset. | §1.6.3, §1.6.5, §1.10 |
| 25 (P3) | **Fixed.** `mainQueueSchedule` is a static func. `logoInk` is a `var` with a default. `hostsTile = true` and `tileArtSource` are set in `.onAppear` before `focusChanged(true…)`. | §1.4, §2.3, §5.2, §5.5 |
| 26 (P3) | **Fixed** as a device-tune item with a named log to read. | §2.2, §2.5 |
| 27 (P3) | **Fixed.** Gate 1 runs unit tests plus simulator probe lines; the legs run at the final gate. | §9.1 |
| 28 (P3, spec B) | Not spec A. | — |
| 29 (P3) | **Fixed.** Copy: "…trailers on posters and in the hero wait…" (deslop 5/5). | §4.3 |
| 30 (P3) | **Fixed.** Stage P1 brief note: wrap `TextSwapModel(timing: .stage)` and drive the stage art from `shown`. | §1.8 |

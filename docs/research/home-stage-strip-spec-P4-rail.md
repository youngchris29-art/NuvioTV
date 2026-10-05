# Home Stage & Strip · P4 spec: the navigation rail (H9, FEAT-45)

**Status:** design spec for W2-D (Opus) and the rail half of W3. Written 2026-10-05 against base `d68b9d61` (clone `~/Claude/Projects/NuvioMobile-home-stage`). Paths are relative to `NuvioMobile/iosApp/NuvioTV/` unless noted. No code was changed to write it.

**Binding inputs:** plan `docs/home-stage-strip-plan-2026-10-03.md` (H9, "Navigation rail (H9)", W2-D, Risk 7, device steps 14–16, Spike verdict); Search S1 W2 (`docs/search-s1-native-search-plan-2026-10-04.md`); spike rail `NuvioMobile-stage-spike@035095a4` `DesignSystem/SpikeRail.swift`.

**Corrections after the P3 critique (2026-10-05)**
- #8: in Stage, Hide While Browsing moves with the strip's page (`setScrolledDown(…, motion: .page)`, the page's curve and duration, no resting settle) (§1.3, §5.2, §6.2).
- #12: W2-D starts after W2-A, W2-B and W2-C have all landed; `SettingsDescriptions.swift` goes W1-C → W2-C → W2-D; `Localizable.xcstrings` changes only through the scripts, once, at the end (§7.1).
- #13 / R1: `.railTabRoot` also publishes `\.railLeadingInset` (36 or 0), which P1 declares. Stage and the folder Rows page ignore the safe area and read it instead (§0 R3, §5.1, §5.2).
- #14 / R2: Stage's route (row key captured, `requestFocus(rowKey:itemId:)` restore) uses P1 §1.5's seams. `FolderRowsPage` registers the same route, and the background trailer stops on `isFocusedChrome` (§2.5, §6.2).
- R3, R4: Menu routing restated (§2.2, §6.2); the row-index write owns the rail, and the strip's mirror stays for the probe (§6.2).
- #20: the expand animation honours Reduce Motion (§1.2).
- #21: the Settings root registers a route that arms its one-shot landing correction (§2.5, §6.2).
- #22: the Appearance pane hides Hide Hero Artwork While Browsing in Stage (§4.1).
- Critique Q2, Q6 and Q7 are decided, which settles this spec's own Q1–Q3 and R7. Its Q4 is resolved; Q5 and Q6 wait for Probe G and the device (§0, §8).

## 0. Decisions this spec makes

| # | Decision | Why |
|---|---|---|
| R1 | **Right returns to the current tab; Select switches tab.** Select on the current tab's item = Right. | The highlight never changes the page behind the dim (no live switching), so Right goes into the page you can see, and an Up/Down overshoot can't become a tab switch. Christian walked this on the device in the spike. |
| R2 | **Content gate = one UIKit flag at the shell:** `isUserInteractionEnabled = false` on the `UITabBarController`'s view while the rail holds focus. The spike's per-root `.disabled` is the specified fallback (§2.3). | One site covers every tab root, every pushed page and the UIKit-hosted Search keyboard. The Grid keyboard (x 80…512, y 261…1011, S1 spike log) is a geometric neighbour of the centred rail, out of `.disabled`'s reach. No SwiftUI invalidation, no `.disabled` side effects on `.searchable`. |
| R3 | **Always Visible inset = +36 pt of leading safe area** (`.safeAreaPadding`) on every tab root: content 140 → 176 pt from the bezel; full-bleed art still reaches x = 0. Stage and the folder Rows page ignore the safe area, so they read the same 36 pt from `\.railLeadingInset` (R1, §5.1). Kept for this beta (Q6). | The rail reserves `16 + 84 + 16 = 116`; the side safe area is 80, so the extra is 36. Each screen keeps its 60 pt margin from the new edge, and the system keyboard (anchored at x = 80) moves clear. |
| R4 | **Menu inside the rail depends on how it opened.** By **Left**: Menu closes it. By **Menu** or the hidden-bar redirect: no handler, so the system suspends the app. **Decided 2026-10-05 (critique Q2).** | "Menu closes it" alone leaves no Menu exit from the app (root → rail → content → rail). The split keeps FEAT-30's grammar and the plan's close for a Left entry. One pure function. |
| R5 | **Restoration tiers:** Home (Classic and Stage), the folder Rows page and Detail register SwiftUI-side return routes, and the Settings root registers one that arms its landing correction (§2.5); every other surface returns to its default focus (`resetFocus(in:)` + the S1 ladder). | Spike verdict: SwiftUI-side only. A Left entry always comes from the leftmost item (card 0 of a row), so "first card of the remembered row" is exact for it. |
| R6 | **Migration:** `sidebar_style` `"sidebar"` → `"rail"`, read from the persistent domain only; `"sidebar"` also reads as Rail. | A `-sidebar_style sidebar` launch arg lives in the argument domain and must not be persisted. The key is device-local, never synced (no reference in `shared/` or any sync blob). |
| R7 | **Hide While Browsing** treats the Search tab and immersive pushes (Detail) as browsing. **Decided 2026-10-05 (critique Q7).** | The Grid keyboard occupies the left edge; Detail is "into a title" (FEAT-30's immersive hide). |

## 1. Files, types, numbers

### 1.1 New `DesignSystem/NavigationChrome.swift` (pure, unit-tested)

```swift
import UIKit   // UIFocusHeading only

nonisolated enum NavigationChrome {
    static let styleKey = "sidebar_style"            // kept: device-local, never synced
    static let railVisibilityKey = "rail_visibility" // new: device-local
    static let legacySidebarValue = "sidebar"

    enum Style: String { case tabs, rail }
    enum RailVisibility: String { case always, whileBrowsing = "browsing" }

    static func style(raw: String?) -> Style                // "rail" | "sidebar" → .rail, else .tabs
    static func style(_ d: UserDefaults = .standard) -> Style
    static func isRail(_ d: UserDefaults = .standard) -> Bool
    static func railVisibility(raw: String?) -> RailVisibility   // "browsing" → .whileBrowsing, else .always
    static func railVisibility(_ d: UserDefaults = .standard) -> RailVisibility
    static func reservesWidth(_ d: UserDefaults = .standard) -> Bool   // isRail && .always

    /// Once per launch from NuvioTVApp.init (next to RowEdgeFadeSetting.migrateLegacy, :84).
    /// Reads `d.persistentDomain(forName: domain)?[styleKey]`; if it is exactly "sidebar", writes
    /// "rail". Returns whether it wrote. Never touches the argument domain or rail_visibility.
    @discardableResult
    static func migrateLegacy(_ d: UserDefaults, domain: String) -> Bool

    /// R3. `max(0, RailMetrics.reservedEdge − sideSafeArea)` when `reservesWidth`, else 0.
    static func contentSafeAreaExtra(sideSafeArea: CGFloat, reservesWidth: Bool) -> CGFloat
    /// `RowEdgeMargins(leading: RowSoftEdgeMask.margin + extra, trailing: RowSoftEdgeMask.margin)`.
    static func rowEdgeMargins(sideSafeArea: CGFloat, reservesWidth: Bool) -> RowEdgeMargins
    static var topCompensation: CGFloat { Theme.Size.sidebarTopCompensation }  // still ships 0
}

nonisolated enum RailOpenReason: String, Equatable { case left, menu, hiddenBarRedirect, rearm }

nonisolated enum RailFocusPolicy {
    /// A failed move opens the rail only if every condition holds.
    static func shouldArm(heading: UIFocusHeading, railMode: Bool, railHoldsFocus: Bool,
                          originInTabContent: Bool, presentedOverShell: Bool, vetoed: Bool) -> Bool
    // = heading.contains(.left) && heading.isDisjoint(with: [.up, .down]) && railMode
    //   && !railHoldsFocus && originInTabContent && !presentedOverShell && !vetoed

    enum InRailMove: Equatable { case exitToContent, contained }
    static func moveFailedInRail(heading: UIFocusHeading) -> InRailMove   // .right → exit, else contained

    enum MenuInRail: Equatable { case closeToContent, systemDefault }
    static func menuInRail(openedBy: RailOpenReason) -> MenuInRail        // .left → close, else system (R4)

    enum SelectAction: Equatable { case switchTab(Int), returnToCurrent }
    static func select(item: Int, currentTab: Int) -> SelectAction
}

nonisolated enum RailVisibilityRule {
    struct Inputs: Equatable {
        var railMode, holdsFocus, revealed, rootCoverActive, immersive, scrolledDown: Bool
        var visibility: NavigationChrome.RailVisibility
        var selectedTab: Int
    }
    /// Precedence: !railMode → false; holdsFocus → true; rootCoverActive → false; revealed → true;
    /// .always → true; (.whileBrowsing) immersive → false; selectedTab == 1 → false;
    /// scrolledDown → false; else true.
    static func shown(_ i: Inputs) -> Bool
}
```

### 1.2 `RailMetrics` (private to `NavigationRail.swift`, mirrored as `static let`s on `NavigationChrome` where the math needs them)

| Constant | Value | Notes |
|---|---|---|
| `bezelInset` | 16 | pill's leading edge from the screen edge (plan); kept for this beta (Q6) |
| `collapsedWidth` | 84 | |
| `expandedWidth` | 300 | grows rightward only; height unchanged so no item moves vertically |
| `contentGap` | 16 | |
| `reservedEdge` | **116** | `bezelInset + collapsedWidth + contentGap` |
| `innerPadding` | 12 | horizontal |
| `verticalPadding` | 22 | |
| `itemPlatter` | 60 | circle behind the glyph; the selected tab's is filled |
| `iconSize` | 36 | `Image(systemName:).resizable().scaledToFit().frame(36×36)`: no `Font.system(size:)` at the call site (HIG Typography) |
| `itemSpacing` | 14 | |
| `avatarGap` | 18 | extra top padding above the avatar |
| `labelGap` | 18 | |
| `cornerRadius` | 42 | `collapsedWidth / 2` |
| pill height | **492** | `2·22 + 6·60 + 5·14 + 18`; centred: y 294…786 on 1080 |
| `dimOpacity` | 0.55 | full screen, behind the pill, only while expanded |
| `expandDuration` | 0.20 s | ease-out; Reduce Motion → no width animation, the labels and dim cross-fade (#20) |
| `slideDuration` | 0.25 s | Hide While Browsing; Reduce Motion → opacity only. Stage's `.page` writes use the page's own duration instead (§5.2) |
| `restingShowSettle` | 0.35 s | kept from `SidebarMetrics` (SidebarOverlay.swift:234); never for Stage's `.page` writes |
| `exitVerifyDelay` | 0.5 s | route restore fallback (spike `exitToContent`, SpikeRail.swift:216) |

**Clearance check (unit-tested):** Always Visible puts content at 80 + 36 + 60 = 176. The widest row lift is a Saga card at ≈30 pt per side (500 × 0.1212 / 2, `cardSystemLiftScale`), so 146 ≥ 116. Hide While Browsing puts content at 140, so 110 > 100 (the pill's trailing edge). The overlay never covers a focused first card at rest in either mode.

### 1.3 `NavigationChromeModel` (replaces `SidebarChromeModel`, SidebarOverlay.swift:56–91)

Same ownership rule as today: `@State` on `MainTabView` (ContentView.swift:370), never `@StateObject`, and only the rail observes it (T3 / BUG-66).

```swift
@MainActor final class NavigationChromeModel: ObservableObject {
    @Published var scrolledDownByTab: [Int: Bool] = [:]       // unchanged semantics
    @Published private(set) var revealRequest = RailRevealRequest(generation: 0, reason: .menu)
    @Published var isFocusedChrome = false                      // unchanged
    private(set) var motionByTab: [Int: RailMotion] = [:]       // not published; read with the change
    nonisolated init() {}
    func setScrolledDown(tab: Int, _ v: Bool, motion: RailMotion = .scroll)   // write-on-change, as today (#8)
    func requestReveal(_ reason: RailOpenReason)                // generation &+= 1
    func setFocusedChrome(_ f: Bool)
    // Return routes: NOT published. A LIFO stack per tab, keyed by token.
    func pushReturnRoute(tab: Int, token: UUID, _ route: RailReturnRoute)
    func removeReturnRoute(tab: Int, token: UUID)
    func topReturnRoute(tab: Int) -> RailReturnRoute?
}
struct RailRevealRequest: Equatable { var generation: Int; var reason: RailOpenReason }
nonisolated enum RailMotion: Equatable { case scroll; case page(seconds: TimeInterval) }   // .page: Stage's strip (§5.2)
struct RailReturnRoute {
    let capture: @MainActor () -> Void        // called at arm time, focus still on the origin
    let restore: @MainActor () -> Bool        // true = issued a SwiftUI focus write
    let vetoesLeftArm: @MainActor () -> Bool  // an app-handled Left owns this press
}
```

Environment: `\.navigationChrome` (replaces `\.sidebarChrome`, SidebarOverlay.swift:97–109; same fallback-instance pattern) and new `\.railTabIndex: Int?` (default `nil`), so a pushed page knows its tab.

### 1.4 New `DesignSystem/NavigationRail.swift`

```swift
struct NavigationRail: View {
    @Binding var selectedTab: Int
    let activeProfile: NuvioProfile?
    let rootCoverActive: Bool
    let shellFocusScope: Namespace.ID
    @ObservedObject var chrome: NavigationChromeModel
    let tabBarVisibility: TabBarVisibility   // plain let + onReceive($immersiveHidden), as SidebarOverlay.swift:274
    @AppStorage(NavigationChrome.railVisibilityKey) private var visibilityRaw = "always"
    @Environment(\.resetFocus) private var resetFocus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var armed = false
    @State private var openedBy: RailOpenReason?
    @State private var revealed = false
    @State private var immersiveHidden = false
    @State private var restingShown = false
    @State private var restingGeneration = 0
    @State private var focusGeneration = 0
    @State private var rescueGuard = StrandedRescueGuard()
    @FocusState private var focusedItem: Int?
}
```

**View tree:**

```
ZStack(alignment: .leading)
├─ if expanded: Color.black.opacity(0.55).ignoresSafeArea().allowsHitTesting(false)   // dim
└─ if shown: pill.padding(.leading, 16)
      VStack(alignment: .leading, spacing: 14)
      ├─ ForEach(RailItem.tabs)  // ids 0…4: Home, Search, Library, Add-ons, Settings
      └─ item(RailItem.profile).padding(.top, 18)   // id 5 = the Profile tab, drawn as ProfileAvatar(size: 60)
      .padding(.vertical, 22).padding(.horizontal, 12)
      .frame(width: expanded ? 300 : 84, alignment: .leading)
      .background(alignment: .leading) {      // GLASS BEHIND, never around (Orivio trap)
          RoundedRectangle(cornerRadius: 42, style: .continuous).fill(.clear)
              .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 42, style: .continuous)) }
      .focusSection()
      .onExitCommand(perform: menuHandler)    // non-nil only when openedBy == .left (R4)
      .accessibilityElement(children: .contain).accessibilityIdentifier("navigation_rail")
.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).ignoresSafeArea()
.background { HiddenTabBarFocusBlocker(onFocusLandedInHiddenBar: revealForStrandedFocus) }  // 0×0
.overlay(alignment: .topLeading) { stateProbe }   // DEBUG, ALWAYS mounted (its `shown=` token is the hide test)
```

**Items:** `RailItem` replaces `SidebarItem` (SidebarOverlay.swift:115–140) with the same ids, the same English titles as keys, and the same SF Symbols. Armed: a native `Button { select(item) } label: { itemLabel }` with `.buttonStyle(.borderless)` and `.focused($focusedItem, equals: item.id)`. Not armed: the same `itemLabel`, not focusable. The id is `rail_item_<title>` either way (`rail_item_Home` … `rail_item_Settings`, `rail_item_Profile`). `itemLabel` is an HStack(spacing 18): a 60 pt ZStack, plus `Text(localizedTitle).font(Theme.Font.body)` only while expanded. In that ZStack the selected tab's circle is `Theme.Palette.accent` (selection state: brand allowed), with the glyph in `accentText`, otherwise `textPrimary`. For the profile item the label is the profile's name, with an accent ring when tab 5 is selected (contract: "profile avatars ring"). No custom `ButtonStyle`: the FEAT-30 `SidebarItemButtonStyle` carve-out leaves the HIG contract (§6.3).

**State probe** (`rail_state`, DEBUG, append-only): `rail_state armed=%d expanded=%d focused=%d reason=%@ gated=%d vis=%@ shown=%d tab=%d route=%@ inset=%d`. `focused` is the `@FocusState` value (−1 = none), which is readable on the tvOS 27.0 simulator where `hasFocus` is not.

Logs, all `NSLog("[NavRail] …")`: `arm reason=… origin=<type>`, `contained heading=…`, `exit via=right|menu|select route=home|detail|none result=focus|fallback`, `veto origin=hero-carousel`, plus the existing hand-off and rescue lines.

## 2. Focus graph

### 2.1 States

| State | Pill | Buttons | Gate | Dim |
|---|---|---|---|---|
| Rest | shown per `RailVisibilityRule` | labels, unfocusable | open | no |
| Armed (≤ 0.45 s) | shown | Buttons, focus being taken | open | no |
| Focused | shown, 300 pt, labels | Buttons, one focused | **closed** | 0.55 |
| Exiting | shown | Buttons until focus leaves | open | fading |

**Invariant:** gate closed ⇔ `focusedItem != nil`. It is driven only from `.onChange(of: focusedItem)`: non-nil → `setFocusedChrome(true)` and `RailContentGate.set(true)`; nil → `setFocusedChrome(false)`, `RailContentGate.set(false)`, `armed = false`, `revealed = false`, `openedBy = nil`. A cover, alert or popover that takes focus therefore always reopens content.

### 2.2 Arming (entry)

| Trigger | Where | Reason | Notes |
|---|---|---|---|
| A failed **Left** | `.onReceive(NotificationCenter.default.publisher(for: UIFocusSystem.movementDidFailNotification))` on the rail; read `UIFocusUpdateContext` from `userInfo[UIFocusSystem.focusUpdateContextUserInfoKey]` | `.left` | `RailFocusPolicy.shouldArm`. `originInTabContent` = `HiddenTabBarFocusBlocker.focusItemIsInTabContent(context.previouslyFocusedItem)` (§2.3). `presentedOverShell` = the window root's `presentedViewController != nil`. `vetoed` = `topReturnRoute(tab: selectedTab)?.vetoesLeftArm() ?? false`. Never `.onMoveCommand`, which fires on every press (Orivio lesson 7). Swipe momentum didn't fire it on hardware (spike). |
| **Menu** at a tab root | `.railMenuReveal()` on Search/Library/Add-ons/Settings root/Profile; Home's `railMenuRevealHandler`; Stage's exit handler at row 0 | `.menu` | unchanged grammar: on Home, Menu from down the page still scrolls or pages to the top first |
| Focus lands in the hidden bar | `HiddenTabBarFocusBlocker.onFocusLandedInHiddenBar` → `revealForStrandedFocus` | `.hiddenBarRedirect` | S1 carry (§3) |
| Hand-off landed nowhere | last ladder check | `.rearm` | SidebarOverlay.swift:590–597 |

**Arm sequence:** `topReturnRoute(tab:)?.capture()` → `armed = true` → `openedBy = reason` → `takeFocusAfterReveal()`. That function is ported from SidebarOverlay.swift:629–656: async write, a 0.15 s retry, fail-closed after 0.3 s, `rescueFailed` stamping. It always targets `selectedTab`'s item, whether the rail is shown or slid out: focus wins over every hide term.

**Veto:** Classic Home's carousel CTA pages on a Left with no target (`HeroCarouselInteractionModifier`, HomeView.swift:3198–3208; `heroCarouselActive` :275). Home's route vetoes while `heroFocused && heroCarouselActive`. There, Menu at the top opens the rail instead.

### 2.3 The content gate

`RailContentGate.set(_ gated: Bool)` calls `HiddenTabBarFocusBlocker.current?.setContentGated(gated)`. New members on the moved `BlockerView`:

```swift
private weak var tabController: UITabBarController?   // cached in apply()
func setContentGated(_ gated: Bool) {
    guard let tab = tabController else { return }
    // The rail is an overlay of the TabView, so its host is NOT inside tab.view. If this blocker
    // (mounted in the rail) ever is, gate only the selected tab's view instead.
    let target = isDescendant(of: tab.view) ? tab.selectedViewController?.view : tab.view
    target?.isUserInteractionEnabled = !gated
}
static func focusItemIsInTabContent(_ env: UIFocusEnvironment?) -> Bool
// Walk parentFocusEnvironment until a UIView; true iff it is a descendant of tab.view and
// !isInBlockedBar(view). Fail closed (false) when unknown.
```

`restore()` (SidebarOverlay.swift:797–809) also ungates. The tab bar keeps its own disabled flag, so ungating `tab.view` never makes the hidden bar focusable again.

**Probe G (W2-D step 8; decides the mechanism):** on FA87, with the rail open from Classic Home, from Search with the keyboard up, and from a pushed Detail: press Down ×8, Up ×8, then Right. Pass = `rail_state focused` stays in 0…5 through the Down and Up presses and nothing in content reports focus; Right exits. **Fallback if any leak:** delete the UIKit gate and add `RailContentGateModifier` (`@Environment(\.navigationChrome)`, `@State gated`, `.onReceive(chrome.$isFocusedChrome) { gated = $0 }`, `.disabled(gated)`) to each Tab closure inside `.railTabRoot` (§5.1). This is the spike's device-proven mechanism (StageStripSpike.swift:273), and it may leave the Search keyboard ungated (Q5).

### 2.4 Inside the rail

| Input | Result |
|---|---|
| Up / Down | the engine moves between items; past either end it fails, `moveFailedInRail` → `.contained`, logged, no-op |
| Left | fails, contained |
| **Right** | fails (content is gated) → `.exitToContent` → **exit, current tab** (R1) |
| **Select** on another item | `selectedTab = id`, then exit to that tab |
| Select on the current item | exit to the current tab (same as Right) |
| **Menu** | `menuInRail(openedBy:)`: `.left` → exit to the current tab; anything else → no handler, system default (suspend) (R4) |

### 2.5 Exit and restoration

```
exit(to tab: Int, via: …):
  1. RailContentGate.set(false)                      // content focusable again, rail still focused
  2. if let route = chrome.topReturnRoute(tab: tab), route.restore() {
         // SwiftUI focus write in content; the engine moves focus off the rail →
         // focusedItem = nil → disarm (2.1). Verify:
         after 0.5 s: if focusedItem != nil { fallbackHandOff(tab) }
     } else { fallbackHandOff(tab) }

fallbackHandOff(tab):                                 // SidebarOverlay.handOffFocusToContent, :551–601
  guard HiddenTabBarFocusBlocker.isBlocking else { stay in rail; log }
  armed = false; focusedItem = nil; revealed = false; focusGeneration &+= 1
  next turn: resetFocus(in: shellFocusScope)
  checks = SidebarHandOffLadder.checks(forTabTitled: RailItem.title(for: tab))   // 2.5 s on Search
  per check: if focus nil → resetFocus again; at last → armed = true, reveal(.rearm)
```

**Restore per surface:**

| Surface | Route | Lands on |
|---|---|---|
| Home, **Stage** | registered by `StageStripHome` (R2, P1 §1.5) | the current row's remembered card |
| Folder **Rows** page (P2) | registered by `FolderRowsPage`, the same shape as Stage's (R2); without it Right would land on default focus (the Edit band, or row 0) and the strip would page away | the current row's remembered card |
| Home, **Classic** | registered by `HomeView` (§6.2) | hero CTA if it held focus; otherwise `PinnedRowFocusRequest(rowKey: lastOwnedRowKey)`, the existing seam (PinnedRowUpFallback.swift:22–30, applied by every row at :76–105), whose first card is the Left origin |
| **Detail** (any tab) | registered by `DetailView` on appear, removed on disappear (beside `push/popImmersive`, :1194–1196); tab from `\.railTabIndex` | `heroFocus` captured at arm (`.play`, `.trailer`, …; :508); returns false for Detail rows → default |
| Search | none | default focus = the system keyboard, waiting up to 2.5 s (ladder) |
| Settings root | registered by `SettingsRootView` (#21): `restore` arms its one-shot landing correction (`landingCorrectionArmed`, SettingsRootView.swift:66, :112–120) and returns false | the fallback hand-off lands in the `List`, and the correction moves focus to `lastCategory`. The root's own focus-graph doc (:11–33) records that a freshly built tvOS `List` doesn't honour default focus on its own, which is why the correction exists, and nothing arms it on a rail exit today |
| Library, Add-ons, Profile, Settings panes, folder Grid page, See All, person pages | none | the screen's default focus (P4 Q4, accepted for this beta; device step 14 reads against this table) |

Home's routes (Classic and Stage) return false while Home is covered: `!homePath.isEmpty` (HomeView.swift:156) or `resume != nil`. The folder Rows page's route, like Detail's, is pushed on appear and removed on disappear, which a push over the page triggers. Routes are a LIFO per tab, so a folder Rows page over Home puts its own route on top, and a page with no route falls to the default.

**From P1 (§1.5, R2):** `PinnedRowFocusRequest.itemId` (P1 §3.3) and the controller's `currentRowKey`, `memory` and `requestFocus(rowKey:itemId:)`, which issues P1's rungs. Stage's route is `capture: { savedRow = stage.currentRowKey }`, then `restore: { guard !covered, let row = savedRow else { return false }; stage.requestFocus(rowKey: row, itemId: stage.memory.itemId(for: row)); return true }`, with `vetoesLeftArm: { false }`. A Left entry comes from card 0, which memory then holds. Classic needs none of this.

## 3. Search S1 carried into the rail

| S1 piece (today) | In the rail |
|---|---|
| `HiddenTabBarFocusBlocker.onFocusLandedInHiddenBar` (SidebarOverlay.swift:681, 780–795) | kept verbatim in the moved file; the rail passes `revealForStrandedFocus` |
| `revealForStrandedFocus` (:535–547) | ported: `HiddenTabBarRedirect.shouldReveal(landedInHiddenBar: true, railMode: NavigationChrome.isRail(), railHoldsFocus: chrome.isFocusedChrome)`, then `rescueGuard.allowsReveal(now:)`, then `chrome.requestReveal(.hiddenBarRedirect)` |
| `StrandedRescueGuard` (HiddenTabBarRedirect.swift:32–45) | kept unchanged; `rescueFailed` stamped from the ported `takeFocusAfterReveal` |
| `SidebarHandOffLadder` (:53–61) | kept (name unchanged, doc updated); used by **both** the Right/Menu exit and the post-Select hand-off |
| Right on the panel → `handOffFocusToContent` (:497–503) | replaced by the `movementDidFail(.right)` exit (§2.4). The Grid keyboard is a geometric right-neighbour of the centred rail only while the gate is open, and the gate is closed while the rail holds focus |
| Menu from the keyboard | the search container still moves focus into the hidden bar, the redirect opens the rail (`reason=hiddenBarRedirect`), and a Menu in the rail is then the system default (R4) |

`HiddenTabBarRedirect.shouldReveal` changes its labels to `railMode:` / `railHoldsFocus:`, and its 4 tests follow. `test93SidebarMenuFromSearchKeyboard` → `test93RailMenuFromSearchKeyboard` (§7.3).

## 4. Settings and migration

### 4.1 Appearance pane (`Screens/Settings/AppearanceSettingsPane.swift`)

| Row | Key | Options (stored → label) | Default | Visible |
|---|---|---|---|---|
| Navigation (:244–257) | `sidebar_style` | `"tabs"` → "Top Tabs" (existing key), `"rail"` → "Rail" | tabs | always |
| **Rail** (new, directly below) | `rail_visibility` | `"always"` → "Always Visible", `"browsing"` → "Hide While Browsing" | always | only when `NavigationChrome.style(raw:) == .rail` |
| Hide Hero Artwork While Browsing (:294–299) | `hero_poster_focus_only` | unchanged | off | **only when Home Layout is Classic** (`@AppStorage(HomeLayout.defaultsKey)` resolved through `HomeLayout.resolve`): it has no meaning in Stage (#22). The row stays a literal `descriptionID: .appearanceHideHeroArtwork` inside the `if`, as `SettingsDescriptionsTests`' regex needs |

- The Navigation binding (:84–99) **normalises on get**: `NavigationChrome.style(raw: sidebarStyle).rawValue`. A launch-arg `"sidebar"` then shows "Rail", not a blank pill. It sets `pendingAppearanceRowFocus = "navigation"` before the write (unchanged).
- The Rail row gets the same wrapper with hint `"railVisibility"`, plus `.accessibilityIdentifier("appearance_row_rail")` and `.focused($appearanceRowFocus, equals: "railVisibility")`.
- Navigation subtitle (replaces "Sidebar hides the top tab bar…"): **"Rail swaps the top tab bar for a column of icons on the left."**
- `SettingsDescriptions.swift`: rewrite `.appearanceNavigation` (:233); add `case appearanceRail = "appearance.rail"`. Copy scored with `scripts/deslop/deslop.py`, **5/5 each**. The Codex cleanse was skipped: the strings are short, and Codex is over quota until 10-29.
  - Navigation: "Top Tabs keeps the tab bar across the top of the screen. Rail replaces it with a column of icons on the left edge. Press Left at the edge of a page, or Menu, to open it. Default: Top Tabs."
  - Rail: "Always Visible keeps the rail on screen and moves pages a little to the right to make room for it. Hide While Browsing slides it away while you scroll or open a title, and brings it back at the top of a page. Default: Always Visible."
- New English keys: "Rail", "Always Visible", "Hide While Browsing", the subtitle, the two descriptions. They go through `populate-localizable-xcstrings.py` → de/es/fr/it/vi → `merge-translations-into-xcstrings.py` in the batch's one scripts pass, after W2-D (W2-C phase 2, P2 §4.1). W2-D never hand-edits `Localizable.xcstrings`. "Sidebar" and the old subtitle go stale and are left in the catalog.

### 4.2 Migration

`NuvioTVApp.init`, right after `RowEdgeFadeSetting.migrateLegacy` (:84):
`NavigationChrome.migrateLegacy(.standard, domain: Bundle.main.bundleIdentifier ?? "")`

- **Idempotent:** it only writes when the persistent value is exactly `"sidebar"`, so a second run is a no-op.
- **Argument domain safe:** a stored `"tabs"` with `-sidebar_style sidebar` passed stays `"tabs"` on disk.
- **No sync impact:** the key is device-local. The Test profile on the Living Room Apple TV is on `"sidebar"` today, so its first launch of this build is the migration's device check (step 14).

### 4.3 Remount key

ContentView.swift:65 and :151: `@AppStorage(NavigationChrome.styleKey) navigationStyle`, plus new `@AppStorage(NavigationChrome.railVisibilityKey) railVisibility = "always"`. The key becomes `.id("\(appTheme.paletteKey)|\(navigationStyle)|\(railVisibility)|\(uiFont)")`. The visibility mode changes the Tab closures structurally (the inset), so it switches only across a remount (T3 / BUG-66, the same reasoning as ContentView.swift:140–150).

### 4.4 Tabs mode stays byte-identical

Every new modifier branches structurally (`if NavigationChrome.isRail() { … } else { content }`), the house rule at SidebarOverlay.swift:14–21. In Tabs mode the shell renders the same tree. The renames don't change behaviour, and the `.id` string only gains a constant `|always`. `TabBarContentScrollLink` (:264, :368) and the system tab bar's hide-on-scroll stay Tabs-only.

## 5. Layout per mode and per surface

### 5.1 `.railTabRoot(_ index: Int)` (new, in `NavigationRail.swift`)

Applied inside every `Tab {}` closure in `MainTabView` (ContentView.swift:379–414), after `.tabBarImmersiveHide()`. Rail mode only (structural):

```swift
content
  .environment(\.railTabIndex, index)
  // Always Visible only:
  .safeAreaPadding(.leading, NavigationChrome.contentSafeAreaExtra(sideSafeArea: PinnedRowGeometry.sideSafeArea, reservesWidth: true))  // 36
  .environment(\.railLeadingInset, NavigationChrome.contentSafeAreaExtra(sideSafeArea: PinnedRowGeometry.sideSafeArea, reservesWidth: true))  // 36 (R1)
  .environment(\.rowEdgeMargins, NavigationChrome.rowEdgeMargins(sideSafeArea: PinnedRowGeometry.sideSafeArea, reservesWidth: true))  // 176 / 140
```

`.safeAreaPadding` rather than `.padding`: `ignoresSafeArea()` backgrounds (Home hero art, Stage art and wash, Detail backdrop) still reach x = 0 behind the rail. A plain padding would move their frames. Stage's root and the folder Rows page ignore the safe area by design (P1 §1.3), so the padding never reaches them. They read `\.railLeadingInset` (P1 declares it, default 0) for the stage block and the rows, and inherit `\.rowEdgeMargins` from here, which matches (R1). Environment values flow into NavigationStack destinations, so the pushed folder page gets them too.

### 5.2 Per surface

| Surface | Always Visible | Hide While Browsing |
|---|---|---|
| Home Classic | rows, hero text and CTA at 176; the hero backdrop is full-bleed; rows clip at `176 − allowance` (`RowLeadingEdgeClip`), so nothing slides under the rail | no inset; overlay; hides on `isScrolledDown` (the existing hysteresis mirror) |
| Home **Stage** | stage left block and strip rows at 140 + `railLeadingInset` = 176; stage art and wash `.ignoresSafeArea()` (P1 contract, R1) | hides when the strip starts paging to a row > 0 and returns when it starts paging to row 0, sliding with the page's curve and duration, with no resting settle (#8, §6.2) |
| Folder **Rows** page (pushed, P2) | as Stage: 176 via `railLeadingInset` | the page writes no mirror, so the rail keeps Home's state |
| Search | page at 176; the Grid keyboard should move from x 80 to 116 (**Probe I**) | hidden on the Search tab (R7); Menu (redirect) or Left still opens it |
| Library / Add-ons | at 176 | per-tab scroll mirror (TabBarVisibility.swift:333–336, now `reportToRail`) |
| Settings root and panes | title, explainer column and List all shift 36 (explainer `.padding(.leading, 60)` sits inside the safe area); `geo.size.width / 3` recomputes | never scrolls, so shown at rest |
| Profile | centred content, unaffected | shown |
| Detail (pushed) | shown; content at 176; backdrop full-bleed | hidden (immersive) unless focused or revealed |
| Folder Grid page, See All, person (pushed) | shown, inherited inset | follow their tab's mirror |
| Player, stream picker, trailer bridge, Top Shelf cover | **hidden automatically:** all are `fullScreenCover` presentations above the root hosting view; `presentedOverShell` blocks arming; `rootCoverActive` releases focus (port of SidebarOverlay.swift:608–614) | same |

**Hide While Browsing motion:** `.transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))`, animated on `shown` over 0.25 s. The hide edge is immediate, and the show edge waits 0.35 s of continuously not-scrolled (port `updateRestingVisibility`, SidebarOverlay.swift:331–353). A `.page(seconds:)` write (Stage) animates both edges with the page's own `.easeOut(duration: seconds)`, and skips the settle: the row index is discrete, so the rail arrives with the strip instead of 0.1 s after it (#8). There's no inset in this mode, so nothing else moves.

## 6. Retirement and call sites

### 6.1 `DesignSystem/SidebarOverlay.swift`: file deleted

| Lines | What | Goes to |
|---|---|---|
| 26–40 | `enum SidebarChrome` | `NavigationChrome` |
| 56–109 | `SidebarChromeModel`, key, env | `NavigationChromeModel`, `\.navigationChrome` |
| 115–140 | `SidebarItem` | `RailItem` |
| 171–188 | `SidebarItemButtonStyle` | **deleted** (system `.borderless`) |
| 194–235 | `SidebarMetrics` | deleted (`RailMetrics`) |
| 249–657 | `SidebarOverlay` | deleted; logic ported into `NavigationRail` as cited above |
| 678–824 | `HiddenTabBarFocusBlocker` | **moved verbatim** to new `DesignSystem/HiddenTabBarFocusBlocker.swift`, plus §2.3's additions |
| 839–886 | `SidebarMenuRevealModifier` | `RailMenuRevealModifier` / `.railMenuReveal()`, reason `.menu`; keep a short form of the Up-reveal archaeology (BUG-98: never reveal on Up) |
| 892–914 | top compensation | `.railTopCompensation()`, still a no-op at 0 |

### 6.2 Call-site changes

| File:line | Change |
|---|---|
| ContentView.swift:65, :151 | §4.3 |
| :370, :373, :417 | `NavigationChromeModel`, `\.navigationChrome` |
| :379–414 | each Tab: `.railTabRoot(0…5)` |
| :430, :523–533 | `ShellFocusScopeModifier` gates on `NavigationChrome.isRail()` (rail only; test54 broke when this scope existed in both modes) |
| :435 | `.railTopCompensation()` |
| :457–467 | `if NavigationChrome.isRail() { NavigationRail(selectedTab: $selectedTab, activeProfile: activeProfile, rootCoverActive:, shellFocusScope:, chrome: navigationChrome, tabBarVisibility: tabBarVisibility) }` |
| :518 | `.railMenuReveal()` |
| NuvioTVApp.swift:84 | migration call |
| HiddenTabBarRedirect.swift:15–24 | labels, doc |
| TabBarVisibility.swift:183, :193 | `railMode = NavigationChrome.isRail()`; `.hidden` for the whole session in rail mode (as today in sidebar mode) |
| :261, :289–295, :307, :312, :333–336 | env rename; `reportToSidebar` → `reportToRail` (gated on `isRail`) |
| TabBarContentScrollLink.swift:264, :368 | `!NavigationChrome.isRail()` |
| TabBarStateProbe.swift:323 | `NavigationChrome.isRail()`; **keep the `m=sb` token** (TabBarContentScrollLinkTests.swift:95 asserts it) |
| SearchView.swift:136, LibraryView.swift:58, AddonsView.swift:27, SettingsView.swift:83 | `.railMenuReveal()`; doc comments in SettingsView :27–28, SettingsRootView :39, SettingsPaneScaffold :15 |
| HomeView.swift:37 | `@Environment(\.navigationChrome)` |
| :793 | probe becomes `debug_navchrome mode=tabs\|rail vis=always\|browsing inset=36\|0 comp=N` |
| :980–1031 | `: railMenuRevealHandler)` |
| :1796 | `navigationChrome.isFocusedChrome` |
| :1871, :2006 | `NavigationChrome.isRail()` |
| :2922–2933 | `railMenuRevealHandler`: `guard NavigationChrome.isRail(), !isScrolledDown`, then `requestReveal(.menu)` |
| HomeView (new) | Classic route registered in `.onAppear` when `isRail` and `homeLayout == .classic`: `capture` stores `.hero` if `heroFocused`, else `.row(lastOwnedRowKey)`; `lastOwnedRowKey` is a new `@State`, written in `handleRowFocusOwnership` (:1931) on `owns == true` and never cleared on `false` (unlike `focusedRowKey`); `restore` as in §2.5; `vetoesLeftArm` = `heroFocused && heroCarouselActive` |
| DetailView (new) | route push and remove beside :1194–1196, keyed by `@Environment(\.railTabIndex)` (skip when nil) |
| Screens/Home/StageStripHome.swift (P1 file) | (a) `atTopExit` in rail mode = `railMenuRevealHandler` (nil in Tabs mode, so the system default); row > 0 still pages to row 0 first (R3). (b) In rail mode, `onPageStart: { index, s in navigationChrome.setScrolledDown(tab: 0, index > 0, motion: .page(seconds: s)) }` (#8). This write owns the rail. The strip's `reportsScrollToTabBar` mirror stays for TabBarStateProbe, and its later crossing writes the same value, a no-op under write-on-change (R4). (c) The Stage route (§2.5), pushed on appear and removed on disappear. (d) Up at row 0 in rail mode has no target and never reveals (BUG-98). (e) Rename the trailer teardown's `.onReceive(sidebarChrome.$isFocusedChrome)` (W2-A's) to `navigationChrome` (R2) |
| Screens/FolderRowsPage.swift (P2, W2-B's file) | the folder route (§2.5), the same shape as Stage's, keyed by `\.railTabIndex` (R2) |
| Screens/Settings/SettingsRootView.swift | the Settings root route (§2.5, #21) |
| Screens/Settings/AppearanceSettingsPane.swift:294–299 | Hide Hero Artwork While Browsing shown only in Classic (§4.1, #22) |

**Conflict with P1's Menu routing:** none in substance (R3). Stage's own handler sits on the strip, so it wins at row > 0 and pages to row 0 first. At row 0 it delegates to the rail; the folder Rows page installs no handler and pops (P1 S4). W2-D lands after W2-A, W2-B and W2-C (#12) and adapts the `sidebarChrome` references W1-A and W2-A wrote.

### 6.3 Docs (main session, after W2-D)

`docs/design/hig-hybrid-contract.md`: remove the FEAT-30 `SidebarItemButtonStyle` carve-out from Buttons, and change the Search row's "In Sidebar mode…" to "In Rail mode…". Add a **Navigation rail** MUST: glass is a background behind native `Button`s; the rail arms only on a failed Left or Menu and is never permanently focusable; content is gated while it holds focus.

## 7. Ownership and tests

### 7.1 W2-D (Opus): file ownership and order

New: `DesignSystem/NavigationChrome.swift`, `DesignSystem/NavigationRail.swift`, `DesignSystem/HiddenTabBarFocusBlocker.swift`. Deleted: `DesignSystem/SidebarOverlay.swift`. Edited: every file in §6.2. The Xcode project uses synchronized groups (9 `PBXFileSystemSynchronizedRootGroup`), so there are no pbxproj edits. Agents never build.

**When (#12, the P3 file matrix):** W2-D starts only after W2-A, W2-B and W2-C have all landed: it edits `StageStripHome.swift` (W1-A, then W2-A), `FolderRowsPage.swift` (W2-B), `HomeView.swift` (W1-A) and `SettingsDescriptions.swift` (W1-C → W2-C → W2-D). Its new English strings go into `Localizable.xcstrings` only through the scripts, in the one translation pass at the very end (W2-C phase 2). It never hand-edits the catalog.

Order: (1) move the blocker and add the gate and content check; (2) `NavigationChrome` plus unit tests; (3) `NavigationRail`; (4) shell wiring and migration; (5) renames; (6) Appearance rows and descriptions; (7) routes (Classic, Stage, folder Rows, Detail, Settings root) and Stage hooks; (8) main session: build, **Probe G** (§2.3), **Probe I** (Always Visible on FA87: `app.keyboards.firstMatch.frame.minX ≥ 115` on Grid, Home card 0 `minX ∈ [175, 177]`); (9) the test93 port and harness helpers.

### 7.2 Unit tests (NuvioTVTests)

| File | Cases |
|---|---|
| `NavigationChromeTests.swift` (new) | style(raw:): tabs / rail / "sidebar" → rail / nil / garbage → tabs; visibility: browsing / always / nil / garbage → always. **Migration** (a `UserDefaults(suiteName:)` per test, `domain` = suite name): "sidebar" → "rail" and returns true; "rail" no-op; "tabs" no-op; missing stays missing; garbage unchanged; second run returns false; `rail_visibility` untouched. **Inset math:** reservedEdge == 116; extra(80, true) == 36; extra(80, false) == 0; extra(116, true) == 0; extra(130, true) == 0 (never negative); margins(80, true) == (176, 140); margins(80, false) == .standard; clearance: 176 − 30 ≥ 116 and 140 − 30 > 100 |
| `RailFocusPolicyTests.swift` (new) | shouldArm: the all-true case → true; each of the six conditions negated → false; heading `[.left, .up]` → false; `.right` → false. moveFailedInRail: right → exit; up / down / left → contained. menuInRail: left → close; menu / redirect / rearm → system. select: other → switchTab; same → returnToCurrent. RailVisibilityRule: 9 cases, one per precedence step, including `.always` while immersive → shown and `.whileBrowsing` on tab 1 → hidden. `setScrolledDown` keeps the last `RailMotion` per tab and stays write-on-change (a same-value `.scroll` write after a `.page` write leaves `.page`) |
| `HiddenTabBarRedirectTests.swift` | labels renamed; the 8 existing cases unchanged otherwise |

That adds about 45 cases to NuvioTVTests' 1042 at the base.

### 7.3 UI tests

New `NuvioTVUITests/NavigationRailUITests.swift`, class `NavigationRailUITests`, with helpers copied (the harness's duplication rule). Named `testRailNN`, so they never collide with W3's numbered Stage legs. Launch args: `-sidebar_style rail -rail_visibility always|browsing -home_layout classic|stage`. "Focused" means `rail_state focused=<id>` (every runtime); content focus identity uses `hasFocus` on **FA87 (26.5) only**, because tvOS 27.0 never reports it. Never press Menu while a rail button holds focus: a Menu-opened rail suspends the app (R4).

| Test | Steps → assertions |
|---|---|
| Rail01 LeftFromFirstCard (classic and stage) | Down to a catalog row; Left one press at a time, recording the focused card's label, until `rail_state expanded=1 reason=left focused=0` (≤ 12 presses); `app.buttons["rail_item_Home"]` exists |
| Rail02 LeftMidRow | from card 2, one Left → `expanded=0`, and the focused label is card 1's |
| Rail03 RightReturnsSameCard | after Rail01, Right → within 1.5 s `expanded=0 armed=0 gated=0 route=home`; FA87: the focused label equals the recorded card 0 |
| Rail04 MenuAtTabRoot | Home (top), Library, Settings root: Menu → `focused=<tab> reason=menu`; exit with Right. On the Settings root, open a category and come back first: after the Right, the focused row is that category, through the root's landing correction (#21) |
| Rail05 Contained | rail open on Home: Down ×8 → `focused=5`, Up ×8 → `focused=0`, still `expanded=1`; FA87: no content button `hasFocus`. **05b**, the same from the Search keyboard (opened by Menu): the keyboard never takes focus |
| Rail06 SelectSwitchesTab | rail on Home → Down to `rail_item_Library` → Select → within 1.5 s `tab=2 focused=-1 expanded=0`; Library content exists |
| Rail07 HideWhileBrowsing (stage) | `shown=1` at launch; Down → `shown=0` within 1.0 s, and strip card 0's `minX` unchanged (±1); Up → `shown=1` within 0.8 s, with no resting settle (#8); Search tab → `shown=0` |
| Rail08 AlwaysVisibleInset | `navigation_rail` frame `maxX ≤ 101`; Classic card 0 `minX ∈ [175, 177]` (a Tabs-mode run: `[139, 141]`); on a Detail opened from Home, `navigation_rail` exists and the Play button's `minX ≥ 116` |
| Rail09 MigrationAlias | `-sidebar_style sidebar` → `navigation_rail` exists, `debug_navchrome` contains `mode=rail`; Appearance `appearance_row_navigation` label contains "Rail" |
| Rail10 DetailRoundTrip | Detail: Left from Play → `reason=left`; Right → `route=detail`; FA87: Play has focus |

**In `NuvioTVUITests.swift`:**
- `test93SidebarMenuFromSearchKeyboard` (:9423) → `test93RailMenuFromSearchKeyboard`: the same legs with `rail_item_*`, `-sidebar_style rail`, an added `reason=hiddenBarRedirect` check, and the 3 s settle kept.
- `test84SidebarModePaneMenuPopsToRoot` (:9277) → `test84RailModePaneMenuPopsToRoot`.
- **Delete** `test52SidebarOverlay` (:7234); Rail01, Rail04, Rail06 and Rail09 replace it.
- Helpers: `launchToHome` (:227) and `openTab` (:300–326) rail branches detect `navigation_rail`. They open the rail by Left (≤ 15 presses until `expanded=1`), never by a blind Menu, then move to `rail_item_<title>`, Select, and pause 2.5 s (ladder). `focusSearchKeyboard` (:545) checks `rail_item_*`; :8969 detects `navigation_rail`.

W2-D owns the test93 port and the helpers (it is W2-D's canary). W3 owns `NavigationRailUITests`, the test52 deletion and the test84 port.

## 8. Risks and open questions

**Risks**
1. **The UIKit gate may not bind SwiftUI focus items** (an ancestor's interaction flag is proven only for UIKit views, the hidden `UITabBar`). Probe G decides, and the fallback is specified.
2. **Safe-area propagation** into NavigationStack destinations and into `.searchable`'s `UISearchContainerViewController` is unproven. Probe I and Rail08 measure it.
3. **Private class names:** the redirect still matches `UITabBarButton` by name; `test93` is the canary.
4. **Holding Left** along a row opens the rail at card 0 on the next repeat. That is the intended entry, and momentum swipes didn't fire it on hardware. The `arm` log line catches any surprise.
5. **T3 / BUG-66:** `MainTabView` must not observe `NavigationChromeModel`. `.railTabRoot` takes only launch-constant inputs, and the rail is the sole observer.

**Decisions (Christian, 2026-10-05, all as the P3 critique recommended) and resolved questions**
- **Q1 (R4), critique Q2:** decided. Menu inside a Menu-opened rail suspends the app, as FEAT-30 does: Menu opens the rail at a tab root, and Menu again leaves the app, the remote's normal grammar. Menu still closes a rail that Left opened.
- **Q2 and Q3, critique Q6:** decided for this beta. Keep the 36 pt content shift (content at 176, 76 pt clear of the pill) and the pill 16 pt from the bezel (icons 22 pt inside the 80 pt overscan margin; Orivio uses 28). Revisit from the Gate 2 screenshots and a look on his TV.
- **R7, critique Q7:** decided. Hide While Browsing also hides the rail on Search (the Grid keyboard sits on the left edge) and on Detail (FEAT-30 already hides there).
- **Q4:** resolved by the critique. Library, Add-ons, Settings panes and pushed grids return to their default focus for this beta; device step 14 reads against the §2.5 table. Exact return needs a route per screen (a follow-up row).
- **Q5:** waits for Probe G. If it forces the `.disabled` fallback, decide then whether the rail hides on Search in Always Visible too.
- **Q6:** waits for the device. Is `.borderless` row focus readable on glass under the dim? `.bordered` with a capsule shape is the native alternative.

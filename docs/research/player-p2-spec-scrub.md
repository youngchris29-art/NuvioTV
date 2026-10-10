# Player P2 spec: swipe scrub with the preview card (2026-10-07)

Scope: P2 item A1 only (gestures, arbiter, scrub mode, rate curves + knobs, preview card, probes, tests). The store, `commandNode`, chapters, aspect and their settings are the sibling spec `player-p2-spec-store.md`; this spec consumes two things from it: a read API and `TransportBarModel.chapters` (already declared, `TransportBarModel.swift:18`).

Code anchors are in the clone `~/Claude/Projects/NuvioMobile-player`, branch `claude/player-p2` at `0c10ca4a4`, paths relative to `iosApp/NuvioTV/`. "MPV" = `Screens/MPVPlayerView.swift`.

## 0. Decisions this spec makes (for the critique)

1. **Scrub mode outlives the finger.** Lifting the finger leaves `.scrubbing`; Select / Play / Menu / Up / Down end it (system and Orivio grammar, research §5.2). While playing, 8 s with no scrub input cancels it (no seek) so a stray swipe cannot pin the bar up (`TransportHideRule.mayHide` is false while a mode is active, `PlayerTransportBar.swift:150`). Paused: no timeout.
2. **Video keeps playing during a scrub** (D1), same as P1's held step: the 16 pt dot shows the live position (`PlayerTransportBar.swift:271-277`).
3. **The 160 pt rule** is the brush guard for the one case D1 opens up: playing with the bar hidden. Thresholds: 190 pt with a pill focused, 160 pt playing with the bar hidden, 45 pt otherwise (bar up, or paused). One table, §1.3.
4. **The down-swipe recogniser stays** (hardware-proven in P1). The arbiter's vertical-down at 110 pt also opens the panel; both go through one deduped opener (§1.5).
5. **The plan's `UILongPressGestureRecognizer` for holds is NOT in P2.** P1's timer hold passed the device pass 15/15; replacing it buys nothing for scrub. Drop that line from the plan unless the critique disagrees.
6. **Rate knob is a scale, not a rate:** `-debug.scrubRateScale <factor>` (the plan's `-debug.scrubRate <s/pt>` only fits the Orivio curve; a scale fits both).
7. **Target time label keeps P1's position** (`TransportBarLayout.targetLabelFrame`, `PlayerTransportBar.swift:78-81`: top 18 pt under the track centre, label centre ≈ 35 pt under). Research's "28 pt under" is not worth a second label position for stepping vs scrubbing.
8. **No frame → no card body.** The time label still shows; a chapter title, if any, sits where the card's top would be.
9. Developer rows for the two knobs, because Steven cannot pass launch args (device pass step 4). Two row titles + two descriptions are the only new strings.

## 1. `Screens/Player/ScrubGestureArbiter.swift` (new, pure Swift, no UIKit)

### 1.1 Types

```swift
import Foundation

/// The rate curve for a horizontal scrub (D3). `deltaSec` takes one sample's increment in points.
enum ScrubRateCurve: String {
    case orivio, bobsupra
    var probeCode: String { self == .orivio ? "o" : "b" }

    func deltaSec(points inc: Double, durationSec: Double) -> Double
}

/// What the controller knows at each sample; built fresh by `MPVTVPlayerViewController.scrubContext()`.
struct ScrubContext: Equatable {
    var barVisible: Bool
    var paused: Bool
    var pillFocused: Bool
    var scrubbing: Bool          // TransportPreview.mode is .scrubbing
    var canScrub: Bool           // file loaded, duration > 0, no panel presented, not ended
    var pressesDown: Int         // MPV `pressesDown.count` (:300)
    var lastPressUptime: TimeInterval   // MPV `lastClickUptime` (:298)
}

struct ScrubGestureArbiter {
    enum Intent: Equatable { case undecided, horizontal, vertical(down: Bool), ignored }
    enum Event: Equatable {
        case none
        case beginScrub                 // the stroke just became horizontal
        case scrubDelta(points: Double) // one sample's dx increment, stroke already horizontal
        case openPanel                  // vertical, downward
        case swipeUp                    // vertical, upward
        case lightTap                   // ended undecided with < tapMaxTravelPt of travel
    }

    static let horizontalIntentPt: Double = 45
    static let hiddenPlayingIntentPt: Double = 160
    static let pillIntentPt: Double = 190
    static let verticalIntentPt: Double = 110
    static let axisRatio: Double = 1.5
    static let tapMaxTravelPt: Double = 20
    static let moveSuppressSec: TimeInterval = 0.4

    private(set) var intent: Intent = .undecided
    var probeCode: String   // "u" undecided, "h", "v", "i" ignored

    mutating func touchBegan()
    mutating func moved(tx: Double, ty: Double, now: TimeInterval, context: ScrubContext) -> Event
    mutating func touchEnded(context: ScrubContext) -> Event
    /// The scrub ended mid-stroke (Select, Menu, a press): the rest of this stroke does nothing.
    mutating func abandon()

    static func horizontalThreshold(_ c: ScrubContext) -> Double
}
```

`tx`/`ty` are the recogniser's cumulative `translation(in:)` (points, +x right, +y down). Velocity is not an input to either curve; the controller logs it only (see §4.4).

### 1.2 Rate curves (exact)

- **Orivio (default):** `inc × max(durationSec / 4800, 0.25)`. 600 s file: 0.25 s/pt; 2 h film: 1.5 s/pt.
- **bobsupra** (read from `bobsupra/NuvioTVOS@ad10335` `PlayerViewModel.swift:3025-3046`, fetched for this spec):
  `a = |inc|`; `a ≤ 0.0001 → 0`; `df = durationSec > 0 ? clamp(√(durationSec/3600), 0.8, 1.8) : 1`;
  `a ≤ 3`: `m = 0.7 + 0.3·(a/3)`; `a ≤ 8`: `m = 1 + 1.5·((a−3)/5)·df`; else `m = (2.5 + 3.5·min((a−8)/12, 1))·df`;
  result `sign(inc) · a · 0.06 · m`. (`df` does not touch the first band; the third band multiplies the whole bracket.)

The rate scale and the clamp are applied by `TransportPreview` (§2), not here.

### 1.3 Decision rule

`touchBegan()` sets `intent = .undecided`, `origin = (0, 0)`, `travel = 0`, `lastTx = 0`, `suppressed = false`.

`moved(...)`:
1. **Move suppression.** If `context.pressesDown > 0` or `now − context.lastPressUptime < moveSuppressSec`, set `origin = (tx, ty)`, `lastTx = tx`, return `.none` (a click rolls the finger; nothing measured during or 0.4 s after a press counts, and measurement restarts from where the finger is).
2. `dx = tx − origin.x`, `dy = ty − origin.y`; `travel = max(travel, hypot(dx, dy))`.
3. `intent == .horizontal`: `inc = tx − lastTx; lastTx = tx`; return `inc == 0 ? .none : .scrubDelta(points: inc)`.
4. `intent` is `.vertical` or `.ignored`: `.none`.
5. Undecided. Vertical first: `|dy| ≥ 110 && |dy| ≥ 1.5·|dx|` → `intent = .vertical(down: dy > 0)`, return `dy > 0 ? .openPanel : .swipeUp`.
6. Horizontal: `|dx| ≥ horizontalThreshold(context) && |dx| ≥ 1.5·|dy|` → if `!context.canScrub` then `intent = .ignored`, `.none`; else `intent = .horizontal`, `lastTx = tx` (the travel up to the decision is NOT applied: no jump), return `.beginScrub`.
7. Otherwise `.none` (a diagonal stays undecided: nobody consumes it).

`horizontalThreshold`: `pillFocused → 190`; else `scrubbing → 45`; else `!barVisible && !paused → 160`; else `45`. D1: `paused` never blocks a scrub.

`touchEnded(context)`: `intent == .undecided && travel < tapMaxTravelPt` → `.lightTap`; anything else `.none`. Then the arbiter keeps `intent` (the probe shows the last stroke's verdict) until the next `touchBegan`.

`abandon()`: `intent = .ignored` if it was `.horizontal`.

### 1.4 Recogniser wiring (MPV `viewDidLoad`, after the light tap at `:386-389`)

```swift
let pan = UIPanGestureRecognizer(target: self, action: #selector(handleScrubPan(_:)))
pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
pan.allowedPressTypes = []          // presses keep flowing to pressesBegan untouched
pan.cancelsTouchesInView = false
pan.delaysTouchesBegan = false
pan.delegate = self
view.addGestureRecognizer(pan)
scrubPan = pan
swipeDown.delegate = self
lightTap.require(toFail: pan)        // a tap only when the pan never began
```

- New `extension MPVTVPlayerViewController: UIGestureRecognizerDelegate` with `gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:) → true` when both recognisers are among `{scrubPan, swipeDown, lightTap}` (store `swipeDown`/`lightTap` in new `private weak var` fields); `false` otherwise.
- Tap vs pan: if the pan never begins (UIKit's own small slop), it fails at touch-up and the light tap fires as in P1. If it began, the tap fails and the arbiter's `.lightTap` (travel < 20 pt) calls the same `performLightTap(force: false)` (MPV `:415`), so `LightTapGuard` (`PlayerRemoteRules.swift:33-39`) still applies. Never both.
- Presses: `allowedPressTypes = []` means the pan never sees a press, so `pressesBegan/Ended/Cancelled` (`:1629`, `:1769`, `:1800`) and P1's Menu-on-release (`pendingMenuAction`, `:243`) are unchanged. The cover's Menu tap (`gateCoverMenuTap`, `:511-530`) is a press-only recogniser on an ancestor `UITransitionView`; the pan cannot interact with it. Nothing to change there.
- Focus: the controller is first responder (`canBecomeFirstResponder`, `:544`) and the pills draw non-focusable (P1 critique decision 4), so the focus engine has nothing to move during a pan. No focus suppression is needed; state this in a code comment.

### 1.5 One panel opener

`handleSwipeDown` (`:402-408`) and the arbiter's `.openPanel` both call:

```swift
private var lastGesturePanelUptime: TimeInterval = 0
private func openPanelFromGesture() {
    let now = ProcessInfo.processInfo.systemUptime
    guard presentedViewController == nil, now - lastGesturePanelUptime > 0.6 else { return }
    lastGesturePanelUptime = now
    cancelExactStage(); stopHoldTimer(); apply(transport.cancel())   // today's handleSwipeDown body
    onOpenPanel?(.info)
}
```

`handleSwipeDown` becomes: `guard scrubArbiter.intent != .horizontal else { return }` (a scrub stroke that drifts down must not open the panel), then `openPanelFromGesture()`.

## 2. `TransportPreview` additions (`Screens/Player/TransportPreview.swift`)

New stored properties: `var scrubCurve: ScrubRateCurve = .orivio`, `var scrubRateScale: Double = 1`, `private var scrubMovedAny = false`, `private var scrubBackwardNoted = false`. New `Output` case: `case cancelUpNext`. New constant `static let scrubIdleCancelSec: TimeInterval = 8`.

Extract `private func commitRequest(target: Double) -> CommitRequest` from `pressEnded` (`:151-156`: `covered` → `[.exact]`, else `[.keyframes, .exact]`) and use it in both places; `pressEnded` behaviour is byte-for-byte the same.

| Method | From | Effect | Returns |
|---|---|---|---|
| `scrubBegan(positionSec:)` | `.idle` | `originSec = positionSec`; `mode = .scrubbing(targetSec: clamp(positionSec))`; `previewSec` = that; both flags false | `.none` |
| | any other mode | nothing (the controller ends a scan / step first, §3.2) | `.none` |
| `scrubMoved(deltaPoints:)` | `.scrubbing(t)` | `d = scrubCurve.deltaSec(points:, durationSec:) × scrubRateScale`; `next = clamp(t + d)`; set mode + `previewSec`; `scrubMovedAny = true` if `next != t` | `.cancelUpNext` the first time `next < originSec − 1`, else `.none` |
| `scrubNudge(direction:)` | `.scrubbing(t)` | same with `d = ±firstStepSec` (10 s) | same rule |
| `scrubCommit()` | `.scrubbing(t)` | `mode = .idle`; if `!scrubMovedAny`: `previewSec = nil`, `.none`; else `previewSec = t` (held until landing, as the hold does) | `.commit(commitRequest(target: t))` (fromSec = `originSec`) |
| `scrubCancel()` | `.scrubbing` | `mode = .idle`, `previewSec = nil` | `.none` |

Every method from a non-`.scrubbing` mode (other than `scrubBegan` from idle) returns `.none` and changes nothing. `cancel()` (`:175-188`): split `.scrubbing` out of the `.idle, .scrubbing` arm and route it to `scrubCancel()`. `pressBegan` in `.scrubbing` stays `.none` (`:121-122`; the controller sends arrows to `scrubNudge`). Clamp is the existing `[0, duration − 0.5]` (`:92-94`).

The commit goes through `apply → issueCommit` (MPV `:1870-1921`), so a scrub is the same deliberate seek as a hold: two stages unless cached, `skipPlanner.beginSeek(kind: .user, fromSec: origin)` via `issueSeek` (`:2102-2108`), `refineSeek` in the exact stage (`:1985`), the landing timers of `armCommitLanding` (`:1930`). Nothing new in `SkipSegmentPlanner`.

`MenuPrecedence` (`PlayerRemoteRules.swift:16-24`) needs no new step: `.scrubbing.isActive` is already true, so Menu resolves to `.cancelMode`, performed on release (`performMenuAction`, MPV `:272-279` → `transport.cancel()`), and `publishTransport`'s active → idle edge (`:1895`) calls `flashControls()`, which keeps the bar up. Update the `.cancelMode` comment to say "scrubbing: nothing committed".

## 3. Controller (`MPVTVPlayerViewController`, MPV)

### 3.1 State and knobs

Near the P1 transport fields (`:135-150`):

```swift
private var scrubArbiter = ScrubGestureArbiter()
private weak var scrubPan: UIPanGestureRecognizer?
private weak var swipeDownRecognizer: UISwipeGestureRecognizer?
private weak var lightTapRecognizer: UITapGestureRecognizer?
private let scrubCurve: ScrubRateCurve          // `debug.scrubCurve`: "bobsupra" → .bobsupra, anything else .orivio
private let scrubRateScale: Double              // `debug.scrubRateScale`; ≤ 0 = Auto 1.0
private var scrubIdleWork: DispatchWorkItem?
private var scrubPublishWork: DispatchWorkItem?
private var lastScrubPublishUptime: TimeInterval = 0
private var previewFrameWork: DispatchWorkItem?
private var previewFrameToken = 0
private var lastPublishedScrubbing = false
var seekPreviewSource: SeekPreviewSource?       // nil until the store spec wires it
```

Read the two knobs in `init` next to `holdTickSec` (`:338-341`); assign `transport.scrubCurve`/`scrubRateScale` in `viewDidLoad` next to `rampScale` (`:375-379`). Set `state.transport.scrubCurveCode = scrubCurve.probeCode` there too.

`scrubContext()`: `barVisible: state.controlsVisible`, `paused: cachedProps().paused`, `pillFocused: state.transport.focusedPill != nil`, `scrubbing: { if case .scrubbing = transport.mode { true } else { false } }`, `canScrub: fileLoaded && cachedProps().duration > 0 && presentedViewController == nil && !state.isEnded`, `pressesDown: pressesDown.count`, `lastPressUptime: lastClickUptime`.

### 3.2 Pan handler and events

```swift
@objc private func handleScrubPan(_ gr: UIPanGestureRecognizer) {
    let t = gr.translation(in: view)
    switch gr.state {
    case .began:
        scrubArbiter.touchBegan()
        route(scrubArbiter.moved(tx: t.x, ty: t.y, now: uptime, context: scrubContext()))
    case .changed:
        route(scrubArbiter.moved(tx: t.x, ty: t.y, now: uptime, context: scrubContext()))
    case .ended, .cancelled, .failed:
        route(scrubArbiter.touchEnded(context: scrubContext()))
    default: break
    }
    #if DEBUG
    state.transport.debugArbiter = scrubArbiter.probeCode
    #endif
}
```

`route(_ e: ScrubGestureArbiter.Event)`:

- `.beginScrub`: if `.scanning` → `apply(transport.endScanInPlace())` (ends the scan where it is, records the span as P1 does, `:2023`); if `.stepping` → `stopHoldTimer(); apply(transport.cancel())`. Then `cancelExactStage()`, `state.transport.focusedPill = nil`, `base = skipPlanner.seekInFlight?.targetSec ?? cachedProps().position` (the `beginHold` rule, `:1838`), `apply(transport.scrubBegan(positionSec: base))`, `flashControls()`, `restartScrubIdle()`.
- `.scrubDelta(p)`: `performScrubOutput(transport.scrubMoved(deltaPoints: p))`.
- `.openPanel`: `if scrubbing { apply(transport.scrubCancel()) }`; `openPanelFromGesture()`.
- `.swipeUp`: scrubbing → `apply(transport.scrubCancel())`; else bar hidden → `flashControls()`; else nothing.
- `.lightTap`: scrubbing → nothing; else `performLightTap(force: false)`.
- `.none`: nothing.

`performScrubOutput(_ out:)` (the throttled sibling of `apply`): if `out == .cancelUpNext` → `state.upNextCancel?()` (once per scrub, like `beginHold`'s backward rule, `:1837`). Then publish at most every 1/30 s: if `uptime − lastScrubPublishUptime ≥ 1/30` → `publishTransport()`, stamp; else (re)arm `scrubPublishWork` for the remainder so the final sample always lands. Then `requestPreviewFrame()`, `restartScrubIdle()`, and `scheduleHide()` is not needed (mode active). Every other scrub transition (begin, nudge, commit, cancel) uses the plain `apply` and publishes at once.

`apply(_:)` (`:1870`): add `case .cancelUpNext: state.upNextCancel?()`.

`publishTransport()` (`:1887`): detect the scrubbing edge with `lastPublishedScrubbing`. Entering: `state.scrubCardUp = true`. Leaving (any path: commit, cancel, Menu, idle timeout, panel): `scrubIdleWork?.cancel()`, `scrubPublishWork?.cancel()`, `previewFrameWork?.cancel()`, `previewFrameToken += 1`, `state.transport.previewFrame = nil`, `scrubArbiter.abandon()`, `state.scrubCardUp = false`. Centralising here means every exit path cleans up.

`restartScrubIdle()`: cancel and, only while `!cachedProps().paused`, arm `scrubIdleWork` for `TransportPreview.scrubIdleCancelSec` → `apply(transport.scrubCancel())`.

### 3.3 Presses while scrubbing (`pressesBegan`, `:1629`)

Add a `scrubbing` check as the first branch of each case below, before the existing scan/step logic; everything else is unchanged. `cancelExactStage()` at the top (`:1647-1652`) stays.

| Input | While scrubbing | Code |
|---|---|---|
| Select | Commit (two-stage), play state unchanged | `apply(transport.scrubCommit())`; `#if DEBUG state.seekProbe.scrubs += 1` when it returned `.commit`; `flashControls()` |
| Play/Pause | Commit, then play if paused | as Select, then `if cachedProps().paused { togglePause() }` |
| Left / Right click | ±10 s on the preview; no hold, no seek | `restartScrubIdle(); apply(transport.scrubNudge(direction: ∓1/±1)); flashControls()`; never `beginHold`. The release reaches `pressesEnded` (`:1784-1795`) whose `transport.pressEnded` returns `.none` outside `.stepping`: harmless |
| Up | Cancel, bar stays | `apply(transport.scrubCancel())` (the idle edge flashes the bar) |
| Down click | Cancel, then open the panel (no chip, no up-next, no pill) | `apply(transport.scrubCancel())`; `if presentedViewController == nil { refreshTracksAsync(); onOpenPanel?(.info) }` |
| Swipe down | Cancel, then panel | §1.5 (`handleSwipeDown` is ignored only while the *current stroke* is horizontal) |
| Menu | Cancel, bar stays | existing `MenuPrecedence` `.cancelMode` on release (§2) |
| Light tap | Nothing | `route(.lightTap)` and the tap recogniser's `handleLightTap`: add `guard !scrubbing` to `performLightTap` |
| A new pan stroke | Horizontal (45 pt) moves the same preview; vertical down cancels + panel; vertical up cancels | `.beginScrub` from `.scrubbing` would call `scrubBegan`, which returns `.none` from a non-idle mode, so the stroke just continues; the `.beginScrub` branch must skip `scrubBegan`/`flashControls` side effects only when not idle (guard `if case .idle = transport.mode`) |

`pressesCancelled` (`:1800`): a cancelled arrow while scrubbing does nothing to the scrub (its nudge already applied). Leave the existing body; it only touches `.stepping`.

## 4. The preview card

### 4.1 Model (`TransportBarModel.swift`)

Add `@Published var previewFrame: CGImage? = nil`, `@Published var scrubCurveCode = "o"`, and `#if DEBUG @Published var debugArbiter = "u" #endif`. Add, at the top of the same file:

```swift
/// The read side of `SeekPreviewStore` (sibling spec). A frame within ±GOP of `sec`, or nil.
protocol SeekPreviewSource: AnyObject, Sendable {
    func thumbnail(near sec: Double) async -> CGImage?
}
```

(If the store spec makes `thumbnail(near:)` synchronous, conformance still compiles; an actor's isolated method satisfies `async`.) On `MPVPlaybackState` (`:60-111`) add `@Published var scrubCardUp = false` (the screen observes `state`, not `state.transport`).

### 4.2 Frame plumbing (controller)

`requestPreviewFrame()`: cancel `previewFrameWork`; arm 50 ms; on fire, read the target from `transport.mode` (`.scrubbing(t)` else return), `previewFrameToken += 1; let token = previewFrameToken`, then `Task { [weak self, source = seekPreviewSource] in let img = await source?.thumbnail(near: t); await MainActor.run { guard let self, self.previewFrameToken == token else { return }; self.state.transport.previewFrame = img } }`. Also call it once from `.beginScrub` and after each nudge. A nil source leaves `previewFrame` nil (time only).

### 4.3 Geometry (`TransportBarLayout`, `PlayerTransportBar.swift:13-88`)

```swift
static let cardSize = CGSize(width: 400, height: 225)
static let cardGapAboveTrack: CGFloat = 30      // above the 14 pt active track's top
static let cardCornerRadius: CGFloat = 12
static let chapterGap: CGFloat = 8
static let chapterHeight: CGFloat = 34

/// Card centred on `centreX`, clamped inside [trackMinX, trackMaxX].
func previewCardFrame(centreX: CGFloat) -> CGRect   // y = trackCentreY − 7 − 30 − 225
/// Chapter title above the card (or, with no card, at the card's top edge y), same clamp, given width.
func chapterLabelFrame(centreX: CGFloat, width: CGFloat, cardShown: Bool) -> CGRect
```

On 1920 × 1080: card y = 985 − 262 = 723 … 948; chapter label 681 … 715. With no card the chapter label's bottom sits at the card's top edge minus 8 (same y as with a card): one position, no jump when a frame arrives.

`PlayerChipStyle` (`PlayerChipStyle.swift:16-17`): add `static let scrubCardBottomInset: CGFloat = 420` (above the chapter label, 1080 − 681 + 21). MPV `chipBottomInset` (`:2723-2725`): `state.scrubCardUp ? PlayerChipStyle.scrubCardBottomInset : (existing)`.

### 4.4 View (`PlayerTransportBar.chrome`, `:207-227`)

- `let scrubbing = { if case .scrubbing = model.mode { true } else { false } }()`.
- After `track(...)`, when `scrubbing`: compute `cx = layout.x(forSec: target, durationSec:)`. If `model.previewFrame` is non-nil: `Image(decorative: frame, scale: 1).resizable().aspectRatio(contentMode: .fill)` in `cardSize`, clipped to a `RoundedRectangle(cornerRadius: 12)`, `.overlay(RoundedRectangle(...).strokeBorder(.white.opacity(0.4), lineWidth: 2))`, `.glassEffect(.regular, in: RoundedRectangle(...))` behind the image, positioned at `previewCardFrame(centreX: cx)`; `accessibilityIdentifier("player.bar.previewCard")`, `accessibilityHidden(true)`.
- Chapter title: `model.chapters.last(where: { $0.sec <= target + 0.001 })?.title`, non-empty only; `PlayerTransportMetrics.meta`, one line, tail truncation, max width `cardSize.width`; measured width via `onGeometryChange` into a new `@State chapterWidth`; positioned at `chapterLabelFrame`; `accessibilityIdentifier("player.bar.previewChapter")`.
- End labels: in `timesRow` (`:296-347`), when scrubbing force `showElapsed = false` and `showRemaining = false` (overlap logic stays for stepping); give both `Text`s `.animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: scrubbing)`.
- Lockup and pill row already fade on `active` (`:214-221`); change their `.animation(.easeInOut(duration: 0.15), value: active)` to `reduceMotion ? nil : …`. The card and chapter label appear with `.transition(.opacity)` under the same `reduceMotion ? nil : .easeInOut(duration: 0.15)`.
- The target label (`:337-345`) and the live dot (`:271-277`) are reused unchanged: `previewSec` is the scrub target.

## 5. Probes (DEBUG)

- `debug_transportProbe` (`PlayerTransportBar.swift:352-367`): append ` scrub=<%.1f|nil> curve=<o|b> frame=<0|1> arb=<u|h|v|i>` (`scrub` from `model.mode`, `frame` = `previewFrame != nil`, `arb` = `model.debugArbiter`).
- `debug_seekProbe` (`Player/SeekProbe.swift`): `@Published var scrubs = 0`, label gains ` scrubs=\(probe.scrubs)`. A scrub commit also bumps `commits` through `issueCommit`'s existing `note(commit:stages:)`.
- `NSLog("[Scrub] begin base=%.2f thr=%.0f curve=%@")`, `[Scrub] commit target=%.2f from=%.2f stages=%@`, `[Scrub] cancel why=%@` (menu/up/down/idle/panel), `[Scrub] stroke end intent=%@ travel=%.0f vx=%.0f`: one line each, DEBUG only, for the device pass console.

## 6. DEBUG scrub injection (`-debug.scrubInject`)

The simulator cannot swipe. Launch arg `-debug.scrubInject "<script>"`; script = samples separated by `;`, each `dx,dt` or `dx,dt,dy` (per-sample increments in points; `dt` seconds before the sample; missing `dy` = 0). Pure parser in `ScrubGestureArbiter.swift`: `enum ScrubInjectScript { static func parse(_ s: String) -> [(dx: Double, dy: Double, dt: Double)] }` (malformed samples skipped, `dt` clamped to [0, 1]).

Trigger: Darwin notification `com.nuvio.debug.transport.scrubInject`, reposted as `Notification.Name.nuvioDebugTransportScrubInject` by `TransportDebugDarwinBridge.install()` (`PlayerTransportBar.swift:395-409`: add the second observer in the same `install`). The controller observes it in the `#if DEBUG` block of `viewDidLoad` (`:390-397`; token removed in `destroyPlayer` like `lightTapObserver`). On fire: `scrubArbiter.touchBegan()`, then a chain of main-runloop `Timer`s, each adding its sample to cumulative `(tx, ty)` and calling `route(scrubArbiter.moved(...))` with the live `scrubContext()`, then `route(scrubArbiter.touchEnded(...))`. Same path as the real recogniser below `handleScrubPan`. Legs post it ≥ 0.6 s after their last remote press (move suppression).

## 7. Developer rows and strings

`Screens/Settings/DeveloperSettingsPane.swift` after "Exact Seek Delay (A/B)" (`:189-200`), same `SettingsPickerRow` pattern, `@AppStorage("debug.scrubCurve") var scrubCurve = ""` and `@AppStorage("debug.scrubRateScale") var scrubRateScale = 0.0`:

- **"Swipe Scrub Curve (A/B)"**, options `["", "bobsupra"]`, labels "Auto" / "Flick", `descriptionID: .devScrubCurve`.
- **"Swipe Scrub Speed (A/B)"**, options `[0.0, 0.5, 2.0]`, labels "Auto" / "Slower" / "Faster", `.devScrubSpeed`.

`SettingsDescriptions.swift`: cases `devScrubCurve = "dev.scrubCurve"`, `devScrubSpeed = "dev.scrubSpeed"`; texts "An A/B switch for how a swipe moves the playhead. Auto moves it at a steady rate that scales with the film's length; Flick moves it further the faster you swipe." and "An A/B switch for how far a swipe moves the playhead. Slower halves it; Faster doubles it."; add both to the "Applies to the next playback." footnote arm (`:413`). New English keys: the two titles, "Flick" (Auto/Slower/Faster exist). Five locales at the end of the batch, per the plan. Nothing user-facing in the player itself.

## 8. Tests

### `NuvioTVTests/ScrubGestureArbiterTests.swift` (new, ≥ 17)

Context helper with defaults: bar up, playing, no pill, not scrubbing, canScrub, no presses, last press 10 s ago, `now = 100`.

1. 44 pt horizontal, bar up → `.none`, undecided. 2. 45 pt → `.beginScrub`. 3. Bar hidden, playing: 159 → `.none`; 160 → `.beginScrub`. 4. Bar hidden, paused: 45 → `.beginScrub` (D1). 5. Pill focused: 189 → `.none`; 190 → `.beginScrub`. 6. Already scrubbing, bar hidden: 45 → `.beginScrub`. 7. Vertical down 110 → `.openPanel`; 109 → `.none`. 8. Vertical up 110 → `.swipeUp`. 9. Vertical wins: (dx 60, dy 120) → `.openPanel`. 10. Diagonal (dx 100, dy 90) → stays undecided; end → `.none` (not a tap). 11. Tap: travel 12 then end → `.lightTap`; travel 20 → `.none`. 12. After horizontal, samples return `.scrubDelta` with per-sample increments; the decision's own travel is not returned. 13. Move suppression: last press 0.3 s ago, 80 pt → `.none`; at 0.45 s a further 44 pt from the rebased origin → `.none`, 45 → `.beginScrub`. 14. A press down (pressesDown 1) suppresses. 15. `canScrub == false` at threshold → `.ignored`, later samples `.none`. 16. `abandon()` mid-stroke → following samples `.none`. 17. Orivio `deltaSec`: 600 s → 0.25/pt; 7200 s → 1.5/pt; duration 0 → 0.25/pt. 18. bobsupra `deltaSec`: inc 2 at 600 s → `2·0.06·0.9 = 0.108`; inc 5 at 600 s (df 0.8) → `5·0.06·(1 + 1.5·0.4·0.8) = 0.444`; inc 20 at 600 s → `20·0.06·6·0.8 = 5.76`; inc −20 → −5.76; inc 20 at 14400 s (df 1.8 cap) → `12.96`. 19. `ScrubInjectScript.parse`: `"20,0.03;0,0.03,30;bad"` → two samples.

### `NuvioTVTests/TransportPreviewTests.swift` additions (≥ 9)

1. `scrubBegan` from idle → `.scrubbing(origin)`, `previewSec == origin`. 2. `scrubMoved(140)` Orivio, duration 600 → target origin + 35. 3. Scale 2 → +70. 4. bobsupra curve via `scrubMoved(20)` ×7 at 600 s → +40.32 (±0.01). 5. Clamp: moves past the end stop at `duration − 0.5`; below 0 stop at 0. 6. `scrubNudge(-1)` → −10, first time below `origin − 1` returns `.cancelUpNext`, a second backward move returns `.none`. 7. `scrubCommit` after moves → `.commit` with `fromSec == origin`, stages `[.keyframes, .exact]` uncovered / `[.exact]` covered; mode idle, `previewSec == target`. 8. `scrubCommit` with no movement → `.none`, `previewSec == nil`. 9. `scrubCancel` and `cancel()` from scrubbing → idle, `previewSec == nil`, `.none`. 10. From `.scanning` / `.stepping`, `scrubBegan` changes nothing (the controller ends them first). 11. `pressEnded` regression: the P1 commit-request cases still pass unchanged (existing tests cover it; run the whole class).

### UI legs (`NuvioTVUITests/PlayerTransportUITests.swift`, existing `launch`/`launchWithBarHidden` helpers `:12-32`, `:179-183`)

Add a `postScrubInject()` helper (same `CFNotificationCenterPostNotification` call as `testLightTapFlipsEndTime`, `:225-226`) and teach `bar(_:)`/`probe(_:)` nothing new (they already split on `key=value`). Script `S = "20,0.03" repeated 10 times` (200 pt; decision at 60, 140 pt applied → Orivio +35 s on the 600 s fixture).

1. **`testScrubSelectCommitsOnce`**: `launchWithBarHidden(extra: ["-debug.scrubInject", S])`; Up; wait `vis=1`; sleep 0.6; read `commits` c0; post; wait `mode=scrubbing`, then 1 s for the script; `T = scrub`; assert `T − pos_before ∈ [30, 42]`, `curve=o`; Select; wait `commits == c0+1`, `scrubs=1`, `|lastTarget − T| ≤ 1`, `mode=idle`; after 4 s the bar `pos` is within 2.5 s of `T + 4` (one GOP of the 2 s-keyframe fixture plus playback) and `commits` is still c0+1.
2. **`testScrubMenuCancels`**: same inject; Menu; wait `mode=idle prev=nil vis=1`; `scrubs=0`, `commits == c0`; `player.mpv` still exists (P1's cover gate makes this a real assertion).
3. **`testPillFocusedScrubIgnored`**: inject `"25,0.03"` ×6 (150 pt); Up, Up (wait `focus=pill:subtitles`); sleep 0.6; post; wait 1.5 s; `mode=idle`, `focus=pill:subtitles`, `scrubs=0`.
4. **`testVerticalSwipeOpensPanel`**: inject `"0,0.03,30"` ×5; Up; sleep 0.6; post; `player.panel.tab.info` exists within 6 s with value `selected` (`PlayerTopPanel.swift:101`).
5. **`testScrubCurveFlick`**: extra `-debug.scrubCurve bobsupra`; as leg 1 up to the read; `curve=b`, `T − pos_before ∈ [36, 47]` (+40.32); Menu to end.

## 9. Agent brief (W1 agent A: gestures + arbiter + scrub mode + card)

Clone `~/Claude/Projects/NuvioMobile-player`, branch `claude/player-p2` (do not create another; `git checkout -b` refuses over the MPVKit symlink). MPVKit is a symlink over the gitlink: **stage by explicit paths, never `git add -A`**; `git status` may error on MPVKit, ignore it. One build at a time; Bash tool sandbox OFF for `xcodebuild test` (in-sandbox it exits 70). Agent B (store) runs in parallel on other files; you own `SeekPreviewSource` (§4.1), B conforms to it. Do not touch `SeekPreviewStore.swift`, chapters, aspect or `commandNode`.

Files: create `Screens/Player/ScrubGestureArbiter.swift`, `NuvioTVTests/ScrubGestureArbiterTests.swift`; edit `Screens/Player/TransportPreview.swift`, `Screens/Player/TransportBarModel.swift`, `Screens/Player/PlayerTransportBar.swift` (layout statics + chrome + timesRow + probe + Darwin bridge), `Screens/Player/PlayerChipStyle.swift`, `Screens/Player/SeekProbe.swift`, `Screens/Player/PlayerRemoteRules.swift` (comment only), `Screens/Settings/DeveloperSettingsPane.swift`, `Screens/Settings/SettingsDescriptions.swift`, `Localizable.xcstrings` (append English keys), `NuvioTVTests/TransportPreviewTests.swift`, `NuvioTVUITests/PlayerTransportUITests.swift`; add new files to `iosApp.xcodeproj` targets (app: the arbiter; NuvioTVTests: the test). MPV regions: state (`:60-111`, `MPVPlaybackState.scrubCardUp`), fields (`:135-150`), `init` (`:338-341`), `viewDidLoad` recognisers + DEBUG observers (`:375-397`), `handleSwipeDown`/`performLightTap` (`:402-430`), `pressesBegan` (`:1629-1767`), `apply`/`publishTransport` (`:1870-1896`), new methods next to `beginHold` (`:1834`), `destroyPlayer` (remove the inject observer), `chipBottomInset` (`:2723`), and the delegate extension at the end of the controller.

Order: (1) arbiter + curves + parser + its tests → run them; (2) `TransportPreview` scrub API + tests → run the class; (3) model/protocol/probes; (4) controller wiring §3 + §1.4–1.5; (5) card view §4.3–4.4; (6) Developer rows + strings; (7) Debug build; (8) UI legs 1–5 plus the P1 regression legs `testHoldStepCommitsOnce`, `testScanLatchesAndCycles`, `testScanMenuCancelsBackToOrigin`, `testLightTapFlipsEndTime`, `testMenuHidesBarThenExits`, `testPillFocusWalk`; (9) Release build. Commit per step with explicit paths.

Commands, from `~/Claude/Projects/NuvioMobile-player/iosApp`, destination `platform=tvOS Simulator,id=FA87E9B6-F28D-4DF9-84E4-A5A4C5DBFC4E`:
- Smoke server first: `python3 build/smoke/range_server.py 8000 build/smoke` (background); URL `http://127.0.0.1:8000/test-long.mkv` (600 s HEVC, 2 s keyframes).
- Build: `xcodebuild -project iosApp.xcodeproj -scheme NuvioTV -configuration Debug -destination '<dest>' -derivedDataPath build/DerivedData build` (Release: `-configuration Release`).
- Unit: `xcodebuild test -project iosApp.xcodeproj -scheme NuvioTVTests -destination '<dest>' -derivedDataPath build/DerivedData -only-testing:NuvioTVTests/ScrubGestureArbiterTests -only-testing:NuvioTVTests/TransportPreviewTests -only-testing:NuvioTVTests/PlayerRemoteRulesTests -only-testing:NuvioTVTests/PlayerTransportBarLayoutTests`.
- UI: `TEST_RUNNER_PLAYER_BAR_PROBE=1 TEST_RUNNER_PLAYER_SMOKE_URL=http://127.0.0.1:8000/test-long.mkv xcodebuild test -project iosApp.xcodeproj -scheme NuvioTVUITests -destination '<dest>' -derivedDataPath build/DerivedDataUITests -only-testing:NuvioTVUITests/PlayerTransportUITests/<test>` (the helper already passes `-player.bufferMB 8 -debug.mpvSmokeStartOver YES`). If the simulator wedges after ~6 UI runs, `xcrun simctl shutdown` + `boot` it.

Report: commit list; unit counts per class; each UI leg PASS/FAIL with its final probe lines; Debug + Release result; every deviation from this spec with the reason; anything the simulator could not prove (all real-swipe feel: thresholds, curves, tap-vs-pan, the down-swipe dedupe) listed for the device pass.

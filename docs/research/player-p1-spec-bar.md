# P1 spec: the transport bar (mpv player)

**Batch P1, item "the transport bar"** of `docs/player-revamp-plan-2026-10-06.md`. Written 2026-10-06 against the P1 clone `~/Claude/Projects/NuvioMobile-player` (branch `claude/player-p1` at `5feef338`). Paths are relative to `NuvioMobile/iosApp/NuvioTV/`. Decisions applied: D4 (Infuse geometry), D8 (no black tint, 300 pt scrim), D2/D5 only as far as the bar draws them. Out of scope (sibling specs own them): the preview/commit state machine and scan (`player-p1-spec-preview.md`, `Screens/Player/TransportPreview.swift`), the Settings rows, the skip-chip auto-hide, audio-delay persistence, failure-alert engine buttons.

## Critique decisions (2026-10-06, Opus critique; record `docs/research/player-p1-critique-2026-10-06.md`)

These override anything below that disagrees; the sections have been edited to match.

1. **Paths.** Player files live in `Screens/Player/`, settings panes in `Screens/Settings/` (the earlier `Player/…` paths did not exist).
2. **Pill focus model: player-driven is PRIMARY.** `TransportBarModel.focusedPill: PillKind?` is published, the pills are non-focusable views drawn with the focused look, and the controller's `pressesBegan` routes Left/Right/Select/Down/Menu/Play to the row while `focusedPill != nil` (§4). System focus (`@FocusState` + `.focusSection()` + `reclaimFocus` hop) is the documented alternative, used only if device-pass item 6 reports that pill movement must follow touch-surface swipes (clicks only move the player-driven row). Reason: `PlayerChipStyle.swift:4-8` ("libmpv owns the remote"), every press stays in one switch (Menu precedence, hide timer, P2's pan arbiter), and no focus hand-back can produce the "Up does nothing" class.
3. **Hide rule** (identical text in both specs) — §5 "Hide rule".
4. **Menu precedence** (identical text in both specs) — §5 "Menu precedence".
5. **Ownership: sequential, not parallel.** Agent A (preview spec) runs first and creates `Screens/Player/TransportBarModel.swift` and all controller seek/scan/buffered wiring; agent B (this spec) runs second on A's commit. Both edit `MPVPlayerView.swift`, `pressesBegan` in particular; one working tree and one build at a time rule out a parallel split. Region list in "Agent brief".
6. **One model, one set of names.** `TransportBarModel` (on `MPVPlaybackState.transport`) is the only published transport state: `previewSec`, `mode: TransportPreview.Mode`, `bufferedRanges: [BufferedRange]`. There is no `state.previewSec`, `state.transportMode` or `state.bufferedRanges`. `BufferedRange`, `TransportPreview.parseSeekableRanges` and `BufferedRange.merge(_:gapSec:durationSec:)` are agent A's (preview spec §4); this spec has no buffered parser and no buffered tests.
7. **Chip insets while the bar shows:** bottom 240, trailing 86 (§2).
8. **Probes:** `debug_transportProbe` (this spec: geometry, focus, visibility) and `debug_seekProbe` (preview spec: commits, stages, speed, chip). Shared fields are spelled identically: `mode=` from `Mode.probeName`, `pos=%.1f`.

## 1. Files

| File | Change |
|---|---|
| `Screens/Player/TransportBarModel.swift` (new, **created by agent A**) | `TransportBarModel`, `TransportSpan`, `TransportChapter` (§3). Agent B only adds `focusedPill`/`pills`/presentation fields if A left them out. |
| `Screens/Player/PlayerTransportBar.swift` (new) | `PlayerTransportBar` view, `TransportBarLayout` (pure geometry), `TransportTimeFormat`, `TransportSpanMath`, `TransportHideRule`, `PlayerTransportMetrics` (fonts). |
| `Screens/Player/PlayerPills.swift` (new) | `PillKind`, `PlayerPillRow` view. |
| `DesignSystem/FlatControlStyles.swift` | Add `PlayerPillDisc` (a view, not a `ButtonStyle`: the pills are non-focusable) next to `ChipButtonStyle` (`:127`) so it can use the file-private `FocusLook` (`:10-21`). |
| `Screens/MPVPlayerView.swift` | State additions, press/hide hunks, overlay swap, deletions (below). |
| `Screens/Player/PlayerTopPanel.swift` | `initialTab` init parameter. |
| `Screens/PlaybackModels.swift` | none: agent A adds `PlayerTuning.showClockKey = "player.showClock"` and `holdModeKey` in W1. |
| `NuvioTVTests/PlayerTransportBarLayoutTests.swift`, `NuvioTVUITests/PlayerTransportBarUITests.swift` (new) | §9. The project uses synchronized groups, so new files need no `.pbxproj` edit. |

**Deleted:** `PlayerControlsOverlay` (`MPVPlayerView.swift:2112-2158`, including its `timeString`) and `ProgressBar` (`:2160-2172`). The overlay call at `:2004-2006` becomes `PlayerTransportBar(model: state.transport, state: state)`. The `showPauseInfo`/`pauseInfoTask` timer (`:1939-1940`, `:2009-2014`, `:2046`, `:2088-2109` except the idle-timer line) is replaced by §6.

**Ownership.** Sequential: agent A's commit lands first (preview spec "Agent brief"); agent B starts from it. Agent A owns, in `MPVPlayerView.swift`: the seek/scan state fields, `transport` on `MPVPlaybackState`, `refreshState` mirroring (position, duration, paused, speed, preview, mode, buffered), `:1018` skip spans, the `.leftArrow`/`.rightArrow` cases, the mode-active pre-checks at the top of the `.select`/`.playPause`/`.downArrow`/`.upArrow`/`.menu` cases, `pressesEnded`, `beginSeek`→`beginHold`, `issueSeek`/`issueCommit`, `startScan`/`endScan`, the options array, and the one `SeekProbeLabel` line in the screen body. Agent B owns everything else listed in §4–§6: `controlsSession` and the closures on `MPVPlaybackState`, `viewDidLoad` wiring + light-tap recogniser, the pill-routing branch and the bar-hide branch of `pressesBegan` (inserted AFTER A's mode-active pre-checks), `flashControls`/`scheduleHide`/`hideControlsNow`, `onOpenPanel`'s signature, `MPVPlayerRepresentable`, and the `MPVPlayerScreen` body (overlay swap, pause card, chip insets, `onAppear` feeds). B must keep A's `SeekProbeLabel` line when swapping the overlay.

## 2. Geometry (1920 × 1080 canvas, all `.ignoresSafeArea()`)

The bar is one full-screen `GeometryReader` with `.ignoresSafeArea()`. Children are placed by frames from `TransportBarLayout(canvas: CGSize, pillCount: Int)`, which is pure and unit-tested. tvOS reports 1920 × 1080 points on every Apple TV, but the layout derives everything from `canvas` anyway. Distances are in points; "from bottom" means measured from the bottom screen edge.

| Element | Spec | Token / literal |
|---|---|---|
| Track | x 86 → 1834 (width = W − 172); centre line **95 from bottom** (global y 985) | literal `sideInset = 86`, `trackCentreFromBottom = 95` |
| Track height | 10 at rest, 14 while `mode` is not idle; centre fixed, 0.15 s ease | literal |
| Track base | capsule, white 20 % | literal |
| Buffered fill | capsules per merged span, white 35 % | literal |
| Skip spans | 4 pt band, centred on the track, white 60 %, drawn above buffered and played (invisible over the white played fill by design) | literal |
| Chapter ticks | 2 × track height, white 60 % (empty in P1; renders if given) | literal |
| Played fill | white, 0 → x(previewSec ?? positionSec) | — |
| Live-position dot | only while `previewSec != nil`: 16 pt circle, white, 2 pt black 40 % stroke, centred on track at x(positionSec) | literal (Orivio rest dot 16) |
| Times row | top = track rest bottom + **13** (global y 1003), frame height 34 (Orivio time row) | literal |
| Elapsed | leading edge x 86, 28 pt monospaced | `PlayerTransportMetrics.time` |
| Remaining / end time | trailing edge x 1834, same font | same |
| Target time (preview) | centred under x(previewSec), same row, same font, frame clamped inside 86…1834 | same |
| "Swipe down for info" hint | centred at x = W/2 on the times row, `Theme.Font.caption`, white 70 %; hidden while `previewSec != nil` | token |
| Title | 44 pt semibold, **bottom edge 60 above the track centre** (global y 925), frame height 53, leading x 86 | `PlayerTransportMetrics.title` |
| Meta line | 28 pt regular, white 75 %, frame height 34, directly under the title (spacing 2, global y 927–961; 19 pt clear of the track top) | `PlayerTransportMetrics.meta` |
| Pills | 62 pt discs, spacing **25**, row trailing edge at x 1834, vertical centre = title centre (global y 898) | literal (`FusionMetrics` glyph disc) |
| Lockup width | `W − 172 − pillRowWidth − 40`, where `pillRowWidth = n·62 + (n−1)·25` (6 pills: 497 → lockup 1211) | derived |
| Bottom scrim | `LinearGradient` black 0 at top → 0.55 at bottom, height **300** (global y 780–1080), part of the bar so it fades with it | literal |
| Clock (optional) | top-trailing, inset `Theme.Spacing.screen` (60) from top and trailing, `Theme.Font.sectionTitle.monospacedDigit()`, sits above the stream-info card in one trailing `VStack` when both show | tokens |
| Chips while bar is up | the up-next/skip chip stack's insets become **bottom 240, trailing 86** (`PlayerChipStyle.barUpBottomInset = 240`, `barUpTrailingInset = 86`, added to `PlayerChipStyle`). Check: the lockup/pill block's top is the pill top, y 867 = 213 from bottom (title top 872); 240 leaves 27 pt, more than the focused pill's 1.05 lift (≈ 1.6 pt) plus its 8 pt shadow offset. The action chip (`sectionTitle` = callout + 2 × 16 padding ≈ 70 pt) then spans 770–840, the up-next stack (caption ≈ 41 + 12 + chip) ≈ 717–840, both inside the scrim. Trailing 86 aligns the chip with the track end and the pill row. Back to `PlayerChipStyle.edgePadding` on both edges when the bar hides, animated with `PlayerChipStyle.animation`. Replace the screen's `.padding(PlayerChipStyle.edgePadding)` on both chip branches with `.padding(.bottom, up ? 240 : edgePadding).padding(.trailing, up ? 86 : edgePadding)` where `up = state.controlsVisible`. | literal |

The preview card (400 × 225, 30 pt above the track) belongs to P2/P3. The bar only reserves the slot: the lockup and the pills fade out (0.15 s) while `mode` is not idle.

**No glass panel behind the track (D8).** The old 35 % black-tinted glass card (`:2148`) and its shadow are gone. Legibility comes from the scrim. Glass appears only on the pill discs.

**Long titles.** Title and meta are `.lineLimit(1)` with `.truncationMode(.tail)` inside the lockup width. Pills never shrink and never wrap, and the lockup takes all the squeeze. Fixed frame heights keep the layout independent of font metrics.

**Fonts.** The HIG contract bans fixed point sizes at call sites, and no Theme token matches 44 or 28 (`screenTitle` = title3 48 bold, `metaStrong` = caption1 25 semibold, `body` = 29; `Theme.swift:435-505`). So the literals sit in one place, `PlayerTransportMetrics`, and follow the font family and Larger Text:
- `.system`: `Font.system(size: UIFontMetrics(forTextStyle: rel).scaledValue(for: size), weight: w)`
- `.openSans`: `Font.custom("Open Sans", size: size * Theme.Font.openSansScale, relativeTo: rel).weight(w)`

These are keyed on `Theme.Font.family` (`Theme.swift:205`). title = (44, `.semibold`, rel `.title3`), meta = (28, `.regular`, rel `.body`), time = meta's recipe + `.monospacedDigit()`.

## 3. Model

`Screens/Player/TransportBarModel.swift`, created by agent A in W1 (whole file, so B only consumes it). `PillKind` is declared here too (B's `PlayerPills.swift` adds its `visible`/`panelTab`/symbol extensions), so A's file compiles without B's.

```swift
struct TransportSpan: Equatable, Hashable { var start: Double; var end: Double; var kind: String? }
struct TransportChapter: Equatable { let title: String; let sec: Double }
enum PillKind: String, CaseIterable { case subtitles, audio, speed, sources, episodes, more }

@MainActor final class TransportBarModel: ObservableObject {
    @Published var positionSec: Double = 0
    @Published var durationSec: Double = 0
    @Published var previewSec: Double? = nil                    // written by agent A's apply()
    @Published var mode: TransportPreview.Mode = .idle          // written by agent A's apply()
    @Published var bufferedRanges: [BufferedRange] = []        // merged, clamped (preview spec §4)
    @Published var skipSpans: [TransportSpan] = []             // kind = SkipInterval.type
    @Published var chapters: [TransportChapter] = []           // empty in P1
    @Published var title = ""
    @Published var metaLine = ""
    @Published var isPaused = false
    @Published var playbackSpeed: Double = 1
    @Published var showsEndTime = false                         // light-tap flip
    @Published var showsClock = false                           // player.showClock
    @Published var pills: [PillKind] = []
    @Published var focusedPill: PillKind? = nil                 // player-driven row focus
    var pillsEngaged: Bool { focusedPill != nil }
}
```

`TransportPreview.Mode` gets, in agent A's `TransportPreview.swift`, `var isActive: Bool` (not `.idle`) and `var probeName: String` (`idle`, `stepping`, `scanning`, `scrubbing`). Both probes and the bar use these; nobody else spells the names.

**`MPVPlaybackState` (`MPVPlayerView.swift:29-90`) additions:** agent A: `let transport = TransportBarModel()` (+ `#if DEBUG let seekProbe = SeekProbe() #endif`). Agent B: `controlsVisible` (`:34`) gains `didSet { if controlsVisible && !oldValue { controlsSession &+= 1 } }`; `@Published private(set) var controlsSession = 0`. No new closures: every pill input arrives in the controller's `pressesBegan` (§4).

**Feeds:**

| Field | Source |
|---|---|
| positionSec, durationSec, isPaused, playbackSpeed | agent A, `refreshState` (`:1236-1244`), right after the existing `state.*` assignments |
| bufferedRanges | agent A, preview spec §4 (coalesced `demuxer-cache-state` read, JSON parse, fallback span) |
| skipSpans | agent A, at `:1018`, beside `state.skipIntervals = intervals`: map to spans, dropping `type` == `post-credits` (case/space-insensitive, same test as `SkipSegmentPlanner.swift:254`) |
| title, metaLine, pills, showsClock | agent B, `MPVPlayerScreen.onAppear` (`:2062`). title = `context.title`; metaLine = `[NativeInfoHeader(context:).subtitle, context.providerName]` non-empty parts joined by `" · "` (`Screens/Player/PlayerInfoTab.swift:25-40` already builds "S1 · E4 · Episode name"); pills = `PillKind.visible(...)`; showsClock = `UserDefaults.standard.bool(forKey: PlayerTuning.showClockKey)` |
| previewSec, mode | agent A's `apply(_:)` after every `TransportPreview` call |
| showsEndTime | agent B, controller light tap (§6) |
| focusedPill | agent B, controller `pressesBegan` (§4) |

## 4. Pill row (`PlayerPills.swift`)

| `PillKind` | SF Symbol | Shown when | Opens `PlayerPanelTab` | AX label key |
|---|---|---|---|---|
| `.subtitles` | `captions.bubble` | always | `.subtitles` | "Subtitles" (exists) |
| `.audio` | `speaker.wave.2` | always | `.audio` | "Audio" (exists) |
| `.speed` | `gauge.with.dots.needle.67percent` | always | `.playback` | "Speed" (new) |
| `.sources` | `square.stack.3d.up` | `canSwitchStreams` (`onPlayNext != nil`) | `.playback` | "Sources" (exists) |
| `.episodes` | `list.bullet.rectangle` | `canSwitchStreams && context.contentType == "series" && !context.episodes.isEmpty` | `.playback` | "Episodes" (exists) |
| `.more` | `ellipsis` | always | `.info` | "More" (new) |

The order is fixed as listed. `static func visible(isSeries:canSwitchStreams:hasEpisodes:) -> [PillKind]` and `var panelTab: PlayerPanelTab` are pure. In P1, Speed/Sources/Episodes land on the Playback tab, not on a specific column; column focus is a follow-up.

**View.** An `HStack(spacing: 25)` of `PlayerPillDisc(symbol:, focused: model.focusedPill == kind)` (no `Button`, nothing focusable), each with `.accessibilityElement()`, `.accessibilityLabel(kind.title)`, `.accessibilityAddTraits(.isButton)`, `.accessibilityValue(model.focusedPill == kind ? "focused" : "")` and `.accessibilityIdentifier("player.pill.\(kind.rawValue)")`. Glyph: `Image(systemName:).font(.system(size: 26, weight: .semibold)).frame(width: 62, height: 62)`.

**`PlayerPillDisc`** (in `FlatControlStyles.swift`, same anatomy as `ChipBody` `:134-186`, driven by its `focused` parameter instead of `@Environment(\.isFocused)`). At rest: `Circle()` with `.glassEffect(.regular, in: Circle())` (no tint) and a white glyph. Focused: `Circle().fill(FocusLook.platter)`, glyph `FocusLook.onPlatter`, `FocusLook.liftShadow`, scale `FocusLook.liftScale`, `FocusLook.anim`. No press animation in P1. This is the app's existing system-focus look, with no custom rings.

**Focus grammar: player-driven (PRIMARY, critique decision 2).** The mpv controller keeps first responder the whole time; the row's "focus" is `transport.focusedPill`. All of it lives in `pressesBegan`, after agent A's mode-active pre-checks (preview spec §2.2): the first two rows are the new `.upArrow` case; the rest are one branch, checked before the normal cases, that runs when `transport.focusedPill != nil` and consumes the press:

| Input | State | Result |
|---|---|---|
| Up | bar hidden, `mode` idle | `flashControls()` (bar up, focus on the track) |
| Up | bar up, `mode` idle, no pill | `focusedPill = pills.first`, `flashControls()` |
| Up | pill focused | no-op, `flashControls()` |
| Left / Right | pill focused | `focusedPill` moves one place, clamped at the ends (no wrap), `flashControls()`. Never seeks. |
| Down | pill focused | `focusedPill = nil` (back on the track), `flashControls()`. Does not fire the skip chip or open the panel; the next Down does. |
| Select | pill focused | `let tab = pill.panelTab; focusedPill = nil; refreshTracksAsync(); onOpenPanel?(tab)`. The panel's `onClosed` already calls `reclaimFocus` (`MPVPlayerView.swift:1901-1904`). |
| Play/Pause | pill focused | `togglePause(); flashControls()`; the pill stays focused. |
| Menu | pill focused | `focusedPill = nil`, `hideControlsNow()`, `swallowMenuRelease = true` (see "Menu precedence", §5) |

`flashControls()` is the "input" signal: every row press re-arms the hide timer through it, so no SwiftUI-side `noteInput` exists.

**Focus reset.** `focusedPill = nil` whenever the bar hides (`hideControlsNow()` and the hide work item both clear it) and on every `controlsSession` bump (hidden → shown), so every raise starts on the track. Never from `onAppear`: the bar stays in the tree permanently (§6), so `onAppear` fires once.

**Controller wiring** (`viewDidLoad`, `:256-262`): only the light-tap recogniser (§6). `onOpenPanel` (`:206`) becomes `((PlayerPanelTab) -> Void)?`; the existing calls at `:277` and `:1346` pass `.info`. `MPVPlayerRepresentable` (`:1896`) builds `PlayerTopPanel(model:extraTab:initialTab: tab)`. `PlayerTopPanel` (`Screens/Player/PlayerTopPanel.swift:36`) gains `init(model:extraTab:initialTab: PlayerPanelTab = .info)` with `_tab = State(initialValue: initialTab)`; its `onAppear` already focuses `tab` (`:56`).

**The alternative (not built in P1): system focus.** Real `Button`s with `.focused($focusedPill, equals:)`, `.disabled(!engaged)`, `.focusSection()`, and `DispatchQueue.main.async { state.reclaimFocus?() }` on disengage. It buys touch-surface swipes between pills and real VoiceOver focus; it costs a focus hand-back on the critical path (plan Risks, "Up does nothing"), presses that no longer reach `pressesBegan` while a pill holds focus (so the hide timer, Menu precedence and P2's pan arbiter split across UIKit and SwiftUI), and a model `PlayerChipStyle.swift:4-8` says this screen has never hosted. **Trigger to switch:** device-pass item 6 reports that the pill row should follow touch-surface swipes, or that clicks alone feel wrong. Identifiers, the probe's `focus=` field and `testPillFocusWalk` stay valid in both models. P2's pan recogniser can map horizontal pans to `focusedPill` moves while a pill is focused, which closes most of the swipe gap without the switch.

## 5. Press and hide hunks (`MPVPlayerView.swift`, agent B, on top of agent A's commit)

- `pressesBegan` (`:1321`):
  - `.select`/`.playPause` record `lastClickUptime = systemUptime` first.
  - Agent A's mode-active pre-checks run first in every case (preview spec §2.2); they consume the press when a scan or held step is live.
  - Then the pill branch (§4) when `transport.focusedPill != nil`.
  - New `.upArrow` case (bar hidden → raise; bar up → focus the first pill), per §4.
  - `.menu`: the Menu precedence list below, in that order.
- `flashControls` (`:1475-1484`) becomes `state.controlsVisible = true; scheduleHide()`. `scheduleHide()` cancels `hideWork` and reads `delay = TransportHideRule.delay(isPaused: cachedProps().paused, pauseCardEnabled: playerSettings?.pauseOverlayEnabled != false)`; `nil` means no timer. When it fires, the work item hides (and clears `focusedPill`) only if `TransportHideRule.mayHide(pillFocused: transport.focusedPill != nil, modeActive: transport.mode.isActive)`; otherwise it does nothing, and the next input re-arms it.
- `togglePause()` calls `flashControls()` after it (it already does at `:1326`), so pausing re-reads the paused delay.
- `hideControlsNow()`: cancel `hideWork`, `transport.focusedPill = nil`, `state.controlsVisible = false`.
- Every return of `transport.mode` to idle calls `flashControls()` (agent A's `apply` does it after a commit or an end of scan).

**Hide rule** (identical text in both P1 specs). The bar hides 4 s after the last input while playing. While paused, it hides 5 s after the last input only when the Pause Info Card is enabled (the shared `pauseOverlayEnabled`, default on), and the card then fades in 0.25 s after the bar's fade ends; with the card disabled, the paused bar never hides. The bar never hides while a pill is focused (`transport.focusedPill != nil`) or while `transport.mode` is not idle: a hide timer that fires in either state does nothing, and the next input re-arms it. Any press other than Menu while the card shows raises the bar, which removes the card; Menu follows the precedence list. Menu hides the bar at once (Menu precedence). In code: `TransportHideRule.delay(isPaused:pauseCardEnabled:) -> TimeInterval?` (4 / 5 / `nil`) and `TransportHideRule.mayHide(pillFocused:modeActive:) -> Bool`.

**Menu precedence** (identical text in both P1 specs). The top panel is a presented view controller: while it is up, Menu goes to it and closes it, so it comes first by construction. In the controller's `.menu` case, the first match wins and every case except the last sets `swallowMenuRelease = true`:
1. `transport.mode` is stepping → `cancel()` (nothing committed); scanning → `cancel()` (back to where the scan started). The bar stays up.
2. The up-next chip is showing → `state.upNextDismiss?()` (today's rule, `:1350-1353`).
3. A pill is focused → `focusedPill = nil` and `hideControlsNow()`.
4. The bar is up → `hideControlsNow()`.
5. Otherwise → `closeFailover(); onExit?()`.
The skip chip is not part of the list: Menu never dismisses it (it auto-hides after 10 s, preview spec §6), so with only the skip chip on screen Menu exits, as today. The pause card is not part of it either: with the card up and the bar hidden, Menu exits.

## 6. View behaviour

- **Always in the tree.** `PlayerTransportBar` is never conditionally inserted. The chrome uses `.opacity(visible ? 1 : 0)`, `.offset(y: visible ? 0 : 24)` (0 when Reduce Motion is on), `.animation(.easeInOut(duration: 0.25), value: visible)` and `.allowsHitTesting(visible)`. That is the plan's 0.25 s opacity + 24 pt bottom slide. The video layer never moves.
- **Pause card** (`:2008-2014`): shown when `state.isPaused && !state.controlsVisible && !state.isBuffering && pauseCardEnabled`, with `pauseCardEnabled` read once in `onAppear` (same read as `:2095`). Transition: `.opacity.animation(.easeInOut(duration: 0.25).delay(0.25))`, so it starts after the bar's fade ends. Any press other than Menu raises the bar (`flashControls`), which removes the card. The old `showPauseInfo`/`pauseInfoTask` 1.5 s timer is deleted (§1).
- **Light tap.** Add `UITapGestureRecognizer(target:action: #selector(handleLightTap))` in `viewDidLoad` with `allowedPressTypes = []` and `allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]`. `handleLightTap()`:
  1. ignore if `systemUptime − lastClickUptime < 0.5` (a click is also a touch);
  2. if `!state.controlsVisible`, call `flashControls()`;
  3. otherwise toggle `transport.showsEndTime`; when it turns true, (re)arm a 4 s `endTimeWork` that sets it false, then call `flashControls()`.

  `showsEndTime` resets to false on every `controlsSession` bump. DEBUG builds also observe the Darwin notification `com.nuvio.debug.transport.lightTap`; a static `CFNotificationCenter` callback reposts it as `NotificationCenter` `.nuvioDebugTransportLightTap`, and the controller observes that with a block token removed in `destroyPlayer`, never in `deinit` (the BUG-141 lesson).
- **Right label:** `showsEndTime ? "ends \(TransportTimeFormat.endClock(now:, remaining:, speed:))" : TransportTimeFormat.remaining(position, duration)`. The end time is `now + (duration − position) / max(speed, 0.1)`, formatted with `DateFormatter` `timeStyle .short`, `dateStyle .none`, current locale. While `durationSec <= 0`: remaining shows `--:--` and no end time is offered (the tap is ignored).
- **Formats** (`TransportTimeFormat`, a port of the deleted `timeString`, `:2151-2156`): `elapsed` is `m:ss` or `h:mm:ss`, non-finite → `0:00`; `remaining` is `-` + the same.
- **Overlap rule** (`TransportBarLayout.labelVisibility(target:elapsed:remaining:gap: 16)`): with `previewSec != nil`, hide the elapsed label when `target.minX < elapsed.maxX + 16`, and the right label when `target.maxX > remaining.minX − 16`. Label widths come from `onGeometryChange(for: CGFloat.self)`. The target frame is clamped inside 86…1834 first.
- **Clock:** `TimelineView(.everyMinute)` with `Text(date, format: .dateTime.hour().minute())`. Shown only when `showsClock && controlsVisible`, and it fades with the bar.

## 7. Accessibility identifiers and the probe

| Identifier | Element |
|---|---|
| `player.bar` | the chrome container |
| `player.bar.track` | the track `ZStack` (frame = rest track) |
| `player.bar.time.elapsed` / `player.bar.time.remaining` | the two end labels (value = their text) |
| `player.bar.time.target` | the preview target label |
| `player.pill.subtitles` … `player.pill.more` | pills (`PillKind.rawValue`) |
| `player.bar.clock` | clock |
| `debug_transportProbe` (DEBUG only) | probe |

The probe is a leaf `Text(verbatim:)` view; `verbatim` keeps it out of `Localizable.xcstrings`, unlike `Text("debug_trailerMorph …")` (`HomeView.swift:6639`). It uses the `TrailerMorphDebugLabel` recipe (`:6635-6644`): 8 pt, opacity 0.011, `.allowsHitTesting(false)`, identifier `debug_transportProbe`. It sits inside `PlayerTransportBar` but **outside** the faded chrome, so it stays in the AX tree while the bar is hidden. Spelling (space-separated `key=value`):

`mode=<idle|stepping|scanning|scrubbing> pos=<%.1f> prev=<%.1f|nil> buf=<n ranges> focus=<pill:<kind>|track|none> y=<%.0f> x0=<%.0f> x1=<%.0f> vis=<0|1> ends=<0|1> pills=<n>`

`y` is canvas height − the track's global `midY`, and `x0`/`x1` are its global minX/maxX, measured with `onGeometryChange` on `player.bar.track`. `focus` is `none` when hidden, `pill:<kind>` when `transport.focusedPill == kind`, and `track` otherwise. `mode` is `transport.mode.probeName`; `pos` is `transport.positionSec` with `%.1f`, the same spelling `debug_seekProbe` uses (preview spec §10). The tvOS 27 runtime never reports `hasFocus` (`NuvioTVUITests/PlayerTopPanelProbeTests.swift:10`), so the legs read `focus=` from the probe.

## 8. Strings (English, `Localizable.xcstrings`)

New: `"Speed"`, `"More"`, `"ends %@"` (from `String(localized: "ends \(clock)")`). Reused keys: `"Subtitles"`, `"Audio"`, `"Sources"`, `"Episodes"`, `"Swipe down for info"`. The five locales go through the batch-end scripts (plan, Defaults).

## 9. Tests

**Unit**, `NuvioTVTests/PlayerTransportBarLayoutTests.swift` (all pure, 16 cases; buffered merge/parse tests belong to agent A's `BufferedRangesMergeTests`/`TransportPreviewTests`):
- `testTrackCentreIs95FromBottomOn1080Canvas`, `testTrackInsetsAre86`
- `testFractionToXMapsAndClamps` (0 → 86, 0.5 → 960, 1 → 1834, −0.2 → 86, 1.3 → 1834; duration 0 → 86)
- `testPillRowWidthSixPillsIs497`, `testLockupWidthShrinksWithPillCount`
- `testElapsedFormat` (59 → `0:59`, 3600 → `1:00:00`, NaN → `0:00`), `testRemainingFormat` (`-1:02:03`), `testRemainingUnknownDuration` (`--:--`)
- `testEndClockDividesBySpeed` (fixed `now`, `en_US_POSIX`, UTC), `testEndClockNilWithoutDuration`
- `testTargetLabelClampedToTrack`, `testOverlapHidesElapsed`, `testOverlapHidesRemaining`
- `testHideRuleDelays` (playing 4; paused + card 5; paused, no card nil), `testHideBlockedByPillOrActiveMode`
- `testPillVisibilityAndTabs` (movie, no switching: subtitles/audio/speed/more; series with switching: all six; movie with switching: no episodes; tab mapping per §4)

The player-driven row's moves are a pure helper too: `PillKind.move(from:by:in:)` (clamped, no wrap) is covered inside `testPillVisibilityAndTabs` (from `.subtitles` by −1 stays; from `.more` by +1 stays).

**UI legs**, `NuvioTVUITests/PlayerTransportBarUITests.swift`. Skipped unless `PLAYER_BAR_PROBE=1` (`TEST_RUNNER_PLAYER_BAR_PROBE=1`) and a source URL is in `PLAYER_SMOKE_URL` (`TEST_RUNNER_PLAYER_SMOKE_URL`). Each test launches the app itself with `launchArguments += ["-debug.mpvSmokeURL", url, "-player.nativeDolbyVision", "NO"]` (the argument domain feeds `UserDefaults`, so no pre-warm), then waits for `player.mpv` and for `debug_transportProbe` to show `pos=` > 1. Agent A's `PlayerTransportUITests.swift` uses the same gate, the same launch helper and the same env names.
- `testBarGeometryProbe`: press Up (bar up), read the probe: `vis=1`, `y` 95 ± 2, `x0` 86 ± 1, `x1` 1834 ± 1, `pills ≥ 4`.
- `testPillFocusWalk`: Up (bar up, `focus=track`), Up → `focus=pill:subtitles`; Right → `pill:audio`; Down → `focus=track`; Left → `pos` decreases (the arrow seeks again); Up, Select → `player.panel.tab.subtitles` exists with value `selected`.
- `testLightTapFlipsEndTime`: Up; `notify_post("com.nuvio.debug.transport.lightTap")` from the runner (same simulator notifyd) → `ends=1` and the `player.bar.time.remaining` label starts with "ends"; after 4.5 s, `ends=0`.
- `testBarHideRules`: playing, no input → `vis=0` by 4.6 s; Select (pause) → `vis=1` at 4.5 s and `vis=0` by 6 s (pause card on by default); Up, Up (pill focused) → `vis=1` at 6 s.
- `testMenuHidesBarThenExits`: Up → `vis=1`; Menu → `vis=0` and `player.mpv` still exists; Menu → `player.mpv` gone.

Device pass items 1, 5 and 6 in the plan cover this spec on hardware (Test profile).

## 10. Agent brief (W1 agent B, runs after agent A's commit)

**Clone:** `~/Claude/Projects/NuvioMobile-player`, branch `claude/player-p1`, starting at agent A's commit. MPVKit is a symlink over the gitlink: stage by explicit paths, never `git add -A`; `git status` may error on MPVKit, ignore it.

**Create:** `iosApp/NuvioTV/Screens/Player/PlayerTransportBar.swift` (view, `TransportBarLayout`, `TransportTimeFormat`, `TransportSpanMath` for skip spans and x mapping, `TransportHideRule`, `PlayerTransportMetrics`, the `debug_transportProbe` label), `iosApp/NuvioTV/Screens/Player/PlayerPills.swift` (`PillKind` extensions: `visible`, `panelTab`, `symbol`, `title`, `move`; `PlayerPillRow`), `iosApp/NuvioTVTests/PlayerTransportBarLayoutTests.swift`, `iosApp/NuvioTVUITests/PlayerTransportBarUITests.swift`.
**Edit:** `iosApp/NuvioTV/DesignSystem/FlatControlStyles.swift` (`PlayerPillDisc`), `iosApp/NuvioTV/Screens/Player/PlayerChipStyle.swift` (two inset constants), `iosApp/NuvioTV/Screens/Player/PlayerTopPanel.swift` (`initialTab`), `iosApp/NuvioTV/Screens/MPVPlayerView.swift` (the regions in §1 "Ownership" only), `iosApp/NuvioTV/Localizable.xcstrings` (English keys of §8). Do not touch `TransportPreview.swift`, `TransportBarModel.swift` (except adding a field A left out), `SkipSegmentPlanner.swift`, or A's seek/scan code.

**Steps:**
1. `PlayerTransportBar.swift` pure types + `PlayerTransportBarLayoutTests` first; build and run those tests.
2. `PlayerPills.swift` + `PlayerPillDisc`; `PlayerTopPanel` `initialTab`.
3. The bar view + probe; overlay swap in `MPVPlayerScreen` (delete `PlayerControlsOverlay`, `ProgressBar`, the `showPauseInfo` timer; keep A's `SeekProbeLabel` line); pause card rule; chip insets.
4. Controller: `controlsSession`, `onOpenPanel(tab)`, `flashControls`/`scheduleHide`/`hideControlsNow`, the pill branch, `.upArrow`, the Menu precedence list, `lastClickUptime`, light tap + DEBUG Darwin observer (removed in `destroyPlayer`).
5. UI legs.

**Commands** (from `~/Claude/Projects/NuvioMobile-player/iosApp`; never two builds at once; Bash sandbox OFF for `xcodebuild test`):
- Build: `xcodebuild -project iosApp.xcodeproj -scheme NuvioTV -configuration Debug -destination 'platform=tvOS Simulator,id=FA87…' -derivedDataPath build/DerivedData build` (use the FA87 fixture simulator's full UDID from `xcrun simctl list devices`).
- Unit: `xcodebuild test -project iosApp.xcodeproj -scheme NuvioTVTests -destination '<same>' -derivedDataPath build/DerivedData -only-testing:NuvioTVTests/PlayerTransportBarLayoutTests`.
- UI legs (main session runs them in W3 if the agent's run is flaky): `TEST_RUNNER_PLAYER_BAR_PROBE=1 TEST_RUNNER_PLAYER_SMOKE_URL=<url> xcodebuild test -project iosApp.xcodeproj -scheme NuvioTVUITests -destination '<same>' -derivedDataPath build/DerivedDataUITests -only-testing:NuvioTVUITests/PlayerTransportBarUITests`.

**Report back:** commit SHA(s) and files touched; build result; unit test count and result; each UI leg PASS/FAIL/SKIP with the probe line it read; any spec line you could not follow as written, with what you did instead.

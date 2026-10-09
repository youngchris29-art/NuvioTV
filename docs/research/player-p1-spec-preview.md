# Player P1 spec: preview-then-commit seek, scan, buffered ranges, and the small items (2026-10-06)

Scope: the "preview model + commit policy" half of Batch P1 (`docs/player-revamp-plan-2026-10-06.md`), plus audio-delay persistence, skip-chip auto-hide, the failure-alert engine buttons, and the settings rows. The bar's geometry, pills and the clock drawing live in `player-p1-spec-bar.md`. All paths below are relative to `NuvioMobile-player/iosApp/NuvioTV/` (clone, branch `claude/player-p1` at `5feef338`) unless they start with `shared/`. Every decision here is final; the implementer should not have to make a judgment call. Where the decision differs from the plan's wording, the reason follows it.

Two facts about the current code shape everything:

1. **The main thread never reads an mpv property** (`MPVPlayerView.swift:158-176`, BUG-2/3). Reads happen on `eventQueue` (`:102`); the main thread reads `cachedProps()` (`:190`). Every new read below follows that rule.
2. **The hold ramp today is not the official table.** `beginSeek` (`:1383-1401`) seeks 10 s at once, then every 0.4 s seeks `min(10 + n*10, 60)` (20, 30, 40, 50, 60 …), each one a real `seekBy`. The new table (§1.1) is the official 10/20/30/60 table keyed to hold time; it reaches 60 s steps after 2 s of holding, as today, but moves only the preview until release.

## Critique decisions (2026-10-06, Opus critique; record `docs/research/player-p1-critique-2026-10-06.md`)

These override anything below that disagrees; the sections have been edited to match.

1. **Hold ramp is time-based** (§1.1). The step size depends on how long the arrow has been held, not on a tick count: held < 0.6 s → 10 s per tick, < 1.2 s → 20, < 2.0 s → 30, then 60. The first tick fires 0.4 s after the press (hold recognition), then every 0.25 s. The official app keys its table to Android key repeats (~20/s after a ~0.4 s delay), so its 60 s steps arrive within about a second; a tick-count table at 0.4 s (the earlier draft) took 5.6 s. Launch knobs: `-debug.holdTickSec` (Auto 0.25) and `-debug.holdRampScale` (Auto 1.0; multiplies the three time boundaries).
2. **Scan is Apple's latched model** (§1.1, §3). A hold of Right in Scan mode starts 2×; scanning continues after release; each further Right press cycles 2× → 3× → 4× → 2×; Select or Play/Pause ends the scan where it is and plays at the user's speed; Menu cancels back to where the scan started. Any other press (Left, Up, Down) ends the scan where it is and is consumed. mpv has no reverse playback, so a held Left never scans: from idle it steps backward in both modes. The 0.6 s latch window of the earlier draft is gone.
3. **Hide rule and Menu precedence:** identical text in both specs, here in §2.2.
4. **Ownership: sequential.** This spec's §1–§5 and §10's TransportPreview / BufferedRanges / planner-refine tests and UI legs 1–3 are **W1 agent A**, who runs first. §6–§9 and §11, UI leg 4 and the planner chip tests are **W2 agent C** (plan: W2 = settings + strings, skip chip, audio delay, failure alert). The bar spec's agent B runs between them. Region lists in "Agent briefs" (§13).
5. **One model.** Agent A creates `Screens/Player/TransportBarModel.swift` (the class in bar spec §3) and `MPVPlaybackState.transport`; it writes `transport.previewSec`, `transport.mode`, `transport.bufferedRanges` (and position/duration/paused/speed/skip spans). There is no `state.previewSec`, `state.transportMode` or `state.bufferedRanges`.
6. **Buffered ranges:** the JSON string read is verified on the first build with a one-shot DEBUG log, and every read falls back to one span `[time-pos, demuxer-cache-time]` when the parse yields nothing (§4).
7. **Paths:** player files are in `Screens/Player/`, settings in `Screens/Settings/`.
8. **Probes:** `debug_seekProbe` lives in a new `Screens/Player/SeekProbe.swift` (agent A), always present in DEBUG builds (no `debug.seekProbe` gate), placed by one line in `MPVPlayerScreen`'s body (there is no `MPVPlayerControls`). Fields shared with `debug_transportProbe` use the same spelling: `mode=` from `Mode.probeName`, `pos=%.1f`.

---

## 1. `Screens/Player/TransportPreview.swift` (new, pure Swift)

No UIKit, no mpv, no clock of its own. The controller owns the timers and passes the hold time in. `struct`, all mutations `mutating`.

```swift
struct TransportPreview {
    enum HoldMode: String { case step, scan }          // persisted rawValue in `player.holdMode`
    enum Mode: Equatable {
        case idle
        case stepping(direction: Int, accumulatedSec: Double, ticks: Int)
        case scanning(rate: Int)                        // 2, 3 or 4
        case scrubbing(targetSec: Double)               // P2 only; P1 never enters it
        var isActive: Bool { if case .idle = self { return false }; return true }
        var probeName: String                           // "idle" | "stepping" | "scanning" | "scrubbing"
    }
    enum Stage: Equatable { case keyframes, exact }
    struct CommitRequest: Equatable {
        let targetSec: Double
        let fromSec: Double                             // gesture origin (skip planner span start)
        let stages: [Stage]                             // [.keyframes, .exact] or [.exact]
    }
    enum Output: Equatable {
        case none
        case immediateSeek(deltaSec: Double)            // a plain relative ±10 s seek, as today
        case startScan(rate: Int)
        case setScanRate(Int)
        case endScan(fromSec: Double, returnToSec: Double?)   // nil = stay where the scan is
        case commit(CommitRequest)
    }

    var holdMode: HoldMode = .step
    var rampScale: Double = 1                           // -debug.holdRampScale; boundaries × scale
    var durationSec: Double = 0                         // 0 = unknown: no upper clamp
    var seekableRanges: [BufferedRange] = []            // set by the controller each buffered read
    private(set) var mode: Mode = .idle
    private(set) var originSec: Double = 0
    private(set) var previewSec: Double? = nil          // nil while idle

    static let firstStepSec: Double = 10
    static let holdStartSec: TimeInterval = 0.4         // first tick: a press held this long is a hold
    static let defaultTickSec: TimeInterval = 0.25      // later ticks
    static func stepSec(heldSec: Double, rampScale: Double = 1) -> Double {
        heldSec < 0.6 * rampScale ? 10 : heldSec < 1.2 * rampScale ? 20 : heldSec < 2.0 * rampScale ? 30 : 60
    }

    mutating func pressBegan(direction: Int, positionSec: Double) -> Output
    mutating func holdTick(heldSec: Double) -> Output
    mutating func pressEnded(direction: Int) -> Output
    mutating func endScanInPlace() -> Output            // Select / Play / Left / Up / Down while scanning
    mutating func noteLivePosition(_ sec: Double)       // scanning: preview follows time-pos
    mutating func noteCommitLanded()                    // previewSec = nil after a commit's seek lands
    mutating func cancel() -> Output
}
```

`BufferedRange` is `struct BufferedRange: Equatable { let start: Double; let end: Double }` in the same file, with `static func merge(_:gapSec:durationSec:) -> [BufferedRange]` and `TransportPreview.parseSeekableRanges(_:)` (§4). A struct, not the `(Double, Double)` tuple the brief named, because `@Published` change checks and `XCTAssertEqual` need `Equatable`.

### 1.1 Rules, exactly

**Clamp.** `clamp(x) = max(0, durationSec > 0 ? min(x, durationSec - 0.5) : x)`. The 0.5 s is `SkipSegmentPlanner.clamp`'s EOF rule (`Screens/Player/SkipSegmentPlanner.swift:307-309`): a target at or past EOF wedges mpv. Every `previewSec` and every `CommitRequest.targetSec` goes through it. `accumulatedSec` is stored post-clamp (`accumulatedSec = clamp(originSec + raw) - originSec`), so reversing at an edge moves at once.

**`pressBegan(direction:positionSec:)`** (`direction` is ±1):
- From `.idle`: `originSec = positionSec`.
  - Step mode, or Scan mode with `direction < 0`: `mode = .stepping(direction, accumulatedSec: clamp(origin ± 10) - origin, ticks: 0)`, `previewSec = origin + accumulated`, return `.immediateSeek(deltaSec: ±10)`. The first press is a plain ±10 s seek, as today.
  - Scan mode with `direction > 0`: `mode = .stepping(+1, accumulatedSec: 10 (clamped), ticks: 0)`, return `.none`. No seek yet. A click in Scan mode seeks on release (system grammar: a click acts on release, a hold scans); in Step mode it stays on press.
- From `.stepping(d, acc, _)` (a second press, the other key, before release): `mode = .stepping(direction, acc' = clamp(origin + acc + direction*10) - origin, ticks: 0)`, set a private `moved = true`, return `.none`. No real seek: the preview only. The controller restarts the hold clock for the new key.
- From `.scanning(r)`: `direction > 0` → rate cycles 2 → 3 → 4 → 2, `mode = .scanning(next)`, return `.setScanRate(next)`. `direction < 0` → `endScanInPlace()`. The press is consumed either way; its release does nothing.
- From `.scrubbing`: `.none` (P2 defines it).

**`holdTick(heldSec:)`** (the controller calls it first at `holdStartSec` = 0.4 s after the press, then every `holdTickSec` = 0.25 s; `heldSec` = uptime now − the press's uptime):
- `.stepping(d, acc, n)`: `n' = n + 1`.
  - Scan mode, `d > 0`, `n' == 1`: `mode = .scanning(rate: 2)`, `previewSec = originSec`, return `.startScan(rate: 2)`.
  - Otherwise: `acc' = clamp(origin + acc + d * stepSec(heldSec: heldSec, rampScale: rampScale)) - origin`, `moved = true`, `previewSec = origin + acc'`, return `.none`.
- Any other mode: `.none` (a held Right that started a scan keeps ticking harmlessly).

With the defaults the ticks land at 0.40 (+10), 0.65, 0.90, 1.15 (+20 each), 1.40, 1.65, 1.90 (+30 each), then 2.15, 2.40, … (+60 each). Cumulative preview offset including the press's own 10 s: +20 after 0.4 s of holding, +80 after 1.15 s, +170 after 1.9 s, +410 after 2.9 s. The official Android table counts repeats (`PlayerScrubRates`: repeats 1–2 → 10, 3–7 → 20, 8–14 → 30, 15+ → 60) at ~20 repeats/s, so it hits 60 s steps under 1.2 s but with 50 ms ticks; at the Siri Remote's 4 ticks/s the same per-tick sizes reached that fast would jump the preview by 240 s per second within a second of holding, so the 60 s tier starts at 2.0 s. `-debug.holdRampScale 0.5` (60 s steps from 1.0 s) is the A/B lever for a faster feel.

**`pressEnded(direction:)`**: ignored (`.none`) when `direction` is not the current stepping direction, so the first key's release after a direction change is a no-op.
- `.stepping` with `ticks == 0 && !moved`:
  - Step mode or backward: `.none` (the immediate seek already ran). `mode = .idle`, `previewSec = nil`.
  - Scan mode forward: `.immediateSeek(deltaSec: 10)`. `mode = .idle`, `previewSec = nil`.
- `.stepping` otherwise: `.commit(CommitRequest(targetSec: clamp(origin + acc), fromSec: originSec, stages: covered ? [.exact] : [.keyframes, .exact]))` where `covered = seekableRanges.contains { $0.start <= t && t <= $0.end }`. `mode = .idle`; `previewSec` stays at the target until the controller calls `noteCommitLanded()` (on the commit's first `PLAYBACK_RESTART`, or after 1.5 s), so the bar does not jump back while the seek lands.
- `.scanning`: `.none`. **The scan is latched**: releasing the key does not end it.

**`endScanInPlace()`** in `.scanning`: `mode = .idle`, `previewSec = nil`, return `.endScan(fromSec: originSec, returnToSec: nil)`. Elsewhere `.none`.

**`noteLivePosition(_:)`** in `.scanning`: `previewSec = sec`. Elsewhere a no-op.

**`cancel()`**: `.stepping` → `.idle`, `previewSec = nil`, return `.none` (nothing committed). `.scanning` → `.idle`, `previewSec = nil`, return `.endScan(fromSec: originSec, returnToSec: originSec)`. Called on Menu, panel open and `viewDidDisappear`.

**Scan grammar, in one place** (Scan mode only; Step mode never scans):

| Input while scanning | Result |
|---|---|
| Right press | next rate (2 → 3 → 4 → 2) |
| Select, Play/Pause | `endScanInPlace()`; playback continues at the user's speed, not paused |
| Left, Up, Down | `endScanInPlace()`; the press is consumed (Left does not also step, Down does not open the panel or fire a chip) |
| Menu | `cancel()`: back to where the scan started, at the user's speed |
| end of file (`snap.eof`) | `endScanInPlace()` from `refreshState` |
| releasing Right | nothing (latched) |

A held Left from idle in Scan mode steps backward exactly like Step mode (preview, then one commit on release).

---

## 2. Wiring in `MPVTVPlayerViewController` (`Screens/MPVPlayerView.swift`)

### 2.1 State

Replace `seekTimer` / `seekDirection` / `seekHoldCount` (`:115-117`) with:

```swift
private var transport = TransportPreview()
private var holdTimer: Timer?
private var holdStartUptime: TimeInterval = 0       // uptime of the press that started the current hold
private var pendingExact: (generation: Int, request: TransportPreview.CommitRequest, deadline: DispatchWorkItem)?
private var exactWork: DispatchWorkItem?
private var commitLandWork: DispatchWorkItem?       // 1.5 s fallback for noteCommitLanded()
private var commitGeneration: Int?                  // generation of the last commit's first stage
private var scanRestore: (speed: Double, wasMuted: Bool)?
private var bufferedReadPending = false
private let holdTickSec: TimeInterval               // read once in init (§9)
private let commitExactDelaySec: TimeInterval       // read once in init (§9); < 0 = never run the exact stage
```

`transport.holdMode` is set once in `viewDidLoad` (`:246`) from `UserDefaults.standard.string(forKey: PlayerTuning.holdModeKey)`, default `.step`; `transport.rampScale` likewise from `debug.holdRampScale` (§9). `transport.durationSec` is set in `refreshState` (`:1236`) from `snap.duration`.

`PlayerTuning` (`Screens/PlaybackModels.swift:12-27`) gains `holdModeKey` and `showClockKey` here, in W1 (agent A), because the controller and the bar read them; the Settings rows that write them are W2 (§9).

`MPVPlaybackState` (`:29-90`) gains `let transport = TransportBarModel()` (the class in bar spec §3, created by agent A in `Screens/Player/TransportBarModel.swift`) and, in DEBUG, `let seekProbe = SeekProbe()`. Agent A mirrors into `state.transport` in `refreshState`: `positionSec`, `durationSec`, `isPaused`, `playbackSpeed`; and at `:1018`, `skipSpans` (bar spec §3 Feeds).

### 2.2 Presses (`pressesBegan` `:1321-1369`, `pressesEnded` `:1372-1381`)

At the top of `pressesBegan`, before the switch, for every handled press type: `cancelExactStage()` (§2.3). A new press between the two stages cancels the exact stage, and the new gesture starts from the keyframes landing.

**Mode-active pre-checks** (agent A). At the top of each case below, before any other branch (the bar spec's pill branch and Up/Menu bar handling come after these, added by agent B):

- `.rightArrow`: if scanning → `apply(transport.pressBegan(direction: 1, …))` (next rate), consumed, no hold timer. Otherwise `beginHold(+1)`.
- `.leftArrow`: if scanning → `apply(transport.endScanInPlace())`, consumed, no hold timer. Otherwise `beginHold(-1)`.
- `.select` / `.playPause`: if scanning → `apply(transport.endScanInPlace())`, do NOT toggle pause, consumed. If stepping → `apply(transport.cancel())`, then fall through to `togglePause()` as today.
- `.upArrow` (new case; agent B fills in the idle behaviour): if scanning → `apply(transport.endScanInPlace())`, consumed; if stepping → `apply(transport.cancel())`, consumed.
- `.downArrow`: if scanning → `apply(transport.endScanInPlace())`, consumed (no chip, no panel); if stepping → `apply(transport.cancel())`, then the existing behaviour.
- `.menu`: step 1 of the Menu precedence list below.

`beginHold(dir)`:
```swift
if dir < 0, case .idle = transport.mode { state.upNextCancel?() }  // once per hold, as today (:1386)
let base = skipPlanner.seekInFlight?.targetSec ?? cachedProps().position   // seekBy's rule (:1435-1439)
holdStartUptime = ProcessInfo.processInfo.systemUptime
apply(transport.pressBegan(direction: Int(dir), positionSec: base))
restartHoldTimer()
flashControls()
```
`restartHoldTimer()`: invalidate `holdTimer`; schedule a one-shot `Timer` at `TransportPreview.holdStartSec` (0.4 s) whose block calls `tick()` and then installs a repeating `Timer(holdTickSec)` that calls `tick()`; both on `RunLoop.main` `.common`. `tick()` = `apply(transport.holdTick(heldSec: systemUptime − holdStartUptime))`. Keep `upNextCancel` on the idle-to-hold transition only, never per tick or per direction change.

`pressesEnded`: for `.leftArrow`/`.rightArrow`: `holdTimer?.invalidate(); holdTimer = nil; apply(transport.pressEnded(direction:))`. While scanning this returns `.none` (latched).

`endSeek()` (`:1403-1407`) becomes `holdTimer?.invalidate(); holdTimer = nil`. `deinit` (`:1649`) invalidates `holdTimer` instead of `seekTimer`.

`apply(_ output:)`, main thread:
- `.immediateSeek(d)`: `seekBy(d)` (unchanged `:1428-1442`, relative seek).
- `.commit(r)`: `issueCommit(r)`.
- `.startScan(rate)`: `startScan(rate)` (§3). `.setScanRate(r)`: `eventQueue.async { setMpvDouble("speed", Double(r)) }`.
- `.endScan(from, returnTo)`: `endScan(from:returnTo:)` (§3).
- `.none`: nothing.
After every call: `state.transport.previewSec = transport.previewSec`, `state.transport.mode = transport.mode`, update `seekProbe` (DEBUG), and when the mode went from active to `.idle`, `flashControls()`.

**Hide rule** (identical text in both P1 specs). The bar hides 4 s after the last input while playing. While paused, it hides 5 s after the last input only when the Pause Info Card is enabled (the shared `pauseOverlayEnabled`, default on), and the card then fades in 0.25 s after the bar's fade ends; with the card disabled, the paused bar never hides. The bar never hides while a pill is focused (`transport.focusedPill != nil`) or while `transport.mode` is not idle: a hide timer that fires in either state does nothing, and the next input re-arms it. Any press other than Menu while the card shows raises the bar, which removes the card; Menu follows the precedence list. Menu hides the bar at once (Menu precedence). In code: `TransportHideRule.delay(isPaused:pauseCardEnabled:) -> TimeInterval?` (4 / 5 / `nil`) and `TransportHideRule.mayHide(pillFocused:modeActive:) -> Bool`.

**Menu precedence** (identical text in both P1 specs). The top panel is a presented view controller: while it is up, Menu goes to it and closes it, so it comes first by construction. In the controller's `.menu` case, the first match wins and every case except the last sets `swallowMenuRelease = true`:
1. `transport.mode` is stepping → `cancel()` (nothing committed); scanning → `cancel()` (back to where the scan started). The bar stays up.
2. The up-next chip is showing → `state.upNextDismiss?()` (today's rule, `:1350-1353`).
3. A pill is focused → `focusedPill = nil` and `hideControlsNow()`.
4. The bar is up → `hideControlsNow()`.
5. Otherwise → `closeFailover(); onExit?()`.
The skip chip is not part of the list: Menu never dismisses it (it auto-hides after 10 s, preview spec §6), so with only the skip chip on screen Menu exits, as today. The pause card is not part of it either: with the card up and the bar hidden, Menu exits.


### 2.3 `issueCommit(_:)` and the two stages

`issueSeek` (`:1452-1473`) gains `@discardableResult -> Int` (returns `generation`) and an `onRejected: (() -> Void)? = nil` hop for the rejection branch. No other change to its body.

```swift
private func issueCommit(_ r: TransportPreview.CommitRequest) {
    let t = String(format: "%.3f", r.targetSec)
    if r.stages.first == .keyframes {
        let gen = issueSeek(kind: .user, targetSec: r.targetSec, fromSec: r.fromSec,
                            args: [t, "absolute+keyframes"], onRejected: { [weak self] in self?.pendingExact = nil })
        guard commitExactDelaySec >= 0 else { seekProbe.note(commit: r.targetSec, stages: "k"); return }
        let deadline = DispatchWorkItem { [weak self] in self?.runExactStage() }
        pendingExact = (gen, r, deadline)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: deadline)
        seekProbe.note(commit: r.targetSec, stages: "ke")
    } else {
        issueSeek(kind: .user, targetSec: r.targetSec, fromSec: r.fromSec, args: [t, "absolute+exact"])
        seekProbe.note(commit: r.targetSec, stages: "e")
    }
}
```
`seekProbe` is `state.seekProbe`, the DEBUG probe model of §10 (compiled out of Release; wrap its calls in `#if DEBUG`). `issueCommit` also sets `commitGeneration = gen` (the first stage's generation, for either branch) and arms `commitLandWork` (1.5 s) → `transport.noteCommitLanded()` + republish, so the preview playhead always clears.

**Preview hand-back.** In the `MPV_EVENT_PLAYBACK_RESTART` main-thread block, when `generation == commitGeneration`: `commitGeneration = nil`, `commitLandWork?.cancel()`, `transport.noteCommitLanded()`, `state.transport.previewSec = nil`. This runs whether or not the planner guard below passes, so the bar's played fill switches from the preview to the real position on the first landing.

Flags are always explicit (`absolute+keyframes`, `absolute+exact`) so behaviour never depends on mpv's `hr-seek` default. The short press stays `relative` (`:1441`), unchanged.

**When the exact stage runs.** It runs `commitExactDelaySec` (150 ms) after the keyframes stage's engine confirmation, so the keyframe picture shows first: that is stage 1's whole point. In the `MPV_EVENT_PLAYBACK_RESTART` main-thread block (`:1711-1720`), after `skipPlanner.seekCompleted(…)` and inside the existing `generation == self.seekGeneration` guard, add: `if let p = pendingExact, p.generation == generation { scheduleExact(after: commitExactDelaySec) }`. `scheduleExact` cancels `p.deadline` and posts `exactWork` = `runExactStage()`. If no confirmation arrives within 1.5 s, the deadline item runs the exact stage anyway.

`runExactStage()`: `guard let p = pendingExact else { return }; pendingExact = nil; skipPlanner.refineSeek(targetSec: p.request.targetSec, fromSec: p.request.fromSec, now: …)`, then issue the seek through the generation path WITHOUT a second `beginSeek`. Do that with a new `issueSeek` parameter `planner: Bool = true`; `runExactStage` passes `false` because `refineSeek` already told the planner.

`cancelExactStage()`: `exactWork?.cancel(); pendingExact?.deadline.cancel(); pendingExact = nil`. Called from every handled press (§2.2), `onOpenPanel`, `viewDidDisappear`, and `replay()` (`:1419`).

**Generations.** Two seeks, two generations. The keyframes completion is reported to the planner only when no exact stage has been issued since (the existing `generation == seekGeneration` guard, `:1712`). Once the exact stage is issued, the keyframes stage's restart is ignored, and the planner stays `seeking` until the exact stage's own restart. `awaitingSeekStartGeneration` / `startedSeekGeneration` (`:150-154`, `:1700-1706`) need no change. Each `issueSeek` already resets them for its own generation.

### 2.4 `SkipSegmentPlanner` additions (`Screens/Player/SkipSegmentPlanner.swift`)

1. `mutating func refineSeek(targetSec: Double, fromSec: Double, now: TimeInterval)`: the second stage of one user gesture. If a `.user` seek is in flight, replace it with `Seek(kind: .user, targetSec: targetSec, fromSec: inFlight.fromSec, startedAt: now)`. If idle, `seekState = .seeking(Seek(kind: .user, targetSec: targetSec, fromSec: fromSec, startedAt: now))`. Unlike `beginSeek` (`:114-146`), it leaves `promptIndex`, `consumed`, `chipSuppressedIndex` and `abandonedSeek` alone. Its completion records the same span (`fromSec`→landing) the keyframes stage did, so the deliberate-seek list gains no new span. Intervals the gesture touched stay consumed, and the "deliberate seek never auto-skips" rule holds across the 150 ms gap between the stages: the keyframes landing is already marked deliberate by `seekCompleted` (`:149-176`).
2. `mutating func recordUserSpan(fromSec: Double, toSec: Double)`: `recordDeliberate(fromSec:toSec:)` (`:281`) made callable, for the scan.
3. The chip auto-hide (§6; W2, agent C).

---

## 3. Scan mode

`startScan(rate:)`, main thread:
```swift
let userSpeed = state.playbackSpeed
eventQueue.async { [weak self] in
    guard let self, self.mpv != nil else { return }
    let wasMuted = self.getFlag("mute")                 // eventQueue read, never main
    DispatchQueue.main.async { self.scanRestore = (userSpeed, wasMuted) }
    self.setFlag("mute", true)
    _ = self.command("set", args: ["audio-pitch-correction", "no"])
    self.setMpvDouble("speed", Double(rate))
}
```
`endScan(from:returnTo:)`, main thread: on `eventQueue`: `speed = scanRestore.speed` (the user's speed, not 1.0), `mute = scanRestore.wasMuted`, `audio-pitch-correction = yes`. Then on main:
- `returnTo == nil` (ended in place): `skipPlanner.recordUserSpan(fromSec: from, toSec: cachedProps().position)`.
- `returnTo != nil` (Menu): no span is recorded (the scanned stretch was not watched, so its intervals must still auto-skip when played); `issueSeek(kind: .user, targetSec: returnTo, fromSec: cachedProps().position, args: [String(format: "%.3f", returnTo), "absolute+exact"])`. Exact only: the origin is behind the playhead, inside the 64 MiB back buffer (§5) in practice.
- Both: `scanRestore = nil`, `state.transport.previewSec = nil`, `flashControls()`.
The app has no mute control today (no `mute` write in the file), so `wasMuted` is false in practice. It is read anyway so a future mute control is respected.

While `case .scanning = transport.mode`:
- `refreshState` calls `transport.noteLivePosition(snap.position)` and republishes `state.transport.previewSec`. If `snap.eof`, it calls `apply(transport.endScanInPlace())` first.
- `updateSkipPrompt` (`:1309-1317`) passes `autoSkipTypes: nil`, so no auto-skip fires mid-scan. The chip may still show; Down ends the scan rather than firing it (§2.2).
- The skip planner sees an in-place scan as one user span, origin to the position where it ended, recorded once. There is no `beginSeek` at scan start: a scan longer than 10 s would trip `seekTimeoutSec` (`:63`) and leave the planner on the stale guard.
- `setSpeed` (`:1088`) from the panel is ignored while scanning; the panel can't be open anyway (Down ends the scan first).
- The bar stays up for the whole scan (hide rule: `mode` active).
- Backward holds never scan: mpv has no cheap reverse playback, so a held Left steps in both modes, and a Left press during a scan ends it in place (§1.1 scan grammar).

---

## 4. Buffered ranges

**Read**: `mpv_get_property_string(mpv, "demuxer-cache-state")` on `eventQueue` through the existing `getString` (`:1847-1853`), then `JSONSerialization`. mpv prints a node-typed property as JSON when it is read as a string; this is an assumption until the first build proves it. Why not a node walker: walking `mpv_node` unions safely (`MPV_FORMAT_NODE_MAP`, `mpv_free_node_contents`) is ~60 lines of unsafe-pointer code. P3 needs that anyway for `screenshot-raw` through a new `mpv_command_node` wrapper, so it gets written there once, where it can't be avoided. Here the string form is about 15 lines and fails soft.

Parse (`static func parseSeekableRanges(_ json: String) -> [BufferedRange]` in `TransportPreview.swift`, so it is unit-testable): top-level object → `"seekable-ranges"` array → each element's `"start"` and `"end"` as `Double`. Anything malformed means `[]`. Do not use `fw-bytes` in P1.

**First-build verification (agent A, required before reporting back).** In DEBUG, the first read after `MPV_EVENT_FILE_LOADED` prints once: `[Transport] cache-state raw=<first 300 chars or nil> ranges=<n> fallback=<0|1>`. Run the mpv smoke rig (UI leg 1 does it) and copy that line into the report. If `ranges=0` with a non-nil raw string after 10 s of playback, the JSON assumption is wrong for this MPVKit build: say so in the report and leave the fallback below as the live path (no node walker in P1).

**Fallback (every read, automatic).** If `getString` returns nil or the parse returns `[]`, read `getDouble("demuxer-cache-time")` and `getDouble("time-pos")` on the same `eventQueue` hop; when `cacheTime > pos`, use the single range `[pos, cacheTime]`; otherwise `[]`. No back-buffer span is drawn in fallback.

**Cadence**: in `refreshState` (`:1236`, the 0.5 s poll, `:1227-1233`), only when `state.controlsVisible || transport.mode.isActive`, dispatch one coalesced read: `bufferedReadPending` set on main and cleared on main in the result hop, the same shape as `refreshStreamInfoAsync` (`:1294-1303`). Do not use `mpv_observe_property`: the node changes on every demuxer packet.

**Publish**: `let merged = BufferedRange.merge(raw, gapSec: 5, durationSec: snap.duration)`. Sort by start, clamp each range to `[0, duration]` when the duration is known, drop ranges with `end <= start`, and join neighbours when `next.start - current.end < 5`. Always set `transport.seekableRanges = merged` (the commit's cache check uses it). Assign `state.transport.bufferedRanges` only when the count changed or an edge moved by more than 0.5 s, so the publisher doesn't churn. A target in a gap under 5 s counts as covered, which is fine: the exact seek runs over that short gap with no keyframe stage first. A stale list (bar hidden for a while, then a quick hold) can only make the commit choose `[.exact]` where `[.keyframes, .exact]` would have been faster, never a wrong landing.

## 5. Cache option

In the `options` array (`:406-440`) add `("demuxer-max-back-bytes", "64MiB")`. The Streaming Buffer block (`:465-470`) runs after the array and overrides it when `bufferMB > 0`. Change its back-bytes line to `max(bufferMB / 2, 64)` MiB, so no setting ever drops below the new floor. Resulting back-buffer per setting: Default (0) → 64; 64 → 64; 150 → 75; 512 → 256. Forward (`demuxer-max-bytes`) is unchanged: mpv's default when 0, otherwise `bufferMB`. No new setting. The plan's "Streaming Buffer sub-value" is this floor.

---

## 6. Skip chip auto-hide (`SkipSegmentPlanner`)

The smallest change lives in the planner: the prompt is already its output, and Down already acts only on `state.skipPrompt` (`:1334`). If the planner returns nil, the chip is gone and Down falls through to the panel.

- `static let chipAutoHideSec: TimeInterval = 10` (official `SkipIntroVisibilityRules`).
- `var autoHidesChip = false`. The mpv controller sets it to `true` where `skipPlanner` is declared (`:145`). The native engine keeps it false in P1: AVKit eats presses, so it could not bring the chip back. P4 revisits.
- Private `chipShown: (index: Int, since: TimeInterval)?` and `chipHiddenIndex: Int?`.
- In `evaluate` (`:205-268`), at the point it would return a prompt for `index`: if `chipShown?.index != index`, set `chipShown = (index, now)`. If `autoHidesChip && now - chipShown!.since >= chipAutoHideSec`, set `chipHiddenIndex = index`, `promptIndex = nil`, and return `Decision()`. In the "no interval here" branch (`:222-228`), clear `chipShown` and `chipHiddenIndex` too, so re-entering an interval starts a fresh 10 s. Early returns while seeking leave both untouched.
- `mutating func noteInput(now: TimeInterval) -> Bool`: if `chipHiddenIndex != nil`, set `chipShown = (chipHiddenIndex!, now)`, clear `chipHiddenIndex`, and return true (another 10 s). Otherwise return false.
- Controller: at the top of `pressesBegan`, `let revealed = skipPlanner.noteInput(now:)`. If revealed, call `updateSkipPrompt(...)` with the cached snapshot right away. If revealed and the press is `.downArrow`, consume it (`handled = true`, no panel). A second Down then skips. Other presses reveal the chip and still do their own action.

The 10 s runs on wall time and keeps running while paused, as in the official app.

---

## 7. Audio delay persistence (`shared/`)

`shared/src/commonMain/kotlin/com/nuvio/app/features/player/PlayerTrackPreferenceStorage.kt:23-28` (the `expect object`) gains:
```kotlin
fun loadAudioDelayMs(videoId: String): Int?
fun saveAudioDelayMs(videoId: String, delayMs: Int)
```
`SubtitleAudioModels.kt:29-30` gains `const val AUDIO_DELAY_MIN_MS = -10_000` and `const val AUDIO_DELAY_MAX_MS = 10_000`, the panel's ±10 s limit (`Screens/Player/MPVPlaybackTab.swift:59`).

Actuals mirror the subtitle pair line for line, with key `audio_delay_ms` (`private const val audioDelayMsKey = "audio_delay_ms"`), stored as `scopedKey(audioDelayMsKey, id)`, which is `ProfileScopedKey.of("audio_delay_ms|<videoId>")` and clamped to the new range:
- `appleMain/…/PlayerTrackPreferenceStorage.apple.kt:66-83` (`NSUserDefaults` integer)
- `jvmMain/…/PlayerTrackPreferenceStorage.jvm.kt:77-90`
- `androidMain/…/PlayerTrackPreferenceStorage.android.kt:76-89` (not compiled locally; mirror exactly)

Sign-out wipe: `shared/src/commonMain/kotlin/com/nuvio/app/core/account/AccountDataStores.kt:480` gains `AppleKeySpec.DynamicPrefix("audio_delay_ms|")` after `subtitle_delay_ms|`. Android is covered by the shared `nuvio_player_track_preferences` file. If `AccountDataStoresTest` enumerates prefixes, add it there too.

Swift: in `onFileLoaded` (`:762`), right after the subtitle restore (`:766-768`):
```swift
if let storedMs = PlayerTrackPreferenceStorage.shared.loadAudioDelayMs(videoId: context.videoId) {
    setAudioDelay(Double(storedMs.intValue) / 1000.0)
}
```
`setAudioDelay` (`:1106-1110`) appends `PlayerTrackPreferenceStorage.shared.saveAudioDelayMs(videoId: context.videoId, delayMs: Int32((seconds * 1000).rounded()))`. Replace the comment at `MPVPlaybackTab.swift:56-58` ("no persistence spec for it yet") with "persists per title/profile, like the subtitle delay". Gates: jvm and K/N test counts move only by any test added; the commonTest suite must stay green.

---

## 8. Failure alert engine buttons

**Context field**: `PlaybackContext` (`Screens/PlaybackModels.swift:29-94`) gains `var forcedEngine: PlaybackEngine? = nil` and `var resumeAtSec: Double? = nil`. `id` (`:96-102`) is unchanged: the relaunch bumps `attempt`, which already re-keys the cover.

**Annotate the failure**: `PlaybackFailure` (`:118-127`) gains `var engine: PlaybackEngine = .mpv` and `var otherEngineEligible = false`. `PlayerScreen` (`Screens/PlayerScreen.swift`) wraps `onPlaybackFailed` before passing it down (`:56`, `:61`):
- mpv reported it: `engine = .mpv`. `otherEngineEligible` is true only when `!forcedMPV` (native hasn't already failed this attempt) and a probe exists, and `PlayerEngineRouter.route(probe:, nativeDVEnabled: true, dvP7FelToMpv: false).engine == .native`. Today that is only the "Keep Profile 7 FEL on mpv" case. For that, `decideEngine` (`:91-111`) also stores the probe (`@State private var probe: ProbeResult?`). With the native flag off there is no probe and no button; probing at alert time would block the alert for up to 4 s.
- native reported it (only possible with `forcedEngine == .native`, see below): `engine = .native`, `otherEngineEligible = true`. mpv takes everything.

**Forcing**: in `PlayerScreen.shown` (`:36-41`): `if context.forcedEngine == .mpv { return .mpv }`. For `.native`, show `.native` without waiting for the probe, and pass `onFallback: nil` to `NativePlayerScreen`, so a native failure reports itself (`NativePlayerScreen.swift:108-115`) instead of silently falling back to the mpv path that just failed.

**Resume**: MPV `computeResumePosition` (`:1157`): first line `if let s = context.resumeAtSec, s > 10 { pendingResumeSec = s; return }`. `NativePlaybackCoordinator.swift:688-690`: `let resume = startOver ? nil : (context.resumeAtSec.flatMap { $0 > 10 ? $0 : nil } ?? recorder.resumePositionSec(...))`.

**Alert** (`Screens/StreamPickerView.swift:359-381`): `ManualFailureAlert` (`:1192-1198`) gains `let retry: PlaybackContext?` and `let retryEngine: PlaybackEngine?`, filled in `handlePlaybackFailure` (`:1082-1086`) when `failure.otherEngineEligible`: `retryEngine = failure.engine == .mpv ? .native : .mpv`, `retry = ctx` with `forcedEngine = retryEngine`, `resumeAtSec = failure.positionSec`, `attempt = ctx.attempt + 1`, `launchSource = .manual`. Buttons, in order: "Try with mpv" / "Try Native Player" (when `retry != nil`) → `manualFailureAlert = nil`, then after 0.35 s `selected = retry` (the same pattern as `:370-372`); "Try Next Source" (unchanged); "Back to Sources" (unchanged).

---

## 9. Settings and Developer knobs

`PlayerTuning` (`Screens/PlaybackModels.swift:12-27`): `static let holdModeKey = "player.holdMode"` ("step" / "scan", default "step") and `static let showClockKey = "player.showClock"` (Bool, default false). Both are device-local. **Agent A adds these two constants in W1** (§2.1); agent C adds everything else in this section.

`Screens/SettingsViewModel.swift` (`:460-500` block): `@Published var holdMode: String = UserDefaults.standard.string(forKey: PlayerTuning.holdModeKey) ?? "step"` + `setHoldMode(_:)`; `@Published var showClock: Bool = UserDefaults.standard.bool(forKey: PlayerTuning.showClockKey)` + `setShowClock(_:)`, with the same body shape as `setEnhancedRenderer` (`:491-494`).

`Screens/Settings/PlayerSettingsPane.swift`, Playback section, after Pause Info Card (`:48-53`):
```swift
SettingsPickerRow(title: String(localized: "Hold Left/Right"),
    selection: Binding(get: { model.holdMode }, set: { model.setHoldMode($0) }),
    options: ["step", "scan"], descriptionID: .playerHoldMode,
    label: { $0 == "scan" ? String(localized: "Scan") : String(localized: "Step") })
SettingsToggleRow(title: String(localized: "Show Clock"),
    subtitle: String(localized: "Show the time of day while the controls are up (mpv player)"),
    isOn: Binding(get: { model.showClock }, set: { model.setShowClock($0) }),
    descriptionID: .playerShowClock)
```

`Screens/Settings/SettingsDescriptions.swift`: player cases after `:139`: `case playerHoldMode = "player.holdMode"`, `case playerShowClock = "player.showClock"`; dev cases after `:205`: `case devHoldTick = "dev.holdTick"`, `case devHoldRamp = "dev.holdRamp"`, `case devCommitExactDelay = "dev.commitExactDelay"`. Texts (`text(for:)`, `:210`+):
- `.playerHoldMode`: "Choose what holding Left or Right does in the mpv player. Step jumps further the longer you hold and moves once when you let go. Scan plays at 2× and keeps going after you let go: press Right again for 3× or 4×, Select to carry on from there, Menu to go back. Default: Step."
- `.playerShowClock`: "Shows the time of day in the corner while the player controls are up. Off by default."
- `.devHoldTick`: "An A/B switch for how often a held Left or Right adds a step. Auto is 0.25 seconds."
- `.devHoldRamp`: "An A/B switch for how quickly a held Left or Right moves up to bigger steps. Auto reaches 60-second steps after 2 seconds; Faster after 1 second; Slower after 4 seconds."
- `.devCommitExactDelay`: "An A/B switch for how long the player waits after a jump before it lands on the exact frame. Auto is 150 ms. Keyframes Only skips that second step."
Footnotes (`footnote(for:)`, `:394`+): `.playerHoldMode` → "Applies to the next playback."; all three dev cases → "Applies to the next playback."

`Screens/Settings/DeveloperSettingsPane.swift`, after the Trailer Buffer (A/B) row (`:153-162`):
- `@AppStorage("debug.holdTickSec") private var holdTickSec = 0.0`; picker "Hold Step Interval (A/B)", options `[0.0, 0.15, 0.4]`, labels Auto / 0.15 s / 0.4 s.
- `@AppStorage("debug.holdRampScale") private var holdRampScale = 0.0`; picker "Hold Ramp Speed (A/B)", options `[0.0, 0.5, 2.0]`, labels Auto / Faster / Slower.
- `@AppStorage("debug.commitExactDelayMs") private var commitExactDelayMs = 0`; picker "Exact Seek Delay (A/B)", options `[0, 75, 300, -1]`, labels Auto / 75 ms / 300 ms / Keyframes Only.

The controller reads all three once in `init` (agent A writes these reads in W1; the rows are W2): `holdTickSec = d > 0 ? d : TransportPreview.defaultTickSec` (0.25); `transport.rampScale = r > 0 ? r : 1` (set in `viewDidLoad`, where `transport` is configured); `commitExactDelaySec = ms == 0 ? 0.15 : (ms < 0 ? -1 : Double(ms) / 1000)`. Launch arguments `-debug.holdTickSec 0.15` / `-debug.holdRampScale 0.5` / `-debug.commitExactDelayMs 300` override through the argument domain with no extra code. Per D9, the knobs are removed at the next cut.

---

## 10. Tests

### `NuvioTVTests/TransportPreviewTests.swift` (new, 25 cases; agent A)

Helper: `held(k) = 0.4 + 0.25 * Double(k - 1)`, the hold time of tick `k` at the defaults. Ticks 1…8 → steps 10, 20, 20, 20, 30, 30, 30, 60.
1. `testStepSecBoundaries`: `stepSec(heldSec:)` at 0.4 → 10; 0.59 → 10; 0.6 → 20; 1.19 → 20; 1.2 → 30; 1.99 → 30; 2.0 → 60; 10 → 60. With `rampScale: 0.5`: 0.3 → 20, 0.6 → 30, 1.0 → 60. With `rampScale: 2`: 1.19 → 10, 3.99 → 30, 4.0 → 60.
2. First press from idle (Step) → `.immediateSeek(+10)`, mode `.stepping(1, 10, 0)`, preview = origin + 10.
3. Press + release with no tick → `.none`, idle, preview nil (no second seek).
4. Press, ticks at `held(1)`, `held(2)`, release → `.commit` target origin + 40 (10 + 10 + 20), `fromSec` origin.
5. Press, 4 ticks → preview origin + 80 (10 + 10 + 3·20).
6. Press, 7 ticks → origin + 170 (10 + 10 + 60 + 90).
7. Press, 8 ticks → origin + 230.
8. Backward from origin 25, 3 ticks → preview clamps at 0; commit target 0.
9. Forward near the end (duration 1500, origin 1490) → preview and target 1499.5.
10. Unknown duration (0) → no upper clamp.
11. Reversal at the clamp moves at once (acc stored post-clamp).
12. Direction change mid-hold: Right held 3 ticks, press Left → acc − 10, ticks 0, no `.immediateSeek`; Right's release ignored; Left's release commits.
13. Commit stages `[.keyframes, .exact]` when the target is outside `seekableRanges`.
14. Commit stages `[.exact]` when the target is inside a range (boundary inclusive at both ends).
15. Scan mode click (press + release, no tick) forward → `.none` on press, `.immediateSeek(+10)` on release.
16. Scan mode hold forward → `.startScan(2)` on tick 1, preview = origin; later ticks → `.none`.
17. Scan mode backward hold → steps (never scans), commit on release.
18. Scan is latched: releasing Right while scanning → `.none`, mode still `.scanning(2)`.
19. Right presses while scanning → `.setScanRate(3)`, then 4, then 2; each release → `.none`.
20. Left press while scanning → `.endScan(fromSec: origin, returnToSec: nil)`, idle, preview nil.
21. `endScanInPlace()` while scanning → `.endScan(fromSec: origin, returnToSec: nil)`; while idle → `.none`.
22. `noteLivePosition` while scanning moves `previewSec`; in idle it is a no-op.
23. `cancel()` while stepping → `.none`, idle, preview nil, no commit.
24. `cancel()` while scanning → `.endScan(fromSec: origin, returnToSec: origin)`.
25. `parseSeekableRanges`: a valid mpv JSON sample → ranges; garbage, a missing key and an empty array → `[]`. Plus `noteCommitLanded()` clears a commit's held preview.

### `NuvioTVTests/BufferedRangesMergeTests.swift` (new, 6 cases; agent A)
Unsorted input sorted; gap 4.9 s merged; gap 5.0 s kept apart; overlapping ranges merged; clamped to the duration and zero-length ranges dropped; empty in → empty out.

### `NuvioTVTests/SkipSegmentPlannerTests.swift` additions (9 cases: the first four agent A, the last five agent C)
- `testRefineSeekAfterKeyframesLandingKeepsOneGestureSpan`: intro 100–190; user seek 50 → 140 keyframes completes at 138; `refineSeek(140, from: 50)` completes at 140; playing tick at 141 with auto-skip intro → no auto-skip; chip shown.
- `testRefineSeekWhileKeyframesInFlightReplacesTarget`: `seekInFlight.targetSec` is the refined value and `fromSec` the original.
- `testRefineSeekDoesNotResetChipSuppression`: after a chip press, refine → still no chip for that interval.
- `testRecordUserSpanConsumesScannedIntervals`: `recordUserSpan(0, 300)` over intro 100–190 → seek back to 120, play → no auto-skip.
- `testChipAutoHidesAfterTenSeconds` (`autoHidesChip = true`): chip at t 0 … 9.9, nil at 10.
- `testChipAutoHideOffByDefault`: the same ticks with the flag false → chip at 15.
- `testNoteInputRevealsHiddenChipForAnotherTenSeconds`: hidden at 10, `noteInput(12)` → true, chip at 12 … 21.9, nil at 22.
- `testNoteInputWhenChipVisibleReturnsFalse`.
- `testLeavingAndReenteringIntervalRestartsTheTimer`.

### UI legs (`NuvioTVUITests/PlayerTransportUITests.swift`, new; mpv smoke rig, FA87)

Same gate and launch helper as the bar spec's `PlayerTransportBarUITests`: skipped unless `PLAYER_BAR_PROBE=1` and `PLAYER_SMOKE_URL` are set (`TEST_RUNNER_` prefixes for xcodebuild); each test launches the app with `launchArguments += ["-debug.mpvSmokeURL", url, "-player.nativeDolbyVision", "NO"]` plus its own extras, then waits for `player.mpv` and for the probe's `pos=` > 1.

**DEBUG probe** (`Screens/Player/SeekProbe.swift`, agent A): `@MainActor final class SeekProbe: ObservableObject` (`commits`, `lastTarget`, `stages`, `speed`, `chip`, `paused`, `modeName`, `pos`) on `MPVPlaybackState` (DEBUG only), and `struct SeekProbeLabel: View` drawing, with the `TrailerMorphDebugLabel` recipe (`HomeView.swift:6635-6644`):
`Text(verbatim: "commits=\(commits) lastTarget=\(Int(lastTarget)) stages=\(stages) speed=\(String(format: "%.1f", speed)) mode=\(modeName) chip=\(chip ? 1 : 0) paused=\(paused ? 1 : 0) pos=\(String(format: "%.1f", pos))")`, `.font(.system(size: 8)).opacity(0.011).accessibilityIdentifier("debug_seekProbe").allowsHitTesting(false)`. Always present in DEBUG builds (no UserDefaults gate). Agent A places it with one line at the end of `MPVPlayerScreen`'s `ZStack`: `#if DEBUG SeekProbeLabel(probe: state.seekProbe) #endif`. `stages` is `k`, `ke` or `e` for the last commit; `ke` once the exact stage is issued, `k` while it waits or after it was cancelled. `speed` is the last value written to mpv (the controller's own record; never read the property). `modeName` = `transport.mode.probeName`; `pos` = `state.positionSec`; `chip` = `state.skipPrompt != nil` (agent C's leg reads it).

For the chip leg (agent C), a DEBUG launch key `debug.mpvSmokeSkipInterval` = `"start,end,type"` makes the controller call `applySkipIntervals` (`:1016`) with that one `SkipInterval` once the file has loaded, but only while `debug.mpvSmokeURL` is set.

1. **`testHoldStepCommitsOnce`** (agent A): read `origin` from `pos=`. `remote.press(.right, forDuration: 2.0)`, wait 2 s. Assert `commits=1`, `stages=ke` or `e`, and `lastTarget` in `origin + 140 … origin + 230` inclusive (6, 7 or 8 ticks depending on release jitter: 140 / 170 / 230; the smoke file must be longer than origin + 240). Then a short `remote.press(.right)` → `commits` unchanged (relative seek, not a commit).
2. **`testExactStageCancelledByNewPress`** (agent A): hold Right 1.5 s, then press Right within 100 ms of the release → `stages=k` (exact cancelled); a second 1.5 s hold → `commits=2`.
3. **`testScanLatchesAndCycles`** (agent A): launch with `-player.holdMode scan`. Hold Right 1.0 s → `speed=2.0 mode=scanning`; wait 1.0 s after the release → still `speed=2.0 mode=scanning` (latched); press Right → `speed=3.0`; press Right → `speed=4.0`; press Select → `speed=1.0 mode=idle paused=0`. Then hold Right 1.0 s again (scanning), note `pos=` as the origin at the press, wait 2 s, press Menu → `mode=idle speed=1.0` and, after 2 s, `pos` within ±3 s of that origin; `player.mpv` still exists.
4. **`testSkipChipAutoHides`** (agent C): `-debug.mpvSmokeSkipInterval "5,60,op"`. Wait for `chip=1`, then 11 s → `chip=0`. `remote.press(.left)` → `chip=1`.

Release build, NuvioTVTests green, jvm / K/N green.

---

## 11. Strings (English, `Localizable.xcstrings`; keys = the English text; agent C)

"Hold Left/Right", "Step", "Scan", "Show Clock", "Show the time of day while the controls are up (mpv player)", "Try with mpv", "Try Native Player", "Hold Step Interval (A/B)", "Hold Ramp Speed (A/B)", "Exact Seek Delay (A/B)", "Auto", "Faster", "Slower", "0.15 s", "0.4 s", "75 ms", "300 ms", "Keyframes Only", "Applies to the next playback." (exists), plus the five `SettingsDescriptions` texts in §9. The bar spec's keys ("Speed", "More", "ends %@") are agent B's. The five locales run through `scripts/populate-localizable-xcstrings.py` + `merge-translations-into-xcstrings.py` at the end of the batch (main session).

## 12. Release-notes facts this spec creates

Hold Left/Right defaults to Step; a held arrow now moves only the preview and seeks once, on release, with the official Nuvio 10/20/30/60 table (60-second steps after 2 s of holding). Scan (off by default) keeps scanning after you let go: Right for 3×/4×, Select to carry on, Menu to go back. Show Clock is off. Audio delay is now remembered per title. The skip chip hides after 10 s and comes back on any press (mpv player). "Try with mpv" / "Try Native Player" appear on the failure alert only when the other engine can take the stream. The Developer A/B rows (Hold Step Interval, Hold Ramp Speed, Exact Seek Delay) ship for one rc (D9).

## 13. Agent briefs

Common to both: clone `~/Claude/Projects/NuvioMobile-player`, branch `claude/player-p1`. MPVKit is a symlink over the gitlink: stage by explicit paths, never `git add -A`; `git status` may error on MPVKit, ignore it. One build at a time. Commands run from `~/Claude/Projects/NuvioMobile-player/iosApp`, with the Bash tool sandbox OFF for `xcodebuild test` (in-sandbox it exits 70):
- Build: `xcodebuild -project iosApp.xcodeproj -scheme NuvioTV -configuration Debug -destination 'platform=tvOS Simulator,id=<FA87 UDID>' -derivedDataPath build/DerivedData build` (full UDID from `xcrun simctl list devices`).
- Unit: `xcodebuild test -project iosApp.xcodeproj -scheme NuvioTVTests -destination '<same>' -derivedDataPath build/DerivedData -only-testing:NuvioTVTests/<Class>` for each named class only.
- UI: `TEST_RUNNER_PLAYER_BAR_PROBE=1 TEST_RUNNER_PLAYER_SMOKE_URL=<url> xcodebuild test -project iosApp.xcodeproj -scheme NuvioTVUITests -destination '<same>' -derivedDataPath build/DerivedDataUITests -only-testing:NuvioTVUITests/PlayerTransportUITests/<test>`.
- Agent C only, for §7: from `~/Claude/Projects/NuvioMobile-player`, `./gradlew :shared:jvmTest` and `./gradlew :shared:tvosSimulatorArm64Test` (check the exit code directly; don't pipe).

Report back, both: commit SHA(s); files touched; build result; each named test class's count and result; each UI leg PASS/FAIL/SKIP with the probe line it read; any spec line you could not follow as written and what you did instead.

### Agent A (W1, first)

**Create:** `iosApp/NuvioTV/Screens/Player/TransportPreview.swift` (§1, `BufferedRange`, `parseSeekableRanges`, `Mode.isActive`/`probeName`), `iosApp/NuvioTV/Screens/Player/TransportBarModel.swift` (bar spec §3, the whole class incl. `PillKind`), `iosApp/NuvioTV/Screens/Player/SeekProbe.swift` (§10), `iosApp/NuvioTVTests/TransportPreviewTests.swift`, `iosApp/NuvioTVTests/BufferedRangesMergeTests.swift`, `iosApp/NuvioTVUITests/PlayerTransportUITests.swift` (legs 1–3).

**Edit:** `iosApp/NuvioTV/Screens/PlaybackModels.swift` (two `PlayerTuning` keys), `iosApp/NuvioTV/Screens/Player/SkipSegmentPlanner.swift` (§2.4 items 1–2 only), `iosApp/NuvioTVTests/SkipSegmentPlannerTests.swift` (the four refine/span cases), and `iosApp/NuvioTV/Screens/MPVPlayerView.swift`, only the agent-A regions of bar spec §1 "Ownership": state fields (§2.1), `transport`/`seekProbe` on `MPVPlaybackState`, `refreshState` mirroring + buffered dispatch + scan live position + EOF end, `:1018` skip spans, the mode-active pre-checks, `beginHold`/`pressesEnded`/`apply`, `issueSeek` (return value, `onRejected`, `planner:`), `issueCommit`/exact stage/preview hand-back, `startScan`/`endScan`, the `PLAYBACK_RESTART` additions, the `deinit`/`viewDidDisappear`/`replay` cancels, the options array (§5), the knob reads in `init`/`viewDidLoad`, and the one `SeekProbeLabel` line in `MPVPlayerScreen`. Do NOT touch `flashControls`, the overlay, `PlayerControlsOverlay`, the pause card or the chips (agent B).

**Steps:** 1. `TransportPreview.swift` + its two test classes; build; run them. 2. `TransportBarModel.swift`, `SeekProbe.swift`, `PlayerTuning` keys; build. 3. Planner `refineSeek`/`recordUserSpan` + four tests; run `SkipSegmentPlannerTests`. 4. Controller wiring (§2–§5); build. 5. Smoke rig: capture the `[Transport] cache-state` line (§4). 6. UI legs 1–3.

### Agent C (W2, after agent B)

**Edit:** `iosApp/NuvioTV/Screens/Player/SkipSegmentPlanner.swift` (§6), `iosApp/NuvioTVTests/SkipSegmentPlannerTests.swift` (five chip cases), `iosApp/NuvioTV/Screens/MPVPlayerView.swift` (the §6 lines at the top of `pressesBegan`, `autoHidesChip = true` at `:145`, the §7 audio-delay restore/save, the §8 `computeResumePosition` line, the `debug.mpvSmokeSkipInterval` hook), `Screens/Player/MPVPlaybackTab.swift` (comment), the `shared/` files in §7, `Screens/PlaybackModels.swift`, `Screens/PlayerScreen.swift`, `Screens/NativePlaybackCoordinator.swift`, `Screens/StreamPickerView.swift` (§8), `Screens/SettingsViewModel.swift`, `Screens/Settings/PlayerSettingsPane.swift`, `Screens/Settings/SettingsDescriptions.swift`, `Screens/Settings/DeveloperSettingsPane.swift` (§9), `Localizable.xcstrings` (§11, English only), `iosApp/NuvioTVUITests/PlayerTransportUITests.swift` (leg 4). No new files.

**Steps:** 1. §6 planner + tests. 2. §7 shared + Swift; gradle tests. 3. §8. 4. §9 rows + §11 strings; build. 5. Leg 4; Release build (`-configuration Release`, same command otherwise).

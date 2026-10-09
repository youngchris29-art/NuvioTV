# Player P1 review, round 3 (Opus stand-in for Codex, read-only)

Range: `NuvioMobile-player` `claude/player-p1` at `9a2f5c37e`. The r2 fix commit `9a2f5c37e` is checked against r2 (`player-p1-review-r2.md`), then the two fix commits (`ec4e19fdc`, `9a2f5c37e`) get a fresh pass over `5feef338..9a2f5c37e`, limited to `MPVPlayerView.swift`, `PlayerScreen.swift`, `Player/TransportPreview.swift`, `Player/PlayerRemoteRules.swift` and `Player/PlayerTransportBar.swift`. Paths are relative to `iosApp/NuvioTV/Screens/`. Line numbers are at `9a2f5c37e`.

## r2 verification

| # | r2 finding | Status | Note |
|---|---|---|---|
| P2-1 | Slow keyframes-first commit: the 1.5 s landing fallback clears the preview and the fill snaps to the origin | Fixed | `exactDeadlineFired` (`MPVPlayerView.swift:1856`) re-arms the landing to 4 s on main, before the `eventQueue` hop, while `commitGeneration == generation`. `armCommitLanding` cancels the pending 1.5 s `commitLandWork`. Both 1.5 s items go on main with `asyncAfter`, and the deadline is queued first (`:1825` before `:1836`) with the earlier target, so libdispatch runs it first. **Non-waiting branch:** `runExactStage` then re-arms 3 s on the exact generation (`:1896`), which cancels the 4 s item. The same work item can't fire twice. **Waiting branch:** the 4 s item holds the preview until mpv's SEEK runs the exact stage (3 s re-arm), or it lands on its own at 5.5 s. **Keyframes land first:** the restart block (`:2330`) clears `commitGeneration` and cancels the land work, so the deadline never re-arms. **Teardown:** `viewDidDisappear` → `cancelExactStage` nils `pendingExact`, so the hop's `runExactStage(ifGeneration:)` returns. The land work is `[weak self]` and touches only transport/state, never mpv. Nothing is orphaned by the re-arm itself. One orphan predates r2 and is still open: new P3-1. |
| P3-1 | Cancelled press during a latched scan leaves the hold timer running | Fixed | `:1727`. Outside `.stepping`, every cancelled Left/Right calls `stopHoldTimer()`, and a scan needs no timer: `holdTick` returns `.none` outside stepping, and a Right press during a scan never calls `beginHold`. In `.stepping`, only a cancel of the held key stops and cancels. The other key's hold keeps its timer. A Home press cancels both arrows in one set, and either iteration order ends idle with no timer. |
| P3-2 | Stale `state.panelOpen` routes Menu to `super` | Fixed | `:1653` reads `presentedViewController != nil` alone. The mpv panel always goes through `controller.present(panel…)` (`:2525–2536`, `.overFullScreen`), so a presented panel always shows up there. A cover presented by an ancestor also counts (UIKit's documented ancestor rule), and it takes its own presses. Residual, unchanged from before r2: a Menu that arrives during the panel's dismiss animation still hits `.panel` and goes to `super`. That is the same as the old `||` form, so it is not a regression. |
| P3-3 | Forced native retry offers "Try with mpv" back | Fixed | `PlayerScreen.swift:100`. The only writer of `forcedEngine` is the failure-alert retry (`StreamPickerView.swift:1099`), which sets it to the other engine. A forced-native run now reports `otherEngineEligible = false`. A normal native run (`nil`) still offers mpv. |
| P3-4 | Paused → playing without input leaves no hide timer armed | Fixed | `:1390`. It runs only when `controlsVisible`. It doesn't fight a focused pill or an active mode: `armHide` checks `TransportHideRule.mayHide` when it fires and returns without hiding, exactly as for any input. The pause card needs `isPaused && !controlsVisible` (`:2617`), and the edge is a resume, so the card is already going away. When `togglePause` is called right before `flashControls`, the hide is scheduled twice. `scheduleHide` cancels and re-arms, so that is harmless. |
| P3-5 | A lost press blocks the light tap for the session | Fixed | Cleared in `viewDidAppear` (`:392`) and `reclaimFocus` (`:317`). `reclaimFocus` is called from the panel's `onClosed` and the other cover's `onDismiss` (`:2533`, `:2711`). Clearing it while a press is really down can only matter for a tap during a held click, and the 0.5 s `lastClickUptime` window still guards that. |

## New findings

### P1

None.

### P2

None.

### P3

1. **`MPVPlayerView.swift:1883–1888` with `:1865–1870` and `:2340–2342`: an orphaned `exactWork` can run a newer commit's exact stage before its keyframes start.** This is from r1's eventQueue hop (`ec4e19fdc`), not from r2. `runExactStage` sets `exactWork = nil` without cancelling it.
   - **Scenario:** a keyframes seek lands at about 1.5 s. The deadline fires on main, sees `pendingExact` and hops to `eventQueue`. `drainEvents` has already posted the PLAYBACK_RESTART main block, so that block runs first. It hands the preview back and calls `scheduleExact(after: 0.15)`, which arms `exactWork`. Next, the hop's `runExactStage(ifGeneration:)` runs the exact stage immediately and nils `exactWork`, but the 0.15 s item is still scheduled.
   - **Impact:** normally the orphan fires into a nil `pendingExact` and does nothing. But a new commit can set `pendingExact` inside those 150 ms (a press, then a release that commits). Its `cancelExactStage()` can't reach the orphan, and the orphan's `runExactStage()` carries no generation guard. The new commit's exact seek then stacks before mpv reports its keyframes SEEK, which is the misattribution r1 #3 closed. The window is narrow (150 ms right around a 1.5 s landing), and the result is a mistimed exact stage, not a wrong position.
   - **Fix shape:** `exactWork?.cancel()` before `exactWork = nil` in `runExactStage`. Either add this as well or do it instead: give `scheduleExact`'s work item `runExactStage(ifGeneration: p.generation)`.
2. **`MPVPlayerView.swift:1843–1850` (robustness, low confidence).** The P2-1 fix relies on the deadline running before the 1.5 s land work. libdispatch does that today (same queue, earlier target, same leeway class), but the code doesn't state the dependency. **Fix shape (optional):** in the land work, `guard self.pendingExact?.generation != generation` and skip while the exact stage for that generation is still pending. Then the ordering no longer matters.

Fresh pass, checked and clean:
- `TransportPreview`: `scanArmed` is captured once per gesture, and `transport.paused` is set in `beginHold` before `pressBegan`. `noteCommitLanded` clears only in `.idle`, so a 4 s fallback that fires during a new stepping hold leaves that hold's preview alone. `cancel()` from stepping or scanning resets `previewSec`.
- `MenuPrecedence` / `LightTapGuard`: both are pure, and the order matches the spec. `.panel` and `.exit` don't swallow the release.
- `PlayerTransportBar`: the end-clock formatter cache is main-only and rebuilds when the locale or time zone changes.
- The `issueSeek`/`drainEvents` generation handling is unchanged by r2. A late fallback leaves `commitGeneration` set, which is harmless: generations only grow, and the next commit overwrites it.
- mpv calls stay on `eventQueue`. `issueSeek` returns early when `mpv == nil`, so no post-teardown path reaches mpv.

VERDICT: CLEAN (P1 0, P2 0, P3 2)

# Player P1 review, round 2 (Opus stand-in for Codex, read-only)

Range: `NuvioMobile-player` `claude/player-p1`, fix commit `ec4e19fdc` checked against r1 (`player-p1-review-r1.md`), then a fresh pass over `5feef338..ec4e19fdc`. Paths are relative to `iosApp/NuvioTV/` unless they start with `iosApp/` or `shared/`. Line numbers are at `ec4e19fdc`.

## r1 verification

| # | r1 finding | Status | Note |
|---|---|---|---|
| 1 | Light tap fires on arrow clicks / long Select | Fixed | `LightTapGuard.allows` (no press down, ≥ 0.5 s since the last begin/end/cancel); `pressesBegan`, `pressesEnded` and `pressesCancelled` all stamp `lastClickUptime` and maintain `pressesDown`. Unit tests cover the down, window and long-hold rows. Robustness note in new P3-5. |
| 2 | No `pressesCancelled` | Fixed, with a gap | Arrows: a `.stepping` hold of that key stops its timer and `cancel()`s (no commit); a latched scan is left alone; Menu is swallowed only when `swallowMenuRelease`, else `super`. Gap: a cancel during a latched scan does not stop the hold timer (new P3-1). |
| 3 | Slow uncached commit: exact stage stacks blind, handback never matches, fill snaps to origin | Partly fixed | Fixed: the deadline waits for the keyframes `MPV_EVENT_SEEK` (`exactAwaitsSeekStart`, both checks on `eventQueue`, so the SEEK can't be missed or misattributed), `runExactStage(ifGeneration:)` is generation-guarded, the planner gets `refineSeek` before the exact `issueSeek(planner: false)`, and the exact generation takes the landing handback (3 s). Not fixed: the snap-back itself (new P2-1). |
| 4 | Vacuous Menu UI legs | Fixed | `XCTExpectFailure` now wraps only the "player still presented" assertion; a dismissed cover throws `XCTSkip` after it (reported skipped, never passed). `MenuPrecedence.resolve` is pure and has six order tests plus the release rule. |
| 5 | Late keyframes rejection drops a newer exact stage | Fixed | Guarded on `pendingExact?.generation == expected`. |
| 6 | Menu-cancel return seek marks the scan-end interval | Fixed differently | `fromSec: target`: the planner records a zero-length span at the origin rather than none. Benign (the origin is where the viewer already was). |
| 7 | Planner span test passed by accident | Fixed | Renamed to the endpoint case; asserts right after `recordUserSpan(0, 150)` against a control. |
| 8 | Paused Scan hold latches a dead 2× | Fixed | `scanArmed` requires `!paused`; a paused hold steps. Test `testScanHoldWhilePausedSteps`. |
| 9 | One-tick chip flash on seek presses | Fixed | Arrow presses skip the immediate `updateSkipPrompt`; the reveal shows on the next tick. |
| 10 | `scanRestore` set by an async main hop | Fixed | Speed captured on main before the hop; mute read and stored on `eventQueue`, and `endScan`'s block runs after it on the same serial queue. |
| 11 | Hide delay fixed at arm time | Fixed | `armHide` re-reads `TransportHideRule.delay` when it fires and re-arms for the remainder. Follow-on in new P3-4. |
| 12 | Native retry ignores `resumeAtSec` under Start Over | Fixed | `retryResume` (> 10 s) wins over `startFromBeginning`, same as mpv. `resumeAtSec` is only ever set by the failure-alert retry (`StreamPickerView.swift:1100`), so a normal Start Over is unaffected. |
| 13 | Retried link stays rejected 8 h | Fixed | `RejectedStreamLinks.keep` before the retry. It cannot reopen a link the user rejected: every rejection is automatic, and a retry that fails is rejected again by `handlePlaybackFailure`. "Try Next Source" and Cancel leave the rejection in place. |
| 14 | Doc comment on the wrong property | Fixed | |
| 15 | xcstrings ordering, English-only strings | Declined (cosmetic) | File still parses (1396 keys). |
| 16 | `DateFormatter` per render | Fixed | One cached formatter, rebuilt on a locale/time-zone change. |
| 17 | Retry gate relies on closure capture | Fixed | `context.forcedEngine == nil` in `eligibleForNative`. Related gap on the native side in new P3-3. |
| 18 | `Int(probe.lastTarget)` traps | Fixed | `%.0f`. |

## New findings

### P1

None.

### P2

1. **`Screens/MPVPlayerView.swift:1820` with `:1840` (r1 #3, the half that is still open).** A keyframes-first commit arms the 1.5 s landing fallback (`armCommitLanding(generation: gen, fallbackSec: 1.5)`) on the same deadline as the exact stage. In the slow case the deadline only hops to `eventQueue` (and in the waiting branch does nothing until mpv reports the SEEK), while the land work fires on main at 1.5 s, calls `noteCommitLanded()` and clears `previewSec`. The bar falls back to `positionSec`, which is still the origin, so the played fill snaps back until the exact stage lands. The 3 s re-arm in `runExactStage` comes too late: the preview is already nil, and all it does is hand back an empty preview. Scenario: an uncached debrid HTTP stream, Right ×3 from 10:00, release. The fill jumps to 10:00+ at release, returns to 10:00 at 1.5 s, then jumps to 10:30 when the seek finally lands. That is the spec's "does not jump back while the seek lands". **Fix shape:** in `exactDeadlineFired`, on main and before the hop, cancel `commitLandWork` while `commitGeneration == generation` and re-arm a longer fallback (e.g. 4 s) that the exact stage's `armCommitLanding` then replaces. Or arm the first fallback at 1.5 s only for exact-only commits and at ~4.5 s for `[.keyframes, .exact]`. Add a unit-level seam if possible (the land/deadline ordering is pure timing); otherwise a device-pass item: slow seek, the fill holds the target.

### P3

1. **`Screens/MPVPlayerView.swift:1718`**: `pressesCancelled` during a latched scan leaves the hold timer running (only `.stepping` stops it). `tick()` then calls `flashControls()` every 0.25 s. After the scan ends by Select or Left (`endScanInPlace`, which never stops the timer), the bar can never auto-hide until the next arrow press or a Menu. Trigger: TV/Home or Siri while holding Right after the scan latched. **Fix:** `stopHoldTimer()` for every cancelled Left/Right, whatever the mode. The scan does not need the timer.
2. **`Screens/MPVPlayerView.swift:1643`/`:1649`**: `.panel` hands Menu to `super` whenever `state.panelOpen` is true. `panelOpen` is only cleared by `PlayerPanelHostController.close()` (`onClosed`). If the panel ever goes away by another path, a stale `true` sends every later Menu up the chain, which dismisses the cover without `closeFailover()`/`onExit`. In practice a presented panel takes the presses itself, so the only live input is `presentedViewController != nil`. **Fix:** resolve `panelOpen` from `presentedViewController != nil` alone, or swallow on `.panel`.
3. **`Screens/PlayerScreen.swift:99`**: a native failure always sets `otherEngineEligible = true`, including a native run that was itself the forced retry after an mpv failure. The chain is then mpv fails → "Try Native Player" → native fails → "Try with mpv" offered for the engine that already failed (the comment above `eligibleForNative` says the alert must not alternate engines). **Fix:** `engine == .native ? context.forcedEngine == nil : eligibleForNative`.
4. **`Screens/MPVPlayerView.swift:2034`**: when the timer fires while paused with the pause card off, `currentHideDelay()` is nil and the work returns without re-arming. A later resume that comes without input (none today, but the same class r1 #11 fixed) leaves the bar up until the next press. Cheap hardening: re-arm `scheduleHide()` on the paused→playing edge in `refreshState`.
5. **`Screens/MPVPlayerView.swift:1540`/`:1685`/`:1710` (low confidence)**: `pressesDown` relies on every begun press reaching `pressesEnded`/`pressesCancelled` on this controller. If one is ever lost (a press that presents the panel mid-press, or a first-responder change), the light tap stays blocked for the rest of the session with no symptom but a dead tap. **Fix:** clear `pressesDown` on `reclaimFocus`/panel close and in `viewDidAppear`, or age entries out (e.g. ignore a press older than 10 s). Add to the device pass: open the panel with Down, close it, light tap still toggles the clock.

Checked and found clean in the fresh pass: all new mpv reads and writes run on `eventQueue`. `exactAwaitsSeekStart` and `awaitingSeekStartGeneration` are only touched there (`drainEvents` runs on `eventQueue` through `MPVWakeupRelay`). `seekGeneration`, `pendingExact` and `commitGeneration` are main-only. No timer or work item touches mpv after teardown. `issueSeek` returns early on `mpv == nil`. The deadline, land and exact work items are `[weak self]`. `deinit` can't overlap a running `eventQueue` block, which holds a strong `self`. Scan leaves no stale speed or mute on Menu, swipe-down, Down, Select, Left, EOF or `viewDidDisappear` (`cancel()` → `endScan`), and next-episode/failover rebuild the controller. A stale `exactAwaitsSeekStart` after `cancelExactStage` is harmless because generations only grow. `MenuPrecedence` order matches the spec. For every action the handler either consumes Menu and swallows its release, or (`.panel`) passes both phases to `super`. `.exit` consumes the begin and lets the release through, as before P1. `upNextVisible` matches the old `dismissIfVisible` test (`phase != .hidden`; `.searching` is the visible "Finding next episode…" chip). `audio_delay_ms|` sits in the wipe registry. The value is clamped to ±10 s, the same as the panel's `limit: 10`. Folder-synchronized groups mean the new Swift files need no pbxproj entries. `Localizable.xcstrings` parses.

VERDICT: FINDINGS (P1 0, P2 1, P3 5)

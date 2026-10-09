# Player P2 review, round 3 (Opus stand-in for Codex)

**VERDICT: CLEAN (0 P1 / 0 P2 / 4 P3)**

Range: clone `~/Claude/Projects/NuvioMobile-player`, branch `claude/player-p2`, `0c10ca4a4..1822c18e9` (28 commits). Focus: the r2 fix round `30663c734..1822c18e9` (`7d48faad6`, `f72de87f7`, `cdf9ff772`, `b641098ee`, `1822c18e9`). Read-only; nothing built or run. Line numbers are at `1822c18e9`.

## Checked and found clean

**r2 P2 #1 (Stretch leaves a rejected mode in the profile): FIXED.** `AspectWriteback` (`PlayerAspectMode.swift:72-112`) now keeps `sessionStart`, `stored` and `pendingEchoes`. `valueToPersist` targets the resting mode for Fit/Fill/Zoom and `sessionStart` for Stretch, writing only when the target differs from `stored`. All three call sites are main-only: the settings watcher (`MPVPlayerView.swift:625`, a `FlowWatcher` on `Dispatchers.Main`), FILE_LOADED (`:1157`, inside the main hop at `:3146`) and `persistAspectIfNeeded` (`:2241`, reached from the flash work item and `viewWillDisappear`). `didPersist` runs before `setResizeMode`, so the echo can never beat the queue entry. Walked cases:
- Repeated emissions of the same value (any player setting change re-emits): the first consumes the echo, later ones hit `mode == stored` and return. Covered by `testRepeatedStoredValueIsIgnored`.
- Conflated echoes (Fill then Zoom, watcher reports only Zoom): `firstIndex` consumes through Zoom. A late echo of Fill then Zoom consumes in order. Both covered.
- An outside change not in the queue moves `stored` and `sessionStart` and clears the queue; Stretch then puts the outside value back (`testOutsideChangeBecomesSessionStart`).
- Unknown start: the watcher is subscribed after `ensureLoaded()` (`:619`) and delivers the StateFlow's current value immediately, so `playerSettings` is seeded long before FILE_LOADED, which needs the network. If it were nil, `initial` yields Fit and the first watcher report of the real value lands as an outside change, which self-corrects `sessionStart`. Stretch is never a start (`init` maps it to Fit).
- `viewWillDisappear` with writes pending: the final write happens, the controller goes away, and the queue dies with it. Nothing reads it later.
- A pending echo that never arrives: see P3 #1. It only matters when an outside change equal to the stale entry arrives later, and the reachable triggers are narrow.

**r2 P3 #2 (sentinel false positive across controllers): FIXED.** The key is now `player.harvestInFlightOwner` holding `processToken` (`HarvestCrashSentinel.swift:27-30`); `checkAtLaunch` disables only for a foreign token; `clear` removes the key. Arm and clear bracket `screenshot-raw` on `eventQueue` (`MPVPlayerView.swift:1855-1860`, `defer`); the first-capture `CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)` flushes the whole app domain, so the new key is covered. Nothing else reads the old `player.harvestInFlight` key (grep: only the Developer pane's `disabledKey`). `set(_:Any?)` resolves correctly for both the token and `nil`; `UserDefaults` conforms as is.

**r2 P3 #3 (aspect leg flash race, scrub clock bias): FIXED.** `-debug.aspectFlashSec` is read once in `viewDidLoad` under `#if DEBUG` (`:465-466`). With a 6 s flash the three presses at 0.5 s spacing in step 2 cannot outlast it. The `aw=` oracle distinguishes the new rule from the old one on a Fit or Fill start: step 3 ends `stored=<start> aw=5` where the old rule ended `stored=zoom aw=4` (see P3 #2 for the Zoom start). The scrub leg's midpoint clock removes the one-sided read bias.

**r2 P3 #4 (Chapters tab default focus unproven): FIXED,** with a flake margin (P3 #3). The re-open path asserts row 2 ticked and not focused on the tab, then one Down lands on row 2 and not row 0. `PlayerChaptersTab` backs this with `.defaultFocus($focusedChapter, currentID, priority: .userInitiated)` on a `focusSection` ScrollView, not a `List`, so the "List ignores prefersDefaultFocus" trap does not apply. `hasFocus` is fine on FA87 (26.5); the first half of this leg already loops on it.

**r2 P3 #5 (chapter trim not re-derived): FIXED.** `rawChapters` and `chaptersTrimDuration` are main-only, written in `readChapters`' main hop (`:2187-2191`) and read in `refreshState` (`:1672-1678`). The comparison runs only when the duration changes (a Double compare per tick otherwise); a live or growing stream re-trims a small array per tick, which is cheap. A tick that lands before the read hop sees an empty raw list and publishes nothing; the hop then publishes the trimmed list and its duration, and a later tick re-derives if the duration moved. Each file gets its own controller (one `loadfile` at `:602`, `onFileLoaded` guards on `fileLoaded`), so a stale raw list from an earlier file cannot be re-published. `testGrowingDurationBringsLateChaptersBack` covers drop, no-op and return.

**Full-range pass (P1 rules).** New mpv access in the range is on `eventQueue` (harvest capture, `readChapters`, aspect property writes, `withCommandResult`), or in `setupMpv` as pre-init options (`mpv_set_option_string`, `:824`). Every hop back to main from those blocks is strong (`startHarvest`, `applyAspect`), with `mpv != nil` checks after `destroyPlayer`. The new DEBUG knobs and probe fields (`aspectFlashSec` override, `debugAspectStored`, `debugAspectWrites`, the `[Aspect]`/`[Chapters]` NSLogs) are under `#if DEBUG`. Nothing in the r2 round touches `pressesCancelled`, `LightTapGuard`, `MenuPrecedence` or the generation-bound seek path.

## P1

None.

## P2

None.

## P3

**#1 A pending echo that never arrives can swallow a later outside change.** `PlayerAspectMode.swift:104-112`. `PlayerSettingsRepository.setResizeMode` returns without publishing when the repository already holds the value (`PlayerSettingsRepository.kt:415`), and a StateFlow collector that sees A→B→A inside one main turn reports nothing. In either case the entry stays queued. If the phone later sets the profile to that same value, `firstIndex` consumes it as our echo, `stored` and `sessionStart` stay put, and a later Fit/Fill/Zoom rest equal to the stale `stored` writes nothing, so the phone's value survives the user's choice. Reaching this needs `stored` to drift from the repository, or two writes within one collector turn; the flash gate makes the second near impossible. Fix: in `watcherReported`, when `mode == stored`, clear `pendingEchoes` and return before the `firstIndex` lookup. StateFlow always delivers the latest value last, so a report equal to `stored` means every earlier write is settled. Add a unit case: two writes with no echo, a report of the stored value, then an outside change equal to the older write must move `sessionStart`.

**#2 The aspect leg proves the Stretch rule only on a Fit or Fill start.** `PlayerTransportUITests.swift:647-660`. On a Zoom start, step 3 is a single Stretch rest that writes nothing under both the old and the new rule, so the leg passes against the r1 behaviour. FA87's profile start mode decides this, and a failed earlier run can leave it on Zoom. Fix: when `start == "zoom"`, fail with a clear message or rest once on Fit before step 3 so the walk always passes a written mode before Stretch; or assert `start != "zoom"` with the reason.

**#3 The Chapters re-open focus check is a single read after a fixed 0.8 s sleep.** `PlayerTransportUITests.swift:537-541`. A slow focus update on a loaded simulator fails `row.hasFocus` spuriously. Fix: wait on a `hasFocus == true` predicate for row 2 (a few seconds), then assert row 0 is not focused.

**#4 Overlapping captures in one process share one sentinel key.** `HarvestCrashSentinel.swift:36-39`. If two controllers capture at once (the next-episode hand-off), the first `clear()` removes the second's armed token, so a crash inside the second capture is not detected. The overlap window is short and the sentinel is a best-effort guard already documented as covering the first capture only. Fix if wanted: key the flag per controller (token plus an instance id, cleared only when it still holds that id), or note the limit in the type's doc comment.

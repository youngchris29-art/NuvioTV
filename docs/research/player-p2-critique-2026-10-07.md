# P2 spec critique and reconciliation (2026-10-07)

Opus critique of `player-p2-spec-scrub.md` (spec A, agent A) and `player-p2-spec-store.md` (spec S, agents B and C) against the plan's P2 section, the P1 critique and the clone `~/Claude/Projects/NuvioMobile-player` at `0c10ca4a4`. Read-only on code, no builds.

**Verdict: GO for Wave 1 once C1 and C2 are applied to the specs; the P2 items can be fixed in the specs before the agents start, the P3 items can ride along or wait for review rounds.** Both specs are close to the code: nearly every cited symbol exists where they say it does, the libmpv calls are real, and both keep P1's rules (eventQueue-only mpv access, teardown order, Menu on release). The two blockers are a contract that will not compile and contradictory run orders.

Counts: **2 P1 / 13 P2 / 16 P3.**

## 1. Cross-spec contract conflicts

**C1 (P1) Preview source contract does not compile and has two owners.** A declares `protocol SeekPreviewSource: AnyObject, Sendable { func thumbnail(near sec: Double) async -> CGImage? }` and a controller field `seekPreviewSource`. S declares `actor SeekPreviewStore` with `thumbnail(near sec: Double, tolerance: Double? = nil)`, and wires it through `weak var previewStore` on `MPVPlaybackState`, saying A reads `state.previewStore?.thumbnail(near:)`. A method with an extra defaulted parameter does not witness `thumbnail(near:)`, so the conformance A expects fails to compile. **Resolution:** A owns the protocol exactly as written. S adds a one-line overload on the actor, `func thumbnail(near sec: Double) -> CGImage? { thumbnail(near: sec, tolerance: nil) }`, and an `extension SeekPreviewStore: SeekPreviewSource {}`. Drop `MPVPlaybackState.previewStore` (nothing on the SwiftUI side needs it). The controller holds the store strongly (`private var previewStore: SeekPreviewStore?`, B) and B assigns `seekPreviewSource = store` in `viewDidLoad`; `destroyPlayer` nils both.

**C2 (P1) Run order.** A §9 says "Agent B (store) runs in parallel on other files"; S §10 says A, then B, then C sequentially. They share one working tree and overlap in `MPVPlayerView.swift` (`viewDidLoad`: A, B, C; `apply`: A adds `.cancelUpNext`, C rewrites `.immediateSeek`; `destroyPlayer`: A, B; `drainEvents`: B at PLAYBACK_RESTART, C at FILE_LOADED), in `TransportBarModel.swift` (all three), the bar probe (all three), `MPVPlayerPanelAdapter.swift` (B, C), `DeveloperSettingsPane.swift` (A, B), `SettingsDescriptions.swift` and `Localizable.xcstrings` (all three). Builds are serialised anyway. **Resolution: sequential A → B → C, one agent at a time** (the P1 critique #5 shape; well inside the three-concurrent cost rule). A needs no stub: it leaves `seekPreviewSource` nil, so the card shows time only and the probe reads `frame=0`; B makes frames appear without touching A's files beyond the assignment. Fix A §9's sentence.

**C3 (P2) Chapter title lookup exists twice.** A computes `model.chapters.last(where: { $0.sec <= target + 0.001 })?.title` inline; S adds `TransportBarModel.chapterTitle(at:)` over `PlayerChapters.title(at:in:)` with 0.01 s and empty title → nil. **Resolution:** S's function is the one rule. A writes its inline lookup (C does not exist yet); C's brief gains one step: replace A's inline lookup in `PlayerTransportBar.chrome` with `model.chapterTitle(at: target)`. Empty titles show nothing on the card; the Chapters tab uses `displayTitle` ("Chapter N").

**C4 (P2) Probe fields.** A appends `scrub= curve= frame= arb=`, S appends `chapters= aspect= frames=`. `frame` and `frames` on one line invite a wrong-key assertion. **Resolution:** S's count becomes `thumbs=` (`TransportBarModel.previewFrames` keeps its name or becomes `thumbCount`, B's choice). Field order is fixed in the table below; whoever runs later appends after the earlier fields, no rebase needed under C2.

**C5 (P2) Developer rows and description cases.** Both specs place their rows "after Exact Seek Delay (A/B)" and their description cases "after `:201`". **Resolution:** order in `detailScrollAndTrailerTuningRows`: Hold Step Interval, Hold Ramp Speed, Exact Seek Delay, Swipe Scrub Curve, Swipe Scrub Speed, Thumbnail Harvest, then the existing Trailer Letterbox toggle. Same order for the `SettingsDescriptionID` cases and the "Applies to the next playback." footnote arm (`:413`).

**C6 (P3) Card fill vs letterbox.** A draws the frame with `.aspectRatio(contentMode: .fill)`; S sizes 2.39:1 thumbnails at 320 × 134 and says "the card letterboxes". **Resolution:** `.fit` on a black card body, so the card shows the shot you will land on, uncropped.

**C7 (P3) Line drift.** S cites `MPVPlaybackState` at `:28-67`; it runs `:28-112`. Every other anchor checked (`handleSwipeDown`, `pressesBegan/Ended/Cancelled`, `apply`, `publishTransport`, `issueSeek`, `activatePill`, `destroyPlayer`, `drainEvents`, the libmpv helpers, `chipBottomInset`, `SeekProbeLabel`, `setResizeMode` in `PlayerSettingsRepository.kt:413`) is where the specs say.

## 2. Correctness against the code

**C8 (P2) Chapter mode: a hold after a click jumps back.** In chapter mode S routes P1's press-begin `.immediateSeek` to a chapter jump, but `TransportPreview` keeps stepping from the pre-click origin, so at 100 s a held Right jumps to 240 and then commits around 150 on release. S calls this "accepted"; it reads as a bug. **Resolution:** reuse P1's scan-armed path. A adds `var clickOnRelease = false` to `TransportPreview` (set before `pressBegan`, like `paused`): when true, `pressBegan` from idle returns `.none` and a release with `n == 0 && !moved` returns `.immediateSeek(±10)`, exactly as `scanArmed` does today (`:106`, `:148`); a hold steps from the origin with no jump first. Two unit tests in A's class. C sets it in `beginHold`: `transport.clickOnRelease = edgeClickMode == .chapter && state.transport.chapters.count >= 2`. Cost: a click acts on release (~100 ms later), only in chapter mode.

**C9 (P2) `player.aspectStretchLast` leaks across profiles.** The synced `resize_mode` is profile-scoped (`ProfileScopedKey.of`, `PlayerSettingsStorage.apple.kt:235`); the Stretch key is plain device-local. Profile A picks Stretch over Fit; profile B, also on Fit, opens in Stretch. **Resolution:** Stretch is session-only in P2: the pill cycles through it, nothing persists it, the next playback starts from the synced value. Drop the key, `initial(stretchOver:)` becomes `initial(syncedName:)`, and its tests shrink. Persisting Stretch per profile can come later if asked for.

**C10 (P2) Stretch mapping and runtime options.** `keepaspect` is a VO option; whether a runtime write re-lays out the frame on this build is unproven. **Resolution:** Stretch = `video-aspect-override` set to the drawable's ratio (`"16:9"` on every Apple TV), `keepaspect` untouched. That is a plain property with a known runtime path and stretches any source to the screen. Every mode then writes three properties (`video-aspect-override`, `panscan`, `video-zoom`); fit and fill and zoom write `"-1"` for the override. Keep `-1`: Android's mpv path writes `"no"`, which ignores container aspect and squashes anamorphic files; do not copy it.

**C11 (P3) Zoom differs from the phone.** The synced name is shared with mobile. Android's mpv engine maps Zoom to `panscan 0.5` (`PlayerEngine.android.kt:1179`); iOS mobile maps it to `panscan 1.0`. S's `video-zoom 0.15` also crops 16:9 sources that have no bars. **Resolution:** Zoom = `panscan 0.5`, `video-zoom 0`; it lands between Fit and Fill on scope films, as on Android. Swift sees the Kotlin cases as `.fit/.fill/.zoom` (lowercased bridging); build the enum from `.name` as S says, and map back with an explicit switch.

**C12 (P2) Wave-1 verification items, before the rest of B and C is built.**
- `mpv_command_ret` is in the bundled header (`Libmpv.framework/Headers/mpv/client.h:960`, client API 2.5, MPVKit 0.41.0). S's `withCommandResult` frees the node only after a successful status and copies `data` into `Data` before the free: correct, keep it.
- `screenshot-raw video bgr0`: the format argument is documented for mpv 0.41. First build logs one `[Harvest] took= size= fmt=` line on the simulator; if it fails, S's retry without the format is the fallback, and if the simulator VO cannot screenshot at all, `testHarvestGrows` becomes a device-only item (say so in B's report, do not loosen the oracle).
- `bgr0` → `noneSkipFirst | byteOrder32Little` is right (memory order B, G, R, X).
- `chapter-list` read as a string goes through the default GET_STRING path, which prints node values as JSON, the same path `demuxer-cache-state` proved on both devices. mpv's human-readable chapter list is the OSD print form, which `mpv_get_property_string` does not use. Keep the indexed fallback and log `[Chapters] n=5` once on the fixture.
- `video-aspect-override` with `"16:9"` and `"-1"` at runtime: a one-off probe on the simulator (the Stretch frame fills the screen).

**C13 (P2) Harvest can move `deinit` off main.** `startHarvest`'s `eventQueue` block holds `self` strongly for the length of `screenshot-raw` (tens of ms at 4K), then hands only weak references onward. If the viewer exits during that window, the block's release is the last one and `deinit` (timers, observers, `destroyPlayer`, `mpv_terminate_destroy`) runs on `eventQueue`. Existing blocks avoid this by ending in `DispatchQueue.main.async { self... }` with a strong capture (`refreshBufferedAsync`, `:1577`). **Resolution:** end the `eventQueue` block with `DispatchQueue.main.async { self.harvestCaptured(frame, at: sec) }` (strong), and do the scale and insert from there on a utility queue that carries only the frame and the store. The failure path does the same instead of `[weak self]`.

**C14 (P3) Pan, presses and the cover coexist.** With `allowedPressTypes = []` the pan never sees a press, so the press handlers and `pendingMenuAction` are untouched; the cover's Menu tap is press-only and stays gated; `require(toFail:)` adds no tap delay (both resolve at touch-up); `LightTapGuard` still covers the arbiter's `.lightTap`. No change.

**C15 (P3) Darwin inject.** The runner-to-app Darwin route is proven by `testLightTapFlipsEndTime`. The C callback cannot capture, so add the second `CFNotificationCenterAddObserver` with its own closure literal inside the same guarded `install()`, as A says. The script travels as a launch argument; `dx,dt[,dy]` with `;` is unambiguous, and a value that is not a valid old-style plist reaches `UserDefaults.string(forKey:)` as a string. Read it with `string(forKey:)` and nothing else.

**C16 (P3) Idle cancel and the hide timer.** While scrubbing, `TransportHideRule.mayHide` is false and a fired hide timer does nothing; the 8 s idle cancel ends the mode, the active → idle edge calls `flashControls()`, and the bar hides 4 s later. A brushed swipe with the bar hidden therefore costs 12 s of bar. Acceptable; note it for the device pass. UI legs must press Select within 8 s of the script's last sample; each probe read costs about a second, so keep leg 1 to the reads it lists.

## 3. Design risks

**C17 (P2) No frames while the finger moves.** `requestPreviewFrame` cancels and re-arms a 50 ms timer on every sample, a trailing debounce: during a steady swipe nothing is looked up until the finger pauses. **Resolution:** throttle, not debounce. At most one lookup in flight; start one when ≥ 66 ms have passed since the last start, and always run a trailing one after the last sample. The token guard stays.

**C18 (P2) The harvest blocks `eventQueue` and the core.** A 4K `screenshot-raw` is a GPU readback through MoltenVK plus a ~33 MB copy, run on the queue that drains events and issues seeks. A press during a harvest waits for it, and the VO may drop a frame. S defers any cap to the device pass. **Resolution, cheap and pure:** `HarvestScheduler.tick` gains `recentInput: Bool` (`now − lastClickUptime < 1.5`), which makes the tick ineligible; and `noteFinished(tookMs:)` triples the interval for the rest of the file when a harvest took over 60 ms (log it once). Both unit-tested. The device pass still records `took=` for 1080p and 4K.

**C19 (P3) Card sharpness.** A 320 px thumbnail drawn at 400 pt is 800 px on a 4K UI, a 2.5× upscale. Keep 320 for P2 (the memory numbers hold) and add a device-pass check; 480 px is the fallback (about 1.5× the bytes, still under the 6 MB cap at 200 entries if q stays 0.6).

**C20 (P3) HDR and Dolby Vision.** PQ/HLG frames may come back flat; a Dolby Vision profile 5 or 7 file kept on mpv may come back in the wrong colours. Device-pass item, as S says; add the DV case to it.

**C21 (P3) Eviction covers about 33 minutes.** Oldest-inserted eviction at 200 entries × 10 s drops the start of a long film. Fine for P2; P3's decoder fills gaps. Note it in the record.

**C22 (P3) 190 pt with a pill focused.** Orivio used 190 pt after its skip pill took focus, a different case. Keep A's rule (a long swipe still scrubs and clears pill focus) and put "swipe with a pill focused" on the device pass; the alternative is `.ignored`.

**C23 (P3) Video plays during a scrub (D1, approved) and the aspect pill writes the synced value** (the phone changes too). Both are product calls already made; the release notes must say the second.

## 4. Test gaps

**C24 (P2) Chapter legs cannot pick the fixture.** `launch(extra:)` hardcodes `-debug.mpvSmokeURL` from `PLAYER_SMOKE_URL` (`PlayerTransportUITests.swift:12-32`); passing a second `-debug.mpvSmokeURL` in `extra` leaves which one wins undefined. **Resolution:** `launch(url: String? = nil, extra:)`; chapter legs pass `PLAYER_SMOKE_CHAPTERS_URL` and skip when it is unset.

**C25 (P2) Layout test edits.** `testPillVisibilityAndTabs` has four `visible` expectations (`:113-120`), not three: all four gain `.aspect` after `.speed`; add `XCTAssertEqual(PillKind.aspect.panelTab, .playback)`. `PillKind.panelTab`, `symbol` and `title` are exhaustive switches; `PlayerPanelTab.title` needs `.chapters`. `pills >= 4` in `testBarGeometryProbe` still holds (it asserts a floor; the rig's count depends on `onPlayNext`, so S's "6 pills" is not guaranteed).

**C26 (P2) The scrub Menu leg must assert for real.** `requirePlayerStillPresented` wraps the check in `XCTExpectFailure`; after `0c10ca4a4` the cover no longer dismisses. `testScrubMenuCancels` asserts `player.mpv` exists directly and does not call that helper.

**C27 (P3) Missing unit cases.** Add: `clickOnRelease` press/release/hold (C8); scheduler `recentInput` and the slow-harvest backoff (C18); "a due seek harvest waits for the next eligible tick" (in S's text, not its list); the frame-request throttle as a pure helper (C17); `PlayerAspectMode` props after C10/C11. All remain pure.

**C28 (P3) The aspect leg changes the profile's resize mode.** The leg must read the starting `aspect=` and cycle back to it before ending, and fail with that in the message if it cannot; with C9 there is no Stretch key to clean.

**C29 (P3) `testHarvestGrows` needs the simulator VO to screenshot** (C12). If it cannot, record it as device-only rather than weakening `thumbs>=2`.

## 5. Prose and keys

**C30 (P3) Copy.** Scrub curve: "Auto moves it at a steady rate that scales with the video's length" (not "film's"); "playhead" reads as jargon in Settings, prefer "the position". Edge click: Left goes back to the start of the current chapter, or the previous one within 3 s of a start; the text says "previous chapter". Suggested: "Choose what one click on Left or Right does in the mpv player. Skip 10 s jumps ten seconds. Previous/Next Chapter jumps to the next chapter, or back to the start of this one, when the video has chapters, and skips 10 seconds when it does not. Default: Skip 10 s." Run the new strings through the deslop lint with the batch.

**C31 (P3) Keys.** No collisions: `player.edgeClickMode`, `debug.scrubCurve`, `debug.scrubRateScale`, `debug.harvestIntervalSec`, `debug.scrubInject` appear nowhere in the clone or `shared/`. In the catalog, "Off", "Auto", "30 s", "Faster" and "Slower" exist; "Fit", "Fill", "Zoom", "Stretch", "Aspect", "Chapters", "Chapter %lld", "Flick", "Seek Previews", "Left/Right Click", "Skip 10 s", "Previous/Next Chapter" are new. Write the harvest labels as `String(localized: "\(seconds) s")` (the existing `%lld s` key) instead of new "5 s" / "30 s" literals. Hold Ramp 0.5 = Faster and Scrub Speed 0.5 = Slower is correct (time scale vs distance scale).

## Reconciled contract

| Item | Owner | Contract |
|---|---|---|
| `SeekPreviewSource` | A (`TransportBarModel.swift`) | `protocol SeekPreviewSource: AnyObject, Sendable { func thumbnail(near sec: Double) async -> CGImage? }` |
| `SeekPreviewStore` | B (`Screens/Player/SeekPreviewStore.swift`) | actor; `insert(_:at:)`, `thumbnail(near:tolerance:)` plus the one-argument overload; conforms to `SeekPreviewSource` |
| Store references | B | controller `private var previewStore: SeekPreviewStore?` (strong); A's controller `var seekPreviewSource: SeekPreviewSource?`, assigned by B in `viewDidLoad`; no `state.previewStore` |
| `TransportBarModel` | A, then B, then C | A: `previewFrame: CGImage?`, `scrubCurveCode`, DEBUG `debugArbiter`; B: `previewFrames: Int`; C: `aspectMode`, `aspectFlash`, `chapterTitle(at:)`, `PillKind.aspect` after `.speed` |
| `MPVPlaybackState` | A, then B, then C | A: `scrubCardUp`; B: `previewStoreSummary`; C: `seekToChapter` |
| `TransportPreview` | A only | scrub API per A §2, `Output.cancelUpNext`, `commitRequest(target:)`, and `clickOnRelease` (C8) |
| Chapter rule | C (`PlayerChapters.swift`) | `title(at:in:)`, 0.01 s, empty → nil; C swaps A's inline card lookup for it |
| Card frame | A | `.fit` on a black body, 400 × 225, 30 pt above the active track |
| Aspect | C | fit/fill/zoom/stretch; override `-1`/`-1`/`-1`/`"16:9"`, panscan 0/1/0.5/0, video-zoom 0; Stretch session-only, never persisted |
| User keys | | `player.holdMode` (exists); `player.edgeClickMode` = `skip10` (default) / `chapter` (C); no `player.aspectStretchLast` |
| Debug keys | | `debug.scrubCurve` "" / "bobsupra"; `debug.scrubRateScale` Double, 0 = Auto; `debug.harvestIntervalSec` Int, 0 = Auto (10), -1 = Off, 5, 30; `debug.scrubInject` launch arg only, no row |
| Bar probe (appended after `pills=`) | A, B, C | ` scrub=<%.1f|nil> curve=<o|b> frame=<0|1> arb=<u|h|v|i> chapters=<n> aspect=<fit|fill|zoom|stretch> thumbs=<n>` |
| Seek probe | A, C | A: ` scrubs=<n>`; C's chapter seek uses `note(commit:stages:"ch")` (bumps `commits`) |
| Logs | | `[Scrub] begin/commit/cancel/stroke end`, `[Harvest] took= size= fmt= at=`, `[Chapters] n= raw=` (DEBUG, `NSLog`) |
| Developer rows | A, B | Hold Step Interval, Hold Ramp Speed, Exact Seek Delay, Swipe Scrub Curve, Swipe Scrub Speed, Thumbnail Harvest, then the existing Trailer Letterbox toggle |
| Settings row | C | Settings › Playback, after Hold Left/Right: "Left/Right Click" |

**Run order: sequential, one agent at a time, same clone and branch `claude/player-p2`.**

1. **Agent A** (spec A plus C3's inline lookup, C6, C8's `clickOnRelease`, C15, C16, C17, C26). Files and `MPVPlayerView.swift` regions as in A §9: `MPVPlaybackState.scrubCardUp`, fields, `init`, `viewDidLoad` recognisers + DEBUG observers, `handleSwipeDown`/`performLightTap`, `pressesBegan`, `apply`/`publishTransport`, scrub methods by `beginHold`, `destroyPlayer` (inject observer), `chipBottomInset`, the delegate extension. Gates: its unit classes, legs 1 to 5, P1's six regression legs, Debug + Release.
2. **Agent B** (store, harvest, C1, C4's `thumbs=`, C12's first-build checks, C13, C18). `MPVPlayerView.swift`: store/harvest fields, `viewDidLoad` store creation and `seekPreviewSource` assignment, `refreshState` tick, the PLAYBACK_RESTART landing hook, the harvest MARK section, `withCommandResult`/`screenshotRaw`, `destroyPlayer` nils. Leg 5 (`testHarvestGrows`); A's legs 1 and 2 re-run to see `frame=1` once played ground is scrubbed.
3. **Agent C** (chapters, aspect, settings, C3's swap, C8's wiring, C9, C10, C11, C24, C25, C28). `MPVPlayerView.swift`: FILE_LOADED chapter read, `viewDidLoad` (`seekToChapter`, `edgeClickMode`), `apply`'s `.immediateSeek` → `edgeClick`, `beginHold`'s `clickOnRelease` line, `onFileLoaded` aspect, `applyAspect`/`cycleAspect`, `activatePill`, the flash in `MPVPlayerScreen`. Legs 1 to 4, then everything once more and the Release build.

Then Opus review rounds over `0c10ca4a4..tip` (Codex is out until 10-29), then the device pass in the Test profile.

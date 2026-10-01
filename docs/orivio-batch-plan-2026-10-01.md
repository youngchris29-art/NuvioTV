# Orivio batch (rc15) — plan record, 2026-10-01

Approved plan: `~/.claude/plans/structured-humming-rain.md` (Christian approved 2026-10-01 after the four scoping answers). Source comparison: `docs/orivio-feature-comparison-2026-10-01.md`; reference: `docs/research/orivio-tv-handoff.md`.

**Scope (the five Build-next items):** (1) Auto-Play Best Source on first play + hold-Play "Choose Source…" + Settings toggle with a Cached Sources Only sub-toggle, off by default; (2) next-link failover (auto flows advance silently, manual picks alert with Try Next Source) + 8 h rejected-link memory; (3) hold menu on catalog posters (Library / Watched) and Continue Watching cards (Play Manually / Go to Details / Mark Episode Watched / Start Over / Remove); (4) Sources filters (sort, minimum resolution, Dolby Vision, HDR, Cached Sources Only) applied to every add-on on tvOS; (5) Infuse x-callback return path recording watch progress.

**Shape:** submodule branch `claude/orivio-batch` off `tvos-shared-extraction` `4f26c0d4` (rc14 bump); delegated waves (K1 → K2 ∥ K3; S1 ∥ S2 ∥ S4 → S3 ∥ S5 → S6), internal Opus review rounds until clean; cut as **build 132 / `tvos-v0.3.0-beta.18-rc15`** on Christian's go after Steven's rc14 verdict.

## Evidence

See the "Verified facts" section of the plan file. The three Explore reports and the Opus critique (3 P1 / 10 P2 / 5 P3, all folded in) were run 2026-10-01.

## Prep

| Step | Result |
|---|---|
| Branch | `claude/orivio-batch` created off `4f26c0d4` (2026-10-01) |
| Upstream `99ced26a` reachable | yes (`feat(player): add Infuse playback callbacks`, 2026-09-18, 17 files; its platform file is composeApp's `ExternalPlayerPlatform.ios.kt`, the fork's is `shared/appleMain/.../ExternalPlayerPlatform.apple.kt`) |
| Baseline gates | Kotlin 1291 / 1309 / 432 (batch 10 tip, shared tree unchanged since); NuvioTVTests 441, Debug + Release sim green (rc14) |
| P0 probe: `.contextMenu` on the prominent Play button and on catalog cards (borderless / ring / still, Small / Medium) | Run 1 (02:36, `test71a`/`test71b`, FA87): **cards PASS** — a 2 s Select opened the Continue Watching card's menu in borderless, ring and still styles (the walk met the CW row before a catalog poster; Library tiles on the same style chain were device-confirmed earlier). **Play button: not yet tested** — Detail's initial focus sat on Mark Watched (second button), so the hold toggled it (restored in run 2). Side finding: with the Play gate (`972109f9`) resolving after the page appears, initial focus skips Play. Run 2 (03:56, with sub-wave A compiled in): initial focus landed on Play this time, so the "restore Watched" short press opened the picker before the hold — still no Play-button answer; initial focus is non-deterministic on this runtime. Run 3 uses Left×3 first. The UI-test xcodebuild hung after the suite in run 1 (known class); result bundles unfinalized, PNGs recovered by signature. |

## Waves

| Agent | Tier | Status | Commit |
|---|---|---|---|
| K1 PlayerSettings `streamAutoPlayCachedOnly` + registry entries | Sonnet | done 02:40 (sync signature needs no change: data-class `toString()`; 6 tests in `StreamAutoPlayCachedOnlySettingsTest`) | _gate K pending_ |
| K2 Sources filters shared half (`allStreams`, `streamCachedOnly`, plugin merge in both repositories) | Sonnet | done 02:55 (+ follow-up for `PlayerStreamsRepository`'s plugin hunk; 19 tests in `DebridStreamPresentationAllStreamsTest` + `DebridStreamCachedOnlySettingsTest`; judgment: Cached-only drops plain add-on links incl. server-side-debrid direct URLs and plugin streams — opt-in, documented in the toggle footer) | _gate K pending_ |
| K3 external-playback port + `invalidate` + bridging twins | Opus | done 03:00 (`features/player/external/*`, 21 tests; `handleUrl` is non-suspend; Swift call site `StreamPickerView.swift:684` patched by the main session with the two nil callback args until S1) | _gate K pending_ |
| S1 picker auto-play + failover + rejected links | Opus | done 04:10 (`FirstPlayAutoPlay.swift` controller + overlay, `RejectedStreamLinks.swift`, `PlaybackFailoverPolicy`, `PlaybackStreamKey`, Infuse session wiring in `openExternally`; 46 tests across 3 files; 16 judgment calls incl. a 40 s search deadline, built-in player only for auto-start, MissingApiKey/Stale never rejected, Start Over once per visit; 8 new string keys for S6) | _gate S-A pending_ |
| S2 engine failure/healthy signals + start watchdog | Sonnet | done 03:52 (one-shot `reportPlaybackFailure` on mpv with the four paths; `onFallback` now (position, secondsPlayed); 12 `MPVStartWatchdogTests`; judgment: Start Over skipped on mpv after a native fallback that had played) | _gate S-A pending_ |
| S4 hold menus | Sonnet | done 03:58 (`TitleHoldMenu.swift` + 5 catalog sites + CW row with 4 new closures; `revision` bump re-resolves the menu after an action; 13 `TitleHoldMenuPolicyTests`; device check owed: label freshness after a Detail toggle; 8 new string keys for S6) | _gate S-A pending_ |
| S3 Detail hold-Play + Settings sections | Sonnet | done 04:02 (`HoldPlayChooseSourceMenu` on both Play buttons, attached only while the mode is FIRST_STREAM; `SeriesPlayRoute.forceManual`; Settings "Auto-Play Source" + "Sources" sections; debrid filter values on `SettingsViewModel` with their own watcher rather than `DebridViewModel`; probe code removed) | _gate S-B pending_ |
| S5 deep-link callback + scheme | Sonnet | done 03:59 (`ExternalPlaybackReturnRouter` in `ExternalPlaybackReturn.swift`, callbacks routed before `DeepLink.parse` and deferred until the profile gate; 15 `DeepLinkTests`). The `Info.plist` second scheme `$(PRODUCT_BUNDLE_IDENTIFIER)` was refused by the subagent's safety check and applied by the main session (`plutil -lint` OK) | _gate S-B pending_ |
| S6 strings + UI legs | Sonnet | done 04:12 (35 English-only keys appended, 5 already present, catalog 979 → 1014 keys; legs `test71HoldMenuOnCatalogPoster`, `test72AutoPlayFirstPlayAndHoldPlay` (mode via `-stream_auto_play_mode_2 FIRST_STREAM`, Left×3 before the hold), `test73ExternalCallbackDeepLink`) | _gate S-B pending_ |

## OUTCOME

_filled per wave_

## Review rounds

**Round 1 (Opus, read-only, 04:10–04:25, tree = K wave committed + Swift wave uncommitted):** VERDICT 13 findings (P1 0, P2 3, P3 10). Clean on the brief's main traps (no double reports, no re-arm, no same-runloop alert, no id collisions, no deep-link cover clobbering, no tokenised URL in external-playback logs; persistence symmetric; mobile unaffected).

| # | Sev | Finding | Decision |
|---|---|---|---|
| 1 | P2 | Auto-play always opens the built-in player even when a default external player (Infuse) is set | FIX (F1): first non-failover auto play hands off externally; failover walks stay built-in |
| 2 | P2 | Hold-menu actions are toggles; a stale label (async series mark, external change) can do the opposite of what it says | FIX (F3): explicit save/remove + mark/unmark from the state captured at build; bump `revision` after the async write |
| 3 | P2 | Detail Play button changes view identity one runloop after appearing (`if isOn { .contextMenu }` + async watcher), risking initial focus | FIX (F3): seed from `uiState.value_` synchronously, always attach the modifier with a conditional body, gate on `isPlayEnabled` |
| 4 | P3 | Early-EOF rule can strand the player (no `isEnded` when the report returns false) or fail a finished episode with an over-long declared duration | FIX (F2): fall through to `isEnded` when the report returns false; manual + ≥300 s = normal end |
| 5 | P3 | Presenting the post-play cover runs `viewWillDisappear` → `closeFailover()` permanently | FIX (F2): close only on dismissal/removal |
| 6 | P3 | `secondsPlayed` is wall-clock (pause/stall count toward the 300 s "healthy" clear) | FIX (F2): `PlaybackHealthClock` accumulates only while playing |
| 7 | P3 | `addonId|host+path` stream keys can embed Torrentio-style debrid API keys in storage and logs | FIX (F1): SHA-256 digest of host+path; logs print keys only |
| 8 | P3 | No feedback during a playback failover (overlay suppressed under the player cover) | DECLINED for this batch: an in-player chip is new UI; logged as a follow-up (the dead player stays up to 20 s per resolve) |
| 9 | P3 | Infuse return parsing rejects fractional `position` and compares `lastPlayedUrl` after `+`-decoding | FIX (F4): `toDoubleOrNull`, normalised compare + tests |
| 10 | P3 | Plugin streams re-presented on every scraper completion | FIX (F4): present from the raw merged list |
| 11 | P3 | `watchedItemFromProgress` stamps the last progress-save time as `markedAt` | FIX (F4 + F3): explicit `markedAtEpochMs` parameter; the CW menu passes now |
| 12 | P3 | Device risks not handled in code: 180 pt Entity Browse mini posters under the ~200 pt menu floor; Trailers on Focus dwell may cancel the hold | DEVICE CHECKLIST (already listed); decision recorded after the pass |
| 13 | P3 | Test gaps: resolver `invalidate`, Start Over override, bundle-id scheme through Ktor, picker latch/ordering (view-bound) | FIX (F1/F4) the first three; picker-state extraction DECLINED (scope) |

**Round 2 (Opus, read-only, 04:55–05:10, all 13 commits):** VERDICT 8 findings (P1 0, P2 0, P3 8); every round-1 P2 confirmed closed in the code; the fix commits add no regressions; the new races (polling restart, parent-chain walk, revision-bump Task, external auto handoff + dismiss, raw plugin maps) are guarded.

| # | Sev | Finding | Decision |
|---|---|---|---|
| 1 | P3 | `nativeFailedBeforeStart = secondsPlayed <= 0` drifted once the play clock replaced wall time (a mid-play native fallback inside the first tick reads 0) | FIXED (main session): `onFallback` carries `startedPlaying = readyUptime != nil` |
| 2 | P3 | Replay after the post-play card restarted polling only; the scrobble and display mode stayed torn down (pre-existing teardown in `viewDidDisappear`) | FIXED (main session): the restart branch re-applies display criteria and restarts the Trakt scrobble when a file is loaded; the exit teardown is unchanged |
| 3 | P3 | `isLeavingPlayer` parent-chain walk unproven on hardware | DEVICE CHECKLIST: `[Failover] viewWillDisappear isLeavingPlayer=` printed; must be true on Menu exit, false under the card |
| 4 | P3 | Hold-menu `revision` bump at 400 ms can precede a slow tracker write; a stale tap is a silent no-op | FOLLOW-UP (correct outcome, no feedback) |
| 5 | P3 | `sameSourceUrl` folded only `+`/`%2B`/`%20` | FIXED (main session): full `decodeURLQueryComponent(plusIsSpace)` on both sides + `+`→space fold; `%5B`/`%28` test added |
| 6 | P3 | `markedAtEpochMs` comments claimed a stamp the repository restamps anyway | FIXED: comments corrected (parameter kept, harmless) |
| 7 | P3 | Play now always carries a `.contextMenu` (empty body with auto-play off) | DEVICE CHECKLIST: long press shows nothing and does not swallow the press; a normal press fires once |
| 8 | P3 | Test gaps: guard-run behaviour, refused-report fallthrough, polling restart, `isLeavingPlayer` | DEVICE CHECKLIST / accepted |

Fix round 1 landed 04:35–04:55 (F1 Opus, F2/F3/F4 Sonnet). Extra decisions from the fixers: stream keys digest BOTH halves (`<8-hex add-on tag>|<32-hex host+path digest>`) because `addonId` carries the manifest URL, which for a configured Torrentio contains the debrid key; the library hold action stays `toggleSaved` (the only call that routes to Trakt/Simkl) behind a label-still-current guard; `debridResolveCacheKey` made `internal` for its tests; `PlaybackHealthClock` caps each span at 5 s so a suspended app cannot credit minutes. **Follow-ups logged, not in this batch:** (a) an in-player "Trying another source" chip during playback failover; (b) old-format keys in `tvos_rejected_stream_links_v1` on dev boxes expire naturally (8 h); (c) pre-existing, upstream-parity exposure: `PlaybackProgressRecorder.playbackSession` syncs the full `lastSourceUrl` (a Torrentio-with-debrid link carries the API key) to the server — upstream-report candidate; (d) after Replay from the post-play card the Trakt scrobble is not restarted (pre-existing).

## Gates

| Gate | When | Result |
|---|---|---|
| K (after K1–K3) | 2026-10-01 03:35 | `:shared:jvmTest` 1337 / `:shared:tvosSimulatorArm64Test` 1355 / `:composeApp:iosSimulatorArm64Test` 432, 0 failures (baseline 1291 / 1309 / 432; +46 = the new K1/K2/K3 tests). BUILD SUCCESSFUL in 22m51s. Commits K1 → K2 → K3 on `claude/orivio-batch`. |
| S-A (sub-wave A + the `AppCallbackScheme` stub) | 2026-10-01 03:56–03:58 | Debug sim build green with S1/S2/S4 (first real compile of all three, zero Swift errors); `NuvioTVTests` 516 / 0 failures (baseline 441); Release build green (04:08, tree already carrying S3/S5). Probe run 2 inconclusive (see Prep). Review round 1 (Opus, read-only) started 04:10 on this tree. |
| S-B (full tree incl. S3/S5/S6) | 2026-10-01 04:10–04:28 | UI legs on FA87: `test71HoldMenuOnCatalogPoster` PASS (catalog menu "Add to Library" opened; CW menu seen too), `test72AutoPlayFirstPlayAndHoldPlay` PASS (first-play overlay shown, outcome `list`; **hold on the prominent Play button opened "Choose Source…"** — P0 answered yes on the simulator; the list opened without the overlay), `test73ExternalCallbackDeepLink` PASS; `NuvioTVTests` 531 / 0 (baseline 441); Release build green. Six per-agent commits `68353f42` → `eac0df04`. |
| K round 2 (after F4) | 04:28–04:43 | jvm 1351 / tvOS-native 1369 / composeApp 432, 0 failures (+14 fix-round tests). Commit `9642a45c`. |
| S-C (after F1/F2/F3) | 04:44–05:05 | UI legs test71/72/73 PASS on FA87 (first-play outcome still `list`; hold-Play menu opened); `NuvioTVTests` 565 / 0 (+34 fix-round tests); Release green. Fix commits F2 → F1 → F3 on the branch. |
| K round 3 + S-D (after the review-round-2 fixes) | 05:20–05:50 | jvm 1352 / tvOS-native 1370 / composeApp 432, 0 failures (+1 Infuse decode test); Release build green on the round-2 Swift fixes. `xcodebuild test` (UI legs + `NuvioTVTests`) came back sandboxed (exit 70, sleep assertion) twice in a row despite the sandbox-off flag — the unit suite's last green run is S-C's 565 on the pre-round-2 tree; the round-2 Swift changes touch `PlayerScreen` / `NativePlayerScreen` / `MPVPlayerView` lifecycle code that no unit test exercises. Retries: `xcodebuild test` (exit 70 again), then `build-for-testing` (**TEST BUILD SUCCEEDED** — the round-2 Swift changes compile in Debug with the test target) + `test-without-building` (exit 70, same sleep assertion). The unit suite and UI legs therefore need a run from an interactive terminal before the device pass: `cd NuvioMobile/iosApp && xcodebuild test -project iosApp.xcodeproj -scheme NuvioTVTests -configuration Debug -destination 'platform=tvOS Simulator,id=FA87E9B6-F28D-4DF9-84E4-A5A4C5DBFC4E' -derivedDataPath build/DerivedData` (expect ≥ 565) and the same with `-scheme NuvioTVUITests -derivedDataPath build/DerivedDataUITests -only-testing:NuvioTVUITests/NuvioTVUITests/test71HoldMenuOnCatalogPoster -only-testing:…/test72AutoPlayFirstPlayAndHoldPlay -only-testing:…/test73ExternalCallbackDeepLink`. Commit `83cc5996` (review-round-2 fixes) is the branch tip; 14 commits, local only. |

## Device checklist

See the plan file's "Device pass" section. **Device pass run 2026-10-01 10:50–11:20 on the Living Room Apple TV 4K (3rd gen), dev build `com.youngchris29.NuvioTV` build 131 from tip `83cc5996`, console streamed over `devicectl --console` (`scratchpad/device-console.log`), Christian driving in three blocks.**

Console-proven (timestamps from the stream):
- Start Over from the Continue Watching menu: `[Failover] start over: ignoring saved progress`.
- Auto-Play Best Source, movie `tt33071426`: armed 11:05:17 → 22 candidates, all eligible, 0 rejected at the 3 s settle → pick #1 resolved in 1.2 s → playing. Series `tt27444205:1:1`: 34 candidates → playing in 4 s.
- Menu on the overlay: `cancelled (Menu on the overlay) in searching after 0 attempt(s)` (twice, 11:06:54 and 11:09:40).
- Continue Watching card with auto-play on: re-armed and played the same episode from the resolve cache in 3 s.
- Default external player + auto-play: `tt29485142:1:1` → 1 candidate → `attempt #1 to external player infuse`; the Infuse `x-success` callback came back on the per-install scheme and was consumed at 11:11:57 (`[ExtReturn] consumed /infuse/<id>/success`); a second hand-off (manual pick via Choose Source…) consumed at 11:13:24.
- mpv leg (native player off): `mpv start watchdog armed: 25 s`, no failure fired, and the Menu exit printed `viewWillDisappear isLeavingPlayer=true` (round-2 #3 probe: true on a real exit).
- No `[HoldMenu]` guard skips, no failover reports, no crash or fatal lines across ~1,500 console lines.

Christian's observations (no console trace by design): **blocks A, B and C all good** — hold menu opens in ring, No Zoom and Small-poster styles; the empty hold on Play with auto-play off is inert; Try Next Source, the Sources filters, Choose Source…, Cached Sources Only → list, and the Continue Watching card after the Infuse return all behaved. Block D (Steven-config smoke walk) skipped at his call. **One finding (BUG-125; the record and the previous commit message said BUG-124, which is Steven's Detail-scrim row):** with Trailers on Focus ON, the hold menu works on a poster until it morphs into the landscape trailer card; once the inline trailer is playing, the long press no longer brings up the menu. Trailers on Focus is off by default, and a hold before the 1 s dwell still works. **FIXED the same morning (11:20–11:36): a two-line device probe showed the hold on the playing card never reached the menu body while a plain poster's did; tvOS hit-tests the context menu and the morphed label had nothing hit-testable (base poster at opacity 0, tile non-hit-testable). `.contentShape(Rectangle())` on the morphing label; Christian's hold on the playing card then built the menu and his pick worked. Commit on the branch after `83cc5996`; the `[HoldMenu] menu built` trace line stays.**

## Cut

_pending Steven's rc14 verdict_

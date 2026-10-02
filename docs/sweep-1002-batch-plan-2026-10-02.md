# Morning-sweep batch, 2026-10-02: BUG-128, FEAT-49, CHAT-3, stranded branch

Plan: `~/.claude/plans/give-me-a-plan-vivid-dove.md` (approved 2026-10-02). Source: the 2026-10-02 morning beta-feedback sweep (origin/main `d870932`), beta.18's first field report from u/an_angry_Moose (`pdbtv5r`).

## Christian's calls (asked before the plan was written)

- FEAT-49 pre-fetched sources: Tier 1 + 1b now; Tier 2 (Detail-page list warmup) after a device measurement; no Tier 3.
- BUG-128 glitchy auto-play trailers: instrument, ship hardening behind A/B knobs, draft a public follow-up question.
- Upstream #2150 (`f0f980b3`): adopt. A dismissed up-next card re-arms autoplay once at true end of file.
- Stranded branch `claude/reddit-thread-response-sb07px`: archive the draft on `main`, delete the branch.

## Outer repo (main)

| Commit | What |
|---|---|
| `1c722e3` | merge of the sweep's self-merges into local main (the other live session had committed the upstream-check paragraph as `e9139d0`) |
| `c6c8d12` | `docs/research/source-prefetch-feasibility-2026-10-02.md` committed, with its line-86 claim corrected: tvOS syncs under its own `tvos` namespace, a phone-set preparer limit never reaches it |
| `90f505b` | `docs/comms-reddit-1wbmlhe-reply.md` archived (NOT POSTED, r/Nuvio bars fork promotion since 09-27); `origin/claude/reddit-thread-response-sb07px` deleted |
| `65b57e8` | `docs/comms-reddit-chat3-reply-2026-10-02.md` + `docs/comms-reddit-bug128-followup-2026-10-02.md` (both 5/5, cleanse skipped: Codex limit); `INSTALL.md` line 7 no longer claims Apple TV HD; tracker rows BUG-128 / FEAT-49 / CHAT-3 and the §6 branch line |

Both Reddit drafts await Christian's post.

## Submodule branch `claude/sweep-1002-batch` (off `tvos-shared-extraction` @ `3f377cd8`)

| Commit | Wave | What |
|---|---|---|
| `06e05eca` | K1 (Sonnet) | `preloadNextEpisodeSources` player setting in the FEAT-48 shape (repository, expect/actuals apple/android/jvm, sync export/import under the `tvos` blob, `AccountDataStores` wipe entry), 6 commonTest tests |
| `73fc42db` | S1 (Opus) + S2 (Sonnet) | `NextEpisodeAutoPlay.swift`: `NextEpisodeTriggerPolicy` (pure; the old `onProgress` math verbatim), `Hooks` seam, `TriggerSettings`, preload branch at `max(timeout, 30) s` before the card threshold (streams only, no subtitle prefetch, never while the in-player source list owns the shared flow; re-issued after the mpv panel closes), placeholder-duration guard, the #2150 rider (`dismissedByUser` + `rearmedAtEnd`, no re-arm from Still Watching or when the dismissal already happened at EOF, `jumpToEpisode` disables it for the session), 15 engine tests. Settings → Playback → "Next Episode" section (toggle, off); Account Services → Debrid → "Prepare Links for Instant Playback" 0–5 (Tier 1b; the shared key, sync and wipe entry already existed, nothing in Kotlin) with upstream's rate-limit warning as a caption |
| `932a42e2` | T1-A/B/C + T2-A/B/C (Sonnet) | `TrailerHealthProbe.swift`: `TrailerPlaybackHealthMonitor` (KVO only: `timeControlStatus` waits with reason, `currentItem` re-registration for `AVPlayerLooper` copies, buffer-empty, keep-up, `AVPlayerItemPlaybackStalled`; access/error log on stop), `[TrailerHealth]` console summary + ≤110-char `health …` pane line through `TrailerZoomProbe.log`; surface tags `detail-bg` / `detail-full` / `home-hero` / `inline`; `TrailerLocalHLS.TrackSummary` + `fps` on `TrailerAdaptiveTrack`; `[TrailerRepack] serving … fps= itag= n=`; BUG-41 `hitches=` line in the pane; `TrailerTuning` launch-latched knobs (`debug.trailerBufferSeconds`, `debug.trailerMaxFps`, `debug.trailerLetterboxProbeOff`, `debug.trailerLadder` reserved) + About rows; `TrailerExtractionPreferences.maxVideoFps` makes 60 fps rank below same-height ≤30 fps when set (a preference, not a cap); forward-buffer applied to looper item copies via a `currentItem` observation only when set; probe-off branch after the full-screen policy return. 7 + 4 Swift tests, 5 Kotlin tests |

Facts established on the way (worth more than the diff):
- `PlayerStreamsRepository.fetchStreams` dedupes BEFORE resetting state, so a repeat `loadEpisodeStreams(forceRefresh:false)` on the same key is a true no-op; no Kotlin change was needed for the preload.
- `loadEpisodeStreams` already runs the debrid preparer after the fan-out, so Tier 1 + Tier 1b together pre-resolve the top N cached candidates ~30 s early through the existing 6/min / 30/h budget.
- tvOS had no next-episode settings rows at all; the auto-play timeout is always its default 3 here, so the 30 s floor is effectively constant.
- tvOS never reads `streamAutoPlayNextEpisodeEnabled`; gating the rider on it (as upstream does) would have made it dead.
- The only auto-play trailer surface ON by default in beta.18 is the Detail page; Home inline/hero default OFF.
- `TrailerZoomProbe.log` already prints a `[TrailerZoom]` console copy when `debug.trailerProbe` is on, so per-event health lines appear under that prefix on the console and only the final summary under `[TrailerHealth]`; the repro grep is `TrailerHealth|TrailerZoom\] (wait|stall|keepup|health|probe-off)|TrailerRepack\] serving|BUG41`.

## Gates

| Gate | Result |
|---|---|
| `:shared:jvmTest` / `:shared:tvosSimulatorArm64Test` | 1368 / 1386, 0 failures (baseline 1357 / 1375) |
| `NuvioTVTests` (Debug, FA87) | 645 / 0 (baseline 620) |
| Debug + Release simulator builds | green |
| UI legs on FA87 | `TrailerSoakTests.testColdStoreFirstDwellRevealProfile` PASS (131 s, screenshot-scan oracle); `test51TrailerBridgeAutoPlay` failed its fixture precondition ("hero CTA not on screen", the known fixture state noted on 10-02: the hero-CTA path stays on Home, test33 is the leg that opens a Detail) and then soft-skipped on no resolvable trailer; environmental, not a branch regression |
| Review (Opus read-only, Codex on its limit) | r1 over `3f377cd8..932a42e2`: 0 P1 / 1 P2 / 10 P3. Fixed: P2 looper-copy access-log fold, #2 `!resolvingNext` re-arm guard, #3 only a live card's dismissal counts, #5 `preloaded` reset in `tearDownSearch`, #7 monitor `nonisolated`, #8 hitch snapshot reset, #9 non-finite knob values, #10 next-launch subtitles, #11 `Hooks.searchBegan` seam + 2 engine tests. Declined: #4 (device item 8 below), #6 preload staleness (matches upstream's dedupe; follow-up). r2 over the fix diff: 0 P1 / 1 P2 / 4 P3, all fixed: per-item access-log baseline (the looper recycles replica items whose logs keep old events), pause discards an open wait, deferred hitch reset, negative knob values, test-comment honesty. Post-fix: NuvioTVTests 650 / 0, Release green |

## Merge + cut (2026-10-02, after Christian's device pass PASSED)

`tvos-shared-extraction` fast-forwarded `3f377cd8` → `2060e8fe` (4 commits), pushed, `claude/sweep-1002-batch` deleted local + origin; build bump `5f2d5cd3` (Version.xcconfig 132 → 133), tag `tvos-v0.3.0-beta.19-rc1`, branch + tag pushed; outer pointer `11a6011`. Unsigned Release device build stamped `NuvioBetaTag=tvos-v0.3.0-beta.19-rc1 NuvioCommitSHA=5f2d5cd3`, IPA 27,601,572 B (sha256 `2f47c7f0f6ad8535…`, copy `~/Downloads/NuvioTV-beta19-rc1.ipa`). Hosting: litterbox returned HTTP 500 on six attempts and catbox stored a 0-byte object (its hash dedup), so the IPA is at https://filebin.net/nuviotv-beta19-rc1-bf1ed601/NuvioTV-beta19-rc1.ipa (expires 2026-10-09T17:01Z; the bin's JSON listing is the size oracle, a HEAD on the file URL answers with a 146-byte page) with https://gofile.io/d/fgzqIy9C as backup, both verified at the full size. Steven's DM drafted 5/5 (`docs/comms-dm-drafts-2026-10-02-beta19-rc1.md`): every new setting with its default, the labelled Tab Bar pane ask, and the line that the detail-view redesign request (FEAT-35) is being looked into; **SENT 2026-10-02 1:30 PM ET** on his go (one bubble, verified).

## Owed

- Device pass PASSED 2026-10-02 (Christian). Still worth a look on his next session: review item #4: when the episode ends with the post-play cover already up and a dismissed card re-arms, confirm a second Menu does not leave a frozen last frame; BUG-128 legs L0–L3 with the probes armed; note the per-event health lines print under `[TrailerZoom]`, only the end summary under `[TrailerHealth]`), Merge + cut + DM DONE (above); Steven's beta.19-rc1 verdict owed (labelled Tab Bar panes).
- Post the two Reddit drafts.
- Follow-up (review r1 #6): a preload that ended empty or sat through a long pause is replayed by the dedupe at the threshold; consider `forceRefresh` when the preload ended empty or is older than N minutes.
- Pre-existing, out of this batch (review r1): opening the mpv Sources tab while the up-next card says "Finding source…" clears the shared streams flow while `beginSearch`'s watcher is still subscribed, so autoplay can pick a current-episode stream as "next"; log as a tracker row.
- Held until BUG-128 data: multi-rung HLS master (B4), off-main letterbox scan (B5). Tier 2 warmup after the FEAT-49 measurement.

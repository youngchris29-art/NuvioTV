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
| UI legs test51 + `TrailerSoakTests.testColdStoreFirstDwellRevealProfile` | (pending) |
| Review | (pending) |

## Owed

- Christian: device pass per the plan (FEAT-49 list items 1–10; BUG-128 legs L0–L3 with the probes armed), then merge on his go, beta.19-rc1 / build 133 cut, Steven's DM naming every new setting and its default (Preload Next Episode Sources OFF, Prepare Links OFF, trailer A/B knobs Auto/off).
- Post the two Reddit drafts.
- Held until BUG-128 data: multi-rung HLS master (B4), off-main letterbox scan (B5). Tier 2 warmup after the FEAT-49 measurement.

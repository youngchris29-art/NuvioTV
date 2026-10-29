# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-10-29
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `53869a027` — dated report `docs/upstream-port-plan-2026-10-29.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `d14832e1c` — dated report `docs/nuviotv-android-upstream-port-plan-2026-10-28.md`

## NuvioMobile — 2026-10-29

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `86e0d5bb4` (last plan, 2026-10-28) -> `53869a027`. 30 non-merge commits, **0 paths under `shared/` upstream** (upstream still keeps these files in `composeApp`; the fork's copies live in `shared/`). Fork tip checked: submodule `3a6d50950`, outer `bc54957`.
**New baseline: `53869a027`.**

## Candidates for the tvOS fork

1. **PORT — WatchProgressRepository: off-main persist + in-flight snapshot + metadata-enrichment backoff** (`bb94cb1c1` "fix(player): offline playback performance and reliability", Guilherme Lima Pereira). Upstream `composeApp/.../watchprogress/WatchProgressRepository.kt` (+103). The fork's `shared/.../watchprogress/WatchProgressRepository.kt` still does the JSON encode + `WatchProgressStorage.savePayload` synchronously in `persist()` (line ~1638) and has no enrichment attempt cap (`resolveRemoteMetadata` at ~1059). Three parts: (a) `persist()` snapshots into `PendingWatchProgressPayload`, encodes/writes on `syncScope` guarded by `persistLock` + sequence numbers; (b) profile load prefers the in-flight `pendingPersists[profileId]` over the stored file; (c) `metadataEnrichmentAttempts` map caps entries at 3 failed enrichments (`isMetadataEnrichmentBackedOff`, cleared on profile switch/sign-out). Files: `shared/.../WatchProgressRepository.kt`, tests in `shared/src/commonTest` (add a sequence-ordering test and a backoff test). tvOS relevance: the player persists ticks from the main thread, and the account-data wipe registry must still clear the pending map on sign-out (add `pendingPersists.clear()` where `clearLocalEntries` runs). Effort: **M (3-4 h)** incl. tests and device smoke of resume position.
2. **PORT (optional) — Offline guard for next-episode preload/auto-play** (same commit, `PlayerNextEpisodeAutoPlay.kt`). Skips the preload and auto-play stream fan-out when `isNetworkOffline()`. `PlayerNextEpisodeAutoPlay.kt` is `composeApp`-only; the tvOS player drives next-episode logic in Swift. Only worth it if the fork has a connectivity signal; check `graphify explain "NetworkMonitor"` first. Effort: **S (1 h)** if a signal exists, else skip.
3. **WATCH — ServerPlayback progress-report queue** (same commit, `composeApp/.../servers/ServerPlayback.kt`, +43/-8): split control vs bounded progress queue with sequence-based stale-progress skipping. No `ServerPlayback` in the fork (`shared/` or iosApp). N/A until the fork ports media-server playback reporting; note for then.

## Not applicable (Android / Compose / locale)
- ExoPlayer default engine, Auto engine resolver (`AutoPlaybackEngineResolver.kt`), engine-failover, track carry-over across engine switches (`25760f23e`, `b06f01938`, `41f1d2f54`, `d7ecbe6e0`, `4fbde7816`, `c1ffc45ef`), `PlayerEngine.android.kt`, `PlaybackMediaItems.android.kt`, `NuvioExoPlayerPerformanceHelper`: Android playback-engine choice (libmpv vs ExoPlayer). tvOS has its own AVPlayer/mpv split. The resolver's rule (HDR/DV -> native, anime/Japan animation -> mpv) mirrors what the fork already decides in Swift; no change.
- libass ASS render mode + overlay/video-effect subtitle work (`70e968047` ... `5d074a9c4`, AAR v0.0.10 -> v0.0.12, `PlayerSidecarSubtitles.kt`, `exo_player_view.xml`): Android libass AAR and Media3 effects. Fork renders subtitles via mpv/libass natively. Skip.
- Bulgarian, Polish, Vietnamese string updates (`60116efb0` ... `44c5be86a`, `04c9e2c5d`): composeResources only. The fork's tvOS strings use xcstrings; consider as translation source later, no port now.

## NuvioTV Android — 2026-10-28

Upstream `NuvioMedia/NuvioTV` (`dev`): `c3f68d84a` (last plan 2026-10-27) -> `d14832e1c`. 30 commits (GitHub compare API).
**New baseline: `d14832e1c`.**

## Candidates for the tvOS fork

1. **MED, port the idea — no resume progress for live streams** (`b4e47d6d6`, `583eae818`; PR #4227): mpv can seek inside its HLS cache so a live stream reports seekable, its duration keeps growing past the short-clip guard, and the saved position later seeks beyond the live window. Fix: a pure `LivePlaybackUiPolicy.nextDurationGrowth()` sampled once per tick (skipping readings before mpv reports the requested media) plus a "don't save resume" guard (`LivePlaybackUiPolicy.kt` 28 lines + `LivePlaybackUiPolicyTest.kt`). The fork uses mpv for some streams, so the same hazard can apply; check how `iosApp/NuvioTV` playback progress saving decides a stream is live (graphify `explain` on the progress writer) and port the duration-growth heuristic if it only relies on `seekable`. Swift, ~0.5 day, unit-testable.
2. **LOW-MED, optional — player badge codec detection + filename matching** (`13683564d`; `PlayerMediaInfo.kt` +46, `PlayerBadges.kt`, `PlaybackMatchText.kt`): improves codec badges and falls back to the file name. Folds into the carried "player badges + pack choice" item; read the diff when that is scheduled.
3. **LOW — Montenegrin subtitle language** (`7eb388a83`): OpenSubtitles returns `mne`/`me`, ISO 639-3 is `cnr`; all map to `sr-ME`. The fork has no `mne`/`cnr` handling (grep of `shared/` and `iosApp/NuvioTV`). Three-line map entry in the subtitle language normaliser if one exists; ~15 min.
4. **N/A:** libass video-effect work (`cc9bdb19e`, `d5da6bcaa`, `a8813ffb1`, `f60dab973`, `7070a646a`, `2bc54ec8f`, `6e2e5f961`, `205c314ef`, `3315ef13b`, `8d771aa2c`, `7dc661731`: ASS render mode, overlay alignment, audio-delay propagation to libass; Android AAR), `11b3c9d9c` (updater dex), Hebrew/Turkish strings (`6da2237ef`, `b032356f2`, `5e7a3fd6a`, `173da9d00`) and merges. The tvOS subtitle stack is the fork's own.

## Open items carried (see 2026-10-26 plan)
Simkl/MDBList playback-tracking perf (diff `MdbListProgressProjection.kt` first), Trakt refresh cancellation guard, libmpv no-retry on permanent HTTP errors.

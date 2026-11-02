# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-02
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `46febb568` — dated report `docs/upstream-port-plan-2026-11-02.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `1b6982960` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-02.md`

## NuvioMobile — 2026-11-02

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`) has not moved: still `46febb568` (last plan, 2026-11-01). 0 new commits, nothing to port.
**Baseline unchanged: `46febb568`.**

Carried-over open items from the 2026-11-01 plan: PORT (S) skip-button timer continuity keyed on `segmentCategory` (`a2110d6b8`), and WATCH the auto-failover re-arm check (`a4f69d0ed`, `5c3c19bc4`, `d6c32ec6c`) against the fork's mpv-to-AVPlayer failover.

## NuvioTV Android — 2026-11-02

Upstream `NuvioMedia/NuvioTV` (`dev`): `915e0117e` (last plan, 2026-11-01) -> `1b6982960`. 6 non-merge commits, 20 files (+523/-19). Android-only Kotlin/Java; no `shared/` equivalent.
**New baseline: `1b6982960`.**

## Candidates for the tvOS fork

1. **WATCH (S) — HLG from the HEVC alternative transfer SEI in MKV** (`553548679`; new `HevcAlternativeTransferSei.java`, `MatroskaExtractor.java`). SDR-compatible HLG streams signal BT.2020 in the VUI and carry HLG only in an alternative-transfer SEI, so HDR was never detected. The fork plays through mpv/FFmpeg and has its own HDR probe (the matrix-only colour fix of 2026-10-30), so the same stream class may be misread there. Check with one such sample (Test profile) before porting anything; effort 30 min check, M if the probe needs an SEI peek.
2. **SKIP — HDR from decoder input format** (`865c4a7cc`; ExoPlayer `isHdrVideo` UI state, Android only).
3. **WATCH (S, only if requested) — LFE level option for FFmpeg downmix** (`75c5b944b`; `FfmpegAudioDecoder`, `ffmpeg_jni.cc`, settings and datastore, French strings in `cbf79efdd`). Same family as the earlier night-mode watch item; tvOS mpv would use an `af` chain. New setting would need a default named in release notes.
4. **SKIP — Android-only**: URL focus restoration on settings screens (`f524f2ebe`, Compose focus), missing-strings update (`694240813`).

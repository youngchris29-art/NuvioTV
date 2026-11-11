# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-11
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `83f07d4c2` — dated report `docs/upstream-port-plan-2026-11-11.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `b8c166824` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-11.md`

## NuvioMobile — 2026-11-11

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`) has not moved since the last run: still `83f07d4c2`, 0 new commits. Fork tip checked: `107f596d8`.
**Baseline unchanged: `83f07d4c2`.**

Open items from 2026-11-10 stand (not yet ported): MDBList remap cache (M), auth stays signed in on refresh failure (M), persisted addon subtitle by id (S), DECIDE forced-subtitles default (S). Full list in `docs/upstream-port-plan-2026-11-10.md`.

## NuvioTV Android — 2026-11-11

Upstream `NuvioMedia/NuvioTV` (`dev`): `17ddebe73` -> `b8c166824`. 7 non-merge commits, 18 files.
**New baseline: `b8c166824`.**

1. **CHECK (S) — Restore the episode being watched after process death** (`12c24cdb8`, `LaunchIntentReplay.kt`, `MainActivity.kt`): Android launch-intent replay. tvOS state restoration is separate; WATCH.
2. **CHECK (S) — HLS streams without SPS/PPS** (`a239d298d`, `35942ba5c`, `HlsParameterSetInit*.kt`): ExoPlayer data-source workaround. The fork plays HLS through AVPlayer/mpv/Aether; only relevant if a tester reports a no-init-segment HLS stream failing. WATCH.
3. **CHECK (S) — mpv video time drops to 0, fall back to the audio clock** (`e9a6352fa`, `NuvioMpvSurfaceView.kt`): compare the fork's mpv position reporting for the same zero-time glitch (`graphify query "mpv playback position"`). Swift-side check only.
4. **SKIP — Android-only**: DASH routing for explicit MIME hints (`e85b29072`, `PlayerStreamRouteState.kt`, ExoPlayer routing), slower hero description auto-scroll (`a71108dc9`, Compose), Latin American Spanish strings (`4ad172fac`).

Carried over unchanged from 2026-11-10: post-play timing from End Credits chapters (S), Continue Watching keyed by show (CHECK), forced-subtitles/AutoSync defaults (DECIDE), Trakt write-mapping guard (S) and the Anime-Skip fixes (M).

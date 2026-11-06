# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-06
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `ff846efe7` — dated report `docs/upstream-port-plan-2026-11-06.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `248ed08bf` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-06.md`

## NuvioMobile — 2026-11-06

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `77dfe7c2c` (last plan, 2026-11-05) -> `ff846efe7`. 12 non-merge commits, 48 files (+2824/-374). No changes under `shared/`. Android audio delay/amplification/downmix, Android player fixes, Compose blur, pt-BR string.
**New baseline: `ff846efe7`.**

## Candidates for the tvOS fork

1. **SKIP — Android audio features** (`243f06c8a`, `92ab4d871`, `56dfcff2e`). Android-only; iOS hides them. Revisit only on a tester request for audio delay (mpv `audio-delay`).
2. **SKIP — Android player fixes** (`0403e6f67`, `6f9452616`, `6c080ea78`): mpv surface, libmpv load failures, torrent stall resume.
3. **WATCH (S) — pin auto engine failover to the current source** (`36c3a8081`). Fork has no `engineFailover` state; check any failover flag does not carry to the next episode.
4. **SKIP — Compose blur** (`68c815b2a`, `b90454d72`) and i18n/version churn.

## NuvioTV Android — 2026-11-06

Upstream `NuvioMedia/NuvioTV` (`dev`): `a6a826687` (last plan, 2026-11-05) -> `248ed08bf`. 15 commits. Mostly locales and Android player/autosync; one Trakt fix applies to the fork's shared code.
**New baseline: `248ed08bf`.**

## Candidates for the tvOS fork

1. **PORT (S) — Trakt reverse remap only when the addon lacks the episode** (`f07acf603`, PR #4470; `TraktEpisodeMappingService.kt`). Fork `shared/.../trakt/TraktEpisodeMappingService.kt` `resolveAddonEpisodeMapping` (~line 215) still remaps when the addon has the episode but season counts differ anywhere, so long shows (The Daily Show: Trakt S30E1 -> addon S29E113) lose watched badges. Return null as soon as `addonHasEpisode`, before fetching Trakt episodes; check the forward path (~line 153); add a jvmTest with mismatched season counts. No new setting. Relevant to Test 2 (Trakt source).
2. **WATCH (S) — keep restored subtitle preference** (`19b8a0c2f`, PR #4494): check the fork's remembered add-on subtitle survives a restore/engine switch. Only if reproduced.
3. **SKIP — ExoPlayer EOS overrun** (`105490c2d`, PR #4495) and locales/version.

## Carried over from 2026-11-05
The 2026-11-05 PORT (drop the 2% in-progress threshold, `ca8bdce45`) and WATCH items (`bbf2d4388`, `f4c482e64`) are unchanged; see `docs/nuviotv-android-upstream-port-plan-2026-11-05.md`.

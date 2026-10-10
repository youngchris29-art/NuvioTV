# Upstream port plan — 2026-10-07

Upstream `NuvioMedia/NuvioMobile` `cmp-rewrite`: `c2127769` -> `b8801eb4` (0.5.7-beta, build 139). 10 non-merge commits, **0 changes under `shared/`**.

## Verdict: nothing to port (no actionable items)

| Upstream change | Commits | tvOS decision |
|---|---|---|
| ExoPlayer native memory, custom playback buffers, VOD disk cache + Playback settings UI (PR #2178, halibiram) | 36228818, 26379af4, 394cd0bf, 738084c1, ce949fee, d9d06013, ad6d5e8a, 0e8c373d | N/A. Android-only (ExoPlayer/Media3 aars, `PlayerEngine.android.kt`, OkHttp datasource). The iOS stubs upstream are settings storage only. tvOS uses AVPlayer, which manages its own buffering. Optional, only if a user asks: a tvOS "forward buffer duration" setting (AVPlayerItem.preferredForwardBufferDuration). |
| New `settings_playback_*` strings (EN, TR) | same | N/A, no matching tvOS UI. |
| Version bump 0.5.7 / build 139, store.json | ef4f5fae, b8801eb4 | N/A. Fork versions independently. |

## Claude Code next steps
None required. Optionally run `git -C NuvioMobile fetch upstream` and confirm `git diff --stat c2127769 upstream/cmp-rewrite -- shared` is empty.

# Release videos (HyperFrames)

Beta-announcement videos rendered locally with the [HyperFrames CLI](https://github.com/heygen-com/hyperframes)
(skills installed in `.agents/skills/`). Each release gets a directory with a
`template.html` — a single self-contained HyperFrames composition (dark Crimson
brand palette, JetBrains Sans, 1920×1080) — and the shared `build.py` injects
the app's real font files as base64 before rendering.

## Rendering a video

```bash
cd marketing/release-videos
python3 build.py beta5                      # template.html -> build/beta5/index.html (fonts inlined)
cd build/beta5
npx hyperframes lint                        # fast static check
npx hyperframes check                       # full browser gate (runtime/layout/motion/contrast)
npx hyperframes render --quality high --output nuviotv-beta5.mp4
```

The `build/` output dir is gitignored — only templates are source. (The linter
treats every root-level HTML with `data-composition-id` as an entry point, so
the built file must not sit next to its template.)

Requires Node 22+, FFmpeg, and network on first run (Chrome headless shell +
GSAP/HyperFrames runtime come from CDN/npm).

## Making the next beta's video

1. `cp -r beta5 beta6` and edit `beta6/template.html`:
   - Scene copy lives in plain HTML; feature scenes are `s2`–`s4`, `s5` is the
     amber "heads-up" card, `s6` the outro/CTA.
   - Timings: each scene has `data-start`/`data-duration`; they must tile the
     root's `data-duration` with no gaps, and every GSAP tween's absolute times
     must stay inside its scene window. The visibility toggles at the top of the
     `<script>` block and the shader-transition `time` must match any retiming.
2. `python3 build.py beta6`, then lint → check → render as above.

Design tokens (mirrors `iosApp/NuvioTV/DesignSystem/Theme.swift`): bg `#0D0D0D`,
surface `#1A1A1A`/`#242424`, accent `#E53935`, focus `#FF5252`, text `#F5F7F8`,
muted `#969CA3`, star/warning `#FFC857`.

The same `index.html` is also valid for HeyGen's hosted "Send to HyperFrames"
import (`import-claude-design-from-url`) if a cloud project is ever wanted —
it just needs to be reachable at a public URL.

## Music bed

The render is silent; the music bed is muxed in afterwards. `beta5/assets/`
holds both the finished track (`bgm.wav`, 24s dark electronic underscore in
A minor, 100 BPM, section changes timed to the scenes) and the deterministic
numpy synth that generated it (`bgm_synth.py` — seeded, no ML models, needs
only `numpy` + `soundfile`; retiming for a future beta means editing the
section boundaries at the top and in the gate ranges).

```bash
ffmpeg -i nuviotv-beta5.mp4 -i ../../beta5/assets/bgm.wav \
  -filter_complex "[1:a]volume=0.9[a]" -map 0:v -map "[a]" \
  -c:v copy -c:a aac -b:a 192k -shortest nuviotv-beta5-music.mp4
```

(Alternatives for future videos: HeyGen's 10k-track BGM catalog via the
`media-use` skill needs a one-time `heygen auth login --oauth`; Google Lyria
generation needs `GEMINI_API_KEY`. Local MusicGen exists but needs more free
RAM than this machine usually has.)

## Contents

- `build.py` — font injector (placeholders → base64 `@font-face`)
- `beta5/template.html` — NuvioTV v0.3.0 beta.5 announcement (24s, 6 scenes:
  title, localization, All-Debrid, MAL scores, Trakt heads-up, CTA)

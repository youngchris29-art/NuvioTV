# Release videos (HyperFrames)

Beta-announcement videos rendered locally with the [HyperFrames CLI](https://github.com/heygen-com/hyperframes).
Each release gets a directory holding its sources; the shared `build.py` stages a
project into `build/<project>/` with the app's real font files and the README
screenshots, and the CLI lints, checks and renders from there.

Two project shapes exist:

- **Multi-file** (`beta19/`, the shape to copy from now on): `index.html` is the
  root composition and mounts one scene per file from `compositions/`; `assets/`
  holds the music bed and its generator. Screenshots are referenced as
  `assets/screens/<name>.png` and the brand mark as `assets/brand/<name>.svg`;
  `build.py` copies them from `design/screenshots/` and `design/` at build time,
  so no multi-megabyte PNG is duplicated in git. Fonts are referenced as
  `assets/fonts/jetbrains_sans_*.ttf` and copied from the NuvioMobile submodule.
- **Single-file** (`beta5/`): one `template.html` with `__FONT_*__` placeholders
  that `build.py` replaces with base64 fonts. Kept as history; the current CLI
  lints it with errors (it animates `autoAlpha` on clip elements and nests
  scenes in one file), so start a new video from `beta19/`, not from it.

## The two films

- `explainer/`: the product explainer (98 s, nine scenes: title; Home as a
  stage with the trailer card, a focused collection and the folder inside it;
  the Rail, Search and Discover; the Cinematic page, the season row and the
  hold menu; the source list and debrid; the loading screen growing into the
  Apple TV player, the player panel and four real mpv scan frames; Library and
  a catalog; Settings, the accent swatches and the French profile picker; the
  end card). Screens are full-bleed and a camera punches into the control each
  line names. Neighbouring scene hosts overlap by 0.3-0.5 s so each seam has a
  cause on screen: an iris from the mark, whips, a zoom through a poster, a
  button or an episode card, the loading card growing into the player, a colour
  flood off the selected Ocean swatch and a crimson one into the end card.
  Scene roots are transparent so the scene underneath shows through a seam.
- `beta19/`: the beta.19 release film (44.3 s), framed screens with callouts.

**What the explainer cannot show yet.** Every frame is a real screen, but the
repo holds no screen recordings, so the Stage being walked, a toggle flipping
and playback starting are told with cuts between real states, camera moves and
the rig's 1 fps scan frames (`explainer/assets/frames/`, from
`docs/research/device-rig-2026-10-15/s8-hdr10-scan-burst.mp4`). To replace a
beat with motion, record it as 1920x1080 H.264 (the simulator:
`xcrun simctl io booted recordVideo --codec h264 <file>.mp4`; the Apple TV
itself only gives screenshot bursts, see `docs/device-rig-2026-10-15.md`), put
the file under `explainer/assets/video/`, and in that scene swap the `<img>`
for `<video muted playsinline src="assets/video/<file>.mp4" data-start=...
data-duration=...>` inside the same `.cam` wrapper. Beats worth recording, in
order of payoff: Stage Home walked down three rows (Home scene A); a poster
widening into its trailer (Home B); Play pressed on a title through the
loading screen into the Apple TV player (Player A-B); mpv scanning with the
transport bar (Player D); an Appearance toggle and a theme swatch changing
(Settings B).

## Rendering a video

```bash
cd marketing/release-videos
python3 build.py explainer                  # explainer/ -> build/explainer/ (fonts + screenshots staged)
cd build/explainer
npx --yes hyperframes@0.8.186 lint          # fast static check
npx --yes hyperframes@0.8.186 check         # full browser gate (lint, runtime, layout, motion, contrast, craft)
npx --yes hyperframes@0.8.186 snapshot --review --output /tmp/beta19-review   # beat sheet + seam strips to look at
npx --yes hyperframes@0.8.186 render --quality high --fps 30 --workers 4 \
  --output ../../renders/nuviotv-explainer.mp4
```

`build/` and `renders/` are gitignored: only the sources are committed. (The
linter treats every root-level HTML with `data-composition-id` as an entry
point, so the staged copy must not sit next to its sources.)

Requires Node 22+, FFmpeg, and network on the first run (the CLI downloads a
Chrome headless shell with `npx hyperframes browser ensure`; GSAP comes from
jsDelivr). The fonts come from the submodule; when it is not checked out, point
`NUVIO_FONT_DIR` at any directory holding the three `jetbrains_sans_*.ttf`
files, for example a sparse clone of `NuvioMobile`.

The 0.8.186 pin is the version beta19 was checked and rendered with. Newer CLIs
add lint rules; re-run `check` after moving the pin.

## Making the next beta's video

1. `cp -r beta19 beta20` (or start from `explainer/` for the full-bleed look) and edit:
   - `index.html`: the root `data-duration` and one host `<div>` per scene with
     `data-start`/`data-duration`. The host id, the scene file's
     `data-composition-id` and its `window.__timelines[...]` key are the same
     word. Scenes must tile the root duration; the `<audio id="bgm">` spans it.
   - `compositions/<scene>.html`: one scene per file, everything inside
     `<template>`, root styled as `#root`. Scene timelines count from 0 at the
     scene's own start and use `fromTo` (never `from`). Copy sits in plain HTML:
     `.kicker`, `.head` (one accent word in `<em>`), the `.callout` pills over
     the screenshot (`c1`/`c2`/`c3` slots) and the settings-path `.chip` in the
     frame's bottom-right corner. The camera is the `.cam` wrapper inside
     `.shot`: tween `scale`/`x`/`y` on it to punch in on a control, never on the
     `<img>`. Each scene ends on a 3-frame dip (`.dip` to 0.45) so the cut
     reads as meant. Keep every reading line at least 28 px and on screen for
     about 0.5 s + 0.3 s a word.
   - Swap screenshots by name under `assets/screens/`; they must exist in
     `design/screenshots/`. 1920×1080 captures look sharper than the 960×540
     ones in the punch-ins; the build picks up whatever is there.
2. `assets/bgm_synth.py`: set `DUR` and the section constants at the top
   (`T_FEATURES`, `T_MORE`, `T_OUTRO`, `RISER_FROM`) to the new scene times,
   add chord bars to cover the length, then `python3 assets/bgm_synth.py`
   (needs `numpy` + `soundfile`). Commit the regenerated `bgm.wav`.
3. `python3 build.py beta20`, then lint → check → snapshot → render as above.
   Fix every `check` error and weigh every warning before rendering.

Design tokens (mirrors `iosApp/NuvioTV/DesignSystem/Theme.swift`): bg `#0D0D0D`,
surface `#1A1A1A`/`#242424`, accent `#E53935`, focus `#FF5252`, text `#F5F7F8`,
muted `#969CA3`, star/warning `#FFC857`. Type is the app's JetBrains Sans; the
mark is `design/nuvio-mark.svg`.

## Music bed

The bed is an `<audio>` clip inside the composition, so the render carries it
and no FFmpeg mux step is needed. `beta19/assets/` holds the finished track
(`bgm.wav`, 44.3 s dark electronic underscore in A minor, 100 BPM, section
changes timed to the scenes: percussion enters on the first feature, the arp
drops out under "And more", a riser lands the impact on the end card) and the
deterministic numpy synth that generated it (`bgm_synth.py`, seeded, no ML
models). `explainer/assets/` holds the same synth retimed to 98 s, with a
breakdown while the loading screen grows into the player and the tension
section under Settings. Measure the rendered file with
`npx --yes hyperframes@0.8.186 audio renders/nuviotv-beta19.mp4 --json`.

(Alternatives for future videos: HeyGen's BGM catalog via the `media-use`
skill needs a one-time `heygen auth login --oauth`; Google Lyria generation
needs `GEMINI_API_KEY`.)

## Contents

- `explainer/` — the product explainer (98 s, 9 scenes, see above); its mpv
  scan frames under `assets/frames/`
- `build.py` — stages a project into `build/<project>/` (fonts, screenshots,
  brand files); still inlines base64 fonts for the single-file beta5 template
- `beta19/` — NuvioTV v0.3.0 beta.19 announcement (44.3 s, 8 scenes: title,
  Stage Home with the Classic swap, the Rail in Centre and Corner, the
  Cinematic detail page with the season hold menu and Hide Spoilers, Search
  and Discover, the player panel with Sync Line, Audio Mode, Boost and Dolby
  Vision profile 5, an "And more" list, CTA)
- `beta5/template.html` — NuvioTV v0.3.0 beta.5 announcement (24s, 6 scenes:
  title, localization, All-Debrid, MAL scores, Trakt heads-up, CTA), with its
  24 s bed and synth under `beta5/assets/`

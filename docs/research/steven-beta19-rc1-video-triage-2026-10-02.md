# Steven beta.19-rc1 video triage (IMG_8880.mov, 2026-10-02)

Source: `~/Downloads/steven-beta19-rc1-2026-10-02/IMG_8880.mov` (3840x2160, 30 fps, 396 s, handheld phone filming the TV, French UI). Build on the TV: beta.19-rc1 (build 133). It goes with Steven's verdict DM (bubble 44, 5:09 PM). Bubble 41 adds the trailer-delay idea.

Frames: `docs/research/steven-beta19-rc1-video/` (file names start with mm:ss as `MMSS-…`; `-10fps`/`-30fps`/`-2fps` files are tiles read left to right, top to bottom). Kymographs (`*-kymo-*`) stack one thin column (or row) of pixels per video frame left to right, so anything that moves shows as a curve: a flat line is something standing still.

**How the measurements were taken.** Frames were decoded at 30 fps and scaled to 1920x1080. Positions were tracked by script: brightness centroid of the row-title text, the strongest dark-to-bright edge for the poster tops, and the TV's bottom bezel as the camera reference. Every on-screen move quoted below is net of camera drift (bezel shift subtracted). Pixel → point conversion: in the 6:04–6:12 shots the panel is about 1470 px wide in the 1920 frame, so **1 px ≈ 1.31 pt** of the 1920x1080 tvOS screen. In the Fusion shot (5:01) it is about 1500 px wide, so 1 px ≈ 1.28 pt. Labels: **[measured]** = numbers from the scripts; **[observed]** = seen frame by frame; **[inferred]** = an interpretation.

## Timeline

| Time | What's on screen |
|---|---|
| 0:00–0:03 | Launch, profile picker ("Qui regarde ?") |
| 0:04–0:24 | Home, Nuvio hero (Pressure), Genres row, a fast walk down and up through Nouveaux films / Top 10 des films / Nouvelles séries; hero logos cross-fade on every focus change |
| 0:24–0:36 | Top 10 des films: The Debt Collector card morphs and sits on a still for about 3 s; Nouvelles séries: Comme des frères morphs (still for about 1.5 s, then the video plays); **the hero for Comme des frères has no title or logo at all** |
| 0:36–0:58 | Nouvelles séries: A Different World morph, collapse leaves an empty slot (0:54.8), hero cross-fade with doubled titles |
| 1:12–1:30 | Verity trailer playing in the morphed card (camera zoomed in) |
| 1:30–1:56 | Ring colours: 72 Heures (pink), Elize (gold) → morph → neutral white ring; Elize trailer plays |
| 1:56–2:34 | Top 10 des séries browsing, fast hero swaps; **first-poster glitch on GIGN at 2:10.6** |
| 2:34–2:37 | Studios row, then Services de Streaming with the animated Netflix tile |
| 2:38–2:58 | Netflix collection folder page: skeleton grid, header leaves on scroll, scroll back up |
| 2:58–3:12 | Home browsing |
| 3:13–3:56 | Monstre detail page: scroll down to Episodes / Casting / Bandes-annonces / À voir aussi, back up, several times |
| 3:56–4:20 | Stream list → Infuse hand-off (Netflix intro plays) → back to the Detail page → Home |
| 4:20–4:44 | Home: up and down between Continuer à regarder / Genres / Nouveaux films; **Verity morph starts and aborts at 4:34.7**, then no trailer on the focused Verity for about 9 s |
| 4:44–4:48 | tvOS Home screen |
| 4:48–5:26 | **Fusion** (reference app): hero, rows, Top 10, its own inline trailer card (Scrubs, about 5:20) |
| 5:28–5:35 | Back to NuvioTV Home |
| 5:36–5:55 | NuvioTV Settings (Appearance) |
| 5:54.9 | Tab switch Settings → Home: a one-frame cross-fade, Home showing through Settings |
| 5:56–6:36 | Home: row changes and horizontal moves; City of Blood / Not a Stranger / The Scandal cards morph to a **still** and collapse back after about 2–3 s (trailers dead) |

## 1. Title bounce / "real-time title adjustments" (bubble 44 ❌ item 1)

**Best occurrences:** 6:04.4 (Nouveaux films → Top 10 des films, no trailer playing) and 6:08.9 (Top 10 → Nouvelles séries, no trailer). The camera is nearly still in both shots. Frames: `0364-row-change-every-frame-old-row-sliced.jpg` (every frame, 6:04.30–6:04.83), `0364-kymo-label-vs-poster-nuvio.jpg`, `0364-kymo-row-slide-nuvio.jpg`, `0366-hero-crossfade-15fps.jpg`.

A single Down press produces **four separate visible events**, spread over about 2 s:

1. **Row slide** [measured]. The new row travels about 480 px (≈ 625 pt, one row pitch) upward. The label reaches within 10 px of its rest about 0.7 s after motion starts (6:04.37 → 6:05.07) and settles within 2 px at about 1.15 s (6:05.53). The first 1–2 camera frames carry a very large step; after that the tail is long and slow (the last 30 px take about 0.6 s). The label and the posters move together during the slide: label-to-poster-top gap 38.5–39.3 px (≈ 50 pt) throughout. [observed] The outgoing row does not scroll off: it slides up behind the hero and is **cut by a hard horizontal mask line just below the "Voir le film" button** while fading. For 4–5 frames (6:04.57–6:04.70) a thin sliced strip of the old posters is visible under the hero.
2. **Small creep** [measured]. After the slide the row undershoots by 3–4 px (label 369.2 px at 6:05.77) and creeps back over about 0.6 s. Barely visible.
3. **Hero cross-fade** [measured/observed]. About 0.4–0.5 s after the last focus change, the hero swaps. Old and new logos, genre lines and synopses are both visible at the same position for 3 frames (≈ 0.1–0.2 s): `0366-hero-crossfade-15fps.jpg` (A TOXIC LOVE STORY over WAR MACHINE), `0129-hero-crossfade-double-title-idaho-gign.jpg`. This is the "doubled title" Steven sees: a cross-fade of two different-height texts in the same place, not two titles drawn on purpose. The hero visibly lags focus. At 6:06.0 the ring is on War Machine (#8) while the hero still shows A Toxic Love Story (`0366-hero-lags-focus-war-machine.jpg`).
4. **Late row-title step: this is the "title readjusts itself" motion** [measured]. **The row title moves alone, the posters do not.**
   - 6:06.37 → 6:06.53: label +7.2 px (≈ 9.5 pt) down in 5 frames (≈ 0.17 s). Gap to the poster tops 38.6 → 32.0 px (≈ 50 → 42 pt). Relative to the TV bezel: label −506.6 → −500.4 px, poster tops unchanged at −470/−469 px.
   - 6:11.23 → 6:11.43: same step again, +7 px, gap 38.5 → 31.3 px, in about 0.2 s.
   - Both steps land **1.9–2.3 s after the row press** and **0.2–0.3 s after a hero swap** (hero swaps at 6:06.2 and 6:11.0). A hero swap that happened *after* the label had already settled (6:15.1) produced no step: gap stayed 30.5 px.
   - [inferred] The row is laid out during the slide with its title at the "moving" offset (gap ≈ 50 pt) and only drops to its rest offset (gap ≈ 41 pt) when something decides the row has settled. The release is late (about 2 s) and quick (about 0.17 s), so it reads as a separate jolt. It looks like the held-slide release added in the verdict batch firing late. Worth checking in the device log whether the release is keyed to the hero swap or to a quiet timer.

**Trailer playing vs not.** The two measured cases had no trailer playing. During 0:24–0:36 (cards morphing to trailers) the camera moves too much for px-level numbers. [observed] The same cross-fade and slide happen there, plus the morph pushes the neighbours sideways and back, which adds more horizontal motion in the same second.

**Fusion comparison (4:58.8, Nouveaux films → Top 10 des films)** [measured], `0299-kymo-row-slide-fusion.jpg`, `0301-fusion-reference-rows.jpg`:
- One movement per press. The whole page scrolls about 440 px (≈ 565 pt). Peak 55–58 px/frame, smooth ease-out, within 10 px of rest after about 0.55 s, within 2 px at about 1.0 s.
- The label and the posters stay locked: gap 51–52 px the whole time. After settle, label minus bezel stays constant (−602.5 vs −602.8 px over 1.4 s), so **no late adjustment at all**.
- No hero above the rows once you are in them (Fusion's hero scrolls away with the page), so nothing cross-fades above the focused row. Titles sit under each poster and never move independently.
- Fusion also has one near-hold frame (4:59.33) at the end of its main motion.

Confidence: high on the late label step (two clean measurements, same size); high on the hero cross-fade; medium on the slide-start shape (the first frames are motion-doubled by the camera, see §9).

## 2. Glitches on the very first poster on the left (❌ item 3)

Clearest at **2:10.57–2:10.77** (`0130-first-poster-glitch-30fps.jpg`, `0130-first-poster-morph-abort-ghost-logo.jpg`) [observed]. Focus leaves GIGN (#1, leftmost) while its morph is starting. Poster #2 is pushed right, opening a gap, and the **landscape card's "GIGN" logo of the half-started morph shows as a translucent ghost across poster #1 and the gap** for about 6 frames (0.2 s). Then the gap closes and #2 slides back. The hero swaps to Idaho at 2:10.9.

Related morph-card glitches seen on early cards:
- 0:53.5: morph start shows an **empty dark landscape frame** behind the 2nd poster for 1 frame before the backdrop fills it (`0053-morph-start-empty-dark-frame.jpg`).
- 0:54.8: collapse leaves an **empty slot** between Le Problème Final and Golden Ticket for 1–2 frames (`0054-morph-collapse-leaves-empty-slot.jpg`).
- 1:31.2: mid-morph, the portrait poster and the landscape art are drawn side by side, with "72 HEURES" doubled (`0091-morph-midway-pink-ring-poster-and-landscape-overlap.jpg`).
- 4:34.7–4:35.1: Verity (#1, leftmost) starts to morph (neighbours slide right, a ringed landscape box appears) and **collapses back within about 0.4 s** with focus still on Verity (`0274-verity-morph-starts-then-aborts-10fps.jpg`). This is the dead-trailer case (§8).

Not glitches:
- The **striped "Netflix" tile** in Services de Streaming is an **animated cover**. It cycles N logo → coloured vertical ribbons → N about every 2 s (2:34–2:37, 2:56–3:03; `0156-netflix-tile-animated-cover-stripes.jpg`). The same ribbons are Netflix's own intro, which also plays in Infuse at 4:10.
- Brightness pulses on the leftmost poster at 0:26–0:30 are **camera auto-exposure** [measured]: all three posters step together, and the ratio of first to second poster stays 0.99–1.02.

[inferred] Steven's "even with no trailer playing" most likely means this morph start/abort when focus lands on, or leaves, the first card. With trailers dead, the start-then-collapse still happens (4:34.7). Confidence: medium-high that this is what he means; high that the ghost/gap artefact is real.

## 3. Ring colour before vs after the trailer starts (✅ item 2 follow-up)

[observed] The poster ring takes the depth colour; the morphed trailer card always gets a neutral white ring.
- 72 Heures: pink ring at 1:30.4 (`0090-ring-pink-before-morph.jpg`) → mid-morph still pink (1:31.2) → landscape card with white ring.
- Elize: gold ring at 1:33.1 (`0093-ring-gold-elize-before-morph.jpg`) → white ring on the playing card at 1:34.5 (`0094-elize-morph-ring-neutral.jpg`).
- Same at 0:27 (Debt Collector) and 6:31 (Scandal): white ring (`0027-trailer-card-white-ring.jpg`, `0391-scandal-morph-still-no-video.jpg`).

Confidence: high.

## 4. Row edge fade (❌ item 4)

[measured, rough] At 6:26 a portrait poster bleeding off the left screen edge (The Scandal, Korean poster) darkens over about 100 px of 4K video ≈ 65 pt before the panel edge. Brightness profile across it: 15 → 90 → 146 → 164 (0–255) over the last ~100 px, i.e. a short ramp, then a hard stop at the bezel. Same look at 6:31 on Blame.

On the Detail page (3:28, À voir aussi) the left poster is cut by the screen edge with **no visible fade at all** (`0208-detail-more-like-this-hard-left-edge.jpg`). The Trailers row ends inside the screen.

On Home's right edge, the rows at 6:06 and 6:26 end inside the panel (the last poster fits), so the right fade was not exercised. I could not isolate a portrait-vs-landscape difference at the screen edge from this video; no landscape card sits under the edge in a steady shot. Confidence: medium on "≈65 pt ramp, then hard cut"; low on the portrait/landscape difference (not shown here).

## 5. Collection folder page (Netflix) (❌ item 5)

`0158-folder-open-skeleton.jpg`, `0160-folder-header-leaves-on-scroll-10fps.jpg`, `0161-folder-logo-gone-after-1-press.jpg`, `0162-folder-chips-gone-after-2-presses.jpg` [observed]:
- 2:38.25: the page opens on a grey skeleton grid for about 0.25–0.5 s before the posters load.
- First Down press (2:41.0): the **NETFLIX logo disappears in 1–2 frames (≈ 0.05–0.1 s)** and the grid jumps up by the logo's slot (about 18–20 % of screen height). The chips row is now the top element.
- Second press (2:42.0): the **chips row disappears the same way** and the grid moves up one more step. From then on the page is just a poster grid with no title.
- Scrolling back to the top (2:58.5–2:59.0): chips come back, then the logo, again as abrupt steps.
- Grid scroll between rows is a fast step with no fade at the top or bottom edges.

Confidence: high (observed); the magnitudes are approximate.

## 6. Detail page (❌ items 6, 7 and the Liquid Glass item)

- **Synopsis panel** (3:19.5, `0199-detail-synopsis-glass-panel.jpg`): a glass panel at the top right, laid directly over the key art (over the figure's arm and head in the Monstre art). This matches his "placed in front of the poster" description.
- **Scroll back up** (3:39.9–3:40.7, `0219-detail-scroll-back-up-10fps.jpg`) [observed, medium confidence]: as the header returns, the meta chips (date / 1h6min / ★7.1 / 18) first come in as bright, nearly blank capsules, then re-tint to the red glass with text over about 0.3–0.5 s, a visible "re-render". The Play / trailer / ✓ / + buttons are drawn as plain white or flat pills during the scroll and do not show that glass transition. They arrive in their final look. So the two groups behave differently on the way up, as he says. The camera ghosts text 2–3x during these scrolls (see §9), so the exact frame count is uncertain.
- **More Like This / Trailers** (3:28): no edge fade; hard cut at the left screen edge.
- 3:13–3:56: no background trailer is visibly playing on the Detail page. The backdrop is the static red Monstre art in every sampled frame [observed, medium].

## 7. Trailers stop playing (❌ last item)

[observed]
- **Working:** 0:30–0:33 Comme des frères (the card shows the backdrop still for about 1.5 s, then video); 1:12–1:28 Verity; 1:34–1:56 Elize. The Debt Collector card at 0:26–0:29 showed only its still for about 3 s before he moved on (inconclusive).
- **First failure seen: 4:34.7.** Verity morph starts and aborts within 0.4 s, focus still on Verity. Verity then stays focused (red ring) with **no morph at all** until 4:44 (about 9 s; `0277-verity-focused-no-trailer.jpg`).
- Between 1:56 and 4:34 no clean test exists: fast browsing, folder, Detail, Infuse playback. So the failure started somewhere in **1:56–4:34**. [inferred] It was probably after the Detail page and the Infuse hand-off (3:13–4:20), since the first attempt after that is the first failure.
- **End state (6:16–6:34):** cards still **morph** to landscape, but show **only the backdrop still**. No video for 2–3 s, then the card **collapses back to the poster on its own** while focus stays on it.
  - City of Blood: 6:16.5.
  - Not a Stranger: 6:23.75 → collapse 6:25.5.
  - The Scandal: 6:30.5 → collapse about 6:33.6 (`0389-scandal-still-card-then-collapse-2fps.jpg`, `0391-scandal-morph-still-no-video.jpg`). Motion inside the card is below the static neighbour poster's frame-diff level [measured: median diff 2.4 vs 3.0], i.e. a still.

Confidence: high on the end state; medium on the onset window.

## 8. Stutter / dropped frames

[measured] Frame-to-frame difference through the 6:04.4 slide shows one near-hold at 6:04.77 (diff 11 between neighbours of 21 and 33), i.e. probably one held frame mid-slide. Fusion shows a similar near-hold at 4:59.33. No run of identical frames was found in either app.

Caveat: the phone captures at 30 fps, and 2–3 TV frames are blended into many camera frames during fast motion. Text appears doubled or tripled in motion in **both** apps (e.g. Fusion captions at 5:01, NuvioTV Detail at 3:36), so doubled text *during motion* is not by itself an app bug. The doubled *hero* titles are, because they occur with the hero standing still (cross-fade). Confidence: low–medium. The video is not suited to frame-pacing claims; use the on-device frame sampler (BUG-126) for that.

## 9. Colour / brightness vs Fusion

[measured, low confidence] Same poster (Verity) in both apps, from the camera footage:
- NuvioTV 4:37: mean luminance 0.42, mean saturation **0.48**.
- Fusion 5:01: luminance 0.31, saturation **0.59**.

The NuvioTV poster records brighter but noticeably less saturated, which is consistent with "dull / washed". But the phone re-exposes per scene (Fusion's bright, colourful background pulls exposure down), so this is suggestive only. [observed] Fusion's whole page sits on a bright multicolour blurred ambient background. NuvioTV's rows sit on near-black, with the hero art fading into black on the left. That difference in overall scene brightness is real and large in the footage. For a real comparison, use a still photo of the same poster at the same camera settings (his Smash link may have one).

## 10. Other things visibly wrong

- **Hero with no title**: Comme des frères (0:24–0:36) shows meta + synopsis + CTA with an empty space where the logo/title should be (`0032-hero-missing-title-comme-des-freres.jpg`). [inferred] The logo fetch failed and there is no text fallback.
- **Tab switch cross-fade**: Settings → Home at 5:54.9 shows Home through Settings for 1 frame, then the Home hero fades up from grey (`0354-tab-switch-settings-home-crossfade.jpg`). Minor.
- **Hero picks a stale item when returning from the folder**: back on Home at 2:57.5 the hero first shows "Ne dis pas bonne chance", then jumps to the Netflix folder hero about 1 s later.
- **Genres-row-from-above** (✅ partial item): the 4:20–4:34 up/down sequence has Continuer à regarder present, which per Steven hides the bug. Not demonstrated in this video.
- **Tab bar stuck half-shown**: not in this video (he sent a photo).

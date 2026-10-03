# Home screen: what Steven's beta.19-rc1 verdict tells a redesign (handoff, 2026-10-02)

## Who this is for

This is written for the session planning the Home screen redesign. It covers what Steven's beta.19-rc1 (build 133, `5f2d5cd3`) verdict says about Home, measured from his video and checked against the code.

Steven is the most active beta tester. He runs Show Hero on, the Nuvio hero (logo + synopsis), Large or Medium+ posters, ring/zoom focus, inline auto-play trailers on, and a French UI. He uses the competing Apple TV app **Fusion** as his reference for how Home should feel.

**Evidence** (all in this repo):

| What | Where |
|---|---|
| Frame-by-frame triage of his 6.6-min video (NuvioTV and Fusion side by side, measured) | `docs/research/steven-beta19-rc1-video-triage-2026-10-02.md` |
| 31 named frames and kymographs | `docs/research/steven-beta19-rc1-video/` (file names start with mm:ss) |
| His photos (Fusion vs NuvioTV, tab bar, labels) | `docs/research/steven-beta19-photos/` |
| The fix plan for his verdict, with code citations | `docs/steven-beta19-rc1-verdict-batch-plan-2026-10-02.md` |

## What he likes (keep these)

- **Depth Takes Poster Color:** "WOW". The depth edge and the focus ring take the focused poster's dominant colour. It is his favourite recent change.
- **Type:** the current type is "perfect": system font, with Open Sans Regular for descriptions and Semibold for the rest.
- **The tab bar now hides completely on scroll,** including after a tab switch.

## What he dislikes on Home, with measurements

### 1. Motion: "titles constantly reposition"

This is his top complaint, and he says it makes the app feel unstable.

**NuvioTV.** One Down press produces four separate visible movements over about 2 s:

1. **Row slide.** About 625 pt; within 10 px of rest at 0.7 s, settled at 1.15 s. The label and the posters move together. The outgoing row is sliced by a hard mask line under the hero's CTA for 4–5 frames.
2. **Creep.** A 3–4 px undershoot that creeps back over 0.6 s.
3. **Hero cross-fade.** It happens 0.4–0.5 s after focus settles. The old and new logo, meta and synopsis overlap in the same spot for about 3 frames, which reads as a "doubled title". The hero visibly lags focus.
4. **Late title step.** The row title alone drops about 9 pt in 0.17 s, 1.9–2.3 s after the press and 0.2–0.3 s after a hero swap; the posters stay put. The cause is two app timers that keep adjusting rows after the system's own scroll: a settle corrector, and a held title slide that is released late.

**Fusion.** One ease-out of about 1.0 s per press, and the whole page scrolls. The label and the posters stay locked together, and nothing moves after the scroll settles. The hero scrolls away with the page, so nothing cross-fades above the focused row. Titles sit under each poster.

**He also says navigation feels smoother with the hero off or with the Nuvio hero off.** In code terms, Nuvio hero off drops Home into a "classic" mode with no corrector and no title tracking. He does not like the hero-off look, though: there is no synopsis.

**Design implication.** The pinned-hero-above-scrolling-rows model is where the instability comes from:
- The hero and the focused row compete for the same vertical band.
- The hero content swaps on every focus change.
- The app nudges rows after the engine has already rested them.

A redesign that gives one motion per press (a page scroll like Fusion's, or a hero that does not swap in place) removes the whole class, rather than tuning timers.

### 2. Inline trailers on posters

- **Ring colour.** When a poster morphs into the playing trailer card, the ring goes back to the plain accent colour (white) instead of the poster colour. The morphed card's ring is hard-coded.
- **Morph glitches:**
  - When focus leaves a card whose morph has just started, the next poster is pushed right and a ghost of the landscape logo spans the gap for about 0.2 s. He calls this the "first poster" glitch.
  - An empty frame when a morph starts.
  - An empty slot when a card collapses.
  - Poster and landscape art drawn side by side mid-morph.
  - A morph that starts and aborts with focus unchanged.
- **The morph adds a second motion source.** It widens the card and scrolls the row horizontally (twice: at 0 and 450 ms) while the vertical settle may still be running. The dwell is 1 s from focus, so it often fires before the row has rested.
- **His ask:** a "Trailer Start Delay" option of 1–3 s.
- **After a while, trailers stop playing entirely until relaunch.** The cards morph to a still and collapse back. The first failure in the video comes right after an Infuse hand-off (the app is suspended). The likely cause is the loopback HLS server that every split-stream trailer needs: it has no timeout and no restart. This is being fixed in the verdict batch.

**Design implication.** Decide whether a Home poster should morph into a playing landscape card at all, or whether the trailer should play somewhere that never moves row geometry: the hero or background area (Fusion plays its trailer in a card too, but in a layout where the row is stable). If morphing stays, it must start only after the row is at rest and must keep the poster-colour ring.

### 3. Colour and brightness: "cold, dull, slightly too dark"

- He means the whole app, not just Detail.
- Nothing in the image pipeline alters colour.
- What differs from Fusion:
  - Fusion paints the screen with a **full-colour ambient background taken from the focused title**, a bright blurred multicolour wash behind the rows (see the Fusion frames at 4:48–5:26 and `docs/research/steven-beta19-photos/2026-10-02-rc1-oak-street-fusion-switcher.jpg`).
  - NuvioTV is near-black: background `0x0D0D0D`, surfaces `0x1A1A1A`/`0x242424`, an outline with a slight teal cast.
  - The Home hero scrim is black 0.55 at the top, then the background colour from 0.85 to opaque at the bottom; the Nuvio hero also masks the art's left third.

**Design implication.** An ambient poster-colour background would directly answer "cold/dull/dark". It also extends the poster-colour idea he loves. The Detail/Settings revamp deferred this as an option, so it is free for Home.

### 4. Sharpness: "posters and backdrops look blurry"

- This is confirmed and is not a design problem: every image is decoded at no more than 1920 px, while a 4K Apple TV draws 1920 pt at 2× = 3840 px.
- Posters are also w500, which gets upscaled when the card lifts.
- The verdict batch fixes the decode size (per view: points × screen scale) and moves posters to w780.

**Design implication:** any new full-bleed hero or ambient layer must request and decode at 3840 px. Large posters need at least w780.

### 5. Row edge fade

- He wants the left and right edges of rows to fade gradually into the screen edge, like other Apple TV apps.
- The current "Soft" fade is a 140 pt linear ramp that starts at the row's edge and runs out into the overscan, so it reads as abrupt.
- At Medium+ the ramp is narrower than one card, so portrait rows barely fade.
- He also wants the fade in Detail rows and inside collections.
- The verdict batch widens it to about one card stride with an eased curve.

**Design implication:** design the fade as part of the row, and use it everywhere rows appear (Home, collections, Detail, Search).

### 6. Collections should follow Home's visual logic ("Follow layout", FEAT-43)

- Inside a collection folder, he wants exactly Home's look and behaviour: the same rows, fade and motion.
- Today it is a plain grid. Build 133 also regressed it:
  - the title vanishes after 8 pt of scroll;
  - the genre chips scroll away on the second press;
  - both come back as abrupt steps.
- He wants the title always visible, rising gradually as he scrolls.

**Design implication:** if the redesign defines a reusable "rows page" (hero area, rows, fade, motion rules), collections should be a second instance of it.

### 7. Smaller Home items

- **Up into the first row when Continue Watching is empty:**
  - When the first row is the short Genres chips row, Up from row 2 skips it and lands on the hero; he then has to press Down once.
  - With Continue Watching present it works.
  - The code only scrolls on an Up into the hero; it never redirects focus.
- **Tab bar sometimes stuck half visible** after launch (probe `y=-13 st=part`); a tab switch fixes it.
  - UIKit moves the top tab bar 1:1 with Home's tracked scroll offset and never snaps it.
  - So any Home rest position between 0 and the bar height leaves it half shown.
  - **A redesign should rest Home at offset 0 at the top.**
- **Hero content bugs:**
  - a hero with no title or logo at all (Comme des frères, 0:24–0:36);
  - a stale hero item shown for about 1 s after returning from a collection.
- The striped Netflix tile in Services de Streaming is just an animated cover, not a bug.

## In flight elsewhere: don't duplicate, but plan around

**Steven verdict batch** (plan above; local session, separate clone, waiting on Christian's approval). Fixes on today's Home:
- one motion per press (corrector/slide rules);
- trailer morph gated on rest, and its glitches;
- poster-colour ring on the morphed card;
- the trailer server wedge;
- image decode size and w780 posters;
- edge-fade ramp;
- collection header;
- tab bar snap;
- Up into Genres;
- a Trailer Start Delay setting under Settings → Home Screen;
- hero text fade out-then-in.

If the redesign replaces the pinned-hero Home, several of these become moot. **Tell Christian early which ones**, so the batch can drop them.

**Detail + Settings revamp** (separate session, branch `claude/detail-settings-revamp`):
- owns `DetailView.swift`, all Settings panes except Home Screen, About → Developer, and `Localizable.xcstrings`;
- its Settings re-sort keeps "Home Screen" as its own pane, so redesign settings belong there.

## Questions worth asking Christian before the redesign is planned

1. **Hero model:** keep the pinned hero above the rows, or scroll it away with the page like Fusion? Steven's experience and the measurements both favour one page scroll.
2. **Inline trailers:** in-row morph, hero/background playback, or both with a setting?
3. **Ambient poster-colour background:** in scope?
4. **Titles under posters** (Fusion) or above rows (today)?
5. **Collections:** the same page component as Home (FEAT-43)?

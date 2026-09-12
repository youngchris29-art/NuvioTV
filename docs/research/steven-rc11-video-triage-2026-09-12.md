# Steven's rc11 video — frame-level triage (2026-09-12)

Source: `~/Downloads/IMG_8685.mov` (189.6 MB, 3840×2160, 30 fps, 60.1 s), from https://fromsmash.com/2WVg-7X8.l-ct
(sent 09-11 11:37 PM ET, expires ≈ 09-18). Steven's Apple TV 4K on beta.18-rc11 (build 128), French UI,
**Medium+ posters, Hide Titles ON, carousel hero, zoom on, system font** (his Row Settle pane from the same evening
reads regime `P351c0p0r0z0t37`). Tab bar in classic (top) mode. Evidence in `steven-rc11-video-frames-2026-09-12/`
(1 fps contact sheets, 12 s each; named frames at 2 fps; a 5 fps burst for 36–43 s).

## Timeline

| t (s) | What is on screen | Finding |
|---|---|---|
| 0–1 | Profile picker → Home | normal |
| 1.5–4 | Home at the top: tab bar, Muppet Show hero, **Genres** row (Action / Animation / Aventure / Comédie) with its title, "Nouveaux films" title below | normal |
| 4.5 | Focus on the Action tile | hero cross-fades to the folder hero ("Ouvrir le dossier"); both title logos visible mid-fade |
| 5.0–5.5 | Down onto "Nouveaux films" | row lands with the title readable, then the lifted focused card overlaps the title's lower half (belt intrusion) |
| 6–23 | Walk down: Top 10 des films, Nouvelles séries, Top 10 des séries, Studios | titles visible on every row on the way DOWN; tab bar gone from 6 s on |
| 24–33 | Last row "Services de Streaming" (Netflix → Disney+ → prime video → Paramount+ → HBO max → Apple TV) | at 25.5 s the title is readable above the row; at 31.5 s (Apple TV focused) the **title is gone** — faded by the belt at the same rest (the pane's `belt fire … margin=-13 reason=rest armedFor=833ms`); the row itself rests in the same place both times, so the rc11 last-row shaping holds at Medium+ |
| 33.5 | Warner Bros focused, back on the Studios row | normal |
| 34.5 | Up into "Nouvelles séries" | **title hidden** — the row's top sits under the hero, "Top 10 des séries" readable below |
| 35.5–36.0 | Up into "Top 10 des films", then "Nouveaux films" | titles half under the hero's bottom edge ("catalog names still disappear") |
| 36.5–41.6 | Focus on Onslaught in "Nouveaux films" (row 2); at least four Up presses (hand visible on the remote) | **BUG-112:** nothing moves vertically. The hero stays Onslaught, the focused card stays Onslaught (the row only re-centres by one card twice), the Genres row never appears |
| 41.6–42.5 | Back (Menu) press | hero cross-fades to Muppet Show, the Genres row and the tab bar slide in together — the top-of-Home state |
| 47–49 | Settings | normal |
| 50–59 | Second Home walk: Genres → Nouveaux films (Mayday) → Studios (GIGN hero) → Top 10 des séries → Top 10 des films (Debt Collector) | **tab bar stays pinned over the hero on every row**, even five rows deep — the "after a tab switch it stays visible all the time" state |

## Mechanisms (what the video settles, what it cannot)

- **BUG-112 (genre row unreachable on the walk back up) is reproduced on camera**, and it is a focus failure, not a
  render failure: with row 2 focused, the Genres row is scrolled entirely under the pinned hero and Up does
  nothing; Back rebuilds the top-of-Home state. Working hypothesis: on the walk back UP the upper rows park
  ≈105 pt deeper than on the walk down (the pane's newest four belt lines: `margin=-102…-108 slide=72 intr=68`
  on `tmdb.latest`, `fr.apertaa.top10.custom`, `tmdb series`, collection `3612bd0d…`; the corrector's nudges are
  undone, `UNEXPECTED-WITH-FIT bound=93`), so the row above the focused one lies fully behind the hero overlay.
  The tvOS focus engine treats a fully occluded item as unfocusable, so Up finds no target. rc10 did not show
  this on his device (his rc10 pane parked the middle rows in band). Candidates in the rc11 diff: the
  `rowCardLinkFrameFloor` label frame (published for the last row only — verify it is not leaking into other
  rows through the environment) and the settlePlan last-row exemption. Reproduce on FA87 at Medium+ with Hide
  Titles ON: walk to the last row, walk back up to row 2, press Up, read the Row Settle pane.
- **"Catalog names disappear" at Medium+ = the belt fade + the deep park on the way up.** On the way down every
  title is readable; on the way up the row's top lands under the hero and the belt fades the title (by design
  when it would intrude). Same root as BUG-112: fix the up-walk park and the titles come back.
- **Tab bar (BUG-66):** two states in one recording. Launch-time Home: the bar scrolls off with the content and
  returns at the top (the pane's `minY` walk, `hidden=0 alpha=1` throughout). After visiting Settings and
  returning: the bar stays pinned over the hero at every depth. "No longer split" per Steven. The two states
  are two containments of the same UITabBar; the probe recorded only the first.
- **Medium+ (FEAT-39):** cards, hero compression and the row rests look right at every depth; he calls it
  "absolutely perfect" and now runs it daily.
- **Medium title bounce:** not in this video (recorded at Medium+). Still open per his text.
- **Not shown:** the Row Settle walk itself (his pane is a separate photo at Medium+, not Large as he said),
  the rc10 collection-scroll-position reset (BUG-113), the landscape-collection ask (FEAT-43, photos).

## Frame index

`03.5s-launch-home-top-tabbar-genres`, `05.5s-nouveaux-films-title-clipped-by-lift`,
`06.0s-walk-down-top10-title-visible-no-tabbar`, `25.5s-last-row-netflix-title-visible`,
`31.5s-last-row-appletv-title-faded`, `34.5s-walk-up-nouvelles-series-title-hidden`,
`36.0s-walk-up-nouveaux-films-title-under-hero`, `36.5s-bug112-nouveaux-films-focused-genres-gone`,
`39.5s-bug112-up-press-no-genres`, `41.5s-bug112-up-press-no-genres-2`, `42.0s-bug112-back-press-genres-return`,
`42.5s-home-top-after-back`, `53.5s-second-walk-tabbar-pinned-mayday`, `56.5s-second-walk-tabbar-pinned-gign-deep`,
`59.5s-second-walk-tabbar-pinned-top10`, `burst-5fps-36s-43s-bug112`, `contact-sheet-1…5`.

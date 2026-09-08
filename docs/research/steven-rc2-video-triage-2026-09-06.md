# Steven's rc2 video — frame-level triage (2026-09-06)

Source: `~/Downloads/IMG_8477.mov` (589 MB, 3840×2160, 30 fps, 186.6 s), Steven's Apple TV 4K on beta.18-rc2
(build 118), French UI, **Show Hero ON** for this recording (his daily profile runs it OFF), Large posters with
Hide Labels ON until ~143 s, then Medium after a relaunch. Sidebar (FEAT-30) and Open Sans (FEAT-31) enabled.
Evidence crops in `steven-rc2-video-evidence/` (10 fps and 30 fps contact sheets; grid position × step = time).

## Timeline

| t (s) | What is on screen | Finding |
|---|---|---|
| 0–15 | Profile picker → Home, Large, hero ON, "Top 10 des films" then "Nouveaux films" | normal |
| 20–24 | Down to "Top 10 des films" (from above) | label visible for a full second after landing (23.0–24.0) |
| 24.1 | first horizontal move within the row | **label gone on that frame and never back** (Large title hiding, BUG-87/88) |
| 32–35, 38–39, 42–43 | "Nouvelles séries", "Top 10 des séries", "Genres" | same: label hidden after travel |
| 48–56, 64–68 | last row "Services de Streaming" at Large | **rests ≈90 pt deeper than a middle row; Genres tiles clipped above it** (BUG-89) |
| 69–71 | Up into "Top 10 des séries" (entering from below) | label **fades** out (belt fade, not a cut) |
| 73–86 | "Sur tes traces" detail → trailer bridge → back | bridge OK; pill absent because Home was scrolled down |
| 88.8 | Up to the first row | pill "Accueil" appears once, cleanly (no flicker caught at 30 fps in this window) |
| 90–92 | Up again → sidebar expands | normal |
| 93–109 | Search → "Avatar" detail | **pill "Rechercher" painted over the whole detail page** |
| 110.4–111.0 | bridge leave | caption **scales in 1.25→1** ("title resizes"); caption is **text**, page header is a logo; two caption copies ≈30 px apart for 2 frames at the cover hand-over |
| 114.5–115.5 | bridge return | hard cut to the enlarged still, 1.2 s hold, chrome fades in — as designed |
| 117–122 | detail scrolled: Casting, "Avatar – Saga" row, extras | **Saga row = bare posters** (Hide Labels ON reaches the detail row) |
| 128–143 | Settings walk, Large→Medium | category list in the system face, panes in Open Sans |
| 153–163 | relaunch, Home at Medium | labels visible |
| 164.9–165.6 | Down onto "Top 10 des films" at Medium | **lands, then slides up ≈50 pt over 0.4 s** (corrector's second move = "titles bounce") |
| 174–180 | last row at Medium | same deep rest with Genres tiles peeking |

## Mechanisms (what the video settles, what it cannot)

- **Sidebar over detail pages (new, real bug):** `MainTabView` applies `.environment(\.tabBarVisibility)` on the
  `TabView` and attaches the sidebar as an `.overlay` OUTSIDE it, so the overlay's environment read resolves to
  the unconnected default instance and `immersiveHidden` never arrives. The pill hid on Home's detail only because
  Home was scrolled down (resting rule), not because of the push.
- **Bridge caption:** the 1.25→1 `captionScale` is the resize he calls odd; the caption renders `Text(title)`
  where the page header renders the logo image; the description copy and the player copy are placed by two
  different modifier chains.
- **Saga row:** `collectionRow` uses `PosterCard` with the user's Hide Labels setting.
- **Settings categories:** the category `Text`s carry no font token (List default), every other label uses
  `Theme.Font.body`.
- **Rows on hardware (BUG-87/88/89 family):** the focus engine parks rows deeper than the simulator at both sizes
  (last row ≈90 pt; Medium landing ≈50 pt before the corrector slides it up). At Large the title survives a
  landing from above and dies on the first horizontal move; entering from below it fades. The video cannot say
  which corrector/belt branch fires (`disarmed`, `pullback`, `endOfContent`, belt `arm`/`fire`): that needs the
  device's `[HomeScrollProbe]` lines → the Row Settle Diagnostics pane (About) built for rc5 so a photo carries
  them, and Christian's own Living Room pass.
- **Pill flicker on Up mid-scroll:** not captured in the 30 fps window around 88.8 s (the pill appeared once);
  the mechanism consistent with his description is the show edge re-crossing the scroll hysteresis while the
  settle corrector nudges the scroll near the top → a show-edge settle delay is the fix in rc5.

## rc5 batch (from this triage)

W1 sidebar (immersive hide reaches the overlay; corner position ≈(60, 40) pt from the screen edge; 0.35 s
show-edge settle) · W2 bridge caption (logo, no scale, one placement for both copies) + Saga captions ·
W4 Settings category font · W5 last-row inset floor + `heroPinnedRowsDeviceParkSlack` (96) + Row Settle
Diagnostics pane. Not fixed by rc5, by design: the Large title hiding and the Medium land-then-slide need the
device numbers first.

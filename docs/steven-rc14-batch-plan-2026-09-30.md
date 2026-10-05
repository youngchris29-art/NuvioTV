# Steven rc13 verdict → rc14 batch plan (2026-09-30 evening)

Source: Steven's rc13 DM (7:00–7:14 PM ET, six chat photos, Smash bundle `IMG_8846.mov` + six Row
Settle pane photos + one colour-border example, all in `~/Downloads/steven-rc13-2026-09-30/`), the
09-30 handoff backlog (BUG-121/122/123, BUG-119, restErr placement), and the device-walk logs in
`docs/research/device-walks-2026-09-30/`. Goal set by Christian: plan, fix everything on the list,
produce a Debug device build on the Living Room ATV for his test. Nothing merges, pushes, cuts or
sends without his go.

## What the evidence says

- **Fast-scroll bounce (his P1 residual).** Rests are fixed (every settle line `inBand=1 nudge=0`
  in his fast and slow panes; 0 belt fires in every post-fix device walk). What still moves is the
  BUG-37 *title slide*: a row that is scrolling away under the hero gets its title pushed down by
  `min(clip, 72)` so it stays visible, and the slide is animated per reading. His fast pane shows
  every departing row arming at `margin=-89..-107 slide=72 intr=62`; the slow pane at
  `margin=-18..-38 slide=18..38`. The video (22.8 s, 10 fps) shows the "Top 10 des films" label
  painted over its own departing posters right under the hero. On an Up walk the same slide puts
  the arriving focused row's title on its posters (slide 72 → 8) during the reveal.
  → **Fix:** the slide is a REST remedy. Apply it only to the focused row and only when the rows
  scroll is still (120 ms post-motion re-check); unfocused rows clip naturally.
- **Swipe-up leaves Genres under the hero (BUG-112 residual).** The engine moved focus row → CTA on
  the swipe (skipping a mostly clipped Genres); the catcher saw a consumed swipe and declined, and
  nothing scrolls the rows when the hero gains focus (deliberate ban on focus-triggered scrolls).
  → **Fix:** an Up INPUT (press or swipe, within 500 ms) that lands focus on the hero while the
  rows are scrolled past the first row scrolls to `home_top`. Input-triggered, same class as
  BUG-114's CTA scroll, not a focus-triggered one.
- **Thick border at Bold/Balanced (BUG-110).** On a focused ring-mode card the depth rail
  (1/2/3 pt white at .35/.60/.90) is drawn right inside the 4 pt accent ring; unfocused Bold cards
  carry a 13 pt inward halo band. Video 6.5 s / 12.5 s: bright rims on every tile and poster.
  → **Fix:** no rail or halo on the focused card (the focus treatment owns that edge); halo
  removed everywhere; rail widths unchanged (1/2/3), Bold top alpha .90 → .80.
- **Bold text everywhere.** `Theme.Font.meta` is semibold in both families and is what Settings
  subtitles, hero/detail meta lines and Detail info rows use. `SettingsRowFont` captures fonts in a
  `static let`, so a typeface switch does not reach Settings until relaunch.
  → **Fix:** `meta` → `.medium` (both families); Settings subtitles/values and Detail info values
  → a new regular `detail` token; `SettingsRowFont` computed.
- **One synopsis line on Home + synopsis too big.** Synopsis is `body` (29 pt, 35 pt lines); the
  carousel slot gives its 36 before the logo gives, so Large and Medium+ carousels show one line.
  → **Fix:** new `synopsis` token (caption1, 25 pt, regular; measured line height) for Home + Detail.
  Hero chrome shaved 20 pt (top pad 32 → 24, gaps 16 → 12), the frame slack (now 22) is spent first,
  then the logo (give 34), then the synopsis. Result (system face): Medium+ carousel 2 lines with
  a full-height logo, Large carousel 2 lines, panels 4 lines. Open Sans: Large carousel stays 1.
- **Episode ratings.** Shared already has `EpisodeRatingsVisibility` (show all / hide / watched
  only) in `MetaScreenSettingsRepository`; tvOS never read it. → wire + Settings picker.
- **Row Edge Fade picker does nothing.** No app-drawn fade exists; the four modes only change the
  tvOS scroll-edge style, which his hardware renders identically. The asymmetry he filmed is the
  system effect at the trailing screen edge vs the hard leading clip. → **Soft** becomes an
  app-drawn symmetric mask (48 pt, leading side only once the row has scrolled); System/Hard/Off
  keep their meaning.
- **Detail backdrop dull + blurry.** Scrim trailing stop is .85 black plus a centre→bottom .9
  gradient; the image is the addon's `background` as-is (Cinemeta = metahub `medium`), TMDB `w1280`.
  → lighter scrim (trailing .30, bottom gradient from 55 %), URL upgrade metahub `medium → large`,
  TMDB `w1280 → original`, with the original URL as fallback.
- **Collection logo too close to the posters (FEAT-40).** Header top pad 60, 56 pt to the grid.
  → top pad 44, gap 72 (logo up 16, posters unchanged).
- **Dynamic poster-coloured border (new FEAT-46).** Opt-in: the focus ring takes the focused
  poster's dominant colour (16×16 downsample, saturation-weighted mean, lifted to a ring-usable
  HSB). Computed on focus from the image cache, one state write per focus.
- **BUG-122 (top rows park low).** CW +55, Upcoming +130/+160, first folder row +128 on every walk:
  short label frames let the engine bottom-anchor them, then the corrector pulls them up (the one
  visible jump). → the rc11 last-row floor generalised to CW/Upcoming/collection rows, with the
  layout growth cancelled by a matching negative bottom padding (the focusable frame grows, the
  visible spacing does not); plus no correction at scroll offset 0 (the first row cannot be pulled).
- **BUG-121 (late content).** First settle at +410..+540 with `armSrc=retry` before the engine has
  revealed the row; two −220 nudges. → a rest whose margin exceeds the row height is deferred
  (up to 4 × 0.25 s) before any correction.
- **BUG-123 (last-row idle fade).** 0 fires in every post-fix walk; the 36 ms flicker was the
  focused/unfocused clearance switch on a pre-fix −12 rest. Covered by the hold fix + the slide
  gate; no separate code.
- **restErr unreadable.** The field sits mid-line and the pane truncates the middle. → appended
  last.
- **BUG-119 (hero-off, folder focused: no title/description).** The panel renders a folder hero
  logo-only (FEAT-29). → the panel form shows the folder's name as the meta line and
  "Collection · N titles"-style text in the synopsis slot.

Not in this build: BUG-66 (no pane data from either TV), FEAT-36/45 (product features),
comms (GitHub #3/#4, Reddit `pcvq3mr`) — drafts stay owed for Christian's go.

## Waves (file ownership)

- **Me:** Theme tokens (synopsis/detail/meta), `BrowseComponents.swift` (slide gate, restErr,
  BUG-121 guard, BUG-122 band + floor), `HomeView.swift` (hero-focus Up scroll, hero chrome +
  give order, BUG-119 panel text, short-row floor plumbing), `UpcomingRow.swift`,
  `PinnedRowGeometry.swift` + its tests.
- **Agent A (DesignSystem):** `CardDepthStyle.swift` rail/halo; `RowEdgeEffectStyle.swift` Soft mask.
- **Agent B (Detail/Settings):** episode-ratings wiring (`DetailViewModel`, `EpisodesSection`,
  `DetailView`, `SettingsViewModel`, `AppearanceSettingsPane`), Detail scrim + backdrop upgrade,
  FEAT-40 header spacing (`CollectionsUI.swift` header only), `SettingsRowViews` fonts, the
  FEAT-46 toggle row.
- **Agent C (ring colour):** `ArtworkColorStore.swift` (new), `CachedAsyncImage` cache lookup,
  `PosterCard`/`SagaCard`/`FolderTile` ring colour.
- Then: NuvioTVTests + Debug sim build + Release sim build; one internal Opus review round; fixes;
  Debug device build with the bundle-ID override; `devicectl` install on the Living Room ATV.

## Device checklist for Christian (Medium+ and Large, zoom on, carousel)

1. Fast Down/Up walk: no title rides over posters under the hero; titles settle once.
2. Swipe Up from row 2 to the hero: Genres row fully visible at the top, not faded.
3. Card Depth Bold: no double border on the focused poster; unfocused rims thin.
4. Home hero: 2 synopsis lines at Medium+ and Large; Settings subtitles not bold.
5. Settings → Appearance → Episode Ratings: Hide → no badges on Charmed.
6. About → Row Edge Fade → Soft: both row edges fade; System unchanged.
7. Detail page: brighter backdrop, sharper image (compare Toy Story 4).
8. Open a collection: logo sits higher.
9. Appearance → "Ring Takes Poster Colour": ring colour follows the poster.
10. Top of Home: no jump on CW/Upcoming/first folder row; late addon rows no double nudge.
11. Hero off + folder focused: panel shows the folder name and a description line.

## OUTCOME (2026-09-30 evening, submodule branch `claude/steven-rc14-batch` off rc13 `a9dba967`)

Everything in the waves above was BUILT the same evening. Record of what landed, by item:

| Item | What shipped | Where |
|---|---|---|
| Fast-scroll bounce (BUG-87/89 residue) | The BUG-37 title slide is held while the rows scroll is in motion (120 ms post-motion re-check) and a title that is off screen even after sliding gets 0 — so no departing row's title rides its posters and no arriving row carries a stale 72 on an Up walk; rest behaviour unchanged | `BrowseComponents.swift` `PinnedRowTitleTracking.applySlide`, `TitleTrackingCache.pendingSlide` |
| Swipe-up leaves Genres under the hero (BUG-112 residue) | Input-gated reveal: an Up input (press via `handleHeroUp`/`handleRowsMove`, swipe via the catcher's new `onAnySwipeUp`) that lands focus on the hero within 0.5 s of a row releasing focus, with the rows past the first row, scrolls to `home_top`; a 0.25 s deferred re-check covers the swipe-after-focus order | `HomeView.swift` `revealTopAfterUpIntoHero`, `HomeUpInputBox`; `HomeUpSwipeCatcher.swift` |
| Thick border (BUG-110) | No rail or halo on the focused card; halo removed everywhere (`railHaloSpread` = 0); Bold top alpha .90 → .80; widths 1/2/3 kept | `CardDepthStyle.swift`, `CardDepthRailStyleTests` |
| Bold text | `meta` → `.medium` both families; Settings subtitles/values and Detail info values on the new regular `detail` token; `SettingsRowFont` computed so a typeface switch reaches Settings live | `Theme.swift`, `SettingsRowViews.swift`, `DetailView.swift` |
| One synopsis line / too big | New `synopsis` token (caption1 25 pt, regular) on Home + Detail with its own measured line height; hero chrome shaved 20 pt (pads 12, gaps 12 → 22 pt frame slack); give order slack → logo (34) → synopsis. Medium+ carousel: full logo + 2 lines; Large carousel: logo 76 + 2 lines (system face; Open Sans stays 1 at Large); panels 4 lines | `Theme.swift`, `PinnedRowGeometry.HeroSlotGive.split`, `HomeHeroForeground` |
| Episode ratings toggle | Shared `EpisodeRatingsVisibility` wired: Settings → Appearance → Poster Style → "Episode Ratings" (Show / Watched Only / Hide), watched in `DetailViewModel`, applied in `EpisodesSection.rating(for:)` | `SettingsViewModel`, `DetailViewModel`, `EpisodesSection`, `AppearanceSettingsPane` |
| Row Edge Fade picker (BUG-118) | "Soft" is an app-drawn symmetric mask (48 pt ramps: leading inside the frame once the row has scrolled, trailing in the screen margin); System/Hard/Off keep their meaning | `RowEdgeEffectStyle.swift` |
| Detail backdrop dull + blurry | Scrim trailing stop .85 → .30 (.40 over the poster layer), bottom fade from 55 %; URL upgrade metahub `medium → large`, TMDB `w1280 → original` with the original as fallback (the cached medium shows as the placeholder while the large loads) | `DetailView.swift` `DetailBackdropURL` |
| Collection logo too close (FEAT-40) | Header top pad 60 → 44, grid gap 56 → 72: logo up 16, posters unchanged | `CollectionsUI.swift` `FolderDetailView` |
| Poster-colour ring (new FEAT-46) | Appearance → "Ring Takes Poster Color" (shown when the accent ring or No Zoom is on, default off): the focused card's ring / still highlight takes the artwork's dominant colour (16×16 saturation-weighted mean, lifted to s ≥ .55 v ≥ .85, grey → accent); sampled once per URL from the image cache on focus gain, never downloaded | `ArtworkColorStore.swift` (+ tests), `PosterCard`, `SagaCard`, `FolderTile`, `CachedAsyncImage.cachedImage(for:)` |
| Top rows park low (BUG-122) | rc11's last-row floor published on Continue Watching, Upcoming and collection rows (About → "Short Row Floor (A/B)", default ON), layout growth cancelled by a negative bottom padding AFTER `.focusSection()`; a rest at scroll offset 0 with the row below the band is left alone (`topRest=1`); `restPred` uses the floor where it governs; `shortShaped=` on the settle line, `lastRowShaped` now last-row only | `HomeView.swift`, `UpcomingRow.swift`, `CollectionsUI.swift`, `PinnedRowGeometry.shortRowLayoutCompensation`, `BrowseComponents.settlePlan` |
| Late content (BUG-121) | A rest whose margin exceeds the row height is deferred twice (0.5 s) before any correction | `BrowseComponents.settlePlan` `lateRestDeferral` |
| restErr unreadable | The `restPred=/restErr=` pair is moved to the END of the pane line (`restLawToTail`); the console line is untouched | `BrowseComponents.swift` |
| Hero-off folder focus (BUG-119) | The panel form renders a folder through the three-slot column: collection name as the meta line, "folder · N sources" in the synopsis slot; the carousel keeps the merged logo-only box | `HomeView.swift` `folderHeroPreview`, `nuvioLayout` |
| BUG-123 | 0 belt fires in every post-fix device walk; covered by the hold fix + the slide gate, no code | — |

**Review round 1 (internal Opus, read-only):** 2 P1 + 5 P2 + 5 P3, all addressed except one P2 that was a misread (`CachedAsyncImage` shows the cached fallback as the placeholder while the upgraded primary loads — `InitialRender.showFallbackThenFetchPrimary`) and one P3 kept as a note (the 43.5 pt caption constant over-cancels by ≈4 pt under Open Sans). P1s: the held slide re-applied a stale 72 to the row coming back on an Up walk (fixed: off-screen → 0); the short-row negative padding sat BEFORE `.focusSection()`, the shape that froze directional focus on device in rounds 2–3 (fixed: after the section, and the whole floor behind the About A/B knob for the device pass).

**Side effects to know:** the wider carousel give cap (70 → 92) makes two non-default plans fit that used to fall back to the belt: Large + captions + carousel in No Zoom (compression 92, 1-line synopsis, logo 76) and the zoom-on hold-OFF A/B leg (compression 90.3). Steven's regimes (held, zoom on) keep their rc13 numbers (68.33 / 15.95). At Small/Medium (compression < 22) the 330 pt hero content is centred in the 352 pt frame, so the info block sits ≈10 pt lower than rc13.

**Gates:** Debug + Release simulator builds green on the first compile; NuvioTVTests 439 (all green after the two stale expectations were updated: `meta` weight, late-rest retries); UI tests not run (test63's `lastRowShaped` oracle is protected by the last-row gate). Codex unavailable (model setting), so the review round was an internal Opus agent.

**Device build:** submodule commit `2e762d67` on `claude/steven-rc14-batch`; Debug, bundle-ID override `com.youngchris29.NuvioTV`, installed and launched on the Living Room ATV over `devicectl` — see the chat for the install record and the checklist above. Nothing merged, pushed, cut or sent.

### Device rounds (Christian, Living Room ATV, 2026-09-30 21:30–22:00 ET)

- **Round 1** (`2e762d67`): checklist items 2–7 and 9–11 PASS. Item 1 FAIL — titles still overlapped and jumped into place on the **Up** walk (Down clean). Item 8 FAIL — collection logo still not high enough.
- **Round 2** (`63573d91`): slide gate also holds while the title's own frame changed within 120 ms (the engine's Up-reveal creep is below `noteScroll`'s 4 pt drift tolerance); collection logo top-aligned in its slot and the header pad 44 → 32. Item 8 PASS. Item 1 still FAIL — and the streamed console had the answer: `slide apply row=collection-erfs5gwk-community-2 from=72 to=8` — the applied slide was already 72 before the rest although every apply during the approach was held. The row had been recycled by the `LazyVStack` and re-mounted above the viewport; its first reading took the SEED path, which wrote the measured 72 with no gate and no off-screen rule.
- **Round 3** (`a4062ea2`): the seed seeds 0 while the rows are moving and the off-screen-ruled measurement otherwise (`PinnedRowTitle.appliedSlide`, shared with `applySlide`, unit-tested). **Item 1 PASS — "no more overlaps on the up scroll".** Log: every `slide apply` is `from=0 to=8` (departing rows `8 → 0`), 0 belt fires, 8/8 settles `nudge=0`. **11/11 on the checklist.**

Probe recipe that found it in one round: Debug device build + `devicectl device process launch --console --terminate-existing com.youngchris29.NuvioTV -- -debug.homeScrollProbe YES -debug.pinnedRowSettleProbe YES > log`, then `grep "HomeScrollProbe\] slide"` — the `from=`/`to=` pair on the apply line is the whole diagnosis.
- **Round 4** (`11d8e722`, from the verification workflow on the round-3 diagnosis — confirmed, 7 agents): a slide going to zero is never held (a legitimately deep slide no longer rides through the next Up press), the seed and the apply read the Reading's own `onScreen` verdict (observer-order independent; the cached-geometry form failed open to 72 in one ordering), the pre-seed draw frame obeys the off-screen rule. **Christian: "no overlaps on the up scroll" — 11/11 stands on `11d8e722`.** NuvioTVTests 441/441. Follow-up (workflow F1, not built): at a fast 0.8 s press cadence the 120 ms hold can lag the walk, leaving titles clipped ≈10 pt under the hero edge until the walk pauses — release on the per-row settle decision instead of the wall-clock re-check.

## CUT

rc14 CUT 2026-09-30 night (ET): `claude/steven-rc14-batch` fast-forwarded into `tvos-shared-extraction` (`11d8e722`), build 131 `4f26c0d4`, tag `tvos-v0.3.0-beta.18-rc14`, branch + tag pushed, feature branch deleted (and the cherry-picked `claude/reddit-thread-repoint` removed local + origin); unsigned Release device build stamped `NuvioBetaTag=tvos-v0.3.0-beta.18-rc14 NuvioCommitSHA=4f26c0d4`; IPA 27,293,145 B at https://litter.catbox.moe/u7gsbn.ipa (litterbox 72 h ≈ 2026-10-03 night ET, `content-length` verified; copy `~/Downloads/NuvioTV-beta18-rc14.ipa`); outer pointer `f98bbce`/`efd605d`. **rc14 DM SENT 23:19 ET** (`docs/comms-dm-drafts-2026-09-30-rc14.md`, 5/5, one copy verified); his verdict owed.

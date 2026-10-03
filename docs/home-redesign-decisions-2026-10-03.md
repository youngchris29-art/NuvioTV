# Home redesign: direction decided (2026-10-03)

**Status:** decided by Christian on 2026-10-03. No implementation plan yet, and no code written.

**Inputs**

- Options board: `docs/research/home-revamp-2026-10-02.html` (artifact https://claude.ai/artifact/W1rKJiqwEC32ZH1nyZepir).
- The handoff `docs/home-redesign-handoff-steven-beta19-rc1-2026-10-02.md`, which is Steven's beta.19-rc1 video measured against Fusion.

**Change since the first board:** the board's first pick was B (fixed stage + row strip). After Steven's measurements it became A, as a Fusion-style page.

## Decisions

| # | Question | Answer |
|---|---|---|
| H1 | Hero model | **Fusion-style page scroll.** A billboard carousel at the top that scrolls away with the page; native scrolling below; one motion per press. The pinned hero, its focus-following, and the pinned-row correction code are retired. |
| H2 | Where trailers play on Home | **Both, as a setting.** Trailer Location is either Background or In Row. **Background:** muted, behind the page or in the billboard, after the viewer rests, and stopped by any move. **In Row:** today's morph, started only once the row has rested, keeping the poster-colour ring. |
| H3 | Ambient poster-colour background | **Yes, on by default.** A blurred full-colour wash from the focused title behind the page. It cross-fades after a short pause and is decoded at 3840 px. A setting turns it off (OLED black users). |
| H4 | Titles | **A section heading above each row, plus item names under posters.** Hide Titles turns the item names off. The heading scrolls with its row and is never tracked separately. |
| H5 | Collections | **Same page component as Home (FEAT-43).** A folder is a second instance of it. The folder's title or logo is a header that rises gently on scroll. The grid view stays available as an option. |
| H6 | Pending fix batch `docs/steven-beta19-rc1-verdict-batch-plan-2026-10-02.md` | **Drop M2, M5 and N1. Keep the rest.** See below. |

### What H6 means for the fix batch

The new page makes three items unnecessary, so the batch drops them:

- **M2:** one-motion-per-press settle and slide rules.
- **M5:** hero cross-fade without double text.
- **N1:** Up into the Genres row with no Continue Watching.

Everything else survives the redesign, so the batch still ships it:

- **B:** trailer HLS listener wedge. Needed in any model that plays trailers.
- **I1:** 4K image decode and w780 posters. The new page depends on it.
- **F:** edge fade. Build it as a row-level modifier so the new page reuses it.
- **M3, R1, R2:** morph start gated on rest, the poster-colour ring on the morphed card, and the first-poster glitch. In Row stays as a choice under H2.
- **T1:** tab bar snap.
- **C:** collection header regression. It ships now; FEAT-43 replaces the page later.
- **M4:** Trailer Start Delay setting.
- **A:** Auto-Play Best Source ranking.

**For whoever runs the fix batch:** pass H6 on to that session and Steven's reply DM. The reply should say the Home motion fix arrives with the new page rather than as a tune of the current one.

## Rules the new page must meet (from the handoff)

- One motion per press. Nothing moves after the scroll settles.
- Home rests at offset 0 at the top, so the system tab bar is never left half shown.
- Every full-bleed layer (billboard, ambient wash, background trailer) requests and decodes at 3840 px. Large posters use at least w780.
- The edge fade is part of the row component and applies wherever rows appear: Home, collections, Detail, Search.
- Keep: Depth Takes Poster Color, the current type, and the tab bar hiding on scroll.
- The ambient wash and background trailer start only after the viewer rests, decode once per pause, and stop on any move. Never decode per press.

## Next step

Write an implementation plan in the same format as `docs/detail-settings-revamp-plan-2026-10-02.md`: evidence, specs from Opus Plan agents, waves split by file ownership, gates, and a device pass in the **Test** profile.

**Sequencing:**

1. Start the plan after the fix batch merges. Both touch `HomeView.swift`, `BrowseComponents.swift`, `InlineTrailerCard.swift` and `CollectionsUI.swift`.
2. The redesign's settings (Home Layout, Ambient Background, Trailer Location) live in the Home Screen pane. That pane is outside the Detail + Settings revamp's file ownership.
3. Keep today's layout as "Classic" for one or two betas, the same pattern as Detail.

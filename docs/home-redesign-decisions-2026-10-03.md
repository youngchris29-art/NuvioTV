# Home redesign: direction decided (2026-10-03, revised)

**Status:** decided by Christian on 2026-10-03. There is no implementation plan yet, and no code has been written.

**Inputs:**
- The options board `docs/research/home-revamp-2026-10-02.html` (artifact https://claude.ai/artifact/W1rKJiqwEC32ZH1nyZepir).
- The handoff `docs/home-redesign-handoff-steven-beta19-rc1-2026-10-02.md`: Steven's beta.19-rc1 video, measured against Fusion.

**Revision:** Christian first picked A (a page scroll in the style of Fusion), then switched to **B, Stage & Strip**. This document records B.

## Decisions

| # | Question | Answer |
|---|---|---|
| H1 | Hero model | **B, Stage & Strip.** The top ~54% is a stage that cannot take focus and shows the focused title: art on the right, and logo, meta and synopsis on the left. The bottom ~46% is a fixed-height strip that shows one row at a time, with the next row's heading peeking. Up and Down page whole rows, so each row lands in exactly one place. This retires the pinned hero above scrolling rows, its title tracking, and its settle correction. |
| H2 | Trailers on Home | **Both, as a setting.** The Trailer Location setting has two values. **Background:** plays muted in the stage behind its text, after the viewer rests, and stops on any move. **In Row:** the morph inside the strip, started only once the strip has stopped, keeping the poster-colour ring. The strip's height is fixed, so the morph widens the card only. |
| H3 | Ambient poster-colour background | **Yes, on by default.** A blurred full-colour wash from the focused title fills the strip and blends into the stage art. Decoded at 3840 px. A setting turns it off. |
| H4 | Titles | **The row heading sits at the top of the strip, and item names sit under the posters.** Hide Titles turns the names off. The strip's height leaves room for the names. The heading is never tracked separately. |
| H5 | Collections | **A second stage-and-strip page (FEAT-43).** The folder's logo or title appears in the stage. The grid view stays as an option. |
| H6 | Pending fix batch `docs/steven-beta19-rc1-verdict-batch-plan-2026-10-02.md` | **Drop M2 and N1. Keep M5 and everything else.** |

**H6 in detail:**
- **M2** (the one-motion settle and slide rules) and **N1** (Up into Genres) become unnecessary. The strip pages whole rows and the stage cannot take focus.
- **M5** (the hero text fades out, then the new text fades in) is the rule the stage needs, so it carries over. It was dropped under A; under B it goes back in.
- **Kept, unchanged:**
  - B: the trailer listener wedge.
  - I1: 4K decode and w780 posters.
  - F: the edge fade, built as a row modifier.
  - M3, R1, R2: the morph and ring fixes.
  - T1: the tab bar snap.
  - C: the collection header.
  - M4: the trailer start delay.
  - A: the Auto-Play ranking.

## What B must do to answer Steven's measurements

He measured four movements per press over about 2 s; Fusion makes one. B keeps exactly two moving things, the strip and the stage content.

- **The strip** makes one move per press. Nothing moves after it settles.
- **The stage content** swaps after one short pause (official NuvioTV uses 450 ms). The old text fades out before the new text fades in, so there is never a doubled title. The swap never changes the stage's size and never moves the strip.
- **Images:** the stage art, the ambient wash and the background trailer request and decode at 3840 px. Large posters use at least w780.
- **Tab bar:** Home rests at offset 0 at the top, so the system tab bar is never left half shown.
- **Edge fade:** part of the row component, used wherever rows appear.
- **Keep from today:**
  - Depth Takes Poster Color.
  - The current type.
  - The tab bar hiding on scroll.
  - The FEAT-15 info panel idea, which the stage now carries.

## Still open (ask before planning)

1. **How much of the next row shows:** only its heading, or a sliver of its posters too (official NuvioTV's "Show Preview Row")?
2. **Today's layout:** keep it as "Classic" for one or two betas, the same pattern as Detail?

## Next step

Write an implementation plan in the same format as `docs/detail-settings-revamp-plan-2026-10-02.md`. Start it after the fix batch merges: both touch `HomeView.swift`, `BrowseComponents.swift`, `InlineTrailerCard.swift` and `CollectionsUI.swift`. The new settings (Home Layout, Ambient Background, Trailer Location) live in the Home Screen settings pane, which is outside the Detail + Settings revamp's files.

**Reference implementations:**
- Official NuvioTV `ModernHomeContent.kt`: rows viewport at 52% height, focus inset 40 dp, hero debounce 450 ms.
- VortX: a stage that cannot take focus, with rails in a bottom strip.

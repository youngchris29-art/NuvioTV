# DM draft, beta.19-rc3 (2026-10-05)

To: u/mrStevenx3 (Reddit chat)
Status: DRAFT, not sent. Send only on Christian's go.
Build 135, commit `<SHA>`, tag `tvos-v0.3.0-beta.19-rc3`. IPA link and expiry filled in after the cut.
Lint: 5/5 CLEAN on each bubble (deslop.py; one rule-of-three in bubble 2 reshaped, the Library line). Re-lint after the link, expiry and SHA are filled in. Cleanse skipped: Codex usage limit (until 10-29).

Follows the rc2 thank-you DM (2026-10-05 4:25 PM ET), which told him the new Home keeps the big image and text fixed at the top with one row below, and that collections would follow the same layout. Carries Home Stage & Strip (FEAT-55, device pass 16/16 on 10-05), plus Library L1 and Search S1, both merged after rc2. Setting names and defaults checked against the code on `4f62e836`: Home Layout `home_layout` default Stage; Ambient Background on; Trailer Location `trailer_playback_location` default "poster" (In Row in Stage); Navigation `sidebar_style` default Top Tabs, FEAT-30 "sidebar" reads as Rail; Rail `rail_visibility` default Always Visible; folder Layout in the folder page's Edit menu, Rows unless a folder is set to Grid.

---

Bubble 1:

```
Hi Steven, beta.19-rc3 is up. It has the new Home I told you about.

<IPA_LINK>
(<EXPIRY>)
Build 135. Settings, About should show commit <SHA>.

New Home (Settings, Home Screen, Home Layout: Stage, now the default):
- The top is a fixed stage with the focused title's art, logo, info and synopsis. It never takes focus and never moves.
- Below it sits one row at a time. Up and Down move a whole row per click, in one motion, and the next row's title peeks at the bottom. Nothing moves after a row lands.
- The stage switches to the new title once you stop for about half a second, with the old text gone first.
- Menu from a lower row takes you back to the first row, on the card you were on.
- Ambient Background (on): a soft wash of the focused title's colours behind everything. OLED True Black dims it.
- Trailer Location now reads In Row or Background. In Row (the default) plays inside the poster after you rest on it; Background plays behind the title at the top.
- Collection pages use the same layout, one row per source. The Edit button at the top right has Layout: Rows or Grid, per folder.
- Show Hero, Nuvio-Style Hero, Hero Sources and Autoplay Hero Trailer only show when Home Layout is Classic. Classic is today's Home, if you want to compare.

New rail (Settings, Appearance, Navigation: Top Tabs or Rail, Top Tabs by default):
- A floating pill on the left with the tab icons. Left from the first card opens it with labels, Right takes you back, Select on an icon switches tab. Menu at the top of a tab opens it too.
- Under it, Rail: Always Visible (the default) keeps content clear of the pill, and Hide While Browsing lets it slide away once you scroll.
- If you had Sidebar on, you are on the Rail now.
```

Bubble 2:

```
Also in this build:
- Library: two pills at the top choose the list and the sort order. Chips below filter by type and by watch state (Unwatched, In Progress, Watched). Posters show a watched tick or a progress bar. Hold a poster for Mark as Watched or to remove it from the list it is in.
- Search uses the Apple TV keyboard now. Results update as you type, and a search goes into Recent once you open one of its results.

Could you send a video like your Fusion comparison: a Down walk through a few rows and back up, then one collection page? That tells me whether the bounce is really gone on your TV.

Still on my list from the weekend: the portrait poster that vanishes after the fade, the darker area behind the description page synopsis, and an easier way to the full synopsis.
```

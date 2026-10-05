# Detail + Settings revamp: device pass

**Profile: "Test", never "Chris".** Living Room Apple TV, dev build installed as `com.youngchris29.NuvioTV`, launched with `-debug.detailScrollProbe YES --console`, log streamed to `~/Downloads/detail-settings-revamp.log`. Install any add-on needed for a step into "Test" only, and remove it afterwards.

Mark each step pass / fail with a one-line note. A photo helps for anything that looks off.

## Detail (Cinematic is the default layout)

1. Open a movie with a logo (e.g. Dune: Part Two). The logo does not shift as the page loads. The meta line reads year · runtime · genres. The ratings strip (if MDBList is connected in "Test") fades in without moving anything above it. The synopsis shows up to 4 lines. Credits ("With …", "Directed by …") sit on the right, level with the buttons.
2. Open a title with a long synopsis (one that ends in "…" on the page). Press Up from the buttons onto the synopsis, Select: the full text opens. Menu closes only the sheet; you stay on the page.
3. Open a series you have started in "Test". The first button reads Resume S·E·, and Start Over sits next to it (icon). Start Over plays from 0:00.
   3b. Open a series that is NOT in your recent history (so its page loads slowly). Focus should land on the Play/Resume button once it appears, and must not jump if you already pressed a direction.
4. From the buttons press Down: the first row slides up under the top in one motion and the backdrop dims. Press Up back into the buttons: the whole hero comes back and the dim clears.
5. Scroll to the end of the page: an About section (Director, Writers, Country, Awards, Ratings…) is the last block and reads correctly.
6. Settings → Detail Page → Sections: turn each section off in turn and reopen the title; that row is gone. Turn them back on. Leaving a title page open in Home while you change these must not break focus when you come back.
7. Settings → Detail Page → Hide Spoilers in Unwatched Episodes ON: unwatched episode stills are blurred, their synopsis reads "Synopsis hidden until watched", and "N aired unwatched" next to Episodes is correct. Turn it back off.
8. Trailer auto-play and the background trailer still work on Detail, and returning from the full-screen trailer back to the page is clean (no black flash, no doubled artwork).
9. Settings → Detail Page → Detail Layout → Classic: the old page is back unchanged (glass synopsis panel, labelled buttons, Details table). Switch back to Cinematic.
10. Scrolling Detail up and down feels smooth (no stutter on the hero or rows).

## Settings

11. Every category opens from the root; the left panel follows focus and shows a plain description for each row.
12. Menu inside a category goes back to that same category on the list.
13. In Appearance, change the theme colour: you stay in Appearance, and Menu then returns to Appearance on the list.
14. Switch the Apple TV language to German (or launch with `-AppleLanguages "(de)"`) and skim Settings: titles and descriptions are German, nothing is cut off badly. Switch back.
15. Developer: the diagnostic readouts still show when their switch is on (e.g. Tab Bar Diagnostics).
16. Appearance → Settings Style → Minimal: no icons and no left panel; rows still work. Switch back to Default.
17. Appearance → Navigation → Sidebar: at the Settings list, Menu reveals the sidebar; inside a category, Menu goes back to the list. Switch back to your usual navigation.

Extra checks (from review): toggles switch on Select and show green when on; focused rows (toggles, pickers, links, About rows) all get the white platter; with VoiceOver on (optional), a toggle reads its on/off state and an About row is not announced as a button.

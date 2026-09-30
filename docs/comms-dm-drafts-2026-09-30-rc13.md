# DM draft — rc13 (2026-09-30)

Replaces the unsent 09-15 draft. Answers Steven's rc12 verdict (09-13) and his point-4 question, and covers everything since rc12: the rc13 batch, upstream batch 10, and the 09-30 device fixes. **Status: NOT SENT (waiting on Christian's go).** IPA https://litter.catbox.moe/r886zc.ipa (litterbox 72 h ≈ 2026-10-03 evening ET; 27,243,597 bytes, content-length verified; copy `~/Downloads/NuvioTV-beta18-rc13.ipa`). Lint 5/5 first pass; Codex cleanse could not run (model setting), so no cleanse.

---

Hi Steven, rc13 is up: https://litter.catbox.moe/r886zc.ipa (build 130, commit a9dba967). Same install as before. It has been a while since rc12, so this one is big.

The title bounce and the vanishing titles first. I measured the rows on my own Apple TV this time instead of working from photos, and found the cause: the app was leaving spare room under each row and the TV parked the row half that distance too high, so the title slid onto the poster and then hid. The rows now leave almost no spare room and the TV parks them where the title fits. On my TV it holds at Large and Medium+, zoom on or off, and with Show Hero on or off. Two side effects you should notice: at Medium+ the hero logo is back to full height, and with Show Hero off the description has three lines at Large.

About point 4: you were right. I read "feed selection" as the home page and built the wrong thing. The logo is now on the stream selection screen, after Play. If you meant a different screen, tell me which one.

The rest of your list in this build:

- Walk back up with the touchpad: the fix now catches swipes as well as button presses.
- Seasons 6 and 7 on The 100: Up works from every season poster.
- Depth modes on the Genres tiles: tiles without artwork cap at the Subtle rail, so the blue tiles have no bright line. Photo tiles keep the level you set.
- Descriptions are no longer bold with Open Sans. The year and genre line stays bold on purpose.
- OLED: Settings > Appearance > "OLED True Black". It syncs with your profile.
- Collection pages: the title is centred at the top and stays there while you scroll the grid.
- Edge fade on the rows: the simulator shows no fade at all, so I added a "Row Edge Fade" picker in About. "System" is what you have today. Try "Off", "Hard" and "Soft" and tell me which looks right.

Also new since rc12: no TMDB key is needed any more (you can still enter your own under Content Sources if you want it), an MDBList account can be connected for watchlist, progress and ratings, Simkl can feed "More Like This", movies get a Skip Credits chip, a series can play its episodes in shuffle order, custom poster sets like RPDB can be set from your phone, and the TV now reports what you watch to Simkl.

Still open on my side, so you know I have not lost them: the tab bar (my TV never shows it leaving the screen, so your Tab Bar Geometry pane is the only evidence I can get), the small jump on the top three rows of Home, the hero off mode showing a row with no title, and your two layout ideas for collections and the icon sidebar.

Three things I would like from you on this build:

- A photo of the Tab Bar Geometry pane in About after a cold launch and a walk down Home, and another after you switch tabs and walk again. The pane keeps only real changes now, so it should be readable.
- A photo of the hero off mode showing the top row with no title or description.
- One Row Settle pane at Medium+ after a slow walk down and up. The last field on each line, restErr, should stay within two points of zero.

The country and age question from earlier is still open on my side. Merci!

# DM draft — rc13 (2026-09-30)

Replaces the unsent 09-15 draft. Rewritten 09-30 night after reading the chat: answers his 09-13 list in his order, owns the point-4 misread (he never asked for logos), does NOT re-ask for the hero-off photos he already sent 09-13, and opens on the 09-19 check-in (family matters). Covers the rc13 batch, upstream batch 10, and the 09-30 device fixes. **Status: NOT SENT (waiting on Christian's go).** IPA https://litter.catbox.moe/r886zc.ipa (litterbox 72 h ≈ 2026-10-03 evening ET; 27,243,597 bytes, content-length verified; copy `~/Downloads/NuvioTV-beta18-rc13.ipa`). Lint 5/5 first pass; Codex cleanse could not run (model setting), so no cleanse.

---
Hi Steven, thanks for your patience these last two weeks, and for the kind words. Things have settled enough on my side to get back to this properly. rc13 is up: https://litter.catbox.moe/r886zc.ipa (build 130, commit a9dba967). Same install as before. It is a big one, so I will go through your list from the 13th in order.

The titles disappearing and the bouncing. I measured the rows on my own Apple TV this time instead of working from photos, and found the cause: the app was leaving spare room under each row and the TV parked the row half that distance too high, so the title slid onto the poster and then hid. The rows now leave almost no spare room and the TV parks them where the title fits. On my TV it holds at Large and Medium+, zoom on or off, Show Hero on or off. Two side effects you should notice: at Medium+ the hero logo is back to full height, and with Show Hero off the description has three lines at Large.

The first row of your collection on the way back up: the fix now catches touchpad swipes as well as button presses.

The depth modes on the Genres tiles: tiles without artwork now cap at the Subtle rail, so the blue tiles have no bright line. Photo tiles keep the level you set. This one I could not check in your configuration, so tell me if it still looks wrong.

The non-Nuvio hero mode showing the top row with no title or description: I have your two photos. It is on the list and not in this build.

The fade at the row edges that comes and goes: I could not make the simulator show any fade at all, so I added a "Row Edge Fade" picker in About. "System" is what you have today. Try "Off", "Hard" and "Soft" and tell me which one behaves the same going left and right.

The 100, seasons 6 and 7: Up works from every season poster.

The descriptions are no longer bold with Open Sans, on Home and on the description page. The year and genre line stays bold on purpose.

Your icon-only sidebar idea from Orivio is on the list as an option, alongside the Home-style layout inside collections.

About point 4 from the rc12 note: that was my mistake. I misread an earlier message of yours as a request for logos, and you never asked for it. There is nothing for you to test there.

Also new since rc12: no TMDB key is needed any more (you can still enter your own under Content Sources if you want it), an MDBList account can be connected for watchlist, progress and ratings, Simkl can feed "More Like This", movies get a Skip Credits chip, a series can play its episodes in shuffle order, custom poster sets like RPDB can be set from your phone, and the TV now reports what you watch to Simkl.

Still open on my side: the tab bar (my TV never shows it leaving the screen, so your Tab Bar Geometry pane is the only evidence I can get), the small jump on the top three rows of Home, and the hero off mode above.

Two things I would like from you on this build:

- A photo of the Tab Bar Geometry pane in About after a cold launch and a walk down Home, and another after you switch tabs and walk again. The pane keeps only real changes now, so it should be readable.
- One Row Settle pane at Medium+ after a slow walk down and up. The last field on each line, restErr, should stay within two points of zero.

The country and age question from earlier is still open on my side. Merci!

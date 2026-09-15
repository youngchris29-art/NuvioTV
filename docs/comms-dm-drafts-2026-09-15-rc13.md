# DM draft — rc13 (2026-09-15)

Answers Steven's rc12 verdict (09-13 evening) and his 10:52 AM question about point 4. **Status: NOT SENT.** IPA link and commit filled in after the cut.

---

Hi Steven, rc13 is up: <IPA_LINK> (build 130, commit <SHA8>). Same install as before.

About point 4: you were right. I read "feed selection" as the home page and built the wrong thing. The logo is now on the stream selection screen, after Play. If you meant a different screen, tell me which one.

Changes for your list in rc13:

- Walk back up with the touchpad: the fix now catches swipes as well as button presses. After each hop up, the pane should show an "upFallback" line with "src=swipe" and a "settle" line with "dir=-1". If pages 1 to 3 of the pane still exist from rc12, send those too.
- Seasons 6 and 7 on The 100: Up now works from every season poster.
- Depth modes on the Genres tiles: tiles without artwork cap at the Subtle rail, so the blue tiles have no bright line. Photo tiles keep the level you set.
- Descriptions are no longer bold with Open Sans. I've kept the year and genre line bold on purpose.
- OLED: Settings > Appearance > "OLED True Black". It syncs with your profile.
- Collection pages in rc13: the title is centred at the top and stays there while you scroll the grid.
- Edge fade on the rows: I couldn't get the simulator to show any fade at all. I've added a "Row Edge Fade" picker in About. "System" is what you have today. Try "Off", "Hard" and "Soft" and tell me which looks right.

Also in build 130: TMDB no longer asks for an API key. Play greys out when nothing can play a title. And the Trakt style "up next" picks per episode instead of reusing the last group.

Two things I still need from you:

- A photo of the hero off mode showing the top row with no title or description. I want to see what you see before I touch it.
- One Row Settle pane at Medium+ after a slow walk down and up, and one after a fast walk.

The country and age question from earlier is still open on my side. Merci!

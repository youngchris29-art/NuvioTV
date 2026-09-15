# DM draft — rc13 (2026-09-15)

Answers his rc12 verdict (09-13 evening) and his 10:52 AM question about point 4. **Status: NOT SENT.** IPA link and commit filled in after the cut.

---

Hi Steven, rc13 is up: <IPA_LINK> (build 130, commit <SHA8>). Same install as before.

First, point 4 from the last message. You were right, I read "feed selection" as the home page and built the wrong thing. The logo is now on the stream selection screen, the one after Play. If that is not the screen you meant, tell me which one.

What changed for your list:

- Walk back up with the touchpad: the fix now catches a swipe as well as a button press. On the pane you should see an "upFallback" line with "src=swipe" and a "settle" line with "dir=-1" after each hop up. If pages 1 to 3 of the pane still exist from rc12, send those too.
- Season 6 and 7 on The 100: Up works from every season poster now.
- Depth modes on the Genres tiles: tiles without artwork cap at the Subtle rail, so no bright line on the blue tiles. Photo tiles keep the level you set.
- Descriptions are no longer bold with Open Sans. The year and genre line stays bold on purpose.
- OLED: Settings > Appearance > "OLED True Black". It syncs with your profile.
- Collection pages: the title sits centred at the top and stays put while you scroll the grid.
- Edge fade on the rows: I could not make the simulator show any fade at all, so there is a picker in About called "Row Edge Fade". "System" is what you have today. Try "Off", "Hard" and "Soft" and tell me which one looks right.

Also in this build: TMDB no longer asks for an API key, Play greys out when nothing can play a title, and the Trakt style "up next" picks per episode instead of reusing the last group.

Two things I still need from you:

- A photo of the hero off mode showing the top row with no title or description. I want to see what you see before I touch it.
- One Row Settle pane at Medium+ after a slow walk down and up, and one after a fast walk.

The country and age question from earlier is still open on my side. Merci!

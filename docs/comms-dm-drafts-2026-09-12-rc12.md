# DM draft — rc12 (build 129) to Steven (2026-09-12)

Base: the rc12 batch session's template (`dm-rc12-template.txt`, 5/5) plus the BUG-112 paragraph. Link: https://filebin.net/nuviotv-rc12-c3597933e81b/NuvioTV-beta18-rc12.ipa (filebin, expires 2026-09-20 00:25 UTC; gofile backup page https://gofile.io/d/6IvQQKaJ); the commit prefix is `243da21b`. **Status: SENT 2026-09-12 8:30 PM ET (one copy verified from a fresh process; composer 1911 → 0).** His country/age question (11:58 PM) is deliberately not answered in this draft — Christian's call; add a line if he wants one.

---

Hey! Thanks for the video, the notes and the photos. rc12 is up: https://filebin.net/nuviotv-rc12-c3597933e81b/NuvioTV-beta18-rc12.ipa
Settings → About → Commit should start with 243da21b.

In rc12:

1. The genre row that wouldn't come back: your video and the Row Settle photo showed why. On the way back up, tvOS parks every row about 100 pt too high. The app's correction had already switched itself off on the way down, leaving the first row fully above the screen. Up couldn't land. The correction now re-arms whenever you change direction. If Up still finds nothing, the app scrolls the row above into view and moves focus there itself. This should also keep the catalog names visible on the way up.

2. Studio and network logos on the description page now lift with their focus ring, as cast photos have since rc10. With zoom off, they get a dark outline instead.

3. Card Depth levels: you were right, they were nearly identical. Subtle, Balanced and Bold now differ in line thickness and brightness at every coverage setting. Balanced and Bold also add a soft glow, and the Edge row gets an Off option. I kept the three presets for now rather than building the slider panel from your photo.

4. The title logo now shows on Home when you focus a poster, in both hero modes. It comes from TMDB when the catalog doesn't carry one, so it can take a second visit on a title the app hasn't looked up yet.

Your note about not seeing the bounce when you move slowly helped. It matches the diagnostics, so I added a test setting on my side in rc12. Nothing for you to flip.

One photo would settle point 1: Row Settle Diagnostics after a walk all the way down Home and back up at Medium+, then one more Up from the second row. The panel now has "dir" and "rearm" fields, and an "upFallback" line if the app had to step in.

The Home-style layout inside collections and the depth slider are on the list.

Merci!

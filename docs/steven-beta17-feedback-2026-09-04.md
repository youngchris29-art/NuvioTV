# u/mrStevenx3 — beta.17 (build 116) feedback, Reddit chat

Read 2026-09-04 via ego-browser task space 12 (`reddit chat steven`), room `!tneNX664qJ2yQUEeBpCRWPjS44j3pGJDEFxBCbqykC4:reddit.com`.
Two unanswered messages from Steven since Christian's rc2 DM (2026-09-01 10:44 PM):

## 2026-09-03 4:30 PM — question, UNANSWERED

> Hey, tonight I'm going to test it out and give you a complete overview of Beta 17. I saw that you posted it online. Is it the same one you sent me, or did you make any changes?

Fact for the reply: rc2 was cut from `3c39c677`; public beta.17 (116) is from `ff487392` and adds upstream batch 7 + batch 8 on top (skip-intro Simkl resolver, addon season posters/certification, offline-manifest retry states, up-next Menu dismiss, auto-play scope). Same Steven fixes, not byte-identical.

## 2026-09-04 12:20 AM — full beta.17 feedback (verbatim)

Here is my feedback on beta 17:

What has been fixed and is working correctly:
* The zoom on posters finally works correctly when the option is disabled, well done!
* The selection of the catalogs we want to display in the Hero and on the home screen is working again.
* The catalog titles no longer overlap the posters.

What has not been fixed and is still present:
* The zoom in the trailers is still present.
* The double display in the Hero is still present. This issue has been there for a long time, despite the fact that you have told me several times that it had been fixed. I hope you will manage to solve it. Let me know if I can help in any way to identify or fix this issue.
* When poster zoom is enabled and the Ring color option is activated, the zoom still does not work correctly: it continues to cut off the posters, and the movie titles are displayed with a border around them. I did not show this in this video, but you can see it in the previous video.
* The trailers overlap the edges of the poster, whether I select the Ring color Focus option or not.
* The backgrounds of my collections continue to resize and move back into place when I focus on them.
* I had not mentioned this before, but the title images of my collections do not appear instantly: the text appears first, and then the logo appears afterward. You can see it in the video. On Nuvio, the display is instant.

New bugs:
* The catalog titles bounce when moving around. This has always been the case, but now it is even worse: you can see that the title is constantly trying to move back into position and keeps moving all the time, which is distracting.
* When I scroll through a catalog, there is a glitch affecting the titles on the posters.
* When I move to the last row on my home screen, I can see part of the posters from the previous row.
* The smooth scrolling in the description is not always smooth. On some movies/series, it is perfectly smooth, while on others it is choppy. I think this may possibly be related to whether the page is full or not.
  * Example where it is smooth: Les Condés
  * Example where it is choppy: Drop Games
* I had already mentioned that the title image of my collections was too small. Now it is even smaller than before. When I set the posters to medium size, it is slightly larger, but it is still too small, just like before.
* When I select "No zoom" for posters, the card depth does not work properly: it adds a gap between the movie poster and the edge.

Things I previously requested and have not received any updates about:
* The possibility of moving the top bar somewhere else, for example to the side like on Omni.
* Adding the Open Sans font. I saw a new Nuvio fork for Apple TV that has implemented it. If it can help: https://github.com/vatax3/NuvioTVOS

Here is the video link: https://fromsmash.com/p2smVdWg8U-ct

I also made another video to remind you what the Omni bar looks like and what I am looking for, as well as my Nuvio interface, to show you the borders that are not cut off by the trailers, the size of my collection titles, the text that remains fixed when focusing on an item, etc. I also show you these elements in Omni.

Here is the Omni + Nuvio video: https://fromsmash.com/UhxvT4wFoW-ct

I spend quite a bit of time testing everything and providing detailed feedback. I really hope that my feedback is genuinely helpful to you and makes it easier to identify and fix these issues.

## 2026-09-04 4:25 PM and 4:27 PM — reply to the 09-04 DM (verbatim)

> It's nice to know that my detailed feedback is helpful to you :-) Here's a photo of the Hero's diagnostic report; unfortunately, it's too big, so I can't show you everything, because when I tap the bottom screen, the Apple TV skips parts of it. As for your second question about titles bouncing, that happens even in "medium" mode. However, in "medium" mode, the line above the last line of the catalog doesn't stay on the screen. Regarding the Hero image that automatically crops to the collections, my photos might also help you. Et de rien 😉

> I had already sent you a photo of my diagnosis, but this one was much shorter!

Two Hero Paint Diagnostics photos attached in chat (images, not pulled). Medium question ANSWERED: bounce at Medium too. New Medium-only symptom: the row above the last does not stay on screen.

## 2026-09-05 4:18 AM — new suggestion (verbatim)

> Another suggestion (I think I mentioned this to you a while back): when the trailer plays in full screen from the description, there's no animation to bridge the two. I recorded what happens on Orivio—a fork of Nuvio for Apple TV—as well as what happens on the official Nuvio app (I prefer the Nuvio version). I'm also showing you the animation of my collections on Nuvio, which runs at 60 fps compared to 30 fps on your app. The video: https://fromsmash.com/.8WE-Btmp0-ct

Acknowledged in the 09-05 rc DM as "on the list", no promise. Video pulled 2026-09-05 17:03 ET via the Smash recipe to `~/Downloads/IMG_8468.mov` (172 MB, 54s; Smash page said 6 days left). Tracker rows: FEAT-32 (trailer full-screen bridge animation), FEAT-33 (collection animation frame rate).

## Not done in this intake
- Videos NOT downloaded (fromsmash links; download needs an explicit go-ahead).
- No reply drafted or sent.
- Tracker / dashboard not updated.

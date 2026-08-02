# beta.9 retest reply to u/mrStevenx3 — draft (conversational + bullets, no em dashes)

**✅ POSTED 2026-08-02** — as a direct reply to `p196j81`, via Christian's logged-in Chrome at his request. Markdown editor, passed automod first try, verified live on the permalink with the full text intact. The text below is the as-posted version.

**Was: post as** direct reply to u/mrStevenx3's 11-point beta.9 review (`p196j81`)
https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/p196j81/

**Automod notes:** no "torrent"/debrid-brand content, low filter risk. No backticks, no em
dashes. Composer gotchas as usual (verify expanded composer before typing; validation lags
~3-6s).

**Before posting:** watch their video (reddit.com/link/p196j81/video/66j05f8pvygh1/player) —
it demos the whole list, incl. the Cape Fear/Batman depth pair and how Nuvio handles the
trailer zoom. If the video changes any read below (esp. the depth-effect or search items),
adjust the matching bullet before posting, don't post then correct.

**Language note:** the reporter reads via a translator. Short sentences, plain words, no
idioms.

---

Thank you for another amazing review, and for the video. Went through all eleven points. Here's the honest status on each:

- **Search catalogs: you found a real bug, and it's my top priority.** You're right on all three counts. The selection is ignored, it disappears after a search, and the first row is white text on white. That feature was built because you asked for it, and it shipped broken. That's on me. Fixing all of it first, before anything cosmetic.

- **Trailers still low quality: correct, and here's exactly why.** The real fix was finished a few hours AFTER beta.9 was already built. So build 105 does not have it. It's done, tested, and it will be in the next beta. Not asking you to re-check until then.

- **Black bars on the focus trailer:** separate issue from the quality, and you're right. I'll zoom the trailer to fill the frame like Nuvio does. Same build as the quality fix, so when you test one you test both.

- **GIFs still slow: honest answer, my fix didn't work.** Third build where I thought I had it and didn't. I'm done guessing. Your video shows me exactly where it happens, so I'm going to measure that exact case on real hardware before I touch the code again.

- **Card depth effect (Cape Fear right, Batman wrong):** that pair is a perfect clue. It tells me the effect is sizing itself from the poster image instead of the card, so posters with unusual dimensions leak the outline everywhere. Will fix.

- **Square corners missing on collection images:** confirmed. The collection tile draws its own shape and ignores the Corners setting until it's focused. Will fix.

- **Actor page scrolling down and stuck:** confirmed. Focus is landing on something below the text and dragging the page with it. Will fix.

- **Cursor on the main profile at login:** good call, cheap fix, next beta.

- **Focus outline in your chosen color:** yes, like Nuvio. One thing I'll be careful about: you run the White theme, so a white outline has to stay visible on bright posters. It'll go through the same contrast guard as the other white-on-white fixes you've caught.

- **Genres instead of the catalog list in search:** agreed, it's cleaner. I'll do it in the same pass as the search fix, since it's the same screen.

- **Trailer poster in the description:** nice idea. I'm designing it together with the hero layout I promised you last time, because they share the same screen and I want to lay them out once, properly.

One small favor: can you open Settings > About and tell me what it says? It should show 0.3.0 (105). That screen is new in this beta, and it's the one thing that lets me be 100% sure which build a report comes from.

And thank you for the kind words about the icons and the dimmed description. Eleven points and every one of them actionable. Reviews like this are why the app keeps getting better.

---

**After posting:** mark the reply posted on the tracker (BUG-31/32/33/34, FEAT-14, UX-8/9/10/11
rows + the BUG-19 and UX-4c re-confirm notes), and the next sweep watches for: the About-pane
build number (first ever verifiable retest), their reaction to the trailer-fix-missed-the-cut
explanation, and any answer on which row the GIF stutter shows (if the video doesn't already
settle it).

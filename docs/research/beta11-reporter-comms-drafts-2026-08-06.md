# Reporter communication drafts: beta.11 campaign (v3, 2026-08-07)

Status: **DRAFTS. Nothing posts without Christian's explicit approval.**

v3: conversational rewrite, no em dashes in any reply text. Facts unchanged from v2: every fix
below is committed (`88abcf9a..b8c4e60c`), suite-verified on both runtimes (54/54 including the
first full tvOS 27.0 run), and waiting on the device pass + release cut. Recommended timing:
post drafts 2 and 3 together with the beta.11 announcement so "the next beta" is a build they
can install the same day. The DM (draft 1) can go earlier since it only asks questions. The
BUG-31 part of draft 3 waits on Christian filming the counter-video.

---

## 1. u/tiyeuedm, Reddit DM (BUG-47 + FEAT-19 ack)

**Why a DM:** that's where the report arrived. **Why no .ips ask:** the "crash" is an eject.
The process gets suspended, not killed, so there's no crash log to send. The two questions
confirm their case matches the reproduced mechanism.

> Good news: I managed to reproduce this on tvOS 27, and it's fixed for the next beta.
>
> Two quick questions so I can be sure what you hit is the same thing I found:
>
> 1. When you expanded the search results, was the page empty? Like a "No titles here yet."
> message instead of a grid of posters?
> 2. And after it kicks you to the home screen, if you open NuvioTV again, does it come back on
> that same empty page instead of starting fresh?
>
> If that sounds right, here's what was actually happening: that expanded page was losing your
> search, so it came up with nothing on it. And with nothing on the page for the remote to
> focus, your Back press was going to the system instead of back to your results. That's the
> "crash". The app wasn't dying, it was getting tossed to the home screen.
>
> In the next beta, Back always works there and the empty page has a Go Back button. The beta
> after that fixes the page itself so it actually shows your search results.
>
> Also got your other two requests, Vietnamese and a default subtitle language. Both are on the
> board. The subtitle one fits nicely next to the metadata language picker that's already in
> Settings. Thanks for taking the time to send all three.

---

## 2. u/Ginosaure, thread reply on [`p20ivrz`](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/p20ivrz/) (UX-13)

**Context:** first item from this reporter since their BUG-2 "best fork I've tested"
confirmation. Their repro reproduced first try; the fix is test-verified.

> Fixed in the next beta. And thanks for describing it so clearly, it reproduced on my first
> try.
>
> What was happening: every time you backed out of a poster, the View All grid was getting torn
> down and rebuilt from scratch, so you always landed back on the first one. Now it just keeps
> its state. Press Back from a title and you're on the exact poster you left, same scroll
> position, ready to keep going. Works the same whether you opened the grid from Home or from
> search.
>
> One honest caveat: my automated tests drive the simulator with button presses, but the real
> remote scrolls with swipes, and those two don't always behave the same. So if you update and
> find some path where it still forgets your place, tell me and I'll go dig into that exact
> path.

---

## 3. u/mrStevenx3, comprehensive thread reply on [`p1vylo0`](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/p1vylo0/)

**Context:** answers their full answer set + second video, point by point. **The BUG-31
paragraph needs the counter-video filmed first** (shot list at the bottom). If filming waits,
post without that paragraph and add it as a follow-up comment.

> Your second video did a lot of heavy lifting. Four of the fixes in the next beta trace
> straight back to it, so thank you. Going through your points one by one:
>
> **The black bars (Lucky vs Futurama).** You were right, and your video finally showed me why
> my first two fixes missed. Lucky's trailer has the bars baked into the video file itself, so
> everything that describes the file says it's a normal 16:9 video. No fixed zoom can ever
> handle that and Futurama at the same time. So the player now measures the actual picture
> during the first seconds of playback and zooms each trailer by exactly its own bars. On my
> end, trailers like Futurama look identical to before and barred ones get cropped to fit.
> When you update, check Lucky first. That's the real test.
>
> **Trailers dying after a while.** Your clip caught it happening (the House of the Dragon card
> going black and collapsing). I found and fixed several ways the player could slowly exhaust
> itself over a long session. But I'll be straight with you: I can't recreate a real ten-minute
> couch session in an automated test, so the next beta also ships with a hidden diagnostic
> switch. If it ever happens again, tell me, and I'll walk you through flipping it. Your
> console output will then tell me exactly which resource ran out.
>
> **The white-on-white settings row (Hero style Nuvio).** Your measurement was right for the
> build you filmed. That exact row shows dark text on the highlight now, and I checked it with
> screenshots of the very pane from your video. The same cleanup also caught six other places
> where light text could land on the bright focus highlight, including the tab pills on the
> collections screen, the stream list headers, and the color swatches.
>
> **The white focus ring showing grey.** Fixed. White accents were getting swapped to a dark
> fallback by a safety check that never actually needed to exist. White means white now.
>
> **Collections missing images.** Two parts here. The colored rectangles now pull real artwork
> from the collection's first title, and collections that have a title or logo image show it on
> the tile now too. But before I touch the services row, one question. In your video, the
> Netflix and Prime tiles do show their poster collages while you're just browsing past them.
> What goes dark is the tile you've focused, because it plays that animated logo on a black
> background. Is that animation the thing you meant by missing backgrounds? Because that one's
> a design choice, not a bug, and I'm happy to change it. I could keep the collage visible
> behind the logo, or add a toggle to turn the animation off entirely. Which would you prefer?
>
> **The vanishing row titles (Genres and New Movies).** I've now gone through both of your
> clips frame by frame and I can't catch a title missing while the screen is at rest. After two
> videos, that tells me to stop staring at footage and start measuring on the actual device.
> The next beta carries a measurement probe, and I'll run it on my Apple TV in your exact setup.
> If that still comes up clean, I might ask you to flip the same hidden switch from above so
> your own console can show me the geometry.
>
> **The search filter.** Thanks for confirming it works, and for saying so directly. That
> closed the item cleanly.
>
> *(BUG-31 paragraph, add after filming:)* **The card depth effect.** Here's the recording you
> asked for, straight from my Apple TV on the current build: [video]. Top only is set in
> Settings, and on my screen the effect draws only along the top edge on every poster I tried.
> So the same setting is doing different things on our two devices, which means I'm not
> changing the drawing again until we know why. Two questions to narrow it down: are you on the
> White accent theme in that clip? And does the full outline hit every poster for you, or only
> some, like your Batman and Cape Fear split?

**BUG-31 shot list for Christian (~20s):**
1. Settings → Appearance: show the depth-effect option on "Top only".
2. Home: focus one poster with clean artwork (Batman if available, their broken example;
   Cape Fear was their working one), hold ~3s.
3. Move focus to a second poster, hold ~3s.

---

## Posting checklist (after approval)
- [x] Draft 1 → DM to u/tiyeuedm — **SENT 2026-08-07 ~3:57 PM** via the logged-in session (verified in-thread from youngchris2989); the daily sweep cannot read DMs, so watch for their answer manually or via a forwarded screenshot
- [x] Draft 2 → reply on `p20ivrz` — **POSTED 2026-08-07** (per Christian: last paragraph removed; two-paragraph version live from youngchris2989 as a reply to Ginosaure's comment)
- [ ] Draft 3 → reply on `p1vylo0` (best with the announcement; BUG-31 paragraph only after filming)
- [ ] Christian films the BUG-31 video (shot list above)
- [ ] Log all three in the tracker's update log once posted (the daily sweep watches for answers)

# Reporter communication drafts — beta.11 campaign (v2, 2026-08-07)

Status: **DRAFTS — nothing posts without Christian's explicit approval.**

v2 refresh: written after the campaign finished — every fix referenced below is committed
(`88abcf9a..b8c4e60c`), suite-verified on both runtimes (54/54 incl. the first-ever tvOS 27.0
full run), and gated only on the device pass + release cut. **Recommended timing: post drafts
2–3 together with the beta.11 release announcement** so "the next beta" is a build number they
can install the same day; the DM (draft 1) can go earlier since it asks questions rather than
promising a build. The BUG-31 section of draft 3 is blocked on Christian filming the
counter-video; everything else is ready.

---

## 1. u/tiyeuedm — Reddit DM (BUG-47 + FEAT-19 ack)

**Why a DM:** that's where the report arrived. **Why no .ips ask:** the "crash" is an eject —
the process is suspended, not killed; no crash log exists. The two questions confirm their case
matches the reproduced mechanism.

> Good news — I reproduced this on tvOS 27 and it's fixed for the next beta. Two things you
> could confirm for me, to make sure your case matches what I found:
>
> 1. When you expanded the search results, was the page **empty** — a "No titles here yet."
> message instead of a grid of posters?
> 2. After it kicks you to the home screen, if you reopen NuvioTV, does it come back **on that
> same empty page** (rather than starting fresh)?
>
> If yes to both, it's exactly what I reproduced: that expanded page loses your search (so it
> comes up empty), and with nothing on the page to focus, your Back press was reaching the
> system instead of going back — which throws you out of the app. In the next beta, Back always
> works there and the empty page has a Go Back button; the beta after that makes the expanded
> page actually show your search results.
>
> Also noted your other two asks — Vietnamese, and a default preferred subtitle language.
> They're on the board (the subtitle-language one is a natural fit alongside the existing
> metadata-language picker). Thanks for taking the time to report all three.

---

## 2. u/Ginosaure — thread reply on [`p20ivrz`](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/p20ivrz/) (UX-13)

**Context:** first item from this reporter since their BUG-2 "best fork I've tested"
confirmation. Their repro was complete and reproduced first try; the fix is test-verified.

> This is fixed in the next beta — and thanks for describing it so precisely, it reproduced on
> the first try.
>
> The View All grid was being torn down and rebuilt from scratch every time you backed out of a
> poster, which is why you always landed on the first one. It now keeps its state across the
> round trip: press Back from a title and you're on the exact poster you left, scroll position
> and all, ready to keep browsing. Same fix applies whether you got there from Home or from
> search results.
>
> One honest caveat: my automated checks drive the simulator with button presses, and the real
> Siri Remote scrolls differently — so if you find an entry path where it still forgets your
> place after the update, say the word and I'll chase that path specifically.

---

## 3. u/mrStevenx3 — comprehensive thread reply on [`p1vylo0`](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/p1vylo0/)

**Context:** answers their full answer set + second video. Structure mirrors their items.
**The BUG-31 paragraph needs the counter-video filmed first** (shot list at the bottom);
if filming waits, post the reply without that paragraph and add it as a follow-up comment.

> Your second video did a lot of work — four fixes in the next beta trace directly to it.
> Point by point:
>
> **Trailer black bars (the Lucky vs Futurama pair).** You were right, and the video finally
> gave me the number to prove why both earlier fixes missed: Lucky's trailer has its bars baked
> into the video itself, so every piece of metadata reports it as a normal 16:9 file — no fixed
> zoom can serve it and Futurama at the same time. The player now *measures* the actual picture
> in the first seconds of playback and zooms each trailer by exactly its own bars. On my
> simulator, Futurama-style trailers render identically to today and a barred trailer computes
> its own crop. Check Lucky specifically when you update — it's the acid test.
>
> **Trailers dying after ~10 minutes of browsing.** Your clip located it (the House of the
> Dragon card going black and collapsing). I found and fixed several ways the player pipeline
> could exhaust itself during a long session — and because I can't reproduce a 10-minute couch
> session in an automated test, the next beta also ships with a diagnostic switch. If it ever
> happens again: Settings won't show it, but tell me and I'll walk you through flipping one
> hidden switch that makes your console output tell me exactly which resource ran out.
>
> **The white-on-white settings row ("Hero style Nuvio").** Your measurement was right for the
> build you filmed — and that exact row renders dark-on-white correctly in the next beta (I
> screenshot-verified the very pane from your video). The same pass also fixed six more places
> where light text could sit on the bright focus highlight, including the tab pills on the
> collections screen, the stream list headers, and the color swatches.
>
> **The white focus ring showing grey.** Fixed — white accents were being deliberately mapped
> to a dark fallback by a guard that never actually applied. White now means white.
>
> **Collections missing images.** Two parts. The colored rectangles now pull real artwork (the
> collection's first title), and collections that have a **title/logo image** now show it on
> the tile. But before I chase the services row further, one clarification: at rest your
> Netflix/Prime tiles *do* show their poster collages in the video — what goes dark is the
> **focused** tile, which plays that animated logo-on-black. Is that animation what you meant
> by missing backgrounds? If so, that's a design choice I can change (keep the collage behind
> the logo, or add a toggle to turn the animation off) — tell me which you'd prefer.
>
> **The vanishing row titles (Genres / New Movies).** I've now been through both of your clips
> frame by frame and can't catch a title missing at rest — which after two videos means I
> should stop looking at video and start measuring on the device itself. The next beta carries
> the measurement probe; I'll run it on my Apple TV in your exact configuration, and if that
> still comes up clean I may ask you to flip the same hidden switch so your own console shows
> me the geometry.
>
> **Search filter.** Thanks for confirming it works — and for saying so explicitly. That closed
> the item cleanly.
>
> *(BUG-31 paragraph — add after filming:)* **The card depth effect.** Here's the recording you
> asked for, from my Apple TV on the current build: [video]. Top-only is set in Settings, and on
> my screen the effect draws only along the top edge on every poster I tried. So we're looking
> at the same setting behaving differently on our two devices — which means I'm not changing
> the drawing again blind. Two questions to narrow it: are you on the White accent theme in
> that clip, and does the full outline affect *every* poster for you, or only some (your
> Batman/Cape Fear split)?

**BUG-31 shot list for Christian (~20s):**
1. Settings → Appearance: show the depth-effect option on "Top only".
2. Home: focus one poster with clean artwork (Batman if available — their broken example;
   Cape Fear was their working one), hold ~3s.
3. Move focus to a second poster, hold ~3s.

---

## Posting checklist (after approval)
- [ ] Draft 1 → DM to u/tiyeuedm (can go now; asks questions, promises no date)
- [ ] Draft 2 → reply on `p20ivrz` (best with the beta.11 announcement)
- [ ] Draft 3 → reply on `p1vylo0` (best with the announcement; BUG-31 paragraph only after filming)
- [ ] Christian films the BUG-31 video (shot list above)
- [ ] Log all three in the tracker's update log once posted (the daily sweep watches for answers)

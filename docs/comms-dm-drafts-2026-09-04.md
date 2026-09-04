# DM reply draft — u/mrStevenx3, beta.17 verdict — 2026-09-04

**Status: SENT 2026-09-04 10:16 AM ET (Reddit chat), on Christian's explicit go-ahead. Verified by re-reading the thread: one message, 2,223 characters, paragraphs intact, composer cleared.**

Channel: Reddit chat, from u/youngchris2989. Answers his 09-03 4:30 PM build question and the 09-04 12:20 AM verdict (verbatim in `docs/steven-beta17-feedback-2026-09-04.md`).

SlopMonster loop: lint 5/5 on the first draft, Codex cleanse applied as a rewrite and diffed hunk by hunk (one hunk restored: the cleanse had merged the description-trailer zoom and the poster-edge overflow into one sentence, which are two different bugs), re-lint 5/5.

Asks in the reply (kept to two): Hero Paint Diagnostics photo for the doubled hero (BUG-86), and whether the title bounce (BUG-87) also happens at Medium poster size.

Deliberately NOT in the reply: any date, any "fixed" claim, the tracker IDs, and the GitHub fork links he sent.

---

Hey! First, your question from yesterday: public beta 17 is the RC you tested, synced with upstream Nuvio. That sync adds anime skip-intro and season posters from add-ons. It also adds a retry button when add-ons fail to load offline. None of it touches the things you tested, so your feedback applies as-is.

And yes, your feedback helped. I’m not saying that as a courtesy. The catalog selection fix, trailers coming back with sound, the no-zoom fix and the card depth fix all came directly from your lists and videos. I wouldn’t have found the focus problem in the catalog rows without you saying it “felt impossible to select”. Thank you for the time you put into this.

On the misses:

The doubled hero. You’re right to call this out. I’ve told you several times that it was fixed, and every time I had fixed something in my setup that wasn’t your problem. I’m done guessing. The diagnostics pane should settle it: go to Settings > About, turn on Hero Paint Diagnostics, relaunch, wait about a minute, then photograph the pane. The log now keeps the early lines, so it should show me what your TV is doing that mine isn’t.

The bouncing titles. My overlap fix is misbehaving on your hardware, and it’s worse than the original overlap. This is at the top of my list. Does it also happen with posters set to Medium, or only Large?

Trailers in the description are still zoomed in, and trailers on focused posters still spill past the poster edge. The ring-plus-zoom combination is cutting posters and boxing titles. The logo appears after the text, the last row shows the row above, and No Zoom leaves a gap when card depth is enabled. They’re all on the board now, and I’m working from your video for each one. The Drop Game / Les Condés pair is the first real lead I’ve had on the choppy description.

The collection title became smaller because the Large poster fix stole room from the logo. I’ll size it independently.

The side bar and Open Sans: I hadn’t tracked either request. That’s on me. Both are on the list now. I watched the Omni video, and I understand what you’re after, but I can’t promise timing for those two.

I won’t tell you something is fixed again until I’ve checked it against your setup. Merci!

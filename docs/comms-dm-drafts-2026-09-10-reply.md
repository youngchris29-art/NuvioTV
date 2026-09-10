# DM draft: u/mrStevenx3, reply to the rc8 verdict + 09-10 reports

**Status: SENT 2026-09-10 11:28 AM ET (Reddit chat, Christian's go). Verified from a fresh ego process: one new message from u/youngchris2989 containing "Apple TV 4K", composer 816 → 0 chars after the page-side Send click, no duplicate. Note: the first send round died on a JS syntax error AFTER the fill and BEFORE the click; the second round found the composer still holding the 816 chars and clicked Send once.** Replies to his rc8 verdict (DM 09-09 7:46 PM ET: menu fixed, saga cards still too small, Row Settle pane pages 1–6 photographed, "do you only have a simulator?") and his two 09-10 reports (BUG-102 focus ring in collections with zoom on, BUG-103 collection carousel short of the screen edges). Christian's ask: say he has the latest Apple TV 4K and tests on both the simulator and the device. No build link — rc9 is not cut. Promises made: saga size measured from his official-app photo (next build), BUG-102 fix (next build). Asks: which screen for BUG-103 + a photo.

SlopMonster loop: lint 5/5 on the first draft (172 words); Codex cleanse diffed hunk by hunk — contractions and a merged Apple TV paragraph kept (both facts intact), the invented "I've guessed enough" dropped, trailing notes stripped; final lint 5/5 (157 words).

---

Hey! Thanks for the photos. The paged pane finally shows the whole walk, so I have real numbers to work from now.

Yes, I have the latest Apple TV 4K. I use the simulator to reproduce things quickly, and I test every build on the real Apple TV before it goes to you.

1. Menu: glad that one's done.

2. Saga cards: I'll measure the cards in your photo of the official app and match that size in the next build, instead of guessing again.

3. Focus ring in collections with zoom on: I found it. The collection tiles only draw the ring when zoom is off. Fix in the next build.

4. Carousel not reaching the edges: which screen do you mean, the collection row on Home or the page you open from a collection? A photo would help.

The design examples are still on my list. Bugs first, then I'll come back to them.

Merci!

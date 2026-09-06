# DM draft: u/mrStevenx3, acknowledging the rc2 feedback (2026-09-06)

**Status: SENT 2026-09-06 ~16:55 ET (Reddit chat), on Christian's explicit go. Verified by re-reading the thread: one message from u/youngchris2989, 1,251 characters, composer empty after send; it follows the rc3 follow-up by 23 minutes.** Reply to his 08:34 AM ET rc2 feedback (read after the rc3 follow-up went out at 2:31 PM).
Nothing posts without Christian's explicit go. rc4 is being built in a separate session; this message promises the
description-lines fix and a row-fit change in rc4, and the rest as a following batch.

SlopMonster loop: lint 5/5 on the first draft. Codex cleanse applied as a rewrite via `codex exec` and diffed hunk by hunk: kept the sentence splits and the plainer verbs, dropped the closing rc4 recap (redundant with paragraph two), no fact lost. Final lint below.

---

Hey! Thanks for the rc2 list and the video. I have both. The rc3 build I sent an hour ago only covers the description page. Nothing from your rc2 list is fixed in it yet.

The one-line description on Home is my doing. I took space from the description panel to make the Large rows fit. You're right: one line is useless. rc4 gives it three lines back by trimming the two cushions the focus engine uses around each row. I can't test that change on hardware myself, so when you try rc4, tell me if focus hesitates or skips a row.

Titles still hide at Large and bounce at Medium, and the second-to-last row still has the problem at Large. The fix passes every check I can run in the simulator, so the difference is on the Apple TV itself. I'm working from your rc2 video now. Knowing it happens with the hero on or off narrows it down.

The batch after rc4 will cover the floating bar's flicker when you press Up mid-scroll and its position. It will also cover the trailer transition's title resizing and missing logo, the missing saga titles on the description page, and the font not reaching the Settings categories.

The hero photo is still the one thing that decides the double hero. If you get to it on rc3 or rc4, send it whenever you can.

Merci!

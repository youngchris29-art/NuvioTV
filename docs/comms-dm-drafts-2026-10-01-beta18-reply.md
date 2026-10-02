# DM draft, reply to Steven's beta 18 verdict (2026-10-01)

**Status: SENT 2026-10-01 10:38 PM ET via the ego-browser chat session (one bubble, full text through "Merci!" verified, composer empty). SlopMonster 5/5 first pass; Codex cleanse skipped (account on its usage limit until 10-29).**

Context: Steven's verdict came in 2026-10-01 8:50 PM ET (DM + 5 photos, saved under `docs/research/steven-beta18-photos/2026-10-01-beta18-*.jpg`). Fixed per him: depth Balanced/Bold, Episode Ratings picker, two-line synopsis, Detail backdrop quality. Open: bounce back incl. first row + ~1 s title settle (rc14 hold), text weight reversed from his ask, Detail overlay still dark (wants blur + text moved right), FEAT-46 misread (depth effect should take poster colour, not the ring), Soft fade stops short of the screen edges, folder logo exit animation on scroll, swipe up into the first row still fails with Short Row Floor off, Open Sans too large (back on system font), stutters between rows (pre-dates beta 18). The two Tab Bar Geometry panes are unlabeled: pane A pinned (minY=46 all walk, hidden 1→0 after 4 s), pane B scrolls off (minY to -1431) and returns.

---
Hi Steven, thanks for the full pass and the five photos on release night. The two Tab Bar Geometry panes are the first numbers I have from hardware on that bug, and they show two different things. In one the bar never moves: its top edge stays at 46 for the whole walk, and the app's hide is undone after four seconds. In the other it scrolls off with the rows, down to -1431, and comes back. Which one was the cold launch and which was after the tab switch? You sent the pinned one first.

Your list, in order:

- Bouncing and the one-second title settle: the title now waits for the row to stop moving before it lands, and on your TV that wait shows. I will log the walk again on my Apple TV with your settings and make the title land with the row.
- Text weight: I had it backwards. Regular for the description, semibold for the year and genre line.
- Description page: a blur behind the text, with the text moved to the right, is the direction I will try. I have your Drop screenshot.
- Poster colour: understood, the depth effect takes it, not the ring. The ring option stays.
- Row Edge Fade: Soft stays, and the fade will reach the screen edges.
- Collection logo: it will move out of the way once scrolling starts.
- Swipe up into the first row: failing with Short Row Floor off means the floor is not the cause. I will test the swipe itself on my TV.
- Open Sans: noted, system font it is.

Stutters between rows: which poster size and zoom setting are you on, and does it happen with Show Hero off as well? A short clip of one row change would help.

Merci!

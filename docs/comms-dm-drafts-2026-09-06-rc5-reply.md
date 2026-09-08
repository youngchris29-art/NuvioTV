# DM draft: u/mrStevenx3, reply to his rc5 feedback (2026-09-06)

**Status: SENT 2026-09-06 11:41 PM ET (Reddit chat), on Christian's explicit go. Verified by re-reading the thread: one new message from u/youngchris2989, composer empty after send, no duplicate. The helper `click` on the Send ref wedged twice; the send that took was a page-side `btn.click()` on `button[aria-label="Send message"]` found through the shadow DOM.** Reply to his 7:16 PM ET rc5 feedback + three photos (record in `docs/steven-beta18-batch-plan-2026-09-05.md`, photos in `docs/research/steven-beta18-photos/2026-09-06-*-rc5-*.jpg`). Nothing posts without Christian's explicit go.

What it commits to: three lines in the carousel IF he runs the hero on (Christian's call, phrased as conditional); a look at the two-step Down press on the description page. What it asks for: the hero-off Hero Paint photo (only if the double hero persists with the hero off); the Row Settle photo from the right pane ("Diagnostic de position des rangées"); the commit check (9b02bb16) plus a Saga-row photo; which rows double-step; what the trailer transition looks like now. Icons-only bar acknowledged, not promised.

SlopMonster loop: lint 5/5 on the first draft (329 words). Codex cleanse applied via `cleanse.sh` and diffed hunk by hunk: sentence splits, "look at" → "check", "not the one I need" dropped; no fact lost, no claim changed. Final lint 5/5.

---

Hey! Thanks for the rc5 list and the three photos. Two things in them changed my picture.

Your hero photo was taken with Show Hero on. It shows the fix working: one paint at 2.5 seconds, then no repaint until you picked up the remote four minutes later. So the double hero is gone with Show Hero on. Do you still see it with Show Hero off? If so, I need the same photo with it off, showing a line containing "rowsWait=settled".

The one-line description comes from that same setting. The three-line fix only applies with Show Hero off, because the rotating banner needs the room. Tell me how you normally run Home, hero on or off. If it's on, I'll make room for three lines there too.

The third photo shows the tab-bar pane. I need the row pane, further down in About: "Diagnostic de position des rangées". Turn it on, relaunch, go down every row on Home at Large and back up, then photograph it.

The Saga names and the last row's room are in the same build as the logo and font you did see. I don't know yet why they didn't reach you. Check that Settings → About → Commit starts with 9b02bb16. If it does, a photo of the Saga row would help.

The description scrolling two steps per Down press is new to me. It's the row settling I added in rc3, which you're seeing for the first time. I'll check it. Does it happen on every row or only some?

The trailer transition itself didn't change in rc5. Only the caption did. Tell me what looks different: does the poster still grow and cut to the trailer, or does it just dim now?

Icons only on the floating bar: noted. And yes, the bar staying visible on the first result in Search and on the first page of Home is intended.

Merci!

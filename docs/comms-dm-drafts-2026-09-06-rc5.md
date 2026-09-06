# DM draft: u/mrStevenx3, beta.18 release candidate 5 (2026-09-06)

**Status: SENT 2026-09-06 6:35 PM ET (Reddit chat), on Christian's explicit go. Verified by re-reading the thread: one new message from u/youngchris2989, 1,817 characters, composer empty after send; no reply from Steven had arrived since the 16:55 acknowledgement.** Supersedes the rc4 draft (`docs/comms-dm-drafts-2026-09-06-rc4.md`, never sent):
Christian chose to fold the rest of the rc2 list into the next build before writing to Steven again. Follows the
rc3 follow-up (sent ~16:00 ET) and the rc2-feedback acknowledgement (sent ~16:55 ET), which already explained the
three-line description fix and the trimmed focus cushions. Placeholders `https://litter.catbox.moe/dm1noh.ipa` and `9b02bb16` are filled when
rc5 (build 121) is cut. Nothing posts without Christian's explicit go.

What rc5 carries beyond rc3:

- the W4 reaches-first spend order (three-line panel description at Large, focus cushions trimmed, untested on hardware)
- the floating bar hides on every description page and sits in the corner, with a short settle so it cannot blink while a page scrolls back to its top
- the trailer transition caption is the title logo and no longer resizes
- Saga names under the posters on the description page
- Open Sans on the Settings categories
- the last row on Home gets scroll room so it can settle like the others
- a new "Row Settle Diagnostics" switch in About whose photo carries the row numbers the video cannot (why titles hide at Large and why rows land then slide at Medium)

Channel: Reddit chat, from u/youngchris2989. Register as the rc3 message: plain, honest, French-friendly.

Deliberately NOT in the reply: tracker ids, commit ids beyond the About check, internal names (waves, geometry
types, Codex), the other session, the unproven-floor arithmetic.

SlopMonster loop: first lint 3/5 (semicolons in the header list, one list of three in the body) → rewritten to 5/5. Codex cleanse (`codex exec` via cleanse.sh, body only) applied as a rewrite and diffed hunk by hunk: it split the diagnostics paragraph into the reason and the steps and shortened four sentences, dropped nothing factual; its trailing notes removed. Final lint 5/5.

---

Hey! rc5 is ready: https://litter.catbox.moe/dm1noh.ipa (three days, same Sideloadly steps). Settings → About → Commit should start with 9b02bb16.

I watched your video frame by frame. This build covers most of the rc2 list:

• The description on Home is back to three lines at Large. As I said, that room comes from the two cushions the focus engine uses around each row. I can't test this on an Apple TV myself. If focus hesitates, skips a row or lands on the wrong one, tell me.

• The floating bar now hides on every description page, including those opened from Search, where it was staying visible. It's also moved up into the corner. When you scroll to the top, it waits a moment before coming back, which should stop the blink you saw when pressing Up.

• The trailer transition shows the title's logo instead of text. The size stays fixed.

• The Saga row on the description page has the names under the posters again.

• Open Sans now applies to the Settings categories too.

• The last row on Home has room to settle like the other rows.

I've deliberately left two things unfixed: the titles hiding at Large, and rows landing then sliding up at Medium. Your video shows what happens, but not why. Your Apple TV parks rows lower than my simulator does. I need measurements.

There's a new switch: Settings → About → Row Settle Diagnostics. Turn it on, relaunch, go down every row on Home and back up at Large, then photograph that pane. I need that photo for the next fix.

And I still need the hero photo too: Settings → About, Hero Paint Diagnostics on, relaunch, hands off the remote for 90 seconds, photograph the pane. It should show one line with "rowsWait=settled", one "present" line and one "paint" line, with no second "present" showing a different title after them.

Merci!

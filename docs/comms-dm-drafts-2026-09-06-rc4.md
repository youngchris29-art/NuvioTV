# DM draft: u/mrStevenx3, beta.18 release candidate 4 (2026-09-06)

**Status: SUPERSEDED, never sent.** Christian held this message (2026-09-06 ~17:00 ET) to work through the rest of Steven's rc2 list first; the replacement is `docs/comms-dm-drafts-2026-09-06-rc5.md` (rc5, build 121). Kept for the record. Original header follows.

**Status at drafting: DRAFT, not sent.** Follows the rc3 follow-up (`docs/comms-dm-drafts-2026-09-06-rc3.md`, sent ~16:00 ET) and
the acknowledgement of his rc2 feedback (`docs/comms-dm-drafts-2026-09-06-ack.md`, sent ~16:55 ET), which already
explained the three-line fix, the trimmed cushions, the focus caveat and the next batch. This message is therefore
short: the link, what to check, the reminders. Placeholders `https://litter.catbox.moe/77tezp.ipa` and `a4dbb976` are filled when rc4 (build 120)
is cut. Nothing posts without Christian's explicit go.

Context: rc2 fitted the Large card frame by shrinking the Home focus panel first, which left the description one
line at Large with labels hidden. Steven: "one line is not enough". Christian's decision: the frame now fits by
trimming the two focus cushions above and below each card (reach 88/44 → 64/24) and the panel keeps three lines.
The trimmed cushions have never been proven on hardware, so the message asks him to watch focus.

Channel: Reddit chat, from u/youngchris2989. Register as the rc3 message: plain, honest, French-friendly.

Deliberately NOT in the reply: tracker ids, commit ids beyond the About check, internal names (waves, geometry
types, Codex), the other session.

SlopMonster loop: lint 5/5 on the draft. Codex cleanse (`codex exec` via cleanse.sh, body only) applied as a rewrite and diffed hunk by hunk: it split two long sentences and reworded the photo ask, dropped nothing factual; its trailing notes removed. Final lint 5/5.

---

Hey! rc4 is ready: https://litter.catbox.moe/77tezp.ipa (three days, same Sideloadly steps). Settings → About → Commit should start with a4dbb976.

rc4 brings back the three-line description on Home at Large. As I said, the room now comes from the two cushions the focus engine uses around each row. I can't try that on an Apple TV myself. Walk up and down the rows a few times. If focus ever hesitates, skips a row or lands on the wrong one, tell me. I'll take the room from somewhere else.

rc4 includes rc3's fix for the description page, so if you haven't installed rc3, skip it and take this one.

I still need the hero photo: Settings → About, Hero Paint Diagnostics on, relaunch, then leave the remote alone for 90 seconds before photographing the pane. It should show one line with "rowsWait=settled", one "present" line and one "paint" line, with no second "present" showing a different title after them.

The rest of your rc2 list is the next batch. I have your video and I'm working from it.

Merci!

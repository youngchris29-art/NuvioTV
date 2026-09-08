# DM draft: u/mrStevenx3, beta.18-rc6 (build 122)

**Status: DRAFT at 5/5, NOT sent (waiting for Christian's go).** rc6 = build 122, tag `tvos-v0.3.0-beta.18-rc6`, `7ab5e25f` on `tvos-shared-extraction`, IPA 26,268,565 bytes at https://litter.catbox.moe/jit6b6.ipa (litterbox 72 h ≈ 2026-09-11 18:20 ET; copy `~/Downloads/NuvioTV-beta18-rc6.ipa`). Replies to his 09-07 10:09 PM ET message (Saga = poster art, double hero fixed both ways, collection images "resize live", pane-tail misread, bridge zoom ask, Down double-step on every movie). Carries rc6 = rc5 + the 09-08 batch (`760c0fac` + build bump `7ab5e25f`). Link and commit check filled in after the upload.

SlopMonster loop: lint → rewrite → cleanse → re-lint; first draft linted 5/5 (320 words); Codex cleanse diffed hunk by hunk (phrasing loosened, contractions, one long sentence split; no fact dropped, no claim changed, its trailing notes stripped); final lint 5/5 (304 words).

---

Hey! rc6 is up: https://litter.catbox.moe/jit6b6.ipa
Settings → About → Commit should start with 7ab5e25f.

Three fixes from your last two messages:

1. The trailer transition. The logo grows into place again as the page goes dark. It’s the motion from rc2, with the logo replacing the text.

2. One Down press on the description page now moves the page once. That second step was mine: I waited a third of a second for the system scroll to finish, then slid the row to its resting spot. The slide now takes over while the first scroll is still moving.

3. The collection artwork. Every swap between two folders fades cleanly in your rc2 video, so the crop itself isn’t moving. But testing your own collections on the simulator turned up a different problem: the first time you landed on a folder whose picture wasn’t cached, the hero waited 1.5 seconds, gave up, and stayed blank. The picture arrived a moment later. It got discarded. rc6 shows it as soon as it arrives. Slow image hosts were also blocking every other download for a full minute; that wait is now 20 seconds. To see the difference, quit the app fully, reopen it, and land on a folder you haven’t visited today.

On the Saga row: understood, you mean the poster picture itself has no title inside it. That’s the artwork Nuvio picks for those films, not a label. Do the official Nuvio app’s Saga posters show the title inside the picture on your TV?

One more photo, if you have a minute. After a Large walk, open Settings → About → "Diagnostic de position des rangées", then scroll that list itself down to its last lines and photograph the bottom. Your two photos showed the top of the list. I need what’s at the end.

Merci!

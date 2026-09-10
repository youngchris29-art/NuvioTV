# DM draft: u/mrStevenx3, beta.18-rc9 (build 126)

**Status: SENT 2026-09-10 3:07 PM ET (Reddit chat, Christian's go). Verified from a fresh ego process: one new message from u/youngchris2989 opening with the rc9 text, room count 31 → 32, composer 0 → 1222 → 0 chars around the page-side Send click, no duplicate.** rc9 = build 126, tag `tvos-v0.3.0-beta.18-rc9` (moved from build 125, which never reached him), `665fc031` on `tvos-shared-extraction`, IPA 26,311,195 bytes at https://litter.catbox.moe/sxpipj.ipa (litterbox 72 h ≈ 09-13 15:00 ET, `content-length` verified after seven HTTP 500s; copy `~/Downloads/NuvioTV-beta18-rc9.ipa`). Carries FEAT-34 saga cards 500×281 (measured from his 09-08 photo), BUG-102 (accent ring on collection folder tiles + cast avatars with zoom on), and his three afternoon reports folded in on Christian's call: BUG-103 collection rows bleed to the screen edges, BUG-105 depth rail on collection tiles, BUG-106 saga focus-lift overlap (told as a zoom problem fixed by a wider gap). FEAT-37 live search and FEAT-38 OLED black acknowledged; his full-list reconciliation ask accepted. One ask back: the ring under the lift on hardware (the sim cannot prove it).

SlopMonster loop: lint 5/5 on the draft; Codex cleanse diffed hunk by hunk — five phrasing hunks taken (split opener, explicit card comparison, "Fixed those too.", "reach the screen edges", the reordered zoom sentence), trailing notes stripped; final lint 5/5 (221 words).

---

Hey! Thanks for the photos and the video. They answered my question, and I’ve put the fixes into rc9.

rc9 is up: https://litter.catbox.moe/sxpipj.ipa
Settings → About → Commit should start with 665fc031.

In rc9:

1. Saga cards: I measured them against your photo of the official app instead of guessing. They should now match the size of the cards in that app.

2. Focus ring in collections with zoom on: fixed. The cast photos on the description page had the same gap. Fixed those too.

3. Collection rows now reach the screen edges like the other rows. Your photos showed exactly where they stopped.

4. The depth effect now applies to collection tiles.

5. The focused saga card no longer sits on its neighbour. The focus zoom caused that, so I widened the gap between cards. Their size wasn’t the problem.

One check for you: with zoom and the ring on, does the ring around a collection folder look right when the tile lifts? I can see it in my simulator, but it needs checking on the Apple TV.

Live search and the OLED black option are on the list. And yes, I'll go back through your full lists before the final beta and tell you what's still open.

Say things as you see them. That's what makes this work.

Merci!

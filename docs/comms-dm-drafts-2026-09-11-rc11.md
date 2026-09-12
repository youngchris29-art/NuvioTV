# DM draft: u/mrStevenx3, beta.18-rc11 (build 128)

**Status: SENT 2026-09-11 10:59 PM ET (Reddit chat, Christian's go: "remove the line about the simulator parking the rows and send it"). The simulator sentence was removed before sending (final 239 words, re-linted 5/5). Verified from a fresh process: one new message from u/youngchris2989 (1,506 chars rendered), composer 0 → 1320 → 0 chars around the page-side Send click, no duplicate; the room's message count read 32 → 34 because three unread messages from Steven (6:17 PM, 6:28 PM, 8:13 PM) sat above it.** rc11 = build 128, tag `tvos-v0.3.0-beta.18-rc11`, `40e8060f` on `tvos-shared-extraction` (pushed with the tag), IPA 26,341,818 bytes at https://litter.catbox.moe/b8syph.ipa (litterbox 72 h ≈ 09-14 17:40 ET, first upload accepted, `content-length` verified; copy `~/Downloads/NuvioTV-beta18-rc11.ipa`). Carries the rc11 batch: BUG-87/89 last-row frame floor (the last Home row's card labels are floored at the regime's link frame, so tvOS reveals the same frame for it as for every other row — told as "gets the same frame as the others"), FEAT-39 Medium+ at 134 dp (told with the 4-line trade-off: three lines, two under Open Sans, four only at Medium), BUG-66 Tab Bar Geometry probe armed in every build (rc10's was DEBUG-only — told as "my mistake"). Asks: the Tab Bar pane photo (same recipe) and the Row Settle pane after a full Large walk, (the simulator-caveat sentence was cut at Christian's request before sending). His collection-image note (BUG-107) acknowledged as left out per his own "same on the official app".

SlopMonster loop: template drafted at 5/5 earlier today (lint → rewrite → Codex cleanse diffed hunk by hunk); one sentence added after the simulator finding and re-linted; final lint 5/5 (256 words).

---

Hey! Thanks for the rc10 verdict and the three photos. rc11 is up: https://litter.catbox.moe/b8syph.ipa
Settings → About → Commit should start with 40e8060f.

In rc11:

1. Titles bouncing at Medium and disappearing at Large: your diagnostics showed that the rc10 fix held for every row except the last one. That row parks deeper because there's nothing below it to push it into place. And tvOS kept undoing the app's correction. The last row now gets the same frame as the others, so tvOS parks it in the right spot on its own.

2. Medium+ is a new poster size between Medium and Large, matching the official app's "comfort" setting. At Medium+, the description gets three lines, or two with Open Sans. Four lines only fit at Medium. With the current layout, a bigger poster and four lines can't both fit on the home screen.

3. The menu bar panel didn't work in rc10. That was my mistake. It works in rc11. Same ask as before: Settings → About → Tab Bar Geometry Diagnostics, turn it on, relaunch, walk Home down ten rows and back up, then photograph the panel.

One more photo would settle point 1: Row Settle Diagnostics after a walk all the way down Home and back up, at Large.

Thanks for the note about the collection images. You said it was the same on the official app, so I left it out of the diagnosis.

Merci!

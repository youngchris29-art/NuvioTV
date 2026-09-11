# DM draft: u/mrStevenx3, beta.18-rc10 (build 127)

**Status: NOT SENT (2026-09-11 ~03:15 ET). Waiting for Christian's go.** rc10 = build 127, tag `tvos-v0.3.0-beta.18-rc10`, `1f5121d0` on `tvos-shared-extraction`, IPA 26,332,528 bytes at https://litter.catbox.moe/2sjrq2.ipa (litterbox 72 h ≈ 09-14 03:10 ET, `content-length` verified after one HTTP 500; copy `~/Downloads/NuvioTV-beta18-rc10.ipa`). Carries the rc10 batch: BUG-108 (ring + artwork lift as one on collection tiles and cast avatars), BUG-109 (folder-exit focus), BUG-87/89 (the Large reach floor now holds the focus lift — told as "18 points too short"; the cost, a shorter description at Large with zoom on, is stated), the measured synopsis line height (told as 2 lines under Open Sans, 3 needs a taller box), and the Tab Bar Geometry Diagnostics probe with its photo contract. Asks: the Tab Bar pane photo and a Row Settle pane photo after a Large walk.

SlopMonster loop: lint 5/5 on the draft; Codex cleanse diffed hunk by hunk — all five phrasing hunks taken (no fact dropped), trailing notes stripped; final lint 5/5 (239 words).

---

Hey! Thanks for the rc9 verdict and the photos. rc10 is up: https://litter.catbox.moe/2sjrq2.ipa
Settings → About → Commit should start with 1f5121d0.

In rc10:

1. With zoom on, collection tiles and cast photos now lift together with their focus rings. Your photos showed the picture moving. The ring stayed.

2. Leaving a collection puts focus back on the folder you came from.

3. I found the cause of titles bouncing at Medium and disappearing at Large in your diagnostics. At Large, the space above the posters was 18 points too short to hold both the title and the focus zoom. That meant every landing got corrected and the title got hidden. There's now room for both. The cost is a shorter description on the Large home screen with zoom on. With zoom off, nothing changes.

4. The description line count now uses the font's actual height. With Open Sans, the panel fits two lines. Three would need a taller box, and that's a separate decision.

For the menu bar, tvOS has no setting I can flip, so rc10 adds a panel: Settings → About → Tab Bar Geometry Diagnostics. Turn it on, relaunch, walk Home down ten rows and back up, then photograph the panel. That will tell me what the bar actually does on your TV.

And for the rows, a photo of Row Settle Diagnostics after a Large walk down and up would confirm point 3.

Merci!

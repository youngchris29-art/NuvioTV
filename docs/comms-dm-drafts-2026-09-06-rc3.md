# DM draft: u/mrStevenx3, beta.18 release candidate 3 follow-up (2026-09-06)

**Status: DRAFT, not sent.** Follow-up to the rc2 message sent 01:28 AM ET the same day. Placeholders `https://litter.catbox.moe/2cljii.ipa` and
`9ddc4104` are filled when rc3 (build 119) is cut. Nothing posts without Christian's explicit go.

Context: Steven's 11:29 PM edit (after rc1) said the second-to-last row fix "doesn't work" and that scrolling his
collections hid part of the top line; his two photos were the DETAIL page, a film's Saga row focused with the "Guide
parental" header cut off above it (BUG-96). Fixed after rc2 went out, so rc3 carries it.

SlopMonster loop: lint 5/5 on the first draft; Codex cleanse applied as a rewrite via `codex exec` and diffed hunk by hunk (kept the paragraph splits and the sharper Home-versus-detail sentence, dropped nothing factual, trailing notes removed); final lint below.

---

Hey! One more build. I read your last message after sending rc2 and realised your two photos showed the description page, with a film's Saga row focused and the "Guide parental" header above it cut in half. I'd been looking at the last row on Home. Yours was different.

Before the rc3 fix, rows on the description page had no fixed resting place. Each move down scrolled just far enough to show the focused row, leaving the row above wherever it happened to land.

In rc3, each row settles at the same height when you move to it. What's left of the row above fades out at the top instead of being cut off.

rc3: https://litter.catbox.moe/2cljii.ipa (three days, same Sideloadly steps). Settings → About → Commit should start with 9ddc4104.

Everything from rc2 is included. If you haven't installed rc2 yet, skip it and take this one. And the hero photo I asked for is still needed with rc3.

To check the rc3 fix, open a film with a collection row and walk down through the rows. Tell me whether every header stays whole and whether the settling feels right or too slow.

Merci!

# DM draft — rc14 (2026-09-30)

Answers Steven's rc13 verdict (DM 7:00–7:14 PM ET, six chat photos + Smash video/panes) in his order; thanks him for the video and panes that found the fast-scroll cause; asks for the fast walk, the swipe-up test, the Row Edge Fade A/B and the two Tab Bar Geometry pane photos. Drafted by a three-draft judge workflow, lint 5/5 (431 words); the "four rounds" line corrected by hand (rounds 1–2 were the failures). Codex cleanse could not run (model setting). **Status: NOT SENT — Christian's go owed.** IPA https://litter.catbox.moe/u7gsbn.ipa (litterbox 72 h ≈ 2026-10-03 night ET; 27,293,145 bytes, content-length verified; copy `~/Downloads/NuvioTV-beta18-rc14.ipa`); build 131 `4f26c0d4`, tag `tvos-v0.3.0-beta.18-rc14`.

---
Hi Steven, thanks for the video and pane photos; the slide=72 lines found the fast-scroll cause. With the probes streaming from my Apple TV to the Mac, the title was being slid while the rows were still moving, so it never landed at rest. Titles now move only once the row has stopped, and a row coming back into view from above drops its old slide. It took two more device rounds to get there; down and up, slow and fast, it is clean on my TV now.

rc14 is up: https://litter.catbox.moe/u7gsbn.ipa (build 131, commit 4f26c0d4). Same install as before. The rest, in order:

- Depth Bold and Balanced: no second border on the focused poster (the focus ring owns that edge), and the soft halo band is gone at every level.
- Swipe up: an Up (press or swipe) landing on the hero while the first row is still tucked under it now scrolls the rows to the top.
- Bold text: medium weight wherever the system font was semibold (year and genre line, Settings descriptions). Info values on the description page are regular.
- Descriptions: one size smaller on Home and the description page. The Home hero fits two lines at Medium+ and Large (logo full height at Medium+; Open Sans at Large stays one line).
- Episode ratings: Settings, Appearance, Poster Style, "Episode Ratings": Show, Watched Only or Hide. Charmed yes and The 100 no is the ratings lookup, not the toggle.
- Row Edge Fade: "Soft" in About is now a real fade on both edges. The other three are unchanged.
- Description page: the dark overlay on the right is mostly gone, and the page asks the source for its largest backdrop. Fusion-level sharpness depends on the add-on.
- Collection logo: higher, as asked.
- Your poster colour idea: Settings, Appearance, "Ring Takes Poster Color" (shown with the accent ring or No Zoom on, off by default): the ring takes the poster's dominant colour.

Also: the top rows of Home (Continue Watching, Upcoming, first collection row) no longer jump after landing. If Up or Down around them feels wrong, turn off About, "Short Row Floor (A/B)" and tell me. Row Settle lines now end with restErr so it reads in a photo.

Still open: the tab bar (the Smash bundle had no Tab Bar Geometry photos).

From you:

- The fast walk down and up at Medium+ and Large.
- The swipe-up test.
- Row Edge Fade: Soft or System?
- Two Tab Bar Geometry pane photos: cold launch, then after a tab switch.

Merci!

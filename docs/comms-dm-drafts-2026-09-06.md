# DM draft: u/mrStevenx3, beta.18 release candidate 2 (2026-09-06)

**Status: DRAFT, ready to send, not sent.** rc2 = build 118 from `25e07e08` (tag `tvos-v0.3.0-beta.18-rc2`, unsigned
Release IPA 25.8 MB, https://litter.catbox.moe/js7mfl.ipa, litterbox 72 h ≈ 2026-09-09 01:30 ET, size verified by
`content-length`; local copy `~/Downloads/NuvioTV-beta18-rc2.ipa`). Christian decides the bracketed optional paragraph
(the one-line synopsis trade-off) before sending.

Channel: Reddit chat, from u/youngchris2989. Follows the 2026-09-05 rc1 DM (`docs/comms-dm-drafts-2026-09-05.md`) and
Steven's 5:48 PM verdict with two photos.

SlopMonster loop: lint 5/5 on the first draft (the only hit was the doc header). Codex cleanse applied as a rewrite via `codex exec` and diffed hunk by hunk: kept the contractions and paragraph splits, dropped one invented fragment ("Wrong place entirely.") and five repeated "in rc2" tags, no fact dropped. Final lint 5/5.

Asks in the reply: one Hero Paint Diagnostics photo with Show Hero off (the pane now records his profile's shape), a
look at the first poster of a few rows, Drop Games, and a Medium → Large switch. Deliberately NOT in the reply:
tracker ids, commit ids beyond the About check, the review count, the other session, the 60 fps probe (no default
change yet).

---

Hey! Your two photos showed me what I'd missed for three builds: you run Home with Show Hero off, so the artwork at the top is the focus panel. I'd put every double-hero fix into the rotating banner.

The panel was still painting from the first rows to load, then repainting when cloud sync reordered them a second later. That was the swap you kept seeing.

In rc2, the panel waits for cloud sync the same way the banner does, four seconds at most, then paints once. It also stops taking its first title from Continue Watching while the rows are still being held.

Here is release candidate 2: https://litter.catbox.moe/js7mfl.ipa (same Sideloadly steps, and the link lasts three days). Settings → About → Commit should start with 25e07e08.

One more photo, please. Same steps as before: Settings → About, Hero Paint Diagnostics on, relaunch, hands off the remote for 90 seconds, photograph the pane.

With Show Hero off, a good photo now has one line containing "rowsWait=settled", followed by one "present" line and one "paint" line. There should be no second "present" line with a different title in the seconds after them.

The rest of your list:

• Trailer zoomed on the description page: the full-screen trailer no longer crops. A wide trailer plays with bars, like official Nuvio. Trailers on posters still crop to the poster as before.

• Trailers spilling past the first poster: the row now clips its left edge. Focus the first poster of a few rows and tell me whether anything still shows left of it.

• Collection backgrounds repositioning: the image was growing into place as it arrived. It now stays the same size and crossfades.

• Titles bouncing, and the title that vanished on your first launch: the card's focus frame at Large was taller than the space under the top of Home. The Apple TV's focus engine and my correction kept disagreeing on where a row should rest. The frame now fits, so there's one resting place. The title vanished because a check ran before the layout was final. That check now waits and runs again if a title is hidden.

• Medium → Large bringing the old row problem back: after a few attempts, the correction was switching itself off for the session. Changing size never switched it back on. It resets now, and the move happens with the resize instead of a moment later.

• Choppy description on Drop Games: the glass chips near the top of the page were redrawing against the moving background on every frame. They go flat while the page scrolls and come back when it stops. Tell me whether Drop Games scrolls like Les Condés now.

[Optional, Christian's call: Fitting the Large frame comes with a trade-off. When labels are hidden, the panel at the top of Home gives some of its height to the rows, leaving one line for the description instead of three. If you'd rather keep three lines, say so and I'll take the room from elsewhere.]

Two of your older asks are in this build too, both off by default under Settings → Appearance: Navigation moves the top bar to a side bar, and Typeface adds Open Sans. The side bar is early. It works, but the way you move in and out of it is the part I'm least sure of, so try it for a while and tell me whether the navigation feels right or where it fights you.

Merci!

# DM draft — u/mrStevenx3, beta.18 release candidate — 2026-09-05

**Status: SENT 2026-09-05 4:54 PM ET (Reddit chat), on Christian's explicit go-ahead after the revised paragraphs were shown. Verified by re-reading the thread: one message, 2,903 characters, paragraphs intact, composer cleared. Device pass PASSED earlier the same day (Living Room ATV, build 116 from `2a5874db`). rc1 for beta.18 cut from `146d2233` (build 117, tag `tvos-v0.3.0-beta.18-rc1`), IPA at https://litter.catbox.moe/mqr4in.ipa (25.4 MB, litterbox 72 h, expires ~2026-09-08 16:55 ET, download verified byte-identical to the built IPA). Catbox proper stored 0-byte objects on three attempts today (xfsmbx, cp29bb) and dedups by hash, so those links are dead; do not reuse them.**

Channel: Reddit chat, from u/youngchris2989. Follows the 2026-09-04 reply (`docs/comms-dm-drafts-2026-09-04.md`).

SlopMonster loop: lint 5/5 on the first draft, Codex cleanse applied as a rewrite and diffed hunk by hunk (one invented sentence removed: "I'm not calling that fixed until you've tried it"), re-lint 4/5 on one rule-of-three sentence, reshaped, re-lint 5/5. 2026-09-05 16:40 ET: commit id filled and status updated (placeholder swap only, no prose change), body re-linted. 16:50 ET: Christian's ask, the side-bar line now acknowledges the request and says he is working on it (bugs first); body re-linted.

Asks in the reply: the Hero Paint Diagnostics photo (90 s after a cold launch, no remote), the Trailer Diagnostics photo only if a trailer still looks zoomed, and whether Drop is still choppy. The Medium question was answered 09-04 4:25 PM (bounces at Medium too), so it is acknowledged, not asked.

Deliberately NOT in the reply: dates, commit ids beyond the About check, tracker ids, the review count, the font beyond "on the list". The side bar is acknowledged as in progress at Christian's request (16:50 ET).

---

Hey! Here’s the beta 18 release candidate, built from your beta 17 list. Install it the usual way with Sideloadly: https://litter.catbox.moe/mqr4in.ipa (the link works for three days; say so if you need a fresh one). Settings → About → Commit should start with 146d2233.

The double hero comes first because you were right to push on it. Your video caught the problem: Home painted from the catalogs that had loaded, then rebuilt a second later when cloud sync arrived and reordered the rows. That’s why it returned on every cold launch. Nothing I fixed before got near the actual cause.

Now the hero waits for your hero catalogs, cloud sync and metadata to arrive. It waits no longer than four seconds, paints once, then stays locked for the session. The rows follow the same timing, so the grey cards should stay gone too.

Your two diagnostics photos from beta 17 came through, thank you. This build changes what that pane records, so I need one more from it: go to Settings → About and turn on Hero Paint Diagnostics. Relaunch, then leave the remote alone for 90 seconds before you photograph the pane. Send the photo either way. A good photo has one line starting with "commit" and "first=1", with no lines containing "headChanged=1".

The rest of your list:

• Bouncing titles and the glitch while scrolling a row: the correction was fighting the Apple TV’s focus engine, which behaves differently from the simulator. It now settles once and stops.

• Collection titles: the logo has a bigger slot at every poster size. It now appears with the backdrop instead of arriving after the text.

• Collection backgrounds resizing on focus: the backdrop and logo load before the swap, removing the flash and shrink.

• Trailers zoomed in the description, and trailers spilling past the poster edge: both changed. There’s also a new Trailer Diagnostics switch in About. If a trailer still looks zoomed, turn it on, let the trailer play for ten seconds, come back and photograph the pane.

• Ring colour plus zoom cutting posters and boxing titles: fixed.

• The last row showing part of the row above: fixed. Your Medium note, the row above the last not staying on screen: that geometry changed in the same fix, so tell me what it does on this build.

• No Zoom plus card depth leaving a gap: fixed.

• Choppy description on some titles: the trailer playing behind the text was the likely cause on Drop. Tell me if Drop is still choppy.

About the top bar: I watched your Omni video, and moving it to the side is something I’m working on now. I wanted your bug list fully fixed before adding new features, so it isn’t in beta 18. Open Sans is still on the list too.

Thanks for the Medium answer, that confirmed the fix had to be independent of the poster size. Your note on the trailer transition and the 60 fps collections is on the list too. I’ll go through that video once the hero is settled. Merci!

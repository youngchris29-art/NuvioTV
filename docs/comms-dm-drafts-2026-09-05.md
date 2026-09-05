# DM draft — u/mrStevenx3, beta.18 release candidate — 2026-09-05

**Status: UNSENT. Two placeholders (`[IPA LINK]`, `[COMMIT]`) are filled in when the rc is built from the merged branch. The draft assumes Christian's device pass in Steven's configuration has PASSED before it goes out; if the pass finds a miss, the affected bullet must change. Needs Christian's explicit go-ahead before posting.**

Channel: Reddit chat, from u/youngchris2989. Follows the 2026-09-04 reply (`docs/comms-dm-drafts-2026-09-04.md`).

SlopMonster loop: lint 5/5 on the first draft, Codex cleanse applied as a rewrite and diffed hunk by hunk (one invented sentence removed: "I'm not calling that fixed until you've tried it"), re-lint 4/5 on one rule-of-three sentence, reshaped, re-lint 5/5.

Asks in the reply: the Hero Paint Diagnostics photo (90 s after a cold launch, no remote), the Trailer Diagnostics photo only if a trailer still looks zoomed, whether Drop is still choppy, and the Medium question from 09-04 if unanswered.

Deliberately NOT in the reply: dates, commit ids beyond the About check, tracker ids, the review count, anything about the sidebar/font beyond "on the list".

---

Hey! Here’s the beta 18 release candidate, built from your beta 17 list. Install it the usual way with Sideloadly: [IPA LINK]. Settings → About → Commit should start with [COMMIT].

The double hero comes first because you were right to push on it. Your video caught the problem: Home painted from the catalogs that had loaded, then rebuilt a second later when cloud sync arrived and reordered the rows. That’s why it returned on every cold launch. Nothing I fixed before got near the actual cause.

Now the hero waits for your hero catalogs, cloud sync and metadata to arrive. It waits no longer than four seconds, paints once, then stays locked for the session. The rows follow the same timing, so the grey cards should stay gone too.

To check it, go to Settings → About and turn on Hero Paint Diagnostics. Relaunch, then leave the remote alone for 90 seconds before you photograph that pane. Send the photo either way. A good photo has one line starting with "commit" and "first=1", with no lines containing "headChanged=1".

The rest of your list:

• Bouncing titles and the glitch while scrolling a row: the correction was fighting the Apple TV’s focus engine, which behaves differently from the simulator. It now settles once and stops.

• Collection titles: the logo has a bigger slot at every poster size. It now appears with the backdrop instead of arriving after the text.

• Collection backgrounds resizing on focus: the backdrop and logo load before the swap, removing the flash and shrink.

• Trailers zoomed in the description, and trailers spilling past the poster edge: both changed. There’s also a new Trailer Diagnostics switch in About. If a trailer still looks zoomed, turn it on, let the trailer play for ten seconds, come back and photograph the pane.

• Ring colour plus zoom cutting posters and boxing titles: fixed.

• The last row showing part of the row above: fixed.

• No Zoom plus card depth leaving a gap: fixed.

• Choppy description on some titles: the trailer playing behind the text was the likely cause on Drop. Tell me if Drop is still choppy.

Not in beta 18: the side bar and Open Sans. Both are still on the list.

If you haven’t had a chance yet, does the title bounce also happen at Medium, or only at Large? Merci!

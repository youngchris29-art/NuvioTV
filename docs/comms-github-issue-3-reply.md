# Draft reply — GitHub issue #3 (BUG-114), `dotjarden`

**Status:** DRAFT, not posted. For Christian to review and post (or hand back for edits).
**Target:** https://github.com/youngchris29-art/NuvioTV/issues/3
**Drafted:** 2026-09-29 morning sweep.

---

Thanks for this, and sorry for the silence — sixteen days is far too long to leave a report
like this one sitting, and the delay is on me, not on the quality of the write-up.

Taking the parts in turn.

**The symptom is real and it is ours.** The tab bar being stranded above the screen after a
D-pad walk back up Home is a known open item here, not something your fork introduced. What you
have added is a much sharper repro than we had: a press count, the residual offset (~490 pt) and
the accessibility-tree `y` for the bar. Those three numbers together are the first version of
this I can point an engineer at without asking for a photo first. It is tracked on our board as
BUG-114.

**You were testing current code.** `243da21` is our beta.18-rc12 tip (build 129), so nothing has
landed since that you were missing. Worth saying explicitly, because it rules out the cheapest
explanation.

**On the fix, the history matters and it cuts both ways.** `HomeView.swift` carries a standing
warning at the `onExitCommand` site against scrolling the rows view when the pinned hero gains
focus. Two earlier rounds did exactly that. Both were reverted, because on hardware they wedged
Down navigation and interrupted the Menu-to-top path — neither of which reproduced in the
simulator.

So the shape of your patch is the shape that has already failed here twice. What makes me want
to read it anyway is the constraint you put on it: settle once on focus gain, and no delayed
retries that fight the next Down press. Delayed retries racing the user's next press is a fair
description of how those earlier rounds broke. If your version avoids that by construction
rather than by timing, it is a different patch than the ones that were reverted, and I would
rather review it than wave it off.

**Two asks.**

1. Open the PR against `youngchris29-art/NuvioMobile`, branch `tvos-shared-extraction`. This
   repo is the fork wrapper; the app itself lives in the `NuvioMobile` submodule, so a patch
   filed here has nowhere to land.
2. In your repro, with focus stuck on the hero action and the shelf still at ~490 pt, does a
   **Menu** press recover it — bar back, hero focused, page at the top? Menu from a scrolled-down
   Home already takes the hero and scrolls to `home_top`, so the answer separates two different
   bugs: "the scroll never settled" versus "focus cannot leave the hero at all." If Menu
   recovers it, that is also a usable workaround to tell people while the fix is in review.

One thing to flag up front about acceptance, so it is not a surprise later. The simulator cannot
observe the tvOS system tab bar's mid-expansion state, which is precisely where both earlier
attempts died. A simulator-green regression test is necessary here but it is not sufficient — the
patch needs a pass on real hardware before it ships. We have an Apple TV 4K for that, so this is
a step on our side, not a bar for you to clear.

Thanks again for doing the legwork, and for being careful about what you had and had not
validated. That part was noticed.

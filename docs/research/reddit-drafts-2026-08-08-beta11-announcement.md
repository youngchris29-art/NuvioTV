# Reddit draft, 2026-08-08: beta.11 announcement

Status: **POSTED 2026-08-08 night as [`p2k6dyg`](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/p2k6dyg/)** — approved by Christian ("post it"), went out verbatim via ego-browser on old.reddit's markdown textarea (byte-identical fill verified before submit; rendered check: 12 bold spans, 8 list items, links live, author youngchris2989). Draft 3 still pending (with the corrections below + BUG-31 filming).

Posting notes:
- Top-level comment on the beta thread. The release is already live on the public repo and the
  post body's "Latest build" block already says beta 11 (build 107), so this can go out any time.
- Recommended: post draft 3 (the p1vylo0 point-by-point reply, `beta11-reporter-comms-drafts-2026-08-06.md`)
  right after this comment, **but two of its paragraphs are now stale — see the required
  corrections at the bottom of this file before posting it.** The BUG-31 paragraph still waits
  on the counter-video (shot list in that file).
- Automod: no "torrent", no debrid service names (Rule 6 history). This draft is clean; "debrid"
  as a generic word was fine in earlier posts.
- No em dashes, straight quotes, markdown editor.
- u/tiyeuedm reported BUG-47 by DM; they are deliberately NOT named here. The DM already told
  them the fix is in "the next beta" so they will recognize it.

---

## Draft: beta.11 announcement (top-level comment)

**Beta 11 is up** (build 107): https://github.com/youngchris29-art/NuvioTV/releases/latest

Two headliners this time:

- **Simkl is in.** Connect in Settings -> Accounts & Services with a short PIN code, and your
  watch history scrobbles to Simkl as you watch, movies and episodes both. Anime resolves
  through Simkl's own ID mapping, and when a match is ambiguous you get a picker to set it
  yourself. There is also a Sync Now button if you want to push or pull on demand.
  u/Ginosaure asked for this one a couple of days ago; it was already mid-build, which is why
  I could promise it so confidently.
- **Your keys follow your account now.** Debrid and TMDB API keys sync through your Nuvio
  account, so signing in on a second Apple TV brings your sources with it instead of making you
  type keys with the remote again.

Honesty section, because this one deserves it: while testing that sync on my own Apple TV, I
found that every credential push from the TV app was being silently rejected by the backend.
Not just new setups, every single one, and nothing in the UI ever told you. So if you ever set
a key on the TV and wondered why it never showed up anywhere else, that was not you. It is
fixed and I verified the full round trip on real hardware before cutting this build.

**The Back-button crash out of search results is fixed.** This came in by DM from a tester on
tvOS 27: expanding search results and pressing Back could throw you all the way out to the
Apple TV home screen. It turned out not to be a crash at all. The expanded page was losing the
search, coming up empty, and with nothing on the page to focus your Back press went to the
system instead of the app. Back always works there now, and empty pages carry a Go Back button
so you can never get stranded. Related, and also fixed, u/Ginosaure's report: **See All grids
remember your position.** Back out of a title deep in a grid and you are on the poster you
left, not at the top.

**Focus feels right again.** In beta 10 the zoom happened inside the poster while the tile's
edge stood still, and the growing artwork could swallow the title under it (u/mrStevenx3
called both out). The whole card lifts as one piece now, title staying visible below. And if
the zoom was never your thing, there is a new **No Zoom on Focus** option (Settings ->
Appearance) that marks the focused card with a border and shadow instead of scaling anything.

Also new or fixed:

- **White theme cleanup, round two.** Another sweep over light-text-on-light-highlight spots:
  the settings sidebar, stream list rows and group headers, the cloud library, add-on rows,
  and the tab pills on Collections. And the accent focus ring in White now draws actually
  white instead of swapping itself to grey.
- **Collections look like themselves.** Tiles without a cover pull artwork from their first
  title, collection logos render on the tiles, the focus GIFs decode at tile size so the row
  scrolls smoother, and service tiles with the logo already printed on the cover no longer
  draw it a second time on top.
- **The hero commits its text once.** No more flash of one language being replaced by another
  while the pinned hero loads.
- **Detail pages lost a focus trap.** Certain spots in the description could strand you unless
  you went left first. The whole top block is one focus region now.
- The stream list's language badge respects the dark theme like everything around it.
- A long browsing session is easier on the trailer player, and this build carries a hidden
  diagnostic switch I can walk anyone through if trailers ever go dark on you again.

As always: sideload with a free Apple ID, instructions in the release notes. If you retest
anything, Settings -> About should read **0.3.0 (107)**, include that number with your report.
Thanks to u/mrStevenx3, whose second video drove a good third of this build, to u/Ginosaure
for two well-described reports that both reproduced first try, and to the tester who reached
out by DM. Keep them coming.

---

## Required corrections to draft 3 before it posts (events overtook the 2026-08-06 text)

**1. The black bars paragraph (Lucky vs Futurama) is now FALSE and must be replaced.** The
device pass proved the measurement side works but the zoom gets stomped by the framework, so
bars persist on hardware. That would be fix claim number three if posted as written. Replace
with:

> **The black bars (Lucky vs Futurama).** You were right, and I owe you a straight answer
> instead of a third "fixed". Your video showed me why the first two attempts missed: Lucky's
> bars are baked into the video file itself, so nothing that describes the file admits they
> exist. The good news is the player now measures the actual picture during playback, and on my
> Apple TV it measures Lucky's bars exactly right. The bad news is that the zoom it computes is
> currently being overridden by the drawing framework a frame later, which I only caught by
> watching it fail on real hardware. So: not fixed in this build, genuinely close, and I am not
> claiming it again until Lucky fills the card on my own TV.

**2. The vanishing row titles paragraph needs its ending updated.** The probe ran on hardware
and titles were present at rest, but Christian spotted a likely mechanism the videos could
never show: the focused card's lift can cover the row title above it, which looks exactly like
a missing title in any still frame. Replace the last two sentences with:

> The next beta carried that measurement probe, and I have now run it on my own Apple TV: at
> rest, every title is present with proper clearance. But while doing it I spotted something
> your videos could never show: while a card in the row is focused and lifted, its raised edge
> can cover the title above it. A paused frame of that looks identical to a missing title. That
> is my best suspect now, and it is queued for the next beta.

Everything else in draft 3 held up against the device pass (trailer pipeline, white-on-white,
ring, collections, search filter) and posts as written. BUG-31 paragraph still waits on filming.

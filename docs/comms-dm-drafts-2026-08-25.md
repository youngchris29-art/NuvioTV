# DM reply drafts — 2026-08-25

**Status: UNSENT. Both need Christian's explicit go-ahead before anything is posted.**

Channel: Reddit chat (`chat.reddit.com`), from u/youngchris2989.
Both threads were read end-to-end on 2026-08-25; see the tracker's update-log entry for the intake.

---

## 1 — u/tiyeuedm

**Revised 2026-08-25 (afternoon), after the fix landed.** The first version of this draft was
written before any code existed and hedged accordingly. `b117da3d` is now built and sim-verified, so
the reply can say it is fixed — but the two questions still matter, because what was *proven* in the
simulator is the mechanism, not that his particular title travels through it. Ask them as
confirmation, not as a precondition for believing him.

**Do not promise a date.** beta.15 is held for this plus the focus-ring work, and no build has
reached him yet.

**Deliberately not in the reply:** the addon-count detail (11 installed, 1 matched, 10 dropped). It
is the most interesting thing found today and it is the wrong thing to send a tester — it invites him
to audit his addon list instead of answering the two questions.

> Found it, and it's fixed. Your config answer was what cracked it.
>
> It was never really about Vietnamese — though you were right that the two are connected. Stream
> addons like Meteor look titles up by IMDb id (`tt…`). When you open something from a TMDB-backed
> row — a collection folder, a search result, More Like This — the app was holding that title's TMDB
> id instead, and it never swapped it for the IMDb one before asking for streams. Meteor got an id it
> doesn't take and answered with nothing. The page itself looked perfect because the *metadata*
> lookup does do the swap, which is exactly why this hid for so long. And setting a metadata language
> is what moves you onto those TMDB rows in the first place — so localization was the passenger, not
> the driver.
>
> Now each addon gets asked with the id it actually accepts. I tested it on a title that returned
> nothing before and it comes back full.
>
> Two things would help me confirm your case is the same one:
>
> 1. On the empty list, which message did you see — "No streaming addons installed…" or "No streams
>    found"? Those are different problems and that tells them apart.
> 2. For Tokyo Swindlers, did you press the big Play button at the top, or pick an episode? Episodes
>    take a different route that should already have worked. If episodes failed too, I haven't found
>    all of it.
>
> Answer whenever — it's fixed either way, this just tells me whether to keep digging.
>
> Two others while I'm here. The default subtitle language you asked for shipped back in beta.12 —
> Settings → Playback → Preferred Subtitle Language, Vietnamese is in the list. Sorry, I should have
> told you at the time. Same for the search Back problem and the collection scroll position: both
> fixed in beta.12. If any of those still misbehave, tell me, because that means a fix didn't hold.

---

## 2 — u/mrStevenx3

**Why now:** he asked a direct question ("do you need me to do anything?") and then went and found a
reference implementation. Answer the question, tell him what the reference actually proved, and set
expectations on the build.

**Do not promise a date.** beta.15 is held to fold two more fixes in.

> That link was genuinely useful — thank you for going and finding it.
>
> It confirmed the fix, and not in the way I expected. Their cards never hand focus to the system at
> all: they draw their own ring and their own zoom, and the two are separate switches. Mine aren't —
> turning the ring on quietly swaps in a different, larger zoom, which is why it looks like the ring
> *causes* the zoom. You were right that they're connected; I'd been looking for a bug where there
> was actually a design fault. I'd already tried once to make the ring's zoom match the normal one
> and you told me it still looked wrong, so that approach is dead. I'm separating them properly
> instead: same zoom whether the ring is on or off, and the ring is just a ring.
>
> So, nothing needed from you on that one for now.
>
> On the build: everything from your last report is done and waiting — the collection title under
> the logo, the top bar, the doubled hero, the no-trailer flash, and the description stutter. I'm
> holding the release to get the ring fix in with them rather than making you update twice. When it
> lands, the two diagnostics photos I asked for are still the ones I want: Tab Bar Diagnostics at the
> top of Home and after scrolling, and Hero Paint Diagnostics after a relaunch and about a minute's
> wait. And if the description still stutters, say so and I'll walk you through the A/B switch — it's
> about thirty seconds.

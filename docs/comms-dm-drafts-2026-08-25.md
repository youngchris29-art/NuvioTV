# DM reply drafts — 2026-08-25

**Status: UNSENT. Both need Christian's explicit go-ahead before anything is posted.**

Channel: Reddit chat (`chat.reddit.com`), from u/youngchris2989.
Both threads were read end-to-end on 2026-08-25; see the tracker's update-log entry for the intake.

---

## 1 — u/tiyeuedm

**Why now:** he answered the config question this morning (Vietnamese + the Meteor addon), which is
what let the bug be root-caused. Two questions are still needed to confirm his exact case is the one
that was found, and he has been sitting on a shipped feature he asked for three weeks ago without
knowing it exists.

**Do not promise a date.** The fix is planned, not written.

> Thanks — that was exactly what I needed, and it cracked it.
>
> Meteor asks for streams by IMDb id (`tt…`). When you open a title from a TMDB-backed row — a
> collection folder, a search result, or More Like This — the app carries that title's TMDB id
> instead, and it never swaps it for the IMDb one before asking for streams. Meteor sees an id it
> doesn't accept and answers with nothing. The page itself looks perfectly fine because the
> *metadata* lookup does do the swap, which is what hid this for so long. Nothing to do with
> Vietnamese as such — but setting a metadata language is what moves you onto those TMDB rows in the
> first place, so your instinct that the two were connected was right.
>
> Two things would help me be sure your case is the one I found:
>
> 1. On the empty stream list, which message do you see — "No streaming addons installed…" or
>    "No streams found"? They're different bugs and that tells them apart.
> 2. For Tokyo Swindlers, did you press the big Play button at the top, or pick an episode from the
>    list? Episodes take a different path that should already work — if episodes fail too, I haven't
>    found the whole thing yet.
>
> Separately, one you asked for a while back and I never circled back on: the default subtitle
> language shipped in beta.12. Settings → Playback → Preferred Subtitle Language, and Vietnamese is
> in the list. Same for the search Back problem and the collection scroll position you reported —
> both fixed in beta.12. If any of those still misbehave for you, tell me, because that would mean
> the fix didn't hold.

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

# Reddit beta.15 announcement comment — POSTED, then EDITED (addon-wipe caution)

**EDITED 2026-08-28 (same day, later session):** appended the addon-wipe caution below after
the clean-install account addon-wipe was diagnosed and fixed
(`docs/addon-wipe-investigation-2026-08-28.md`; fix merged as `2f425b52`, beta.16 owed). The
edit warns fresh-install sign-ins off beta.15, gives the toggle-an-addon recovery, and publicly
retracts the cold-launch ask to u/mrStevenx3 (whose DM said stay on 14.5). Comment id unchanged
(`p6fempv`) — sweeps: same watermark, log-don't-file. ⚠️ Mechanics for next time: the NEW
reddit edit composer silently discards programmatic AND real-keystroke edits on save (three
failed attempts, comment never corrupted); **old.reddit.com's edit form works** — set
`textarea.value` + input/change events + click save. Rendered edit verified on the new-reddit
permalink afterwards.

Appended text (verbatim, after a blank line at the end of the original):

> **EDIT (Aug 28):** hold off on beta 15 for now if you would be doing a fresh install and
> signing in to your Nuvio account. We found a bug where a clean install plus sign-in can
> overwrite the add-on list saved on your account with the app's default list. Updating over
> 14.5 does not trigger this specific bug, but the safest move is to wait. The fix is already
> built and ships in beta 16 shortly. If it already hit you: open the app on a device that
> still shows your add-ons (14.5 is fine) and toggle any add-on off and on, that pushes your
> full list back to your account. u/mrStevenx3: this also means please ignore the cold-launch
> ask above for now and stay on 14.5 like we discussed in DM until beta 16 is up.

---

**POSTED 2026-08-28 as top-level comment
[`p6fempv`](https://www.reddit.com/r/Nuvio/comments/1v26ebw/comment/p6fempv/)**
(via ego-browser, logged-in session, new reddit Markdown editor; automod pre-submit
filter passed; rendered text verified identical to the draft below). **The next
sweep's watermark will pass over `p6fempv` — it is our own comment, log-don't-file.**
The sweep should watch for: mrStevenx3's cold-launch verdict (BUG-42/71) and
ring/zoom confirm (BUG-64), any reply on the choppy-scroll / clipped-row-titles
asks, and StudioKentin's answer (BUG-62).

Drafted 2026-08-28. beta.15 (build 113) was released 2026-08-27 and the thread's
pinned "Latest build" block was updated the same day, but no announcement comment
was ever posted until now. Same voice as the beta.14 one
(`comms-reddit-beta14-comment.md`).

Note on attribution: BUG-71/72/73 and the BUG-74 report came in by DM. Per the
beta.11 posting-notes precedent, u/tiyeuedm (BUG-74, DM-only) is deliberately NOT
named; the DM thread already told them the fix would ride this build and the
TMDB-row bullet is recognizable. u/mrStevenx3 is named, matching the beta.14
comment, which publicly followed up his DM diagnostics. Style per posting notes:
no em dashes, straight quotes.

---

beta 15 (build 113) is up: https://github.com/youngchris29-art/NuvioTV/releases/latest

What's new:

* Subtitle Timing: a new row in the player's Subtitles tab (both players) nudges subtitles earlier or later in 100 ms steps until they sit on the audio. Remembered per title across replays, kept separate per profile.
* Settings rebuilt on tvOS's native controls: real lists, switches and dropdown pickers like the Apple TV's own Settings app, with your accent color threaded through. Picking a theme swatch keeps focus on the swatch now instead of throwing you to the top.
* Continue Watching is now built with the same rules as Nuvio mobile (same titles, same order, up to 300 entries, hidden shows filtered) and the Top Shelf mirrors it.
* Your Library and Watch Progress source choices sync across devices: switch your scrobbler from Trakt to Simkl anywhere and every Apple TV follows. The app also refreshes account data in the background while open, so changes from other devices arrive without a relaunch.
* Titles opened from TMDB-backed rows resolve streams reliably now. This was the "streams never load for some titles" report, and it also covers titles opened from a resume deep link.
* The Discover section on Search remembers your last-picked catalog across launches.
* Anime added to a Simkl list is classified as anime (a title misfiled before this build corrects itself the next time you touch it).
* Removing an addon asks for confirmation first, and a pile of sync-reliability fixes landed under the hood.

u/Powerful_Curiosity: thanks for confirming the Continue Watching fix. The full fix shipped in this build, so the sources now stay in sync on their own. If you ever switch scrobblers again, every device should just follow without the manual re-select.

u/mrStevenx3: a big chunk of this build is your reports. The doubled hero on cold launch has a proper fix in 113 (three separate causes, all addressed). A couple of cold launches when you get a chance would tell me if it's finally gone, and if it ever comes back, the Hero Paint Diagnostics photo is still the thing I need. Also in: the focus-ring setting no longer re-enables the zoom, the collection name under the folder logo is gone, and posters without a trailer no longer do the brief landscape flicker. The tab bar not tucking away is the one I'm still on. It never happens in my test rig, only on real hardware, so it's taking longer, but it's not forgotten.

Still open to anyone on beta 15:

* Choppy description scrolling and the clipped row titles in pinned mode: both are still unreproduced here. A short clip or photo of either would unblock them.
* u/StudioKentin: the questions from the 13th still stand whenever you get a moment: which build you were on, and whether the bar got stuck visually or the app stopped responding.

Settings -> About should read 0.3.0 (113), beta tag tvos-v0.3.0-beta.15.

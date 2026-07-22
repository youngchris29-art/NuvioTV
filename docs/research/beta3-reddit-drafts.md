# beta.3 Reddit reply drafts (post after the release is live)

Post these on the beta thread once beta.3 is released. Adjust version number if it ships as something other than `tvos-v0.3.0-beta.3`.

## Top-level release comment

> **beta.3 is up** — this one's almost entirely built from the feedback in this thread. What's in it:
>
> - **Detail pages fixed** — the infinite spinner on most movies (u/mrStevenx3's report) was a real bug in how metadata ids were matched, worst with TMDB catalogs. Details, cast, and trailers load now, and slow addons time out after 5s instead of hanging the page.
> - **Player lag fix** — the first-minute stutter (u/time_continuum) came from the player doing synchronous state reads on the main thread exactly when the decoder was busiest. All player I/O is off the main thread now, and the swipe-up menu opens instantly.
> - **Stream list reorganized** — sources are now grouped per addon/indexer, collapsed by default with stream counts (u/time_continuum's dropdown suggestion). No more lag while everything loads into one giant list.
> - **Readable focus states** — the white-on-white focused rows are gone, and the White theme now uses dark text on light fills everywhere (both reports).
> - **QR sign-in** — as promised (u/Ginosaure): scan a QR with your phone at first launch, approve, done. No more typing credentials with the remote.
> - **Trailer sound** — press play/pause while the detail-page trailer is running to unmute it (u/mrStevenx3).
>
> Grab it from the releases page — same sideload process. Keep the reports coming, this thread has been incredibly useful.

## Individual follow-ups

**To u/time_continuum (BUG-2/3/4/5 reporter):**
> beta.3 has your whole list: the first-minute player lag (root cause was main-thread state polling contending with the decoder — genuinely your report that led us there), the slow swipe-up menu, the white-on-white focused rows, and the indexers now load into collapsed per-addon groups. One question — which stream type were you seeing the lag on (codec / Dolby Vision / debrid vs direct)? Want to confirm the fix covers your exact case.

**To u/mrStevenx3 (big review — BUG-7/8/9/10, FEAT-4/5):**
> beta.3 fixes the detail-page spinner (real bug, worst with TMDB catalogs — your "disabling the addon partially helped" observation was the clue that cracked it), and the background trailer now unmutes with play/pause. Can you check whether the "empty source list after Play" you saw still happens? We think it was the white-on-white focus bug hiding the rows, but if it's genuinely empty for you we'll dig further. Poster tilt and localization are on the list for the next updates.

**To u/Ginosaure (FEAT-1):**
> QR sign-in shipped in beta.3 as promised — it's the main sign-in option at first launch now. Scan, approve on your phone, done.

**FEAT-5 (external player) — reply to u/mrStevenx3 / u/Physical-Lab-9203:**
> Looked into external-player handoff: good news, it's doable on tvOS — Infuse has a documented x-callback API that works on Apple TV (Infuse 7.6.2+), so an "Open in Infuse" option is planned. VLC's URL scheme is only confirmed on iOS so far; if it works on the tvOS build we'll add it too, otherwise Infuse ships first.

**FEAT-3 (TestFlight) — status update when asked:**
> Update on TestFlight: did the homework on why similar apps got pulled — Stremio was removed from the App Store twice, even their stripped-down Lite version on tvOS. TestFlight applies the same review rules, so a full-featured public TestFlight would risk the developer account. Plan: the full build stays on GitHub sideload, and I'm looking at a limited internal TestFlight and/or a stripped "clean" build (no debrid, no preloaded sources) for broader distribution.

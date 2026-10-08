# GitHub issue #5 reply (2026-10-06) — FEAT-56, SenPlayer as an external player — POSTED https://github.com/youngchris29-art/NuvioTV/issues/5#issuecomment-6017661375 (no footer, as drafted: the commitment to add SenPlayer stands)

First reply on youngchris29-art/NuvioTV #5 (`4rtz1z`, 2026-10-05 18:58Z: "Possible to add SenPlayer as External Player? … not everyone is able to afford infuse LOL"). 0 comments on the issue; owed ~17 h at the 10-06 morning sweep.

Facts behind the draft (checked 2026-10-06): SenPlayer has an Apple TV app (App Store: iPhone, iPad, Mac, Apple TV; tvOS 17+; free with a one-off Pro purchase per platform). It opens playback through `senplayer://x-callback-url/play?url=…` (the same x-callback-url shape as the Infuse / VLC / Outplayer specs in `shared/.../ExternalPlayerPlatform.apple.kt`), and its changelog lists URL-scheme playback with external subtitles, a start time, a title and a user agent, a returned playback time on exit, and a 6.1.3 fix for "playback launched via URLScheme could not return" on TV. Nothing in upstream NuvioMobile mentions SenPlayer. Adding it is a new spec in that Kotlin file plus a `senplayer` entry in `LSApplicationQueriesSchemes`; the resume, subtitle and return-position halves need a real test on the Apple TV, which is why the reply does not promise them. VidHub is the cautionary precedent (listed, documented, and its tvOS build ignores the handoff).

Assumption Christian should confirm before posting: the reply commits to adding SenPlayer in a coming build. If he'd rather not commit, replace the second sentence of paragraph 1 with: `It's on the list.`

Lint: reply body 5/5 CLEAN (scripts/deslop/deslop.py, body only; the notes above are not copy). Cleanse skipped: Codex quota is out until 10-29.

```
Thanks for the request. SenPlayer has a play URL scheme of the same kind Infuse, VLC and Outplayer use, and it has an Apple TV version, so it fits the existing external-player path. I'll add it in a coming build, next to the others in Settings → Player and in the source list.

Two things I can't confirm until I've tried it on my own Apple TV: whether SenPlayer takes the resume position and subtitles the way Infuse does, and whether it hands the watch position back when you return. VidHub is listed today and its tvOS build ignores the handoff entirely (a bug on their side), so I'd rather test than promise. Which SenPlayer version are you on?
```

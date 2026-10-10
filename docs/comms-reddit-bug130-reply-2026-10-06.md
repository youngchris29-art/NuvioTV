# BUG-130 answer + BUG-128 thanks to u/an_angry_Moose (trailer restart on full screen; glitch video)

Parent comment: https://www.reddit.com/r/NuvioForks/comments/1wtmutc/tvos_nuviotv_a_native_apple_tv_app_built_on/pdgfqap/ (2026-10-02 17:54Z; the comment answered all three BUG-128 asks, attached a video, named both *Pinocchio* trailers, and asked the BUG-130 question directly).

Status: POSTED 2026-10-06 as comment [`pe7y533`](https://www.reddit.com/r/NuvioForks/comments/1wtmutc/tvos_nuviotv_a_native_apple_tv_app_built_on/pe7y533/) (reply to `t1_pdgfqap`) via the logged-in old.reddit `/api/comment` endpoint (api_type=json, no errors), as drafted: the position-carry commitment stands, the alternate line and the optional tester-build line were NOT used. Sweeps: our own comment, log-don't-file. Was owed ~94 h.

Facts behind the draft (verified in code 2026-10-06, `DetailView.swift` ~1112–1180, `TrailerHeroPlayerView.swift` `FullScreenTrailerPlayer`): the full-screen cover builds a new `FullScreenTrailerPlayer(urlString: item.url, …)`; nothing passes the background copy's time across, so the restart is by construction, not a product decision. Trailer Diagnostics (surface tags `detail-bg` / `detail-full`, health line) shipped in beta.19-rc1 (build 133) and is in every rc since; the public build he runs (beta.18, build 132) has none of it. The video at `pdgfqap` is still untriaged.

Assumptions Christian should confirm before posting: (1) the reply commits to carrying the playback position across the hand-off (the tracker calls this a product call; the alternate line below commits to nothing); (2) the optional last line offers a tester build, which so far only Steven gets.

Lint: reply body 5/5 CLEAN (scripts/deslop/deslop.py, body only; the notes above are not copy). Cleanse skipped: Codex quota is out until 10-29.

```
Thanks, that's everything I needed, and the video helps.

On the restart: it isn't a design choice. The full-screen player starts fresh from the same trailer instead of taking over from the copy behind the page, so it begins at zero. Picking up where the background copy left off, the way Android TV does, is the right behaviour, and I'll look at carrying the position across.

On the glitching: the build you're on has no way to show me what the player is doing at that moment. The next public build adds a Trailer Diagnostics line under Settings → About that records it, including which of the two trailer surfaces was playing. Once you're on it, a photo of that line after a Pinocchio run would tell me a lot. Both Pinocchio trailers are on my list to try here in the meantime.
```

Alternate for paragraph 2, last sentence, if the position carry is not being promised: `Picking up where the background copy left off, the way Android TV does, is what I'd want too. I've logged it.`

Optional closing line (tester build): `If you'd rather not wait for the public build, say so and I'll send you a tester build.`

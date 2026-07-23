# beta.4 announcement draft (r/Nuvio beta thread)

Written to match the beta.3 announcement's voice (`oz19z7h`): bold intro, bullets crediting
reporters by username, plain technical explanations, ends with a call for reports.

---

**beta.4 is up!** This one's a big one:

* **Crash at the profile screen fixed** — u/frpgareth reported the app force-closing every time they picked a profile. Root cause: profile selection loads a dozen data stores in one pass on the main thread, and if *any one* of them hit an error, the whole app died — every time, same spot. Now a failing store just logs and gets skipped, so you always get into the app. If you hit this before, please update and let me know — and if it somehow still crashes, the log now names the exact component, so a quick log grab would point me straight at it.
* **External player support: Infuse, VLC, and Outplayer** — the most requested feature (u/mrStevenx3, and u/Physical-Lab-9203's Infuse comments didn't go unnoticed). Hold-press any stream in the picker → "Open in Infuse" (or VLC / Outplayer), including debrid-resolved links. Or set one as your **default in Settings → Playback → Default Player** and every stream you select opens there — hold-press then gives you "Play in NuvioTV Player" for one-offs, and if the handoff ever fails you fall back to the built-in player instead of a dead remote. Players only show up if they're actually installed. I've verified Infuse on my own Apple TV; VLC and Outplayer use their documented handoff APIs but I couldn't test them on hardware — if you have either installed, reports welcome.
* **Watch trailers full screen** — new "Watch Trailer" button on the detail page, plays with sound and the standard tvOS controls, like the mobile app (u/mrStevenx3).
* **Hero artwork always visible** — several of you read the fade-in-on-focus as a bug (u/time_continuum), so the poster now just shows. If you liked the old look there's a toggle in Settings → Appearance → Poster Style.
* **Poster cards actually rise and tilt now** — u/mrStevenx3 pointed out the effect I advertised wasn't there. It is now, and the focused poster is bigger too. (Respects Reduce Motion.)
* **Custom profile pictures fixed** — pictures imported from other Nuvio apps (like Xperence) load instead of showing a placeholder (u/What_Happened_To_It).
* **Stream list tells you why it's empty** — if sources were found but none are playable (usually torrent-only results with no debrid connected), it now says exactly that and points at the setting, instead of a blank screen (u/mrStevenx3's missing-tracks report).
* **New install guide** — step-by-step sideloading instructions including the wireless path for USB-less Apple TVs and setting up the 7-day auto re-sign: [INSTALL.md](https://github.com/youngchris29-art/NuvioTV/blob/main/INSTALL.md). Covers the questions from u/Sapir28 and u/DotAffectionate3955, plus u/neuroguru23's Signulous tip.

Grab it from the [releases page](https://github.com/youngchris29-art/NuvioTV/releases/latest) — same sideload process, and your accounts/settings survive the update. Keep the reports coming, this thread keeps making the app better.

---

**Posting notes (not part of the comment):**
- Post as a top-level comment on the beta thread, same as the beta.3 announcement.
- The daily tracker sweep will pick up replies automatically (maintainer comments are ignored except fix-shipped statements).
- If character count is a concern on old Reddit, the install-guide bullet is the safest cut — the link is also in the release notes.

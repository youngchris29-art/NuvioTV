# beta.4 announcement draft (r/Nuvio beta thread) — conversational v2

Matches Christian's actual commenting voice in the thread (casual, appreciative, direct).
v1 (formal bullet list) is in git history if needed.

---

**beta.4 is up!**

First — u/frpgareth, the crash you hit at the profile screen was real and it was bad. Turned out if any one of the profile's data stores hit an error while loading, the whole app went down with it, every single time. That's fixed — a bad store just gets skipped now and you get into the app. Would love if you gave it another shot. If it still crashes for you I'd genuinely be surprised, but the logs will now tell me exactly what broke, so say the word and we'll get it sorted.

The big new thing: **external player support**. A bunch of you have been asking for this, and honestly u/Physical-Lab-9203 comparing me to the fork with Infuse support lit the fire 😄. So: hold-press any stream and you'll see "Open in Infuse" (or VLC, or Outplayer — whatever you've got installed). Debrid links hand off too. And if you basically live in Infuse, go to Settings → Playback → Default Player and just make it the default — then every stream you click opens there, hold-press gets you back to the built-in player for one-offs, and if a handoff ever fails it falls back to the built-in player instead of leaving you staring at nothing. I tested Infuse on my own Apple TV and it works great. VLC and Outplayer *should* work the same way but I don't have them on hardware to confirm — if you do, tell me how it goes.

Rest of the batch, mostly straight from your feedback:

* u/mrStevenx3 — the trailer now plays full screen with sound from a proper "Watch Trailer" button, the poster rise-and-tilt effect I claimed existed actually exists now (and the focused poster got bigger), and the empty stream list finally explains itself — "found 44 torrent sources but no debrid connected" instead of a blank screen. That was your missing-tracks mystery.
* u/time_continuum — you were right that the hero looking empty was confusing. The artwork just shows now. (If anyone liked the old fade-on-focus, there's a toggle in Settings → Appearance.)
* u/What_Happened_To_It — your Xperence profile pictures load now instead of the placeholder.
* And for everyone who got stuck sideloading (u/Sapir28, u/DotAffectionate3955): there's a proper step-by-step guide now at [INSTALL.md](https://github.com/youngchris29-art/NuvioTV/blob/main/INSTALL.md) — wireless install for the USB-less Apple TVs, the 7-day auto re-sign setup, and u/neuroguru23's Signulous tip made it in too.

Same download spot as always: [releases page](https://github.com/youngchris29-art/NuvioTV/releases/latest). Update installs right over the top, your accounts and settings stay.

This thread has basically been writing the roadmap — keep it coming.

---

**Posting notes (not part of the comment):**
- Top-level comment on the beta thread, like beta.3's announcement.
- The daily tracker sweep picks up replies automatically.
- Safest cut if too long: the INSTALL.md bullet (link is also in the release notes).

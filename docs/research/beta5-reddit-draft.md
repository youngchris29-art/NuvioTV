# beta.5 announcement draft (r/Nuvio beta thread)

Matches the beta.3/beta.4 voice (`oz19z7h`, beta.4 v1): bold intro, bullets crediting reporters
by username, plain technical explanations, honest about what isn't verified, ends with a call
for reports. Five bullets this time (beta.4 had eight).

---

**beta.5 is up!** Translations, All-Debrid, and a couple of fixes:

* **The app speaks French, Spanish, German and Italian now** — u/mrStevenx3 asked for this a while back and u/Ginosaure asked again for French, and honestly the thread made the case on its own: a lot of you aren't reading this in English. Home, detail pages, the stream picker, all of Settings and the profile gate are translated, and it just follows your Apple TV's system language — nothing to switch on. A few rarely-seen error messages still fall back to English (a few more of those in German than the others; I'll close that gap). If something reads awkwardly or is still in English where it shouldn't be, tell me — that kind of report is genuinely easy to act on.
* **All-Debrid support** — u/Ginosaure asked for this one too. Settings → Debrid → All-Debrid gives you a PIN code to enter on alldebrid.com from your phone, so no typing an API key with the remote (you can still paste a key by hand if you'd rather). Straight up: I don't have an All-Debrid subscription, so I've tested the sign-in, the error handling and the cancel path against the live API, but I have **not** managed to play an actual stream through it. If you're an AD user, that's the one report I'd really like. One AD quirk worth knowing — they dropped the bulk cache-check endpoint, so streams can't be flagged cached/uncached up front like Real-Debrid and TorBox; it resolves when you pick one.
* **⚠️ If you use Trakt, you'll need to sign in again — once per profile.** Trakt logins were being stored per *device* rather than per *profile*, which meant switching profiles could read, or overwrite, another profile's Trakt connection. That's fixed, but the fix changes where the login lives, so existing connections come back logged out after you update. Reconnect under Settings → Trakt on each profile that uses it. Irritating once, correct from then on.
* **MyAnimeList scores** — MAL ratings now show up alongside the existing ones on detail pages. On by default, switchable in the ratings settings.
* **The profile-screen crash — another layer, and better logging.** u/Superb_Freedom9937 is still getting a force-close on every profile tap on beta.4, and I want to be straight about where this stands: I spent a day trying to reproduce it and couldn't, even on a clean install signed into a real account with several profiles. So I can't promise this build fixes it. What I did find is one call on the profile-tap path that wasn't protected the way the rest of it is, and that only runs when you're signed in — which matches the symptoms exactly. It's guarded now, so if that's the culprit it should fail quietly instead of taking the app down, and I've added logging that names each stage of a profile tap. Also, an apology: the log I asked for earlier turns out to live somewhere the Apple TV won't show you, so that request was impossible to satisfy — my fault. If it still crashes and you have a Mac, Xcode → Window → Devices and Simulators → your Apple TV → View Device Logs will have it. If you don't have a Mac, just say so and we'll figure something else out.

Grab it from the [releases page](https://github.com/youngchris29-art/NuvioTV/releases/latest) — same sideload process, and your accounts and settings survive the update (except the Trakt reconnect above). Keep the reports coming.

---

**Posting notes (not part of the comment):**
- Post as a top-level comment on the beta thread, same as beta.3/beta.4.
- **Also reply directly to u/Superb_Freedom9937's comment** (`ozoqvzr`) — a top-level announcement is easy for them to miss, and they've answered every question so far. Short version to paste there:

  > Update for you — beta.5 is up. I couldn't reproduce the crash on my end even on a clean install signed in with several profiles, so I can't promise it's fixed, but I did find one spot on the profile-tap path that wasn't protected and only runs when you're signed in, which fits your symptoms. That's guarded now, plus better logging. Also: the log I asked you for earlier lives somewhere the Apple TV won't show you — that was an impossible ask on my part, sorry. If it still crashes and you've got a Mac, Xcode → Window → Devices and Simulators → your Apple TV → View Device Logs will have it. If not, no worries, say so and we'll find another way.

- u/Ginosaure is worth a direct reply too — both of their requests (French, All-Debrid) shipped in this build, and they're the most likely person to confirm the All-Debrid path.
- The AD "I haven't tested playback" admission is deliberate. It's the same posture as beta.4's VLC/Outplayer caveat, which worked well.
- If length is a problem on old Reddit, the MyAnimeList bullet is the safest cut.

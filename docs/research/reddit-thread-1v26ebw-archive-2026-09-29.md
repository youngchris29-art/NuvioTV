# Archive: the r/Nuvio beta thread (post `1v26ebw`)

Recovered 2026-09-29 from the author's logged-in session (`/api/info.json?id=t3_1v26ebw`),
because the public view of the post now reads `[removed]`.

| Field | Value |
|---|---|
| Title | I built a native Apple TV app for Nuvio. Beta testers wanted! |
| Subreddit | r/Nuvio |
| Author | u/youngchris2989 |
| Posted | 2026-07-21T03:05:56+00:00 |
| Flair | Unofficial Fork |
| Type | gallery post, 4 images |
| Comments at recovery | 185 |
| Score at recovery | 110 |
| State | removed by a moderator (`removed_by_category: moderator`), not locked |
| Removal notice | comment `pcfcvh5` by u/Nuvio-ModTeam, 2026-09-27T19:16Z: r/Nuvio changed its rules and no longer hosts unofficial forks or modified builds; it invites a repost at r/NuvioForks |
| Final watermark | `pcfcvh5` (the removal notice). Last tester comment: `p7w0syf` (u/napes22, BUG-97). Last comment of ours: `p81ihg4` |
| Permalink | https://www.reddit.com/r/Nuvio/comments/1v26ebw/ (comment permalinks still resolve) |

Gallery images (Reddit media ids, no captions):

- `4u5q0pm11ieh1` (3840x2160, image/png)
- `qr4uvxc31ieh1` (3840x2160, image/png)
- `3uyf6tl41ieh1` (3840x2160, image/png)
- `kbmtupx51ieh1` (3840x2160, image/png)

The body below is the stored selftext, byte for byte, as of the beta.17 block edit of 2026-09-02.
It is quoted material: do not edit it.

---

Hey everyone,

For the past while I've been working on **NuvioTV**, a native Apple TV port of [Nuvio](https://github.com/NuvioMedia/NuvioMobile). I didn't want to just stretch the mobile UI onto a TV screen. We've all used apps that do that and they always feel off. So instead I kept Nuvio's core under the hood and built a completely new SwiftUI interface on top, designed from day one for the Siri Remote and the couch. Full transparency: I used Claude AI to help with the port.

It's finally at the point where I'd love to get it in front of more people than just me and my living room.

**Repo:** [https://github.com/youngchris29-art/NuvioTV](https://github.com/youngchris29-art/NuvioTV)  
**Download the beta IPA:** [https://github.com/youngchris29-art/NuvioTV/releases/latest](https://github.com/youngchris29-art/NuvioTV/releases/latest)

**Latest build: beta 17 (build 116)**

What's new in beta 17:

* Large poster size is fixed for good: rows land in the same place every time, no posters cut off, no titles overlapping the row above. No Zoom on Focus behaves the same on every tile. This is the whole batch from the beta.16 report, all of it verified on hardware.
* Add-ons that are still loading no longer look empty. Home, Search and Discover show a loading state while an add-on's manifest is fetched, and if it fails to load you get the error and a Retry button instead of "No results" or "Install an add-on".
* Anime skip intro/outro now resolves IDs through Simkl (the old ARM service is gone) and maps each episode to the right season, so multi-season anime stop getting season 1's timings.
* Menu dismisses the "Play Next Episode" countdown so you can watch to the credits; press Menu again to leave the player. The native player also has a Dismiss action next to Play Next Episode.
* When TMDB has no season art, the season row uses the addon's own season posters (specials included), and addons that publish a localized age rating get it in the rating chip.
* Next-episode auto-play honors your auto-play source setting: with "installed add-ons only" or "enabled plugins only" it picks as soon as those sources have answered.
* Trailers: the silent-trailer regression from beta 16 is fixed, and the catalog list under Home Rows is selectable with the remote again.

Settings -> About should read 0.3.0 (116), beta tag tvos-v0.3.0-beta.17.

**So what does it do?**

The stuff you'd expect: browse catalogs from your Stremio addons, search, a library with collections and cloud sync, continue watching, Trakt scrobbling, TMDB and MDBList metadata, and profiles with PINs. Addons run on a local JS runtime right on the box, and you can install them in the app or straight from `stremio://` links.

The part I'm most proud of is the player. There's a hybrid setup: a native AVPlayer path that remuxes MKVs on the fly, including **Dolby Vision** (it converts Profile 7 to 8.1 during playback) and TrueHD or DTS audio, plus an mpv player with HDR tone mapping for everything else. You get addon subtitles in both players, skip intro, autoplay for the next episode, and a stream picker with quality and codec badges. If you have a debrid service, connect it with a device code or API key and cached results resolve straight to playable links.

There's also all the small tvOS stuff that makes it feel like a real Apple TV app. A hero carousel on the home screen, poster cards that lift and tilt as you move focus around, and a Top Shelf extension so your continue watching row shows up on the Apple TV home screen.

**Installing it**

You don't need a paid developer account. Grab the IPA from the releases link and sideload it with a free Apple ID using [Sideloadly](https://sideloadly.io/), or [atvloadly](https://github.com/bitxeno/atvloadly) if you want something you can host yourself that refreshes automatically. Full instructions are in the release notes. Fair warning about free Apple IDs: apps need a fresh signature every 7 days (both tools can automate this) and you can only have 3 sideloaded apps at a time.

**What I'm looking for**

It's an early beta, so I mostly want to know what breaks. Bug reports, feature requests, or just "hey this played / didn't play on my setup" all help. GitHub issues are the best place, but I'll be in the comments too.

Needs tvOS 26 or later. Screenshots attached so you can see what it looks like.

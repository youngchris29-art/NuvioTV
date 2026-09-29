# r/NuvioForks launch post (replaces the removed r/Nuvio thread `1v26ebw`)

Status: POSTED 2026-09-29T21:33:46Z as post `1wtmutc`: https://www.reddit.com/r/NuvioForks/comments/1wtmutc/tvos_nuviotv_a_native_apple_tv_app_built_on/
Title as posted: `[tvOS] NuvioTV: a native Apple TV app built on Nuvio's core (open source, beta testers wanted)`.
The first attempt was blocked by the sub's title rule; the mod fixed it after the modmail and the post went up on the second attempt.
Stored body verified: text equals the draft, both block anchors and the download line match `update-reddit-beta-post.py`'s patterns.
Reddit stores the four inline images as `https://preview.redd.it/...` lines at the end of the body; an edit must keep those lines.
SlopMonster: 5/5 on `scripts/deslop/deslop.py` (first pass 3/5, two hits rewritten). Codex cleanse
SKIPPED: the local `codex` CLI is configured for a model its account rejects (HTTP 400).

## Posting notes

- **Subreddit:** r/NuvioForks
- **Post type:** text post with the images inline at the end, NOT a gallery. The old gallery post had
  no edit control on old.reddit.
- **Title (cannot be edited later, so no build number in it):**
  `NuvioTV: a native Apple TV app built on Nuvio's core (open source, beta testers wanted)`
- **Flair:** pick the fork/release flair if the sub has one.
- **Images, in order:** `design/screenshots/home.png`, `hero-pinned.png`, `detail.png`, `player.png`
- **Block anchors:** the "Latest build" block keeps the format `update-reddit-beta-post.py` matches
  (`**Latest build:` through `Settings -> About should read`), directly under the download line.
- One bullet in the block was reworded from the 09-02 text ("Auto play for the next episode honors
  your source setting"), same facts.
- After posting: record the new post id, then run Phase 4 of the migration plan.

## Posting attempt 2026-09-29 (BLOCKED, nothing published)

Christian authorized posting through the logged-in session. The post was fully composed in the
new-Reddit editor (title, body text verified equal to the draft, four inline images at the end,
flair "Drop / Release") and then could not be submitted:

- The sub runs a post-guidance rule, "Title must begin with a platform tag: [Android TV] [Fire TV]
  [tvOS] ...". It disables the Post button.
- The rule fires under the "Drop / Release" and "Work in Progress" flairs for EVERY title tried,
  including `[tvOS] NuvioTV ...` and the rule's own example `[Android TV] Nuvio-Lite v1.2 - Fix`.
  Under "Help / Questions" the same titles pass. The rule looks misconfigured on the sub's side.
- Flair is required, so there is no way to post as a release without tripping it.
- Not done: posting under a wrong flair or through `/api/submit` to get around the rule.

Mechanics learned, for the retry:

- `/api/media/asset.json` and `/api/convert_rte_body_format` refuse the cookie session (403 / 404),
  so images cannot be uploaded by API. The composer route works: set the files on the
  `post-composer-toolbar-button-image` file input (CDP `DOM.setFileInputFiles`), then click
  "Add to body"; the images land at the end of the body.
- Switching the editor to Markdown drops images, so the body goes in as an HTML paste in rich-text mode.
- The title needs the `[tvOS]` prefix once the rule works.

## Body

Hey everyone,

Some of you know this one from r/Nuvio. That sub stopped hosting forks last week, so the NuvioTV beta thread lives here from now on.

**NuvioTV** is a native Apple TV port of [Nuvio](https://github.com/NuvioMedia/NuvioMobile). I didn't want to stretch the mobile UI onto a TV screen. We've all used apps that do that and they always feel off. So I kept Nuvio's core under the hood and built a new SwiftUI interface on top, designed for the Siri Remote and the couch. Full transparency: I used Claude AI to help with the port.

**Repo:** [https://github.com/youngchris29-art/NuvioTV](https://github.com/youngchris29-art/NuvioTV)  
**Download the beta IPA:** [https://github.com/youngchris29-art/NuvioTV/releases/latest](https://github.com/youngchris29-art/NuvioTV/releases/latest)

**Latest build: beta 17 (build 116)**

What's new in beta 17:

* Large poster size is fixed for good: rows land in the same place every time, no posters cut off, no titles overlapping the row above. No Zoom on Focus behaves the same on every tile. This is the whole batch from the beta.16 report, all of it verified on hardware.
* Add-ons that are still loading no longer look empty. Home, Search and Discover show a loading state while an add-on's manifest is fetched, and if it fails to load you get the error and a Retry button instead of "No results" or "Install an add-on".
* Anime skip intro/outro now resolves IDs through Simkl (the old ARM service is gone) and maps each episode to the right season, so multi-season anime stop getting season 1's timings.
* Menu dismisses the "Play Next Episode" countdown so you can watch to the credits; press Menu again to leave the player. The native player also has a Dismiss action next to Play Next Episode.
* When TMDB has no season art, the season row uses the addon's own season posters (specials included), and addons that publish a localized age rating get it in the rating chip.
* Auto play for the next episode honors your source setting: with "installed add-ons only" or "enabled plugins only" it picks as soon as those sources have answered.
* Trailers: the silent-trailer regression from beta 16 is fixed, and the catalog list under Home Rows is selectable with the remote again.

Settings -> About should read 0.3.0 (116), beta tag tvos-v0.3.0-beta.17.

**What I changed from upstream**

The business logic is Nuvio's own: addons, catalogs, sync, watch progress and the account system all come from NuvioMobile's Kotlin code, and I port upstream fixes into the fork as they land. I replaced two things. The interface is SwiftUI written for tvOS, and the player is a pair of engines built for the Apple TV. It signs in to the same Nuvio account as the official apps, or to your own self-hosted server.

All of it is open source at the repo above. The IPA is built from that source by a script in the repo, unsigned, with no account and no addons inside. You add your own on first launch. Settings > About shows the build number and the commit it was built from.

**So what does it do?**

The stuff you'd expect: browse catalogs from your Stremio addons, search them, and keep a library with collections and cloud sync. Continue watching follows you between devices. Trakt and Simkl handle scrobbling, with TMDB and MDBList for metadata. Profiles can have PINs. You sign in by scanning a QR code with your phone, so there's no typing a password with the remote. Addons run on a local JS runtime right on the box.

The part I'm most proud of is the player. There's a hybrid setup: a native AVPlayer path that remuxes MKVs on the fly, including **Dolby Vision** (it converts Profile 7 to 8.1 during playback) and TrueHD or DTS audio, plus an mpv player with HDR tone mapping for everything else. Both players get addon subtitles with a timing offset, skip intro, autoplay for the next episode, and a stream picker with quality and codec badges. You can also hand a stream to Infuse, VLC or Outplayer. If you have a debrid service, connect it with a device code or API key.

Then there's the tvOS side. The home screen has a hero carousel, poster cards lift and tilt as you move focus around, and a poster can play its trailer in place when you rest on it. The interface comes in six languages.

**Installing it**

You don't need a paid developer account. Grab the IPA from the releases link and sideload it with a free Apple ID using [Sideloadly](https://sideloadly.io/), or [atvloadly](https://github.com/bitxeno/atvloadly) if you want something you can host yourself that refreshes automatically. Full instructions are in INSTALL.md in the repo. Fair warning about free Apple IDs: apps need a fresh signature every 7 days (both tools can automate this) and you can only have 3 sideloaded apps at a time.

**Feedback**

It's a beta, so I mostly want to know what breaks. Bug reports, feature requests, or "this played / didn't play on my setup" all help. Post here or open a GitHub issue, which is the better home for anything with a crash log or a screenshot. I read every comment. New builds get announced in this thread and the block at the top always describes the latest one.

One ask: please keep NuvioTV bugs here or on GitHub and out of r/Nuvio. The official team doesn't build this fork and shouldn't have to field questions about it.

Needs tvOS 26 or later. Screenshots below.

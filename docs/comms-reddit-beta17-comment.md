# Reddit beta.17 announcement comment — DRAFTED 2026-09-02, NOT POSTED

Covers beta 16 too: beta 16 (build 114, 2026-08-28) never got its own top-level comment (the
beta.15 comment `p6fempv` was edited to say "fixed in beta 16" and the pinned Latest-build block
was swapped, but no announcement). Same voice as `comms-reddit-beta15-comment.md`. Style per the
posting notes: no em dashes, straight quotes. u/mrStevenx3 is named (his DM list drove the whole
beta.17 batch; he is publicly named in the beta.14 and beta.15 comments already). No claim is made
that he has confirmed rc2 or beta 17; the ask is for his verdict. Post as a top-level comment on
the beta thread (`1v26ebw`) after the pinned Latest-build block is swapped to beta 17
(`comms-reddit-beta17-changelog.md`). Sweeps: our own comment, log-don't-file.

---

beta 17 (build 116) is up: https://github.com/youngchris29-art/NuvioTV/releases/latest

Two builds since the last announcement here, so a quick recap of both.

beta 16 (Aug 28) was the important one if you ever did a fresh install: it fixed the bug where a clean install plus sign-in could overwrite the add-on list on your account with the app's default list. Settings sync got the same protection. If beta 15 hit you, re-adding your add-ons on any device syncs them back up. Sorry again to anyone affected.

beta 17, what's new:

* Large poster size is fixed for good. Rows land in the same place every time, no posters cut off at the edge, no row title overlapping the row above, and the hero makes room instead of fighting the rows. No Zoom on Focus behaves the same on every tile.
* Add-ons that are still loading no longer look empty. Home, Search and Discover show a loading state while an add-on's manifest is fetched, and if it fails to load you get the error and a Retry button instead of "No results" or "Install an add-on". No relaunch needed to recover from a slow start.
* Anime skip intro/outro now resolves through Simkl (the old ARM service is gone) and maps each episode to the right season, so multi-season anime stop getting season 1's timings.
* Menu dismisses the "Play Next Episode" countdown so you can watch through the credits; press Menu again to leave the player. The native player also has a Dismiss action next to Play Next Episode.
* When TMDB has no season art, the season row uses the addon's own season posters (specials included), and addons that publish a localized age rating get it in the rating chip.
* Next-episode auto-play honors your auto-play source setting: with "installed add-ons only" or "enabled plugins only" it picks as soon as those sources have answered.
* Trailers: the silent-trailer regression from beta 16 is fixed, the detail page's trailer zoom is stable across clip changes, and the catalog list under Home Rows is selectable with the remote again.

u/mrStevenx3: most of beta 17 is your list. Everything you raised after beta 16 is in this build (Large posters, the blank catalog-selection section, no-zoom, trailer sound, the description-page zoom, settings colors), and I walked the Large-poster layout on my own Apple TV before cutting it. When you get a chance, a pass on 116 with your usual settings would tell me if it matches what you see. The tab bar not tucking away is still the one open item from your list; it only reproduces on hardware, so it's slower going, but it's not dropped.

Settings -> About should read 0.3.0 (116), beta tag tvos-v0.3.0-beta.17.

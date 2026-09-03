<!-- APPLIED 2026-09-02 to post 1v26ebw via the session /api/editusertext route (stored body verified). -->
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

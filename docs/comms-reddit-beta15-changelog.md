**Latest build: beta 15 (build 113)**

What's new in beta 15:

* Subtitle Timing: a new row in the player's Subtitles tab (both players) nudges subtitles earlier or later in 100 ms steps until they sit on the audio. Remembered per title across replays, kept separate per profile.
* Settings rebuilt on tvOS's native controls - real lists, switches and dropdown pickers like the Apple TV's own Settings app, with your accent color threaded through the glyphs and values. Picking a theme swatch keeps focus on the swatch now instead of throwing you to the top.
* Continue Watching is built with the same rules as Nuvio mobile - same titles, same order, up to 300 entries, hidden shows filtered, same recency window - and the Top Shelf mirrors it.
* Your Library and Watch Progress source choices now sync across devices: switch your scrobbler from Trakt to Simkl anywhere and every Apple TV follows. The app also refreshes account data in the background while open, so changes from other devices arrive without a relaunch.
* Titles opened from TMDB-backed rows resolve streams reliably now (addons are asked with an id they accept) - this was the "streams never load from some rows" report.
* The Discover section on Search remembers your last-picked catalog across launches.
* Anime added to a Simkl list is classified as anime (a title misfiled before this build corrects itself the next time you touch it).
* Removing an addon asks for confirmation first.
* A pile of sync-reliability fixes under the hood: rate-limit handling, deduplicated pushes, and periodic refresh while the app is open.

Settings -> About should read 0.3.0 (113), beta tag tvos-v0.3.0-beta.15.

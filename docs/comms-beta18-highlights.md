<!-- RELEASED 2026-10-01 evening as tvos-v0.3.0-beta.18 (build 132, NuvioMobile 1973d411) on both repos, marked Latest. The generated commit list was stripped from the published notes (gh release edit) because the sanitizer leaves review-round and batch-code lines; notes = this file + compare link + install steps. -->
## Highlights

beta 18 is the first public build since beta 17 on September 2. Fourteen release candidates went through one tester's Apple TV in between, and this build carries all of that work plus a month of fixes ported from upstream Nuvio. Every new setting is off by default, so nothing changes until you turn it on.

### Playback and sources

- **Auto-Play Best Source** (Settings > Playback). Press Play on a title and the app picks the best source itself instead of opening the picker. On titles with dozens of candidates the first pick is playing within a few seconds. A **Cached Sources Only** sub-toggle limits it to debrid-cached links. Hold Play on the description page for **Choose Source** when you want the list.
- **Failover.** A link that fails to start, or stalls before the first frame, no longer strands you. Automatic flows move to the next link on their own, up to four tries. A manual pick asks first with **Try Next Source**. Links that failed are remembered for eight hours and skipped.
- **Sources filters apply to every source.** Sort, Minimum Resolution, Dolby Vision, HDR and Cached Sources Only in the stream picker now filter all add-ons and plugins, not only debrid results.
- **Infuse hands progress back.** When you send a stream to Infuse, NuvioTV records the watch progress Infuse reports on return. The resume position is carried out as before.
- **Skip segments for movies**, auto-skip by segment type (Settings > Playback), and the up-next card waits through a post-credits scene. A skip waits for the player to confirm the seek, so it no longer lands early on a slow source.
- **Episode shuffle** in the episodes section.
- A Continue Watching row that carries only a percentage (Trakt) now **resumes at that percentage** in both players. The mpv player applies your preferred audio language before the stream opens, so there is no audible switch after the first seconds. Debrid season packs select the requested episode's file.
- Two more toggles under Playback and Search: **Pause Info Card** and **Recent Searches**.

### Accounts and metadata

- **MDBList account** under Accounts & Services, signed in with a device code. MDBList can be your **Library and Watch Progress source**, receives scrobbles, and the ratings rows follow the connected account. Library lists show the newest additions first.
- **Simkl**: the app now scrobbles to every connected tracker (Simkl was skipped before), Simkl is a **More Like This** source, a **TVDB** option joins the anime-ID preference, four upstream sync bugs are fixed, and an ambiguous Simkl id resolves to the right type.
- **Custom poster URLs.** A poster URL pattern set on the phone, or through Remote Setup, replaces artwork on the TV, with per-screen toggles under Settings > Appearance > Custom Posters.
- **No TMDB key needed.** The app ships with a bundled TMDB key. If you had entered your own, it stays as a personal override.
- **Play is disabled** on a title none of your add-ons or plugins can play, instead of opening an empty stream list.
- Deleted add-ons and library items stay deleted: an empty server pull no longer restores them. Library title logos sync between devices. Add-ons whose ids are not IMDb ids still get episode ratings and the parental guide through their imdb_id field, and per-episode runtimes written as text ("45min") now show.

### Home, description page and appearance

All of this came out of the release-candidate cycle and was checked on the reporting tester's hardware.

- **Row titles stop bouncing and hiding.** At Large and Medium+ poster sizes the focused row title moved while the rows were still scrolling and could land on the poster or fade out. Titles now settle only once the row has stopped. Up from the second row reaches the genre row again, and an Up press or swipe on the hero scrolls the rows to the top.
- **Medium+** poster size: between Medium and Large, with four synopsis lines.
- **Hold menus.** Hold the select button on a poster for Library and Watched actions, and on a Continue Watching card for Play Manually, Go to Details, Mark Episode Watched, Start Over and Remove.
- **Hero**: the focused title's logo reaches the hero before the backdrop commits, the hero paints once at launch instead of twice, a collection folder's backdrop that arrives late still lands, and the synopsis fits two lines at Medium+ and Large.
- **Appearance**: Card Depth Subtle, Balanced and Bold are visibly different. Folder tiles and cast avatars get the accent ring and the depth rail, and in ring mode the artwork and ring lift as one piece. New options: **Ring Takes Poster Color**, an **OLED True Black** theme, regular-weight Open Sans body text, a **Row Edge Fade** choice, and **Episode Ratings** as Show, Watched Only or Hide. Collection rows reach the screen edges, and the folder header is centered and stays put.
- **Description page**: it enters the full-screen trailer the way Nuvio does. The chrome fades, the title becomes a caption, the trailer cuts in from black and returns to the still. Saga rows show wide 16:9 cards with the title logo. Scrolling down keeps the focus engine's own reveal while Up anchors the row under a top scrim. A trailer that fails to extract or play tries the next candidate. The glass chips flatten while the page scrolls, the backdrop is larger with less dark overlay, and the stream picker shows the title logo.
- **Sidebar** (the opt-in top bar): reveals on the Menu press only and hides on the description page.
- The build moved to Kotlin 2.4.10 along with upstream.

Known: on some Apple TVs the tab bar stays pinned after a tab switch. Settings > About carries diagnostics for it.

# Orivio TV vs NuvioTV — feature gap report (2026-10-01)

**Subject:** `github.com/prehakanson-art/OrivioTVAppleTV` at `0c30f52` (v0.11, 2026-09-29), compared against this fork (`tvos-shared-extraction` at rc14, build 131).

**Scope:** features Orivio has that NuvioTV does not, then a ranked recommendation. Features the fork has and Orivio lacks are listed only briefly at the end for perspective.

## What Orivio is

Orivio TV is a second, independent Apple TV port of the same product. It was first published as "NuvioTV for Apple TV" (v0.7.15, 2026-07-13), renamed to Orivio on 2026-07-17, and still signs into the same Supabase account backend (its `OrivioRenameMigration` carries `nuvio.*` preferences forward). It is pure Swift/SwiftUI with no shared Kotlin core: 127 Swift files, roughly 88,000 lines, of which `PlayerViewModel.swift` alone is 11,952. It vendors KSPlayer (FFmpeg), YouTubeKit, libdovi and links TVVLCKit. Deployment target is tvOS 17 and it runs on the Apple TV HD. There is no CI; IPAs are built by a shell script. GPLv3, same as this fork.

The repo ships two documents worth keeping as references on their own: `ORIVIO_TV_HANDOFF.md` (2,089 lines of engineering notes, many of them hardware-verified tvOS pitfalls) and `SETTINGS_REFERENCE.md` (every setting traced to its consumer). Their handoff also names a third sibling, `bobsupra/NuvioTVOS` (KMP + MPVKit), which they read clean-room for facts only.

## Method

Every "missing" below was checked in this fork's code, not in either README: `grep` across `iosApp/NuvioTV`, `iosApp/NuvioTopShelf` and `shared/src` for the feature's identifiers, then a read of the matching file when a hit was ambiguous. Where the fork has the feature on one player engine only, it is marked **partial**. Orivio's side comes from its handoff, settings reference and source files; its own handoff says several items were never exercised on a device, and those caveats are carried into the table.

## A. Features Orivio has that NuvioTV lacks

### A1. Sources and content

| # | Orivio feature | Orivio evidence | Fork status |
|---|---|---|---|
| 1 | **Live TV / IPTV tab.** Embedded iptv-org global list (about 10k channels), pasted M3U playlists, Xtream Codes server/user/password login (v0.11), per-channel headers / manifest type / DRM declarations carried to the player, favourites, an "Add to Home Page" channels row on Home, country and language filters, "Add from Phone" for the playlist URL. | `LiveTVView.swift`, `M3UService.swift`, `LiveStreamOptions.swift`, `LiveChannelFavorites.swift`, `LiveTVSettingsStore.swift`, `SettingsView.swift:1082` | **Missing.** No IPTV, M3U or Xtream code anywhere in the fork. |
| 2 | **Plex and Jellyfin media servers.** Plex PIN flow via `plex.tv/link`, Jellyfin `AuthenticateByName`, library browse screen. | `MediaServerService.swift`, `MediaServerLibraryView.swift`, `MediaServerConnectViews.swift` | **Missing.** Note Orivio's own handoff: "None of the Plex/Jellyfin code has ever been run against a real server." |
| 3 | **TorrServer P2P.** `infoHash`-only streams route through a TorrServer instance on the LAN when no debrid provider is set. | `TorrServerService.swift`, `TorrentSettingsStore.swift` | **Missing.** The fork drops torrent-only streams. |
| 4 | **Stremio account sync.** Signs into a Stremio account and syncs the library through `datastoreGet`/`datastorePut` with hashed deltas. | `StremioAccount.swift` (1,185 lines), `StremioSyncManager.swift` | **Missing.** |
| 5 | **Add-on tooling.** Discover Add-ons (curated list plus the live Cinemeta `addon_catalog`), Add-on Health (manifest latency, dead providers), Export Add-on Setup as a QR, Import setup from pasted URLs, `stremio://` and bare `manifest.json` deep links install. | `AddonDiscoverView.swift`, `AddonCatalogService.swift`, `DeepLinkService.swift`, settings reference "Install Add-on" | **Missing.** The fork adds add-ons on the TV or through Remote Setup from a phone; no browser, no health check, no export. |
| 6 | **Community Collections presets.** One-tap install of Streaming Services / Major Studios / Trending & Top Rated folders backed by stable TMDB network, company and discover sources, grouped so Home matches Android's one-row-per-collection model. | `CommunityCollectionsView.swift` (815 lines) | **Missing.** The fork edits TMDB Discover folders on the TV but has no preset catalogue. |
| 7 | **Local backup and restore.** Exports addons, plugin repos, library, progress and watched items as versioned JSON (resume stream URLs stripped because they carry debrid tokens), and imports it. | `OrivioLocalBackupService.swift`, `AccountView.swift:418` | **Missing.** |

Not a gap: debrid cloud library (both have it), QR account sign-in (both), email sign-in (both), MDBList ratings (both), parental guide (both), Top Shelf (both), JS scraper plugins (both).

### A2. Player engine

| # | Orivio feature | Orivio evidence | Fork status |
|---|---|---|---|
| 8 | **Picture in Picture on every engine.** AVKit refuses sample-buffer sources on tvOS (they disassembled the check), so Orivio built the private generic-view route to host its FFmpeg, VLC and DV render views in the system PiP window. | handoff §7.12, `PictureInPicture.swift`, `PictureInPictureBridge.swift` | **Partial.** The native path is a full `AVPlayerViewController`, which gets system PiP on its own; nothing in the fork references PiP, and the mpv engine has none. |
| 9 | **Scrub previews.** A thumbnail strip while scrubbing, grabbed by its own FFmpeg frame reader, dense pass on wheel engage, cached per title (newest 40 sets on disk). | `ScrubThumbnailer.swift` (715 lines), handoff §7.9 | **Missing** on both engines. |
| 10 | **Hybrid disk cache.** A localhost proxy on port 8097 downloads a direct-file stream to `Library/Caches` at line speed while playing, serves range requests from disk, and the scrubber shows a cache-coverage bar. On by default. | `MediaCacheServer.swift` (3,534 lines), handoff §7.8 | **Missing.** The fork relies on mpv's RAM read-ahead and the remux session. Their own caveat: the pool "ramps up until the server pushes back with 429s", which bites self-hosted aggregators. |
| 11 | **Four engines.** AVPlayer, FFmpeg (KSPlayer), VLCKit as a manual fallback for files that stutter elsewhere, and a bespoke `DVSampleEngine` that demuxes with FFmpeg and feeds compressed HEVC access units straight into `AVSampleBufferDisplayLayer`, with libdovi P7→8.1 inline. Memory about 155 MB flat. | handoff §7.1–7.3, `DVSampleEngine.swift` (3,696 lines), `VLCEngine.swift` | **Partial.** The fork has two engines (AVPlayer via on-device remux to loopback HLS, and mpv). See the technical note below: Orivio retired exactly the loopback-HLS design the fork uses, for memory reasons. |
| 12 | **Dolby Atmos (E-AC-3 JOC) from MKV.** Detects JOC through FFmpeg's `profile == 30` rather than track text, remuxes the selected E-AC-3 track to fMP4/HLS for AVPlayer, and rewrites the `dec3` box with the JOC complexity index because FFmpeg 6.1's muxer omits it, so tvOS lights "Dolby Atmos". | handoff §7.4, `AtmosHLS.swift` (1,023 lines) | **Unverified.** The fork's remux writes `dec3` through the muxer (`RemuxSession.swift:621`) with no JOC handling of its own; whether the index is present depends on the FFmpeg bundled in MPVKit, which I could not read from `Package.swift`. Worth one hardware check with a known Atmos MKV. |
| 13 | **Playback mode and per-title memory.** Automatic / Maximum Fidelity / Compatibility modes; `TitleMemory` remembers engine, audio track, subtitle language, speed and audio-sync offset per title; `DolbyMemory` remembers which titles carry bitstreamable audio so the next play takes the passthrough engine without a probe. | `PlayerSettingsStore.swift`, `PlaybackMemory.swift` | **Partial.** The fork has native-DV sub-settings and a per-title subtitle offset; no mode selector, no per-title engine or speed memory. |
| 14 | **Audio sync and playback speed on every engine**, persisted per title. | `PlaybackMemory.swift:164-176`, handoff §7.4 | **Partial.** mpv only (audio delay not persisted); the native path offers the system speed menu only. |
| 15 | **Video scaling** (fit / zoom / stretch) with an in-player aspect button. | settings reference "Player → Video scaling" | **Missing.** mpv is fixed at `resizeAspect`; the native path has no control. |
| 16 | **Auto-failover and link memory.** On a resolve or playback failure during an auto flow it advances to the next ranked candidate (same add-on first, matched on the add-on name with the debrid prefix stripped), capped at 4 attempts; any link watched under 5 minutes is blacklisted for 8 hours; add-ons whose links refuse range requests are remembered; first-frame (25 s), load (30 s), stall (20 s) and seek-play watchdogs. | handoff §7.13, `PlaybackMemory.swift:250` | **Partial.** The fork falls back from the native engine to mpv mid-play on a stall; it never tries the next link, and has no link blacklist. |
| 17 | **Subtitle extras.** Caption font choice, secondary subtitle language, "Subtitles on by default", a toggle that routes full ASS/SSA typesetting to the VLC engine, nine-position ASS layout so a sign translation and dialogue do not overdraw. | settings reference "Subtitles", handoff §7.11 | **Partial.** The fork's `SubtitleStyleState` has colour, background, outline (width and colour), bold, size, vertical offset, SDH strip, forced, preferred-only. mpv's libass already handles ASS positioning. No font choice, no secondary language. |
| 18 | **Playback decision log.** Every engine branch records stage / choice / reason and the Info panel shows it verbatim, so a report from the couch explains itself. | handoff §7.1 | **Missing** as a user-visible panel. The mpv Playback tab has a diagnostics overlay. |
| 19 | Infuse-measured player chrome, wall-clock start/end times on a light tap, cache bar. | handoff §7.10 | Design difference, not a gap. The fork draws its own top panel because tvOS 26 no longer supplies one. |

### A3. Stream selection

| # | Orivio feature | Orivio evidence | Fork status |
|---|---|---|---|
| 20 | **Auto-play best source on first play.** A global "Auto-play best source" switch, a per-profile Auto Link Selector, "Cached sources only", reuse-last-link with a window (default 24 h), resume-format matching, and **hold Play to get the manual list anyway**. | handoff §7.14, `StreamsView.swift`, `DetailView.swift:298` (`playManuallyMenu`) | **Missing on first play.** `StreamsViewModel.swift:135,179` hard-codes `manualSelection: true`, so the picker always shows. The shared `StreamAutoPlay*` logic only drives next-episode autoplay (see `docs/upstream-port-plan-2026-09-02.md` addendum). |
| 21 | **Stream filters for every add-on.** Smart ranking (REMUX > Blu-ray > WEB-DL, codec, HDR/DV, audio, seeders, bitrate), links-per-resolution cap, per-add-on "search patience" timeout, minimum resolution, hide AV1, HDR only, DV only, cached only. | settings reference "Sources" | **Partial.** `DebridSettings.kt` has sort mode (default / quality / size), minimum quality and a feature filter, but they apply to debrid streams only; no AV1 hide, no per-add-on cap or timeout. |
| 22 | **External players.** nPlayer and SenPlayer targets, "Send the rest of the season" as a playlist, and the x-callback return path: Infuse reports the URL and position on `x-success`, which updates Continue Watching. | `ExternalPlayers.swift`, `DeepLinkService.swift` (`externalPlaybackFinished`) | **Partial.** The fork hands off to Infuse / VLC / Outplayer / VidHub with resume and subtitles, but builds no `x-success` callback and registers only the `nuviotv` scheme for Top Shelf, so progress watched in Infuse is lost. |

### A4. Home, Detail and Library

| # | Orivio feature | Orivio evidence | Fork status |
|---|---|---|---|
| 23 | **Poster hold menu.** Long-press on any poster: Go to Details, Add/Remove from Library, Mark as (Un)watched. On Continue Watching cards: Play Manually, Go to Details, Mark Episode Watched, Start Over, Remove. On live channels: Favourite, Add to Home Page. | `PosterHoldMenu.swift` | **Partial.** The fork uses `contextMenu` in three places, each with a single Remove action (`LibraryView.swift:50`, `SearchView.swift:138`, `HomeView.swift:4310`). Mark-watched exists only on the Detail page (`DetailViewModel.toggleWatched`). |
| 24 | **Personal 1–10 ratings**, two-way with Trakt and SIMKL, scoped per profile. | `RatingsStore.swift`, settings reference "Sync ratings" | **Missing.** The shared Simkl models carry a `userRating` field but nothing rates a title. |
| 25 | Trakt "Clear Trakt Continue Watching" action. | settings reference | **Missing.** Minor. (Trakt/Simkl watchlist two-way, history and Continue Watching sync all exist in the fork.) |
| 26 | **Spoiler blur** of unwatched episode stills (focus reveals) and of barely-started next-up art on Home. | settings reference "Continue Watching" | **Missing.** The fork only hides spoilers inside Trakt comments. |
| 27 | **Collection folder views.** Categories (row per folder) vs Grid, with sort Popular / Top Rated / A–Z / Newest, and per-collection "All" tab and focus-glow switches. | `CollectionView.swift:554-566` | **Partial.** The fork's folder page is a grid; sort modes and the Home-style layout inside a collection are FEAT-43, still open. |
| 28 | **Poster banners switch.** Hides the "In Cinemas" / "#2 Today" tags some add-ons print into poster art by swapping in the clean `posterFallback` poster the add-on also sends. | handoff §6.2 | **Missing.** The fork's `posterFallbackURL` in `HomeView.swift:3704` is a hero-backdrop fallback, a different thing. |
| 29 | Detail page section display toggles (Cast, Collection, More Like This, Production, Comments). | settings reference "Layout → Details Page" | **Partial.** The fork's `TmdbSettings` fetch switches (`useCredits`, `useCollections`, `useMoreLikeThis`, `useProductions`) hide the same rows by not fetching. |
| 30 | Hybrid hero (rolls at the top, becomes a pinned-focus hero once you scroll down, Up hands it back), a separate "Featured" strip, a Next Up row and a Live Channels row. | settings reference "Hero layout", `FusionHeroBar.swift` | **Partial.** The fork has the rolling carousel and the pinned Nuvio-Style hero as separate choices, no auto-switch. |
| 31 | Home catalog auto-refresh timer; Continue Watching sort order; episode stills on CW cards. | settings reference | **Mostly missing.** The fork follows mobile's CW rules (including furthest-episode and unaired-next-up prefs) and has no refresh timer. Minor. |

### A5. Platform and settings

| # | Orivio feature | Orivio evidence | Fork status |
|---|---|---|---|
| 32 | **tvOS 17+ with Apple TV HD support and performance tiers.** `PerformanceProfile` buckets AppleTV5 (2 GB), AppleTV6 (3 GB) and newer, and scales image pixel caps, cache sizes, buffer bytes, worker counts and sync intervals. A Performance pane exposes shadows, focus zoom, parallax, animations, artwork preload and fade-in, a one-switch Performance mode and "Reset to recommended"; system Reduce Motion forces the effects off. | `PerformanceProfile.swift`, `SettingsPerformanceView.swift`, handoff §10 | **Missing.** The fork targets tvOS 26 (`TVOS_DEPLOYMENT_TARGET = 26.0`) and has No Zoom on Focus and Card Depth; `accessibilityReduceMotion` is honoured in the sidebar only. |
| 33 | **Experience Mode** Essential / Advanced, hiding engine, OSD and plugin controls from casual users. | `ThemeManager`, settings reference "Appearance" | **Missing.** The fork's Settings Style Default / Minimal is cosmetic. |
| 34 | **"Separate per profile" switches** for add-ons, plugins, debrid logins, player settings, TMDB, theme, badges, and Trakt/SIMKL, so a household can share one add-on set while keeping separate histories. | `ProfileStore.swift` (`ProfileScopedDefaults`), handoff §8.3 | **Missing.** The fork scopes everything per profile through account sync with no shared mode. |
| 35 | About pane: Clear cache, Licenses & Attributions, Privacy Policy. | `DiagnosticsService.swift`, settings reference "About" | **Missing.** The fork's About shows build identity and an Open Sans attribution only. |
| 36 | Nine accent palettes (adds Lavender and Mint light fills). | `OrivioTheme.swift` | Seven in the fork. Trivial. |
| 37 | TMDB key paste-from-phone page. | `KeyHandoffServer.swift` | Moot: the fork bundles the TMDB key (rc13) and Remote Setup already takes the MDBList key, badge packs and custom poster pattern. |
| 38 | Developer toggles: FPS overlay, playback diagnostics HUD, input debug, hold-menu probe, a LAN probe server on port 8123. | settings reference "Developer" | Not user features. The fork has its own About-pane probes and the mpv diagnostics overlay. |

## B. Two technical findings worth a check (not features)

1. **Loopback-HLS remux memory.** Orivio's first Dolby Vision path was "remux with FFmpeg → serve over a loopback HTTP HLS playlist → AVPlayer", and they retired it because CoreMedia "retains every byte it fetches over that path, process-scoped and unreleasable", measured growing at the fetch rate until jetsam, with an `AVPlayerItem` recycle returning zero memory (handoff §7.3). That is the architecture of the fork's native player (`RemuxSession.swift` + `LocalHLSServer.swift`). No fork user has reported it, and the fork's `tvos-ipa` builds have passed long device sessions, but a deliberate run of a 3-hour 4K DV MKV on the 3 GB Apple TV 4K gen 1 with memory logged would settle it.
2. **Atmos JOC on remuxed E-AC-3.** See A2 #12. If the bundled FFmpeg writes `dec3` without the JOC complexity index, tvOS plays the remux as plain Dolby Digital Plus and the receiver never shows Atmos. One known-Atmos MKV on the Living Room ATV answers this.

## C. What the fork has that Orivio does not (for perspective)

Six UI languages and localized TMDB metadata; self-hosted Nuvio backend discovery and trust review; the TMDB Discover filter editor on the TV; Trailers on Focus with the poster morph, hero trailers and the full-screen Trailer Bridge; the tvOS 26 system tab bar that minimizes on scroll; a bundled TMDB key; MDBList account sync, library and scrobbling; IntroDB movie credits skip with post-credits hold; Simkl-based anime ID resolution (Orivio's `AnimeSkipService` still calls the retired `arm.haglund.dev` service, so its anime skip is likely broken today); header-gated stream playback; Remote Setup covering rows and poster patterns; a shared Kotlin core that absorbs upstream Nuvio fixes daily.

## D. Recommendations

Both projects are GPLv3, so borrowing code is licence-compatible with attribution, but Orivio is pure Swift on KSPlayer while the fork is KMP + mpv, so nearly everything below is a re-implementation guided by their notes. Their handoff is the thing to borrow: it documents the private PiP route, the display-mode pin, the `dec3` rewrite and a dozen focus-engine traps in detail.

### Build next (high value, bounded cost)

1. **Auto-play best source on first play, with hold-Play for the list** (A3 #20). This is parity with upstream mobile, the shared `StreamAutoPlay*` policy and selector already exist, and the fork currently blocks it with `manualSelection: true`. Work is Swift wiring in `StreamsViewModel` / `StreamPickerView`, a Playback settings row, and the hold gesture on the Play button. It also makes the "Play from Top Shelf" path one press.
2. **Next-link failover plus a short link blacklist** (A2 #16). Today a dead debrid link dead-ends the user in the picker. Reuse the autoplay ranking to pick the next candidate from the same add-on, cap attempts, and remember links that died inside five minutes. The mid-play engine fallback stays as is.
3. **Poster hold menu** (A4 #23). `contextMenu` is already in use and every action exists in `shared/` (`WatchingActions`, `LibraryRepository`, the resume prompt). Add Mark Watched, Add to Library and Play Manually / Start Over on posters and Continue Watching cards. One caution from Orivio's `HoldProbe` history: tvOS does not reliably build a long-press menu on a `.card` button style, which is why their menu sits on a plain style.
4. **Stream filters for every add-on** (A3 #21). Lift the debrid-scoped sort, minimum quality and feature filter in `DebridSettings.kt` to the whole picker and add hide-AV1 and a per-add-on link cap. Check upstream `NuvioMobile` first; its `PlayerSourcesPanel` already has filter chips that may be the thing to port.
5. **External-player return path** (A3 #22). The fork already builds `x-callback-url` requests; add an `x-success` / `x-error` callback on a per-install scheme and parse the position Infuse returns into watch progress. Low cost, and Orivio's note about shared schemes resolving to the wrong sideloaded app is the one trap to avoid.

### Consider (product calls)

6. **Live TV / IPTV** (A1 #1). The largest single gap and the one with no fork code at all. It is a new tab, an M3U/Xtream parser, a channel grid, favourites and a Home row, roughly 1,500 lines in Orivio. Only worth it if the Reddit thread or Steven asks for it; it would be fork-only code with no upstream to track.
7. **Personal ratings** (A4 #24). Trakt and Simkl endpoints and the Simkl `userRating` model are in `shared/`; the missing pieces are a rating control on Detail and the two-way sync rules.
8. **Backup / restore and Export Add-on Setup** (A1 #7, #5). Cheapest route is a JSON download endpoint on the existing Remote Setup page plus an upload field, no QR work needed.
9. **Scrub previews** (A2 #9). Feasible on the native path because the fork already links FFmpeg's `avformat` in `RemuxSession`; mpv would need its own grabber. High effort, high polish. Defer until the Steven loop settles.
10. **Spoiler blur** for unwatched episode stills (A4 #26) and the **poster banners** switch (A4 #28). Small, self-contained, nice to batch with a Detail or Home pass.
11. **Performance pane and Reduce Motion** (A5 #32). Relevant only if older boxes show up in reports; tvOS 26 still runs on the Apple TV HD, so a lighter tier is not pointless, but nobody has asked.

### Skip

Plex/Jellyfin (untested even in Orivio, and a different product), TorrServer (needs a server on the LAN), Stremio account sync (the fork's identity is the Nuvio account), VLCKit as a third engine, the bespoke DV sample engine and the hybrid disk cache (both are architecture rewrites, and the cache's 429-ramping behaviour is a support liability), Experience Mode, per-profile sharing switches, and the Infuse-clone player chrome (the fork's panel is already its own design under active iteration).

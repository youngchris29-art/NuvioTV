# NuvioTV (Android TV) → tvOS Feature Gap Analysis

**Date:** 2026-07-02
**Method:** Cloned `NuvioMedia/NuvioTV` (official Android TV app, Kotlin/Compose TV) at HEAD and diffed its screen/feature surface against the NuvioTV SwiftUI target + SharedCore. Shared-layer availability claims verified against current `shared/src`.

---

## 1. Already at parity (no action)

Home (hero pager, continue watching w/ remove + direct resume, catalog rows, collection rows, See All grids), Search, Library, Detail (hero trailer autoplay, info, cast → person detail, collections, more-like-this, episodes), stream picker w/ badges + external subtitles, MPV player (transport, hold-to-seek, track selection, subtitle styling, language auto-select, resume, next-episode autoplay + Up Next, skip intro/outro incl. AniSkip), Trakt device-code auth + scrobbling, cloud accounts + full sync, profiles w/ PIN + avatars, addon install/enable/remove, Home row ordering (≈ CatalogOrderScreen), TMDB key settings, themes, poster style, subtitle appearance.

## 2. Not portable — skip permanently

| Android TV feature | Why it can't come to tvOS |
|---|---|
| TorrServer torrent engine (`core/torrent`, bundled Go binary + TorrentOverlay) | tvOS cannot spawn processes; App Store policy. Torrent addons still work via debrid resolution. |
| In-app APK updater | App Store/TestFlight owns updates. |
| ExoPlayer↔MPV dual-engine failover, Dolby Vision DV7 base-layer tooling (`DV7/`), AFR preflight heuristics | Android display/codec APIs. Single-engine (mpv) on tvOS; partial analog = match-frame-rate below. |
| External DEX plugin extensions (`RepositoryType.EXTERNAL_DEX`) | Dynamic native code loading is impossible on tvOS. JS plugins ARE portable (§5). |
| Android TV home-screen channels (`TvRecommendationManager`) | Platform API. The tvOS analog is Top Shelf (§5). |

## 3. Quick wins — pure Swift, no relink (S each)

| Feature | Android TV source | tvOS implementation sketch |
|---|---|---|
| Playback speed | `PlaybackSpeedAware*` | mpv `speed` property; add a row to the existing track/settings picker (swipe-up panel). No audio-sink work needed — mpv handles pitch. |
| Subtitle delay / audio delay | `SubtitleTimingDialog`, `AudioDelay*` | mpv `sub-delay` / `audio-delay` properties; +/- stepper rows in the swipe-up panel. (Skip Android's per-output-route delay memory v1.) |
| Stream info overlay | `StreamInfoOverlay` | Read mpv props already accessible (`video-codec`, `hwdec-current`, `video-bitrate`, `cache-speed`, resolution/fps); overlay toggled from the panel. |
| Still Watching prompt | `PlayerRuntimeControllerStillWatching` | Counter of consecutive autoplayed episodes in `NextEpisodeEngine`; after N (Android uses episode/hour thresholds), pause + glass dialog. |
| Pause overlay | `PauseOverlay` | On pause >2s, show metadata card (title/synopsis/artwork from `PlaybackContext`) over dimmed video. |
| Search history | `SearchHistoryDataStore` | NSUserDefaults list, rendered as focusable chips above the results in SearchView. |
| Company logos on Detail | `CompanyLogosSection` | `MetaCompany.logo` already exists in SharedCore (TMDB-gated). Render logo row instead of/alongside the text names in the info section. |
| Trakt comments on Detail | `CommentsSection` | `TraktCommentsRepository` **already in SharedCore**. New Detail section, FlowWatcher pattern; requires connected Trakt. |
| Episode ratings heatmap | `EpisodeRatingsSection` | `ImdbEpisodeRatingsRepository` + generated `ImdbEpisodeRatingsConfig` **already in SharedCore** (api.imdbapi.dev, keyless). Color-coded rating chips per episode in EpisodesSection. |
| Parental guide | `ParentalGuideOverlay` + detail | `ParentalGuideRepository` **already in SharedCore**. Detail section + optional player overlay (severity chips per category). |

## 4. Medium — pure Swift, no relink (M each)

| Feature | Notes |
|---|---|
| In-player episodes panel | `EpisodesSidePanel`. Episodes already ride in `PlaybackContext.episodes`; swipe-down or panel button → focusable episode strip → builds new PlaybackContext (same flow as Up Next). |
| In-player source switching | `StreamSourcesSidePanel`. `PlayerStreamsRepository.loadEpisodeStreams` already used by autoplay; panel lists alternates, re-launch player with the new URL, keep position via `start` param/seek. |
| Post-play overlay | `PostPlayOverlay`. On `isEnded` without autoplay target: related titles (`TraktRelatedRepository`/more-like-this) + replay/next actions. |
| Trailers row on Detail | `TrailerSection`. Shared trailer resolver already powers the hero (`TrailerPlaybackSource.progressiveUrl`); add a row of all trailers + full-screen AVPlayer presentation. |
| Discover tab | `DiscoverScreen`. Genre-filtered browsing is already supported by SharedCore (`CatalogTarget.genre` + `CatalogRepository`); build a Discover screen: type toggle (movie/series) × genre chips → paginated grid (reuse CatalogGridView). Optional watched-dimming via `WatchedRepository` ids. |
| Buffer/network settings | `PlaybackBufferNetworkSettings`. Map to mpv `cache-secs`/`demuxer-max-bytes`/`demuxer-readahead-secs`; Settings section + apply at player init. |
| Match content frame rate | `DisplayModeOverlay`/AFR. tvOS analog: `AVDisplayManager.preferredDisplayCriteria` (Apple TV supports match frame rate/dynamic range). Read container fps from mpv `container-fps`, request criteria before playback; Settings toggle. |
| First-run onboarding | `EssentialAddonSetupScreen` + `AppOnboardingDataStore`. Welcome → sign-in (exists) → seed/pick addons → done. Mostly composition of existing screens. |
| Experience mode (Essential/Advanced) | Simple enum + gating of advanced settings sections; it syncs via profile settings on Android (`ExperienceMode` in `ProfileSettingsSyncService`) — decide whether tvOS honors the synced value or stays always-Advanced. Product call more than engineering. |
| MDBList ratings | `MDBListRepository` (Android-side, `api.mdblist.com`, user API key). Port as small Swift URLSession client or add to shared; Settings row for key + ratings row on Detail. |

## 5. Larger / high-leverage (M-L)

**Native debrid (TorBox/RealDebrid/Premiumize) — M, mostly UI.** The entire debrid layer moved to SharedCore in Batch 4d: `DebridProviderApis`, `DirectDebridResolver`, `DebridDeviceAuthorization` (device-code auth!), settings storage. `StreamsRepository` already consumes it internally. Missing is only the Settings UI: provider list → device-code activation screen (same UX as Trakt connect) → enable local resolution. Kills the biggest current pain point (pasting pre-configured manifest URLs).

**Cloud library (debrid cloud files) — M, after native debrid.** `CloudLibraryRepository` + Torbox/Premiumize providers **already in SharedCore**. Library tab section or separate row listing cloud files → play via mpv. Gated on debrid API keys, hence sequenced after native debrid settings.

**QR sign-in — M.** Backend exists on the same Supabase instance (`functions/v1/tv-logins-exchange` edge function; Android polls it while the phone approves). tvOS: generate QR via CoreImage `CIQRCodeGenerator`, poll exchange endpoint, apply session to `AuthRepository`. Needs a small shared addition (or Swift-side ktor-free URLSession call) for the exchange call. Big UX win over typing email/password on a remote.

**Sync codes (generate/claim) — S-M.** Postgrest RPCs `generate_sync_code` / `get_sync_code` (+ claim) exist server-side; Android calls them directly via postgrest. Pairs a device to an account's data without full credentials. Two small screens; call RPCs via shared `SupabaseProvider`.

**Addon/config LAN web server — M-L, distinctive UX.** Android runs tiny HTTP servers (`core/server`) so users configure addons, stream-badge rules, and debrid formatter templates from a phone browser (`http://<tv-ip>:port`). tvOS: implement with `Network.framework` `NWListener` serving the same static pages + JSON endpoints bridging to SharedCore repos. Local-network entitlement + user permission prompt required. Massive text-entry relief on tvOS.

**JS plugins (scrapers) — L.** The seam is already designed for this: shared `PluginScraperHost` interface + `PluginScraperHostProvider` (default = disabled), with `PluginModels`/`PluginSync` in SharedCore and `StreamsRepository` already consuming the host. tvOS work: a Swift (or appleMain Kotlin) host backed by **JavaScriptCore** implementing repo fetch → manifest parse → sandboxed scraper execution (`executeScraper`), plus a Plugins management screen. `PluginSync` means installed repos sync from mobile automatically once the host exists. NUVIO_JS repos only (no DEX).

**Dynamic Top Shelf — M-L.** Replace the static Top Shelf image with a `TVTopShelfContentProvider` extension showing Continue Watching + featured rows (analog of Android's home-screen channels). Extension can't easily link SharedCore; instead the main app writes a JSON snapshot (entries + artwork URLs + deep links) to an App Group container on every progress update, and the extension reads it. Requires App Group + deep-link routing into detail/player.

**TMDB entity browse (studio/network pages) — M.** Android navigates from company logos to a TMDB discover-by-company grid (`TmdbEntityBrowseScreen`). Requires TMDB discover-by-company/network calls that are Android-side today — either add to shared `TmdbService` (relink) or Swift-side URLSession using the stored TMDB key. Sequence after company logos.

**Home layout variants — L, optional.** Android ships three home layouts (Classic/Modern/Grid) + a LayoutSettings screen. tvOS has one polished layout; only worth it if users ask.

**Blocked:** playback issue reporting (`PLAYBACK_REPORTS_BASE_URL` is a private build config, unpublished — same class of blocker as the old `INTRODB_API_URL`).

## 6. Suggested order — STATUS 2026-07-02 (evening re-evaluation)

**Shipped today (all verified on device):** ✅ player quick-wins (speed, sub/audio delay, stream info, pause overlay, still-watching) · ✅ Detail richness (Trakt comments, episode ratings, parental guide, company logos) · ✅ native debrid (device-code auth) · ✅ cloud library.

**Re-scout findings — more is shared-backed than assumed:**

- Discover is fully in SharedCore: `SearchRepository.discoverUiState` + `refreshDiscover(addons:)` → Discover tab is pure Swift UI.
- `SearchHistoryRepository` is in SharedCore (uiState/record/remove, already in the profile coordinator) → history chips are trivial.
- `TmdbMetadataService` carries the entity-browse APIs (`TmdbEntityBrowseData`/rails) → studio/network pages are pure Swift, not a shared addition.
- `MdbListMetadataService` + `MdbListSettingsRepository` are in SharedCore and enrich `MetaDetails.externalRatings` → MDBList is likely just a Settings key row feeding the existing Ratings info row.

**Remaining, reranked:**

1. ✅ **Discovery batch** (Discover tab + search history) — shipped 2026-07-02.
2. ✅ **Player depth batch** — shipped 2026-07-02.
3. ✅ **MDBList key row** + **trailers row** — shipped 2026-07-03.
4. ✅ **QR sign-in** — shipped 2026-07-03 (sync codes deferred; QR covers the UX).
5. ✅ **TMDB entity browse pages** — shipped 2026-07-03 (`EntityBrowseView.swift`; Detail's company-logo chips push studio/network pages when they carry a TMDB id — pure Swift, `fetchEntityBrowse`/`fetchEntityRailPage` already exported).
6. ✅ **Dynamic Top Shelf** — shipped 2026-07-03 (NuvioTopShelf extension + App Group snapshot + `nuviotv://` deep links).
7. ✅ **LAN config server** — shipped 2026-07-03 ("Remote Setup" in Settings: NWListener HTTP server + embedded web page; add-ons/Home rows/TMDB+MDBList keys editable from a phone browser, confirm-on-TV before anything applies).
8. ✅ **JS plugins** — shipped 2026-07-03, verified end-to-end on device. Not JavaScriptCore after all: mobile's QuickJS-based runtime (composeApp fullCommonMain) ported into `shared/src/tvosMain` on a quickjs-kt 1.0.5-tvos mavenLocal fork (`scaffolding/quickjs-kt-tvos.patch` + `build-quickjs-tvos.sh`). Settings → Plugins: master switch, on-TV repo install (iOS App Store flavor has no plugin support, so sync-only wasn't viable), per-scraper toggles. Local test repo in `scaffolding/test-plugin/`. §6 IS NOW COMPLETE — everything portable has been ported.

**Parked:** onboarding/experience mode (product call), layout variants (only if asked), playback issue reporting (private config), downloads (no tvOS storage story), episode release notifications (tvOS has no user-facing notifications), torrent engine + DEX plugins (impossible on tvOS).

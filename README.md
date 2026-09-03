<div align="center">

  <img src="design/preview-lockup-dark.png" alt="Nuvio" width="300" />
  <br />
  <br />

  [![Contributors](https://img.shields.io/github/contributors/youngchris29-art/NuvioTV.svg?style=for-the-badge)](https://github.com/youngchris29-art/NuvioTV/graphs/contributors)
  [![Forks](https://img.shields.io/github/forks/youngchris29-art/NuvioTV.svg?style=for-the-badge)](https://github.com/youngchris29-art/NuvioTV/network/members)
  [![Stargazers](https://img.shields.io/github/stars/youngchris29-art/NuvioTV.svg?style=for-the-badge)](https://github.com/youngchris29-art/NuvioTV/stargazers)
  [![Issues](https://img.shields.io/github/issues/youngchris29-art/NuvioTV.svg?style=for-the-badge)](https://github.com/youngchris29-art/NuvioTV/issues)
  [![License](https://img.shields.io/github/license/youngchris29-art/NuvioTV.svg?style=for-the-badge)](https://github.com/youngchris29-art/NuvioTV/blob/main/LICENSE)

  <p>
    A native Apple TV client for the Nuvio media hub, with SwiftUI over a shared Kotlin Multiplatform core.
    <br />
    Stremio addon ecosystem • Built for the tvOS focus engine &amp; Siri Remote
  </p>

</div>

## About

**NuvioTV** is a native **tvOS (Apple TV)** port of [Nuvio](https://github.com/NuvioMedia/NuvioMobile). It brings Stremio addons, catalogs, watch progress, collections, cloud library, debrid and Trakt into the living room through an interface made for the **tvOS focus engine** and **Siri Remote**.

This fork keeps the parts of NuvioMobile that suit a TV and leaves its touch UI behind. Its Compose-free **domain and data layer** becomes **`SharedCore`**, a UI-free Kotlin Multiplatform framework, with a new **SwiftUI** frontend on top. Mobile and TV share one business-logic core; Apple TV gets its own 10-foot interface.

> **Lineage:** the original *NuvioTV* was a React Native app. It was rewritten as [**NuvioMobile**](https://github.com/NuvioMedia/NuvioMobile), using Kotlin and Compose Multiplatform for Android and iOS. This project reclaims the *NuvioTV* name for a native Apple TV app. It shares NuvioMobile's core but replaces the UI and player for tvOS.

## Screenshots

| | |
|:---:|:---:|
| ![Home hero carousel](design/screenshots/home.png) <br/> **Home**: hero carousel & Continue Watching | ![Search & Discover](design/screenshots/search.png) <br/> **Search**: Discover rows from your addons |
| ![Catalog browsing](design/screenshots/catalog.png) <br/> **Catalogs**: addon catalogs with filter chips | ![Title detail](design/screenshots/detail.png) <br/> **Detail**: metadata, ratings & quick actions |
| ![Series episodes](design/screenshots/episodes.png) <br/> **Series**: season chips & episode shelf | ![Native player](design/screenshots/player.png) <br/> **Player**: native AVPlayer path, platter-free controls |
| ![Grouped stream picker](design/screenshots/streams.png) <br/> **Streams**: per-addon groups, debrid-cached & quality badges | ![Debrid settings](design/screenshots/debrid.png) <br/> **Debrid**: TorBox, Premiumize, Real-Debrid & AllDebrid |
| ![Appearance settings](design/screenshots/appearance.png) <br/> **Appearance**: accent themes & poster styles, synced per profile | ![Localized UI](design/screenshots/localization.png) <br/> **Localized**: English, French, Spanish, German, Italian & Vietnamese |
| ![Localized hero](design/screenshots/hero-localized.png) <br/> **Localized hero**: TMDB supplies title logos, synopsis & genres in your language | ![Wide catalog rows](design/screenshots/landscape-rows.png) <br/> **Wide rows**: 16:9 cards with titles; the focused card lifts clear |
| ![Nuvio-Style Hero](design/screenshots/hero-nuvio.png) <br/> **Nuvio-Style Hero** (opt-in): information on the left, artwork blending in from the right | ![Trailers on Focus](design/screenshots/trailer-morph.png) <br/> **Trailers on Focus**: the poster widens in its row and plays the trailer. When titles are hidden, the logo stays on the tile |
| ![Pinned hero](design/screenshots/hero-pinned.png) <br/> **Pinned hero**: with Nuvio-Style enabled, the hero follows the focused title while only the rows scroll | ![Self-hosted server review](design/screenshots/self-hosted-server.png) <br/> **Self-hosted servers**: connect to your own backend, with discovery, capability details & a trust review before switching |
| ![TMDB filter editor](design/screenshots/tmdb-filter-editor.png) <br/> **TMDB filters on the TV**: edit a Discover folder's filters, including exclusions, on Apple TV and sync them to your account | ![Trailer Location setting](design/screenshots/trailer-location.png) <br/> **Trailer Location**: play the focused title's trailer in the hero instead of widening the poster. Autoplay Hero Trailer needs no focus |
| ![Collection artwork in the hero](design/screenshots/collection-folder-hero.png) <br/> **Collection artwork in the hero**: focus a collection tile and the hero uses that folder's backdrop and title logo | ![Bigger season posters](design/screenshots/season-posters.png) <br/> **Season posters**: the season row matches the More Like This tile size |

## Features

### True 10-foot UI

- A full Human Interface Guidelines pass brings Liquid Glass surfaces, system focus platters and lockups, Siri Remote parallax on every card, and reorganized multi-pane Settings. Poster artwork tracks your thumb on the touch surface.
- **Native SwiftUI** is built around the tvOS focus engine. On focus, poster cards scale, lift and tilt toward you as a single piece, keeping the artwork edge and title together in portrait and wide 16:9 layouts. D-pad navigation comes first. For a still interface, **No Zoom on Focus** (Settings → Appearance) uses a border and shadow instead of scaling, across every tile (See All cards, episode cards, the detail trailer thumbnail) and not just posters. See All grids and collection folder grids remember their positions when you return from a title. Expanding See All from a search row now opens the actual search results. In this beta, the **Large poster size finally lays out cleanly**: rows return to the same position, posters aren't clipped, titles don't overlap the row above, and No Zoom on Focus treats every tile consistently.
- The **Home hero carousel** advances automatically or pages manually through D-pad clicks and left or right touch-surface swipes, wrapping at either end. It includes title-logo artwork and a **Go to Movie / Go to Show** button. Add a TMDB key and the titles, synopses and logos use your language. **Nuvio-Style Hero** (Settings → Home Screen) puts the title and description on the left, blends artwork in from the right and pins the hero above the scrolling rows. The hero updates with the focused title. **See All** now appears as the last card in each shelf. Pinned rows have enough space for the focused card to lift without clipping the row title, which now glides between rows instead of snapping.
- A **floating pill navigation bar**, horizontal episode shelves and watched-episode badges. **Bigger season posters** measure 180×270, matching More Like This and using the same depth as other tiles. If TMDB has no season art, this beta uses the **addon's own season posters**, including specials mapped to the correct season. Addons can also supply a **localized age rating** for the rating chip.
- **Continue Watching** has a separate Upcoming row for episodes airing within the next two weeks. This beta follows the **same rules as Nuvio mobile**, including its titles, order, recency window, hidden-show filtering and limit of 300 entries. Top Shelf mirrors the row. Upcoming also stays in place when you change watch-progress sources.
- **Appearance themes** include seven accent colors, poster sizes, corner styles, wide 16:9 rows and title-label options. Changes apply immediately and sync per profile. The theme picker's focused swatch name is readable on every theme. **Card Depth → Edge Coverage: Top** now produces a visible, lit-from-above rail; the old version was a hairline you couldn't see from the couch. Full remains unchanged. Other options include **Settings Style** presets (Default / Minimal), **icon-only detail buttons**, a **background-trailer duration** of 30s, 1 min, 90s or always, with a smooth fade back to the backdrop, and **Trailer Sound by Default**. This beta rebuilds Settings with native tvOS Lists, switches and dropdown pickers like the Apple TV's own Settings app. Your accent color carries through the sidebar, glyphs and values, and selecting a theme swatch no longer throws focus to the top.
- **Full-screen trailers with sound** play from the detail page at up to 1080p. They no longer show a black screen when Match Content Frame Rate is enabled. Auto-play, background trailers and the poster backdrop layer have separate toggles. As you scroll into the details, the page dims toward black.
- **Trailers on Focus** is optional under Settings → Home Screen. Hold focus on a poster and it widens to a 16:9 card at the poster's original height, then plays the trailer inside the row. Play/pause toggles sound. **Trailer Location: Poster / Hero** moves playback to the Nuvio-Style hero backdrop when Hero is selected, leaving the poster still. The poster's play/pause control continues to toggle sound, Search retains the poster morph, and the Settings summary identifies the active surface. **Autoplay Hero Trailer** is also new and off by default. It plays the featured carousel title without focus, yields when you focus a poster, and stops under a detail page, tab switch or stream picker. When **Hide Titles** is enabled, the title logo or name remains at the bottom-left of the playing tile over a soft scrim, the way Nuvio's TV app shows it, instead of the trailer playing nameless. The trailer pipeline retains no cookies or disk cache between launches, so restarting ends a rate-limited session. Trailers that lost audio in beta.16 have it back, and the detail-page trailer zoom remains stable when clips change.
- **Hero source picker & Home Rows controls** let you choose which catalogs supply the carousel and rearrange Home rows. The catalog list works with the remote again. Collection tiles play their focus GIFs at HD-parity resolution or better on 4K panels, dropping a few frames instead of pixels when needed. They also render the collection's configured backdrop. On the Home page, focusing a collection tile gives its backdrop and title logo to the hero, using the Fusion community collection fields that other Nuvio clients hadn't rendered. The collection name becomes the metadata line, and an Open Folder button appears. Inside the folder, its title logo becomes the page title.
- The **system-native tab bar** minimizes as you scroll into content, following tvOS 26's own apps. From deep in a page, one **Menu** press returns to the top. Long way down, short way back.
- The **Top Shelf extension** puts your content on the Apple TV home screen. It's available in source builds only because free-Apple-ID re-signing breaks extension signatures, so the sideload IPA omits it.
- The UI supports English, French, Spanish, German, Italian and **Vietnamese (Tiếng Việt)**. All six languages include the latest strings. With Metadata Language selected, heroes and rows arrive localized instead of briefly appearing in English, and row captions localize as they enter view.
- **Settings → About** displays the version, build number, beta tag and commit alongside the tvOS version and device model. A bug report can finally identify its exact build.

### Stremio addon ecosystem

- Install **Stremio-compatible addons** that provide catalogs, metadata, streams or subtitles.
- An **on-device QuickJS runtime** executes addon logic locally, without an external server.
- Addons can be installed in the app or through `stremio://` links collected during account sync.
- The **grouped stream picker** collapses sources into per-addon groups with stream counts and independent loading. One slow addon doesn't block the list. Focusing a row reveals its full release name, and stream badges stay readable across every theme, including White. **Header-gated addon streams play**: streams that declare required HTTP headers (a Referer or User-Agent their CDN checks) now pass them to both players, matching Nuvio mobile. Titles from TMDB-backed rows resolve streams with an ID the addon accepts. Removing an addon requires confirmation. This beta also distinguishes a loading addon from an empty one. Home, Search and Discover show a loading state while an add-on's manifest is fetched, instead of "No results" or "Install an add-on". A failed manifest shows its error and a **Retry** button, with no relaunch required.
- **Search Sources** (Settings → Content Sources) selects the addon catalogs used for search on each Apple TV. **Hide Discover** removes the entire Discover section from Search and syncs per profile, leaving a bare search field when Home already carries your genres. This beta remembers the last selected Discover catalog between launches.

### Playback

- The **native player is on by default**. Its AVPlayer path remuxes MKV files on-device, supports **Dolby Vision**, converts Profile 7 to 8.1 through libdovi, transcodes **TrueHD / DTS audio**, and allows seeking anywhere. Swipe or press down to open the classic top panel, which Nuvio draws because tvOS 26 no longer supplies one. The **Info** tab shows the poster, title, episode name, synopsis and a metadata strip (runtime · 4K · Dolby Vision · codec · audio · bitrate), plus live stream details. **Subtitles** lists embedded tracks beside addon subtitles, with Off first and forced or SDH tracks marked. **Audio** lists every track in the file, switches without rebuilding playback, and shows the current speakers or headphones with a route picker. Menu closes the panel. The native transport-bar Audio and Subtitles buttons remain available for tvOS features such as Enhance Dialogue and Reduce Loud Sounds. Preferred Audio and Subtitle Language still apply when playback begins. The mpv player uses the same panel, replacing its old swipe-up menu, and adds a fourth **Playback** tab for speed, subtitle/audio delay, diagnostics, episode jump list and alternate sources.
- The **libmpv player**, provided through MPVKit, handles everything else with `gpu-next` HDR tone-mapping. Playback now prevents the screensaver from interrupting.
- **External player handoff** sends a stream to **Infuse**, **VLC** or **Outplayer**, either per stream or through Default Player, carrying the resume position and addon subtitles. **VidHub** is also listed and follows its x-callback-url documentation, but the current tvOS build ignores the handoff. That's a known failure, reported to Oka Apps, and requires their fix.
- Both players support **addon subtitles**. The native path converts SRT to WebVTT and extracts embedded MKV text tracks into segmented WebVTT as needed. Subtitle auto-selection is forced-track and audio-aware, with full subtitle styling (color, size, background, outline). “Show only preferred languages” now filters the native Subtitles tab too. **Strip SDH Subtitles** (Settings → Playback) removes `[sound cues]`, `(asides)` and speaker labels from text subtitles in both players. This beta adds **Subtitle Timing** to the Subtitles tab. Move subtitles earlier or later in 100 ms steps in either player. The offset is remembered per title and profile, and Reset is persisted too.
- **Skip Intro / Recap / Outro** and **Play Next Episode** appear as focusable Apple-style action pills at the bottom-right, with a small countdown caption above. Next-episode playback starts automatically. The Info tab reports live stream rows (engine, codecs, resolution, active audio/subtitle, bitrate, transfer). The mpv player draws matching chips. This beta resolves **anime skip segments through Simkl**, replacing the retired ARM service and mapping each episode to its correct season. Multi-season anime now receive the right intro and outro timings. Pressing **Menu** dismisses the up-next countdown before it exits the player; the native player also provides a **Dismiss** action beside Play Next Episode. And next-episode autoplay respects the selected source scope, whether that's installed addons only or enabled plugins only, choosing once those sources have answered instead of waiting for the rest.

### Sources & accounts

- **Debrid support** covers **TorBox**, **Premiumize**, **Real-Debrid** and **AllDebrid**. Connect through a device code or API key. Cached results resolve to direct streams with quality, codec and service badges in the picker.
- **Trakt scrobbling** marks movies and episodes as watched automatically, with a separate connection for each profile.
- **Simkl integration** uses a short PIN under Settings → Accounts & Services. Watch history scrobbles to Simkl, while anime uses Simkl's own ID mapping and offers a picker when a match is ambiguous. **Sync Now** triggers an immediate push and pull. In this beta, anime added to a Simkl **list** is classified as anime too; a previously misfiled title corrects itself the next time you interact with it.
- **Provider keys sync with your account.** Debrid and TMDB API keys follow the Nuvio account to every signed-in Apple TV, while AllDebrid remains local to the device. This beta also syncs **Library and Watch Progress source choices** between devices. Change the scrobbler from Trakt to Simkl on one device and each Apple TV follows, including the Continue Watching window. Account data refreshes in the background while the app is open and whenever it returns to the foreground, so remote changes no longer require a relaunch.
- **TMDB / MDBList / MyAnimeList** supply ratings and metadata. Catalog-type and release-date display options are available, along with a **Metadata Language** picker that can follow the Apple TV language or use one of 12 choices.
- **Profiles with PIN entry** include QR-code sign-in, letting you pair with a phone instead of entering credentials through the Siri Remote.
- **Self-hosted servers.** Point the Apple TV at your own Nuvio backend (the [official self-host stack](https://github.com/NuvioMedia/self-host)). Enter the backend URL from the welcome screen or Settings → Account & Services. The app reads `/.well-known/nuvio`, then displays the detected backend, sign-in methods and any trust warning for a public host or plain HTTP. After confirmation, it signs out of the current server, clears local data and reconnects. QR sign-in follows the server's `tv_login` capability, moving approval to `<backend>/tv-login`; email and password appear when the server lacks that capability. **Use Official Server** switches back at any time.
- **Cloud library sync**, collections, and a sortable library with shelf and grid layouts. **TMDB Discover filters are editable on the TV.** Open a collection folder backed by TMDB Discover, a company or a network, then press **Edit Filters** to change sort order, genres, keywords, studios, networks, dates, ratings, language, country, watch providers and region. The new *exclude* filters cover genres, keywords, companies and watch providers just as Nuvio mobile does. Quick chips provide common IDs, and changes sync to the account.
- **A settings slot of its own.** NuvioTV stores settings under a dedicated namespace, preventing another Nuvio TV client on the same account from flipping its options back and forth.

## Requirements

- An **Apple TV** running **tvOS 26** or later, or the Apple TV simulator.
- **macOS** with **Xcode 26** or later.
- A recent **JDK** for Gradle to build the Kotlin `SharedCore` framework.

## Installation (Beta)

Beta builds are published as an **unsigned tvOS IPA** on the [**Releases page**](https://github.com/youngchris29-art/NuvioTV/releases/latest). A paid Apple Developer account isn't required. Sideload the app with a **free Apple ID**; your machine creates the signature during installation. For wireless setup, the 7-day refresh and the complete instructions, see [**INSTALL.md**](INSTALL.md).

1. Download `NuvioTV.ipa` from the [latest release](https://github.com/youngchris29-art/NuvioTV/releases/latest).
2. Sideload it to your Apple TV with one of these tools:
   - [**Sideloadly**](https://sideloadly.io/) for Mac or Windows finds Apple TVs on the local network. If prompted, pair through Settings → Remotes and Devices → Remote App and Devices, where the pairing code appears. An “App ID limit” error means an older sideloaded app must be removed; a free Apple ID permits 3 at once.
   - [**atvloadly**](https://github.com/bitxeno/atvloadly) is a self-hosted Docker web interface that sideloads across the network and can re-sign automatically.
3. On first launch, trust the developer certificate under Settings → General → Privacy & Security.

> **Free Apple ID limits** (normal, not bugs): the signature expires after **7 days**, so the app must be sideloaded again. Both tools can automate the refresh. A free account permits no more than **3 sideloaded apps** at once.

Each beta is a clean build without an account or addons included. Sign in and configure your own sources on first launch. To build it yourself, continue to [Development](#development).

## Development

```bash
# 1. Clone with submodules (pulls the NuvioMobile core; MPVKit lives inside it)
git clone --recurse-submodules https://github.com/youngchris29-art/NuvioTV.git
cd NuvioTV/NuvioMobile
git submodule update --init --recursive

# 2. One-time: build the tvOS QuickJS runtime into your local Maven
../scaffolding/build-quickjs-tvos.sh

# 3. Open the Xcode project, then build & run the NuvioTV scheme on an Apple TV
open iosApp/iosApp.xcodeproj
```

Building the app runs the Gradle task that produces `SharedCore` and links it into the tvOS target. Setup and architecture details live in [`docs/tvos-port-plan.md`](docs/tvos-port-plan.md) and [`scaffolding/README.md`](scaffolding/README.md).

[`NuvioMobile/iosApp/Configuration/Version.xcconfig`](NuvioMobile/iosApp/Configuration/Version.xcconfig) controls versioning for both mobile and tvOS builds.

### Project Structure

- `NuvioMobile/` contains the shared Nuvio core as a Git submodule on this fork's `tvos-shared-extraction` branch, along with the Kotlin Multiplatform code and Xcode project.
  - `NuvioMobile/shared/` contains the UI-free **`SharedCore`** KMP framework, including the domain and data layers used by tvOS.
  - `NuvioMobile/iosApp/NuvioTV/` contains the native **SwiftUI** tvOS app (`Screens/`, `DesignSystem/`, `Bridge/`).
  - `NuvioMobile/iosApp/NuvioTopShelf/` contains the tvOS **Top Shelf** extension.
  - `NuvioMobile/iosApp/iosApp.xcodeproj` is the Xcode project. Build the **`NuvioTV`** scheme.
- `design/` contains brand assets (logo, marks, previews).
- `docs/` contains the port plan, feature-parity roadmap and scouting or migration reports.
- `scaffolding/` contains Phase 0 templates plus the tvOS QuickJS build script and patch.

## Built With

- SwiftUI + the tvOS focus engine
- Kotlin Multiplatform (`SharedCore`)
- AVFoundation / AVKit
- libmpv via [MPVKit](https://github.com/mpvkit/MPVKit)
- Ktor + kotlinx-serialization
- Supabase (auth / postgrest / functions)
- QuickJS (`quickjs-kt`, tvOS fork) for the Stremio addon runtime

## Credits & Upstream

NuvioTV builds on two Nuvio projects:

- [**NuvioMedia/NuvioMobile**](https://github.com/NuvioMedia/NuvioMobile) is the Kotlin and Compose Multiplatform app this fork extends and tracks. `SharedCore` comes from its domain and data layers, and this repository periodically merges upstream changes.
- [**tapframe/NuvioTV**](https://github.com/tapframe/NuvioTV) is the original React Native app.

This independent community fork focuses on Apple TV. It is neither affiliated with nor endorsed by the upstream maintainers.

## Legal & DMCA

Nuvio functions solely as a client-side interface for browsing metadata and playing media provided by user-installed extensions and/or user-provided sources. It is intended for content the user owns or is otherwise authorized to access.

Nuvio is not affiliated with any third-party extensions, catalogs, sources, or content providers. It does not host, store, or distribute any media content.

For comprehensive legal information, including the full disclaimer, third-party extension policy, and DMCA / Copyright information, please visit the [Legal & Disclaimer Page](https://nuvioapp.space/legal).

## License

Distributed under the **GNU General Public License v3.0**, inherited from [NuvioMobile](https://github.com/NuvioMedia/NuvioMobile/blob/main/LICENSE). See [`NuvioMobile/LICENSE`](NuvioMobile/LICENSE).

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=youngchris29-art/NuvioTV&type=date&theme=dark&legend=top-left#gh-dark-mode-only)](https://www.star-history.com/#youngchris29-art/NuvioTV&type=date&legend=top-left)
[![Star History Chart](https://api.star-history.com/svg?repos=youngchris29-art/NuvioTV&type=date&legend=top-left#gh-light-mode-only)](https://www.star-history.com/#youngchris29-art/NuvioTV&type=date&legend=top-left)

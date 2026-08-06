# App Store Edition — Research Report

**Date:** 2026-07-26 · **Status:** Research complete, awaiting review — no implementation started.
**Goal:** Define a separate version of the tvOS app that can pass Apple review for TestFlight and App Store release, follows the tvOS HIG, and adopts Apple's latest (tvOS 26 / Liquid Glass) design language.

Four research tracks feed this report: (1) full codebase inventory of NuvioTV, (2) current App Store Review Guidelines (last revised June 8, 2026) + precedents, (3) deep dive on Fusion, Omni, Vidi, VidHub, Infuse and Stremio Lite, (4) tvOS HIG + Apple design resources. Sources are cited inline; a consolidated source list is at the end.

---

## 1. Executive summary

**It is achievable.** Three Stremio-addon-compatible apps are live on the tvOS App Store today — **Vidi** ($4.99), **Omni** ($9.99), and **Fusion** (free) — plus the "pure player" class (Infuse, VidHub, SenPlayer) that has essentially zero takedown history. The approvable shape is well established:

> A **content-free media hub**: ships completely empty, never says "Stremio," "torrent," or "debrid" anywhere Apple looks, has zero bundled or default sources, does all scraping/debrid configuration on *external websites* (the app only ever sees a pasted manifest URL), and leads its listing with genuinely strong standalone functionality (player quality, home customization, Trakt sync).

**But approval is not safety.** Stremio Lite was approved (iOS Aug 2025, tvOS Oct 29, 2025) and **removed by Apple in January 2026** — the listing 404s today. Its differences from the survivors: the Stremio brand, preloaded catalog ecosystem, and "vast library" marketing made the intent legible. The same Dec 2025–Jan 2026 wave hit Google Play (19-day suspension, reinstated) and Amazon (quiet removal). Our own risk memo ([feat3-testflight-risk-memo.md](feat3-testflight-risk-memo.md)) also notes a "Nuvio Media" iOS app was removed from the App Store in mid-July 2026.

**What this means for us:** the App Store edition must be a genuinely separate, clean binary — sensitive code **compiled out, not UI-hidden** — with a new bundle ID, almost certainly a distinct name/brand, and a first-run experience that works with nothing configured. Five current subsystems must be removed entirely; several more need redesign. Details and the full matrix are in §4.

**The single biggest structural blocker is not a feature — it's the license.** The app inherits **GPLv3** from upstream NuvioMobile, and GPL is incompatible with App Store distribution (the VLC precedent). Unless upstream consents to relicensing/dual-licensing, the App Store edition needs a clean-room plan for any upstream-derived code. This is decision #1 in §8.

---

## 2. What Apple's rules actually say (June 2026 guidelines)

| Guideline | What it says (condensed) | Implication for us |
|---|---|---|
| **5.2.3** Audio/Video Downloading | "Apps should not facilitate illegal file sharing or include the ability to save, convert, or download media from third-party sources… without explicit authorization… Authorization must be provided upon request." | No torrents, no debrid, no browse-popular→press-play→free-stream pipeline. Apple can demand licensing proof for any content the app surfaces by default. |
| **5.2.2** Third-party services | Using/monetizing/displaying a third-party service's content requires permission under that service's ToS. | Kills the in-app YouTube trailer extractor (InnerTube client spoofing) and debrid integration; constrains everything to services whose ToS we satisfy (TMDB, Trakt). |
| **4.2 / 4.2.2** Minimum functionality | Apps shouldn't be "content aggregators, or a collection of links"; must have lasting utility. June 2026 revision also tightened 4.3 against low-value apps. | An empty shell that does nothing until an addon URL is pasted risks rejection. The app must do something real out of the box (player + personal sources + Trakt/TMDB discovery-as-information). |
| **4.2.3(i)** | Must work without requiring another app to be installed. | No hard companion-app dependency (soft phone-assist flows are fine). |
| **2.5.2** Downloaded code | Apps may not "download, install, or execute code which introduces or changes features." | The QuickJS JS-scraper plugin system is a per-se violation (this is why Kodi has never been on the App Store). Data-only Stremio addons (JSON endpoints) are arguably not "code," but see 4.7. |
| **4.7 / 1.2 / 3.2.2(i)** Plug-ins & UGC | "You are responsible for all such software offered in your app"; no App-Store-like general-interest collections of third-party extensions; UGC needs report/block/filter machinery. | No bundled addon catalog or "community addons" directory — this is exactly what Apple made Stremio remove. Any addon a user adds that serves pirated streams is *our* 5.2.3 violation. |
| **2.3.1** Accurate metadata / hidden features | "Don't include any hidden, dormant, or undocumented features… All new features… must be described with specificity in the Notes for Review (generic descriptions will be rejected)." Egregious behavior → **developer account termination**. | No server-side flags that light up removed features later. Removed features must be compiled out of the binary. Honest, specific review notes are mandatory. (The geofenced/time-bomb piracy apps of 2024 made reviewers explicitly hunt this pattern.) |
| **3.1.1 / 3.1.3** Payments | Clients for third-party paid services may offer sign-in but (outside the US storefront) no links/buttons/calls-to-action to purchase externally. US storefront is exempt since May 2025 (Epic ruling). Our own paid features must use IAP. | Trakt VIP upsell links: US-only or omit. No debrid = moot for debrid. |
| **4.8** Login services | Third-party/social login for the *primary* account requires a privacy-preserving alternative (SIWA in practice). Exempt if we use only our own email/password system, or if login is to a specific third-party service for its own content (Trakt qualifies). | Nuvio email/password account: no SIWA needed. Adding Google sign-in would trigger the SIWA requirement. Trakt device-code login is fine as-is. |
| **5.1.1(v)** Accounts | App must be usable without login; if accounts can be created, **in-app account deletion is required** (full record deletion; a direct web link/QR is acceptable on tvOS). | Add a Delete Account flow hitting the existing `delete-account` edge function. Never gate browsing/playback behind account creation. |
| **Privacy (5.1.1/5.1.2)** | Privacy manifest (`PrivacyInfo.xcprivacy`) with required-reason API declarations is enforced at upload since May 2024; nutrition labels must match; privacy policy link in-app and in App Store Connect; ATT only if tracking (we don't — declare `NSPrivacyTracking = false`). | New mandatory work items; check Supabase client and other SDKs against Apple's listed-SDK manifest/signature requirements. |
| **2.1(a) / 2.3.3 / 2.3.6** | Demo account + working backend for review; screenshots must show real UI; honest age rating under the new 13+/16+/18+ system. | Provide a demo Nuvio account in review notes; screenshots of actual tvOS UI; rate honestly for surfaceable content. |

**Precedent ladder** (most→least safe):
1. **Pure personal-media player** (Infuse, VidHub, SenPlayer, iPlayTV's BYO-playlist model): user's own files/servers only — effectively zero takedown history.
2. **Empty addon-hub** (Vidi since ~2024, Omni since Mar 2025, Fusion since Feb 2026): live but exposed; their entire moat is naming, listing copy, and default-state hygiene.
3. **Branded ecosystem with preloaded catalogs** (Stremio Lite): approved, then removed Jan 2026.
4. **Native debrid + in-app indexer search** (Debrify): sideload-only; has never passed review.

---

## 3. Fusion vs Omni (and friends) — what Apple accepted

| | **Fusion – Media Center** | **Omni – Content Hub** | **Vidi · Media Center** | **VidHub** | **Infuse** |
|---|---|---|---|---|---|
| Developer / price | indie ("Marian Marian") / **Free** | indie (Joseph Steckler) / **$9.99 one-time** | Plata o Plomo AB / **$4.99 one-time** | Nanjing Oumi / freemium VIP | Firecore / freemium Pro |
| On App Store since | Feb 2026 | Mar 2025 | ~2024 (first approved) | ~2023 | ~2010s |
| Stremio addon API | Yes — "nearly all Stremio add-ons," paste manifest URL | Yes — catalogs, streams, subtitles, meta | Yes — partial subset | **No** (file/server player) | **No** |
| Listing mentions Stremio/torrent/debrid | **Never** — reads as a personal-media-server client | **Never** — only "Addon support (meta, catalogs, streams and subtitles)" | Generic: "extendible with addons"; explicitly provides no content | n/a | n/a |
| Native debrid account UI | **None** — debrid keys are entered on external addon config sites (Torrentio/AIOStreams), never in the app | **None** (help docs never say "debrid") | **None** | Indirect: generic WebDAV mount that *can* point at debrid WebDAV | None |
| In-app torrent/NZB search | No | No | No | No | No |
| Fresh-install state | Empty home; nothing playable until user adds a URL | Empty; addon URLs typed via local-webserver pairing page from a phone browser | Empty hub; "Add Stremio Addon" manual | Player, no sources | Player, no sources |
| Standalone value (4.2 cover) | Visual home editor, custom lists, AI search | Custom shelves, regex stream filters, auto-play best stream, iCloud sync, KSPlayer 4K HDR | HDR10+/Dolby Vision player, iCloud sync | Wide-codec player, cloud/SMB/Plex/Jellyfin | Best-in-class player, Trakt |
| Metadata / Trakt | TMDB + addon metadata / Trakt + AniList | Cinemeta/TMDB / Trakt scrobble + shelf | Addon metadata / iCloud progress | TMDB built-in / limited | TMDB (hides adult-tagged titles citing App Review) / full Trakt |
| Privacy label / age | No data collected / 4+ | No data collected / 4+ | Diagnostics only / 4+ | No data / 4+ | Minimal / 4+ |

**Distilled acceptance rules** (every survivor follows all of these):
1. **Ship empty** — zero bundled content, catalogs, or default addons.
2. **No piracy vocabulary** anywhere Apple looks: listing, screenshots, UI strings, URLs. (Fusion's description reads "connect to your media server… your personal media collection.")
3. **Addons are opaque pasted URLs**; all scraping/indexer/debrid config lives on external websites the app never links to.
4. **No on-device P2P**, no torrent engine, no NZB. Streams the app plays are plain HTTPS.
5. **No debrid branding or sign-in in-app.** (VidHub's generic-WebDAV mount is the softer allowed variant.)
6. **Neutral screenshots** — shelves, detail pages, filters; no "free latest movies" artwork, no addon names.
7. **Real standalone functionality** headlines the listing (player quality, organization, sync).
8. **Privacy-clean:** "No data collected," 4+, TMDB attribution.

**Monetization observed:** paid-up-front one-time (Omni, Vidi — universal purchase), free (Fusion), or freemium subscription (VidHub/Infuse). Nobody charges for content or bills around debrid. Note: **a paid app using TMDB requires a TMDB commercial license** (their standard terms exclude commercial use, defined to include charging for an app that integrates TMDB content).

---

## 4. Current NuvioTV feature inventory → keep / remove / redesign

Codebase: 72 Swift files (~18.5k lines) in `NuvioMobile/iosApp/NuvioTV/` + KMP SharedCore. Full inventory with file:line references was produced during research; this table is the decision view. "Remove" always means **compiled out of the App Store target** (build flag / separate target), never UI-hidden — per 2.3.1 and our own risk memo.

### Must remove entirely

| # | Feature | Where | Why |
|---|---|---|---|
| R1 | **QuickJS JS-scraper plugin system** — downloads & executes third-party scraper JS (browser-UA-spoofed fetch, DOM parsing, crypto bridges) | `shared/src/tvosMain/.../plugins/` (incl. `TvOsPluginRepository.kt`, `runtime/`), installed at `NuvioTVApp.swift:27` which flips `FeaturePolicy.pluginsEnabled` false→true; Settings → Plugins UI | Per-se 2.5.2 violation (downloaded executable code) + 5.2.3. Upstream already has an `iosAppStore` flavor with plugins disabled — the seam exists. |
| R2 | **All four debrid integrations** (TorBox, Premiumize, Real-Debrid, AllDebrid): cache checks, magnet add, unrestrict, device-code auth, cloud-library browsing (torrents/usenet/web-DL) | `features/debrid/` (20 files), `features/cloud/`, `DebridViewModel.swift`, `CloudLibraryUI.swift`, Settings section | 5.2.2/5.2.3 + the strongest reviewer trigger word in this category. No approved app has native debrid UI. |
| R3 | **Torrent stream handling**: `magnet:`, `torrent://`, `infoHash`/`fileIdx`/trackers, `DebridMagnetBuilder` | `StreamModels.kt:137-180`, `StreamParser.kt`, stream-picker filter logic | 5.2.3; also dead weight once R2 is gone. |
| R4 | **Cinemeta auto-seeding on first run** (the only bundled source) | `HomeViewModel.swift:40,151-155` | Violates "ship empty"; a preloaded community catalog is the Stremio Lite pattern that got it removed. |
| R5 | **In-app YouTube trailer extraction** (InnerTube API, spoofed ANDROID/IOS/ANDROID_VR clients) | `features/trailer/InAppYouTubeExtractor.kt` (~570 lines), `TrailerHeroPlayerView.swift` | YouTube ToS violation → 5.2.2. Upstream's App Store flavor already returns null here; mirror that. |
| R6 | **Torrentio/TorBox debug harness & strings** | `DebugConfig.swift`, `AddonsView.swift:55-66` "Quick install" button | Intent signal; must not exist in the App Store target even DEBUG-gated. |
| R7 | **Trakt VIP upsell links** (non-US) | wherever 426/X-Upgrade-URL is handled | 3.1.3 anti-steering outside US storefront. Show "manage at trakt.tv" text without a tappable link, or US-gate. |

### Must redesign

| # | Feature | Current state | App Store edition |
|---|---|---|---|
| D1 | **Addon system & Add-ons tab** | Full Stremio client; arbitrary manifest URLs; top-level tab; `stremio://` deep links | **Decision required (§8-Q2).** Either (a) Fusion/Omni posture: keep paste-a-URL as a neutral "connect a source," no catalog, no suggestions, no `stremio://` handling, renamed away from "addon"; or (b) drop entirely for v1 and ship pure-player. Either way the Add-ons *tab* goes; sources move into Settings. |
| D2 | **Home screen** | Rows come 100% from addon catalogs (empty without Cinemeta) | Must be genuinely useful when empty: Continue Watching, user Library/Collections, Trakt watchlist/up-next, TMDB discovery rows clearly framed as *information* (detail pages without play buttons unless a user source can serve the title). |
| D3 | **Nuvio account (Supabase)** | Email/password + anonymous + QR sign-in; syncs everything **including debrid API keys, TMDB/MDBList keys, addon+plugin URLs** in the profile blob | Keep accounts + sync, but the App Store edition must sync a **clean subset** — strip third-party credential fields and plugin/addon payloads that could re-import scrapers/debrid config from the sideload build via cloud sync (a server-delivered-config 2.3.1 hazard). Add in-app **Delete Account** (5.1.1(v)); app fully usable logged-out. |
| D4 | **Trakt secret** | `TRAKT_CLIENT_SECRET` compiled into every shipped IPA (extractable from the public unsigned IPA) | Rotate the secret; move the token exchange behind a small server proxy (or use a separate Trakt app registration for the App Store edition). |
| D5 | **ATS bypass** | `NSAllowsArbitraryLoads = true` ("plugin repos… can be plain http") | Remove; scope exceptions to declared domains if any remain. Justification dies with R1/R2. |
| D6 | **RemoteSetupServer** (embedded HTTP server, ports 8080-8089, all interfaces, phone-browser config page) | Manages addon URLs, TMDB/MDBList keys, badge packs; missing `NSLocalNetworkUsageDescription` | If D1(a): keep but add the usage description + Bonjour declarations, re-scope to the reduced feature set, and describe it specifically in review notes (Omni ships the same pattern). If D1(b): remove. |
| D7 | **Branding/bundle ID** | `com.nuvio.media.NuvioTV`, "Nuvio" brand, GitHub sideload releases, README advertising debrid/addons, a "Nuvio Media" app removed from the App Store July 2026 | New bundle ID and (recommended) a **new app name** with no public association to the sideload ecosystem. The App Store listing must never be one Google search away from "debrid setup guide" for the same name. |
| D8 | **License** | **GPLv3** inherited from upstream NuvioMobile; MPVKit non-GPL product (LGPL FFmpeg build) already linked — good | GPL is App-Store-incompatible (VLC precedent). Requires upstream consent to dual-license, or a clean-room boundary for the App Store target. Verify every MPVKit component license (LGPL relink/compliance) regardless. **Decision #1, §8-Q1.** |

### Keep (and headline)

| Feature | Notes |
|---|---|
| **mpv + hybrid AVPlayer player stack**: Dolby Vision P7→8.1 conversion (libdovi), on-device remux to fMP4, loopback HLS server (127.0.0.1-only), TrueHD/DTS→AAC transcode, libass subtitles | This is the app's honest 4.2 differentiator — the thing Infuse charges for. Lead the listing with it. |
| Skip intro/outro (IntroDB/AniSkip), Play Next / autoplay, stream info panel, track selection, subtitle styling | Clean. |
| **Trakt** device-code auth + scrobble | Allowed as a "client for a specific third-party service" (no SIWA trigger). Follow Trakt branding rules; note free accounts are now limited to one connected app. |
| **TMDB / MDBList metadata (BYO key today)** | Keep TMDB; add logo + "not endorsed" notice per TMDB terms. **Decision (§8-Q4):** BYO-key is hostile UX for a consumer App Store app — probably ship a first-party TMDB key (fine under standard terms if the app is free; commercial license if paid). |
| Profiles + PINs, avatars, watch progress/library/collections + sync (cleaned per D3) | Keep. |
| **Top Shelf extension** (`TVTopShelfContentProvider`, resume deep-links) | Already built — this is an HIG good-citizen feature most competitors lack. |
| External player handoff (Infuse/VLC/Outplayer x-callback) | Neutral and allowed (`LSApplicationQueriesSchemes` already declared). |
| Localization pipeline, appearance settings, focus/contrast work | Directly pays off in review (reviewers test with a Siri Remote on real hardware). |

---

## 5. tvOS HIG compliance (what reviewers reject on vs judge on)

### Hard requirements — rejection-class
1. **Back/Menu must walk up to the parent screen, and exit to the Home Screen from the root.** The #1 documented tvOS rejection. No gesture recognizers swallowing Menu; never fake it with `exit(0)`; don't attach a consuming `onExitCommand` at the root.
2. **Everything reachable with the Siri Remote alone** (guideline 2.4.3) — every element focusable, no companion-app requirement. (Our existing `onPlayPauseCommand` fixes for unreachable overlays are exactly this class of work.)
3. **No pointer/cursor navigation.**
4. **Layered parallax app icon is mandatory** (2–5 layers, opaque background, safe-zone). Flat icon = validation failure. tvOS still uses asset-catalog image stacks, *not* Icon Composer.
5. **Safe zone: inset content 60pt top/bottom, 80pt sides** (overscan cropping on real TVs).
6. **Play/Pause on the remote must play/pause**, swipe scrubbing must behave like the system player.
7. **Submission assets:** screenshots 1920×1080 or 3840×2160 (1–10, no alpha, real UI per 2.3.3); App Store icon stack 1280×768; home icon 400×240 @1x/@2x; Top Shelf static image 2320×720 @1x / 4640×1440 @2x.

### Strong conventions
- System focus effects by default; design all five focus states; padding for the ~10% focus scale-up; "avoid using only color to indicate focus."
- Top tab bar (68pt tall, 46pt from top) or the tvOS 18+ TV-app-style sidebar via `TabView` + `.tabViewStyle(.sidebarAdaptable)`.
- Typography: SF Pro, body 29pt, **minimum 23pt**, no light weights. Limited palette deferring to artwork.
- Minimize text entry (pickers over keyboards; `TVDigitEntryViewController`-style PIN entry; tvOS 26 Automatic Sign-In API for account continuity — needs an Apple entitlement request).
- Playback: prefer `AVPlayerViewController` behavior; a custom player (our mpv path) must mirror system transport conventions — swipe to scrub, Play/Pause, info/episodes tabs on the transport bar, instant black-screen start, resume without asking, loading spinner only past ~2s.
- Now Playing metadata via `MPNowPlayingInfoCenter`; `.playback` audio session; PiP supported on tvOS via `AVPictureInPictureController`.
- Optional heavy lift (post-v1): Apple TV app / Universal Search / Up Next integration via catalog feeds + Video Partner Program.

### tvOS 26 / Liquid Glass adoption checklist
1. Build with the tvOS 26 SDK — standard SwiftUI bars/sheets/buttons adopt Liquid Glass automatically; on tvOS, standard controls take the glass appearance **on focus**.
2. Use standard focus APIs on custom controls so they inherit the focus-driven glass treatment.
3. Explicit APIs when needed — `glassEffect(_:in:)`, `GlassEffectContainer`, `.buttonStyle(.glass)` — all confirmed available on tvOS 26. Glass belongs in the floating controls/navigation layer only, never the content layer; use standard materials for content-layer overlays; `clear` glass variant over media needs a ~35% dim layer.
4. Remove custom backgrounds behind bars/sidebars so system glass + scroll-edge effects work (`scrollEdgeEffectStyle`).
5. Liquid Glass renders on Apple TV 4K 2nd gen (2021)+; older hardware keeps the flat look — don't encode meaning in the material.
6. Test with Reduce Transparency / Increase Contrast / Reduce Motion.
7. (The NuvioMobile welcome/sign-in liquid-glass redesign already in the beta.6 track is directionally right.)

### Design resources reality check
- **There is no tvOS Figma kit.** Apple's current resources for tvOS: "tvOS 18" Design Templates (Sketch) + Production Templates (Sketch/Photoshop, incl. Top Shelf layouts), Parallax Previewer + Parallax Exporter for layered images, SF Pro, SF Symbols 7.2. iOS/macOS/watchOS/visionOS Figma kits exist; tvOS is absent — the Sketch templates + HIG metrics are the authoritative source.
- SwiftUI-on-tvOS watch-outs: heavy `LazyVGrid` shelves can stutter (consider `UICollectionView` wrapping for the densest grids), `.buttonStyle(.card)` is the lockup replacement, `.focusSection()` for cross-column focus, `.defaultFocus` for initial placement, no WKWebView on tvOS at all.

---

## 6. Non-content compliance checklist (all mandatory)

- [ ] **Privacy manifest** (`PrivacyInfo.xcprivacy`): required-reason APIs (UserDefaults, file timestamps, disk space — the player/remux cache certainly qualifies), `NSPrivacyTracking = false`, collected-data types matching the nutrition label. Audit Supabase/other SDKs against Apple's listed-SDK manifest+signature requirements.
- [ ] **Privacy nutrition labels** in App Store Connect (account = contact info/identifiers; watch history sync = usage data).
- [ ] **Privacy policy** URL in App Store Connect *and* linked in-app.
- [ ] **In-app account deletion** (full record via `delete-account` edge function; QR/link to a direct deletion page is acceptable on tvOS).
- [ ] **Usable without login**; Trakt and Nuvio accounts optional.
- [ ] **Age rating questionnaire** (new 13+/16+/18+ system) answered honestly for surfaceable content.
- [ ] **TMDB attribution**: logo + "This app uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB," less prominent than our own branding; ≤6-month caching; commercial license if the app is paid.
- [ ] **Trakt branding** per their guidelines; no VIP purchase links outside the US storefront.
- [ ] **Review notes** (2.3.1): specific description of the source model, what the app does/doesn't do, demo account credentials, backend on.
- [ ] **`NSLocalNetworkUsageDescription` + `NSBonjourServices`** if any local-network feature ships (D6).
- [ ] Remove `NSAllowsArbitraryLoads` (D5).
- [ ] Rotate + proxy the Trakt client secret (D4).
- [ ] New bundle ID; `TARGETED_DEVICE_FAMILY = 3`; layered icon; Top Shelf image; 1920×1080 screenshots of real UI.

---

## 7. TestFlight strategy

- **Internal testing (≤100 team members): no review at all** — our friction-free channel while building.
- **External TestFlight** (≤10,000 testers): Beta App Review applies the same guidelines, somewhat less exhaustively — but 5.2.3 is absolutely enforced at beta stage, and **a beta rejection creates a record on the developer account** (the same account that signs everything else). Do not TestFlight the sideload feature set. Our July risk memo's verdict stands: "TestFlight is not a safe harbor."
- Only the **first build of each version** gets full review; keep the version number stable across beta iterations. Never introduce a sensitive feature in a subsequent build of an approved version (that's the hidden-feature pattern).
- Budget time: Beta App Review has been slow/erratic through 2025–2026 (documented 42+ day waits in bad cases).

---

## 8. Decisions needed before planning implementation

**Q1 — License strategy (structural blocker).** The codebase is GPLv3 (inherited from upstream NuvioMobile). Options: (a) get upstream's consent to dual-license the code the App Store edition uses; (b) clean-room the App Store target (new UI code + only components we own or that are permissively licensed); (c) some hybrid where SharedCore pieces are rewritten. This decides how much existing code the new app can reuse, so everything else waits on it.

**Q2 — Product posture.** Two viable shapes:
- **(a) Empty addon-hub** (Vidi/Omni/Fusion shape): keeps the Stremio-compatible source model as neutral pasted URLs, retains most of Nuvio's value for existing users. Moderate, permanent takedown exposure — the survivors' moat is purely hygiene, and Apple removed Stremio Lite from this exact posture-adjacent zone.
- **(b) Pure personal-media player** (Infuse/VidHub shape): local/SMB/WebDAV/Plex/Jellyfin/Emby sources, zero addon anything. Lowest risk with essentially no takedown history — but requires building server-source features NuvioTV doesn't currently have, and serves a different audience than the sideload build.
- A staged path is possible: ship (b), evaluate adding a neutral "custom source URL" later — with the 2.3.1 caveat that the addition must go through review honestly as a new feature.

**Q3 — Name & identity.** Recommendation: a new name with no "Nuvio" association (given the July 2026 "Nuvio Media" removal and the sideload ecosystem's public footprint), new bundle ID, separate marketing site, and a listing that never mentions the sideload project. To confirm: whether the removed "Nuvio Media" app (id6762262229) has any connection to your developer account — if it does, that history attaches to the account and raises the bar.

**Q4 — Monetization.** Free (Fusion model; TMDB standard terms suffice; no IAP work) vs paid-up-front (Omni/Vidi model; needs a TMDB commercial agreement) vs freemium with IAP Pro (Infuse model; most work). Interacts with Q1 (GPL and paid apps are a messy combination even with consent).

**Q5 — Which App Store shell to build from.** Separate Xcode target in this repo sharing cleaned SharedCore modules (fastest, but the compile-out surface is large and 2.3.1-sensitive) vs a fresh app project that imports only vetted modules (cleanest binary story, more upfront work). My recommendation is the fresh project importing vetted pieces — it makes "the removed code is not in the binary" trivially true and auditable.

**Q6 — Deployment floor.** Current NuvioTV targets tvOS 26.0 (Fusion requires 26 too). Staying at 26 keeps Liquid Glass free and the codebase simple; dropping to 18 widens reach (Apple TV HD-era hardware) at real UI-work cost. Recommendation: 26.

---

## 9. Consolidated sources

**Apple:** App Store Review Guidelines (developer.apple.com/app-store/review/guidelines, rev. 2026-06-08) · Account deletion (developer.apple.com/support/offering-account-deletion-in-your-app) · Privacy manifests & listed SDKs (developer.apple.com/support/third-party-SDK-requirements) · TestFlight (developer.apple.com/testflight, App Store Connect help) · HIG: designing-for-tvos, focus-and-selection, remotes, layout, typography, color, images, app-icons, top-shelf, tab-bars, playing-video, materials, entering-data · Adopting Liquid Glass (developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) · WWDC25 219/356/323, WWDC24 10207 · Screenshot specs (App Store Connect reference) · Design resources (developer.apple.com/design/resources).

**Apps:** Fusion (apps.apple.com id6759285919) · Omni (id6741470807, omni.stkc.win, omni-help.github.io) · Vidi (id6648776878, vidi.plomo.se) · VidHub (id1659622164) · SenPlayer (id6443975850) · iPlayTV (id1517121326) · Debrify (github.com/varunsalian/debrify, sideload-only counter-example).

**Stremio timeline:** blog.stremio.com — Lite iOS release (Aug 2025), Lite tvOS release (Oct 29, 2025), full sideloadable IPA response (Feb 2026) · troypoint.com — removal coverage & cross-store enforcement · Verified today: Stremio Lite listing (id6741710156) returns 404.

**Enforcement history:** 9to5Mac (geofenced piracy app, Jul 2024) · MacDailyNews/Intego (Univer Note, Nov 2024) · Tom's Guide (time-bomb apps) · TorrentFreak (piracy brands on App Store) · Slashdot (TV Time removal) · MacRumors/9to5Mac (June 2026 guideline tightening) · TechCrunch (May 2025 US anti-steering; Nov 2025 third-party-AI privacy rule) · Techkings forum (Stremio-alternatives-on-Apple-TV thread) · AnswerOverflow Omni Discord archive.

**API terms:** themoviedb.org/api-terms-of-use · trakt.tv/terms + app.trakt.tv/branding + docs.trakt.tv VIP methods.

**Internal:** [feat3-testflight-risk-memo.md](feat3-testflight-risk-memo.md) (2026-07-22) — prior risk analysis this report extends and largely confirms.

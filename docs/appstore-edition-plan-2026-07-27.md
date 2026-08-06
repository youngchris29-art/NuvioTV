# App Store Edition — Implementation Plan

**Date:** 2026-07-27 · **Status:** DRAFT — awaiting approval. No implementation until approved.
**Basis:** [appstore-edition-research-2026-07-26.md](research/appstore-edition-research-2026-07-26.md)

## Locked decisions

| # | Decision | Choice |
|---|---|---|
| 1 | License strategy | **Clean-room rewrite** (no upstream/GPL code) |
| 2 | Product posture | **Empty addon hub** (Vidi/Omni/Fusion shape) |
| 3 | Identity | **Fresh brand** (no Nuvio association) |
| 4 | Monetization | **Free**, no IAP (TMDB standard terms suffice) |
| 5 | Build approach | **Fresh Xcode project**, new repository |
| 6 | Deployment floor | **tvOS 26** (Liquid Glass native) |

---

## 1. Product definition

**Working codename:** `Beacon` (placeholder everywhere until the real name is chosen — see §10).

**One-line positioning (listing voice):** *A beautiful media hub for Apple TV — organize, discover, and play your personal media with a best-in-class player.*

**What it is (v1.0):**
- A tvOS 26 SwiftUI app that ships **completely empty** of content.
- **Discovery layer:** TMDB-powered browse/search (trending, popular, genres) presented as *information* — detail pages, watchlists, library organization. No play path exists for a title unless a user-added source can serve it.
- **Sources:** users may connect sources by pasting a manifest URL (Stremio-protocol-compatible, but never named that). Sources provide catalogs, metadata, streams, and subtitles. Nothing is bundled, suggested, or linked.
- **Player:** dual-engine — AVPlayer for HLS/MP4, mpv (MPVKit non-GPL/LGPL) for MKV and everything else. System-conventional transport UI.
- **Trakt:** optional sign-in (device code via our proxy), scrobbling, watchlist/up-next.
- **Sync:** iCloud (CloudKit private DB + SwiftData). **No proprietary account system** — this eliminates the account-deletion requirement, the demo-backend burden, and keeps the privacy label at "Data Not Collected."
- **Good-citizen tvOS:** Top Shelf extension, Now Playing metadata, tvOS multiuser (runs-as-current-user), full HIG focus behavior, Liquid Glass.

**Explicit non-goals for the App Store binary (never compiled in):**
- No debrid (no TorBox/Premiumize/Real-Debrid/AllDebrid — no UI, no code, no strings).
- No torrent anything: `magnet:`, `torrent://`, `infoHash` results from sources are **silently discarded** at the parser level.
- No JS/plugin runtime, no downloadable code.
- No bundled/default/suggested sources; no `stremio://` URL scheme; no addon "catalog" or directory.
- No YouTube stream extraction.
- No `NSAllowsArbitraryLoads`.
- No server-controlled feature flags that alter the source model (2.3.1).

**Review-posture rules (enforced, not aspirational):**
1. **Vocabulary ban** in app strings, identifiers, bundle metadata, and listing copy: `stremio, torrent, magnet, debrid, real-debrid, alldebrid, premiumize, torbox, torrentio, aiostreams, scrape(r), piracy, sideload`. Enforced by a CI lint script that greps the app target and `.xcstrings` on every build.
2. In-app terminology: **"Sources"** (not addons). Listing copy mirrors Omni's accepted phrasing: "extend with sources that provide catalogs, metadata, streams and subtitles."
3. Screenshots: shelves, detail pages, player, settings — artwork only from TMDB-licensed metadata display or public-domain demo content. No source names visible.
4. Zero public association with the Nuvio sideload project: separate repo, site, support email, no cross-promotion in either direction, no mention on the beta Reddit thread.

---

## 2. Clean-room & licensing policy

Verified 2026-07-27: every commit in `iosApp/NuvioTV/` (105 commits) is authored solely by Christian Turnbull; `shared/` (SharedCore KMP) derives from upstream `NuvioMedia/NuvioMobile` (GPLv3).

**Tier 1 — Reusable (your sole authorship, original engineering, not ported from upstream):**
Eligible for selective reuse after per-file `git log --follow` authorship confirmation and removal of SharedCore imports. Candidates: the hybrid player stack (`RemuxSession`, `MediaProbe`, `DoviRpuConverter`, `LocalHLSServer`, `AudioTranscoder`, `PlayerEngineRouter`), `MPVPlayerView`, `RemoteSetupServer` (pairing-page pattern), subtitle styling/VTT conversion, Top Shelf snapshot pattern, focus/UX utilities. Reused files get a fresh header and live under the new app's proprietary license.

**Tier 2 — Rewrite from spec (behavior derived from upstream/SharedCore):**
Anything currently in SharedCore: addon protocol client, TMDB service, Trakt client, catalogs/home logic, library/progress models, settings. Process: write a short behavioral spec (endpoints, data shapes, rules) in the new repo's docs, then implement fresh in Swift **without the Kotlin source open**. The Stremio addon protocol itself is publicly documented (protocol specs are not copyrightable); implementing it fresh from the public docs is clean.

**Tier 3 — Never:** any upstream NuvioMobile code, in any form, including "just translating" Kotlin to Swift.

**Third-party licensing:**
- **MPVKit non-GPL product** (LGPL FFmpeg/mpv build): dynamic frameworks only (satisfies LGPL relink), in-app **Licenses/Acknowledgements screen** with LGPL notices and a source-availability link. Verify each component's license flag at integration time (no GPL-flagged components in the non-GPL product).
- Everything else: Apple frameworks + our own code. **Target: zero third-party SDKs besides MPVKit** — keeps the privacy manifest trivial and the binary auditable.
- New repo license: **proprietary, private repo** (recommended; competitors are closed-source and open-sourcing invites forks/scrutiny that erode the review posture). Your call — flagged in §10.

**Caveat (not legal advice):** the Tier 1 analysis (you retain copyright in your own original contributions to a GPL-distributed work and may relicense them) is the standard understanding, but if you want certainty — especially for the player stack, the app's crown jewel — a one-hour consult with a software-licensing attorney is cheap insurance.

---

## 3. Architecture & tech stack

**New repository** (private), sibling to this project — proposed: `~/Claude/Projects/Beacon/`.

```
Beacon/
├── Beacon.xcodeproj            # tvOS app + TopShelf extension targets
├── App/                        # app target: entry, navigation shell, screens
├── Packages/                   # local SwiftPM packages (unit-testable, App-target-independent)
│   ├── DesignKit/              # tokens, typography scale, card/shelf components, focus helpers, glass wrappers
│   ├── SourceKit/              # manifest-URL source client (catalogs/meta/streams/subtitles) + compliance filter
│   ├── MetadataKit/            # TMDB client, models, artwork URLs, disk cache
│   ├── TraktKit/               # device auth (via proxy), scrobble, watchlist/up-next
│   ├── PlayerKit/              # engine router, AVPlayer + MPVKit wrappers, transport VM, subtitle styling
│   └── LibraryKit/             # SwiftData models (library, progress, sources, settings) + CloudKit sync config
├── Server/                     # Cloudflare Worker (Trakt token proxy) + static site (privacy, support, licenses, demo source)
├── docs/                       # behavioral specs (Tier-2 clean-room inputs), decision log
└── scripts/                    # build, lint-banned-words.sh, screenshot capture, release
```

**Stack choices:**
- Swift 6 (strict concurrency), SwiftUI-only, tvOS 26.0 minimum. No UIKit unless a measured grid-performance problem forces a `UICollectionView` wrap (known SwiftUI/tvOS risk — see §8).
- **Persistence/sync:** SwiftData with CloudKit private database (library, watch progress, sources, per-user settings). `NSUbiquitousKeyValueStore` for lightweight prefs. No Supabase, no custom backend for user data.
- **Multiuser:** adopt tvOS runs-as-current-user (`com.apple.developer.user-management`) so each Apple TV viewer gets isolated data + their own iCloud sync — replaces Nuvio's custom profiles/PINs with the system feature (HIG-endorsed, differentiator vs competitors).
- **Networking:** URLSession + async/await, Codable. ATS fully on; **https-only sources** (http manifest/stream URLs rejected with a clear error — also a compliance posture win).
- **Artwork:** custom lightweight disk-cached image loader (AsyncImage semantics, prefetch hooks for shelves — pattern from your ArtworkStore, Tier 1).
- **Navigation:** `TabView` + `.tabViewStyle(.sidebarAdaptable)` (TV-app-style sidebar): Home · Search · Library · Settings.

**Services:**
- **Trakt proxy** (Cloudflare Worker, ~100 lines): forwards `/oauth/device/code`, `/oauth/device/token`, `/oauth/token` (refresh) to Trakt injecting the client secret server-side; no token logging; rate-limited. Fixes the secret-in-binary problem structurally. New Trakt app registration under the new brand.
- **TMDB:** first-party v4 read token in the app config (standard practice; free app satisfies TMDB's non-commercial terms). Attribution screen per TMDB requirements. Optionally proxy later if the key gets abused.
- **Static site** (Cloudflare Pages, new domain): privacy policy, support page, LGPL source-offer/licenses page, and the **review demo source** (below).

**Review demo source:** a static Stremio-protocol-compatible JSON source hosted on our site, serving **only public-domain / CC content** (Blender open movies: Big Buck Bunny, Sintel, Tears of Steel; NASA footage). Given to Apple **only in the Notes for Review** — never referenced in the app — so the reviewer can exercise add-source → browse → play end-to-end with fully licensed content. This converts the app's empty state from a 4.2 liability into a demonstrable, legitimate flow.

### SourceKit compliance filter (load-bearing component)

Applied at parse time, before anything reaches UI or cache:
1. Drop any stream without an `https` URL (kills `infoHash`/`magnet`/`torrent://`/`externalUrl`-only/`clientResolve` results silently).
2. Drop sources/catalogs/items flagged `behaviorHints.adult` (Infuse precedent; supports the age rating).
3. Drop `behaviorHints.p2p` streams.
4. Manifest URLs must be `https`; no redirects to non-https.
5. No release-group string surfacing in default UI: stream rows show source name + quality/size fields, with raw titles available only in a details disclosure. (Keeps screenshots and casual review clean without hiding functionality.)

---

## 4. Feature specification (v1.0)

### 4.1 First-run & Home
- **Welcome:** single glass screen, one primary action ("Get Started") → Home. No sign-in gate of any kind.
- **Home (empty state):** hero row of TMDB trending (information framing), "Set up your library" cards (Connect a Source · Sign in to Trakt · both optional), empty Continue Watching/Library shelves with helpful copy.
- **Home (configured):** Continue Watching (local + Trakt merged) · user-pinned source catalogs as rows · Library shelf · TMDB discovery rows (clearly sectioned). Row order user-configurable.
- Detail pages for titles with no playable source show metadata + Add to Library/Watchlist; the Play button only exists when a connected source returns a compliant stream.

### 4.2 Sources management (Settings → Sources)
- Add via: (a) on-screen keyboard, (b) **phone-assist pairing page** — the app serves a local, token-gated web page (rewritten `RemoteSetupServer` pattern, Tier 1); user scans an on-screen QR, types the URL in their phone browser, confirms on the TV. Requires `NSLocalNetworkUsageDescription` + `NSBonjourServices` (declared, described in review notes; Omni ships the same pattern).
- List/reorder/enable/disable/remove; per-source health check (manifest reachable, resources declared).
- Neutral empty-state copy: "Sources provide catalogs and streams from your own services and servers."

### 4.3 Discovery & search
- TMDB: trending/popular/genre rows, person/collection browse, full detail pages (cast, seasons/episodes, ratings, artwork). TMDB attribution in Settings → About.
- Search: TMDB primary; connected sources' search catalogs merged beneath, grouped by source.

### 4.4 Playback (PlayerKit)
- **Engine router (simplified Tier-1 port):** AVPlayer for HLS/MP4/MOV with supported codecs; mpv for MKV/WebM/everything else. (The full native DV remux path is post-1.0 — §9.)
- Transport UI mirrors the system player: swipe-to-scrub, Play/Pause hard requirement, info/audio/subtitle panels on the transport bar, skip ±10s, instant black-screen start, auto-resume, spinner only past 2s.
- Subtitles: embedded tracks + source-provided subtitles; styling options; SRT→VTT for AVPlayer (Tier 1).
- Now Playing metadata (`MPNowPlayingInfoCenter`) + `.playback` audio session.
- Watch progress recorded locally (SwiftData) → CloudKit; Trakt scrobble if connected.
- Play Next / next-episode autoplay (rewrite, simplified).

### 4.5 Library & sync
- Library (saved titles), Watchlist, Continue Watching, watched history — SwiftData models, CloudKit private DB sync, per-system-user via multiuser entitlement.
- Trakt: device-code sign-in (via proxy), scrobble, watchlist pull, up-next shelf. Sign-out clears tokens. **No VIP upsell links** (compliance; "manage at trakt.tv" text only).

### 4.6 Settings
Sources · Trakt · Playback (engine preference, subtitle style, language) · Appearance (row order) · About (version, TMDB attribution, licenses/LGPL notices, privacy policy link, support link).

### 4.7 Top Shelf extension
`TVTopShelfContentProvider` sectioned items: Continue Watching (resume deep links via app URL scheme — new neutral scheme, e.g. `beacon://`) + Library highlights. Static top-shelf image fallback.

---

## 5. Design system & HIG conformance

**DesignKit deliverables (Phase 0-1):**
- Typography scale per HIG tvOS tables (body 29pt, min 23pt, no light weights); 60/80pt safe-zone layout constants; focus-scale padding constants (~10%).
- Components: poster/landscape lockup cards (`Button` + `.buttonStyle(.card)`), shelf (horizontal row with header), hero, grid, settings row, glass panels (`glassEffect`/`GlassEffectContainer` — floating/controls layer only, never content layer), empty-state card.
- Focus: system effects by default; `@FocusState`/`.focusSection()`/`.defaultFocus` conventions; all five focus states designed; never color-only focus indication.

**Hard-requirement checklist (verified every phase, not at the end):**
- [ ] Back/Menu walks up one level everywhere; exits to Home Screen from root; never swallowed, never `exit(0)`.
- [ ] Every element reachable with Siri Remote alone; no companion requirement (phone-assist is optional convenience).
- [ ] No pointer UI.
- [ ] Content inside 60/80pt safe zones (visual check on real TV overscan).
- [ ] Play/Pause behaves on remote in player and previews.
- [ ] Layered parallax app icon (2–5 layers, opaque background) + 1280×768 store stack; static Top Shelf 2320×720 @1x/@2x; screenshots 1920×1080 real UI.
- [ ] Reduce Motion / Reduce Transparency / Increase Contrast / VoiceOver pass on every screen.

**Liquid Glass adoption:** standard bars/sheets/buttons from the tvOS 26 SDK (free); standard focus APIs on custom controls so they inherit focus-driven glass; no custom backgrounds behind bars/sidebars; `scrollEdgeEffectStyle` where we draw our own chrome; `clear` glass over media with dim layer; never encode meaning in the material (renders only on Apple TV 4K 2nd-gen+).

**Design references:** Apple tvOS 18 Sketch templates + HIG metrics (no tvOS Figma kit exists), SF Symbols 7.2, Parallax Previewer for the icon/top-shelf layered assets.

---

## 6. Compliance work items (mapped to guidelines)

| Item | Guideline | Phase |
|---|---|---|
| `PrivacyInfo.xcprivacy`: required-reason APIs (UserDefaults, file timestamps, disk space), `NSPrivacyTracking=false`, empty collected-data (CloudKit private DB + no analytics ⇒ "Data Not Collected") | 5.1.1/5.1.2, upload-blocking | P0 (scaffold), P6 (final) |
| Privacy nutrition label: Data Not Collected | 5.1.1 | P6 |
| Privacy policy page (site) + in-app link | 5.1.1(i) | P6 |
| No account system ⇒ no deletion flow needed; app fully usable with nothing configured | 5.1.1(v), 4.2 | by design |
| TMDB logo + non-endorsement notice; ≤6-month cache | TMDB terms | P1 |
| Trakt branding per guidelines; no VIP purchase links | 3.1.3, Trakt terms | P4 |
| LGPL notices + source-availability link (MPVKit components); dynamic linking | LGPL | P3/P5 |
| `NSLocalNetworkUsageDescription` + `NSBonjourServices` for pairing page | 2.1 | P2 |
| Age rating questionnaire (expect 4+ — app ships no content; adult-flag filtering on) | 2.3.6 | P6 |
| Notes for Review: specific source-model description, demo source URL, pairing-page explanation | 2.3.1, 2.1(a) | P6 |
| Banned-vocabulary lint in CI | 2.3.1 posture | P0 |
| New bundle ID under fresh brand; `TARGETED_DEVICE_FAMILY=3` | — | P0 |

---

## 7. Phased build plan

Estimates assume current working cadence (you + Claude), focused sessions. Each phase ends with a **gate**: build green, HIG checklist re-run, banned-words lint clean, phase demo on the Living Room Apple TV via devicectl.

**Phase 0 — Foundations (1–2 days)**
New private repo; Xcode project (app + TopShelf targets, tvOS 26, new bundle ID placeholder); SwiftPM package skeletons; DesignKit tokens + typography + safe-zone scaffolding; banned-words lint script wired into build; privacy manifest scaffold; sidebar tab shell with placeholder screens.
*Gate: app runs on sim + device with navigable shell; lint green.*

**Phase 1 — Discovery & detail (4–6 days)**
MetadataKit (TMDB client, models, artwork cache — Tier-2 spec first); Home with trending/discovery rows + empty-state design; Search (TMDB); title/season/episode detail pages; local Library/Watchlist (SwiftData, no sync yet); TMDB attribution.
*Gate: browse/search/detail/library flows complete with remote-only navigation; empty-state Home looks intentional (screenshot-ready).*

**Phase 2 — Sources (4–5 days)**
SourceKit from the public addon-protocol spec (Tier 2): manifest parse, catalogs, meta, streams, subtitles + the §3 compliance filter (unit-tested hard); Sources management UI; phone-assist pairing page (Tier-1 rewrite of RemoteSetupServer with Info.plist declarations); source catalogs → Home rows; source search merge.
*Gate: add/remove/reorder sources; compliant streams listed on detail pages; filter test suite green (torrent/p2p/http/adult all dropped).*

**Phase 3 — Playback (6–10 days)**
PlayerKit: AVPlayer path (HLS/MP4) with system-conventional custom transport; MPVKit (non-GPL, dynamic) integration for MKV; simplified engine router (Tier-1 port); embedded + source subtitles with styling; SRT→VTT; Now Playing + audio session; resume/progress recording; Play Next/autoplay.
*Gate: reference clips (HLS, MP4, MKV/HEVC, MKV+SRT, 4K HDR) play with correct transport behavior on device; Play/Pause + Menu behavior verified; remux/DV advanced path explicitly deferred.*

**Phase 4 — Sync & Trakt (4–6 days)**
CloudKit sync for library/progress/sources/settings; multiuser entitlement + per-viewer verification; Trakt proxy worker deployed; device-code auth, scrobble, watchlist/up-next shelf; merged Continue Watching.
*Gate: two-device sync demo; second Apple TV user profile isolation; Trakt round-trip verified; no secrets in binary (strings check).*

**Phase 5 — Platform polish (3–5 days)**
Top Shelf extension + deep links; licenses/acknowledgements screen; accessibility pass (VoiceOver labels, Reduce Motion/Transparency variants); localization seed (en + the existing xcstrings pipeline pattern, rebuilt); performance pass on shelves (measure before reaching for UIKit); Settings completeness.
*Gate: full HIG hard-requirement checklist green on real hardware; accessibility variants screenshotted.*

**Phase 6 — Compliance & assets (3–4 days)**
Layered app icon + store icon stack + top shelf art (Parallax Previewer verified); 1920×1080 screenshot set; site live (privacy/support/licenses/demo source); final privacy manifest + labels; age questionnaire; App Store Connect record (name, subtitle, keywords, description in accepted-phrasing style); Notes for Review drafted (source model, demo source URL, pairing page, LGPL components); **internal TestFlight** build.
*Gate: App Store Connect upload passes validation; internal TF installable; review-notes dry-run read-through.*

**Phase 7 — Beta & submission (calendar-dependent)**
Internal TF bake (1–2 weeks, recruit from trusted circle — not the public sideload community); fix cycle; **external TestFlight** (first Beta App Review contact — expect days-to-weeks latency; keep version number stable across builds); then App Store submission.
*Gate: approval. Rejection playbook in §8.*

**Total build estimate: ~25–38 working days (≈5–7 focused weeks) to submission-ready**, plus Apple review latency.

---

## 8. Risks & mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| 4.2 "minimum functionality" pushback on empty-shell | Medium | Demo source in review notes proves end-to-end value with licensed content; TMDB discovery + library + player quality stand alone; listing leads with player/organization. |
| Reviewer recognizes the addon-hub pattern and rejects anyway | Medium-low (three live precedents) | Neutral vocabulary throughout; specific honest review notes; if rejected, respond via Resolution Center narrowing scope (e.g., temporarily remove manual URL entry, resubmit, appeal) rather than resubmitting unchanged. |
| Post-approval takedown (Stremio Lite pattern) | Ongoing, real | Brand hygiene (§1 rules); no press/community cross-promotion; the sideload app remains the community's build so guides point there, not at the store app; accept residual risk. |
| Beta App Review slowness (documented 40+ day worst cases) | Medium | Internal TF (no review) for iteration; external TF only when stable; stable version numbers. |
| SwiftUI shelf performance on big grids | Medium | Measure in Phase 1/5 with Instruments; fallback: `UICollectionView` wrap for the heaviest shelves only. |
| LGPL compliance challenge | Low | Dynamic linking + notices + source-offer page; component license audit at MPVKit integration. |
| Clean-room slip (accidental SharedCore-derived code) | Low-medium | Tier-2 spec-first workflow; new repo never adds the old repo as a dependency; PR-style self-review checklist item "no Kotlin open during implementation of this module." |
| TMDB key abuse once shipped | Low | Monitor; move behind the worker if needed (config already proxy-ready). |
| CloudKit sync edge cases (schema migration, conflict) | Medium | Keep SwiftData models small/flat in v1; progress conflicts resolve last-writer-wins; schema versioned from day one. |

---

## 9. Deliberately deferred (post-1.0 roadmap)

1. **Hybrid native player path** (remux → fMP4, Dolby Vision P7→8.1, loopback HLS, TrueHD/DTS transcode — your Tier-1 crown jewel): port after 1.0 ships; it's review-neutral and can headline a 1.1 "player quality" update.
2. External player handoff (Infuse/VLC x-callback).
3. Skip intro/outro (IntroDB/AniSkip) and MDBList ratings (BYO key).
4. Advanced stream badges/filters and regex stream preferences (Omni-style power features).
5. iOS/iPadOS/macOS companion versions (universal purchase groundwork exists via SwiftPM packages).
6. Apple TV app / Up Next integration (catalog feeds + Video Partner Program — heavy, revisit on traction).

---

## 10. Prerequisites & open items (need you)

1. **Apple Developer Program membership** — App Store/TestFlight requires the paid program. Confirm which team the app ships under (`WNYA9B575G` and `8QBDZ766S3` both appear in the current project) and that it's a paid membership in good standing. The account's name will be publicly visible on the listing — consider whether it should be an individual or (cleaner for brand separation) an organization/LLC.
2. **Pick the name.** Criteria: no piracy-community associations, no "Nuvio," App Store search-unique, .com/.app domain available, trademark-sane. Shortlist to check availability against (App Store + domains): *Shelfline, Marquee, Fathom, Skylight, Emberline, Northstar*. (Codename `Beacon` until decided.)
3. **Domain + Cloudflare account** for the static site (privacy/support/licenses/demo source) and the Trakt proxy worker.
4. **New Trakt app registration** under the new brand (fresh client id/secret, secret lives only in the worker). Rotate the old leaked secret regardless — it's shipped in the current public IPA.
5. **New TMDB API registration** under the new brand.
6. **Repo visibility decision** — recommendation: private/proprietary (§2).
7. **Legal comfort check (optional but recommended):** brief attorney review of the Tier-1 reuse position before the player-stack port.

---

## Approval

Reply with approval (or edits) and Phase 0 begins: new repo + project scaffolding. Items in §10 (name, developer account, domain) can proceed in parallel with Phases 0–2 — nothing before Phase 6 hard-blocks on them except the bundle ID, which can start as a placeholder and be finalized before the first TestFlight upload.

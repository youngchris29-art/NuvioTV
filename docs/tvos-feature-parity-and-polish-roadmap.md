# Nuvio tvOS — Feature Parity & Polish Roadmap

_Progress snapshot. Reviewed against the mobile app (`composeApp`) and the tvOS SwiftUI target (`iosApp/NuvioTV`). Last updated: 2026-07-01 (after Phases 0–4, 5a, 6a, 8a shipped; re-scoped against the official Nuvio Cloud API reference, `docs/nuvio-cloud-api-reference.md` v1.1)._

The tvOS app is a native SwiftUI frontend on the shared Kotlin `SharedCore` framework (via the `FlowWatcher` → `StateFlowObserver` bridge). It has grown from a 3-tab walking skeleton into a **5-tab app with profiles, a design system, and most of the core streaming experience**. This doc records what's shipped, the tvOS-specific constraints we hit, and what's left.

---

## 1. Where the tvOS app stands today

**Shell:** launches to a "Who's watching?" profile gate, then a 5-tab `TabView`: **Home · Search · Library · Add-ons · Settings**.

| Area | Status | Notes |
|---|---|---|
| **Profiles** | ✅ Shipped | "Who's watching?" gate, create/switch/edit/delete, per-profile data scoping. Guest AND cloud accounts. PIN lock (digit pad, lockout) + cloud avatar catalog (C5). |
| **Accounts & Sync** | ✅ Shipped (C1–C4) | Nuvio Cloud sign-in/sign-up (email auto-confirms), guest mode fallback, full sync (profiles, addons, library, watch progress/history, collections, settings under `p_platform:"tv"`). Verified bidirectional with mobile. |
| **Home** | ✅ Shipped | Hero banner, Continue Watching (resume + remove), catalog rows, profile switcher, customizable rows (via Settings). Cached art + shimmer. |
| **Search** | ✅ Shipped | Live `TextField` search, tokenized styling. |
| **Library** | ✅ Shipped (5a) | Grid of "Add to Library" saved titles; long-press remove; profile-scoped. |
| **Add-ons** | ✅ Shipped | Install via manifest URL, enable/disable, remove. |
| **Settings** | ✅ Shipped (6a) | Playback (Skip Intro toggle) + Home Rows (enable/disable + reorder catalogs). |
| **Detail** | ✅ Shipped | Backdrop, logo/title, meta line (year/runtime/IMDb/age), **Play · Mark Watched · Add to Library**, genres, overview, Cast, More-Like-This, **muted trailer autoplay** (AVPlayer). |
| **Series/Episodes** | ✅ Shipped | Season selector + episode list → stream picker. |
| **Stream picker** | ✅ Shipped | Streams grouped by add-on, **quality/resolution/HDR/cached badges**. |
| **Player (MPVKit)** | ✅ Shipped | Real MKV/HEVC/Dolby-Vision, transport overlay, hold-to-seek, track/subtitle pickers, external subtitles, save/resume, **Skip Intro/Outro** (press-down). |
| **Design system** | ✅ Shipped (1) | `Theme` tokens, `CachedAsyncImage` (+shimmer), `PosterCard`, applied app-wide. |
| **Infra** | ✅ Shipped | `FlowWatcher`/`StateFlowObserver` bridge; tvOS provider-seam install block; profile-lifecycle coordinator. |

---

## 2. What's been delivered (by phase)

- **Phase 0 — Seam / persistence foundation.** `installTvOsSharedProviders()` wires `ActiveProfileProvider` + `AddonProfileProvider` to the real (shared) `ProfileRepository`; a tvOS `ProfileLifecycleCoordinator` reloads per-profile repos on switch. Enables everything profile-scoped.
- **Phase 1 — Design system.** `Theme` (colors/type/spacing/radii/sizes, mobile's Crimson palette), `CachedAsyncImage` (NSCache + URLCache + shimmer), `PosterCard`/`LandscapeCard`. Applied to Home, Detail, Search, streams.
- **Phase 2 — Detail actions + stream badges.** Mark Watched (`WatchedRepository`) + Add to Library (`LibraryRepository`) with live state; `StreamBadge` chips.
- **Phase 3 — Trailer hero autoplay.** YouTube extractor (`InAppYouTubeExtractor`) migrated to `:shared`; muted looping trailer behind the Detail hero. **Now backed by AVPlayer** (see constraints).
- **Phase 4 — Profiles.** Local guest mode (`signInAnonymously`, no network), "Who's watching?" gate, create/switch/edit/delete, colored avatars, lifecycle refresh on switch.
- **Phase 5a — Library tab.** Saved-titles grid, remove, `item.toMetaPreview()` → Detail.
- **Phase 6a — Settings hub v1.** Skip Intro toggle (gates the player pill) + Home Rows customization (`HomeRepository` already honors `HomeCatalogSettings`).
- **Phase 8a — Skip Intro/Outro.** `SkipIntroRepository` segments → in-player "Skip" pill (press-down to seek).

---

## 3. tvOS-specific constraints we hit (important context)

- **libmpv + Vulkan/MoltenVK is fragile on the tvOS simulator.** `vo=gpu-next` (libplacebo) asserts (`"vo: hit program assert"`) on some streams and when a SwiftUI screen re-renders during playback. Fixes applied: **all libmpv surfaces use `vo=gpu`** (not `gpu-next`), and the **interactive Detail trailer moved to AVPlayer** (native Metal, no second Vulkan context). Trade-off: slightly less advanced HDR tone-mapping — worth re-testing `gpu-next` on real Apple TV hardware someday.
- **No sign-in on tvOS — local "guest" mode.** `AuthRepository.signInAnonymously()` is purely local (UUID in NSUserDefaults), which unlocks local profile/library/settings persistence with no account.
- **Config gaps** (`local.properties` is empty on tvOS) gate several features. Add these keys + relink to enable:
  - `SUPABASE_URL` / `SUPABASE_ANON_KEY` → cloud sync, profile PIN, avatar catalog. **RESOLVED by the API reference** — base URL `https://api.nuvio.tv` and the publishable key are published in `docs/nuvio-cloud-api-reference.md` (§Getting Started). Wire them into `local.properties`, relink, done.
  - `TRAKT_CLIENT_ID` / `TRAKT_CLIENT_SECRET` → Trakt. Still needed (not in the API doc — Trakt is a third party).
  - `INTRODB_API_URL` → broad Skip-Intro coverage (anime works without it via AniSkip). Still needed.
  - TMDB / Premiumize keys → Collections sources, cloud library. Still needed.

---

## 4. What's left — scoped (2026-07-01, post API-reference)

The official Nuvio Cloud API reference changes the picture: the Supabase base URL + publishable key are now **public**, so the whole cloud cluster (accounts, sync, PIN, avatars) moves from "config-gated, someday" to "wire it up now". The shared Kotlin layer already implements virtually all of the client side — `AuthRepository.signInWithEmail/signUpWithEmail`, `SyncManager`, delta-sync adapters (`SupabaseProgressSyncAdapter`/`SupabaseWatchedSyncAdapter`), `p_client_max_profiles = 6` (`MAX_PROFILES`), `AvatarRepository`, and profile-PIN logic in `ProfileRepository`. The tvOS work is mostly config, UI, and lifecycle wiring.

Effort key: **S** = a session, **M** = a few sessions, **L** = multi-day.

### Tier 1 — Cloud bring-up (unblocked by the API doc)

- **C1. Config + smoke test — ✅ SHIPPED (2026-07-01).** `local.properties` has the api.nuvio.tv URL + publishable key (both hosted + nuvio pairs); relink green; health-check + signup verified live (email auto-confirms — no confirmation-mail flow). ⚠️ Discovered: Christian's home network **SNI-blocks nuvio.tv** — cloud testing needs hotspot/VPN until fixed at the router/ISP.
- **C2. Account sign-in UI — ✅ SHIPPED (2026-07-01).** `WelcomeView` (Sign In / Create Account / Continue as Guest) + `AuthView` + `AuthViewModel`; `ContentView` gates on `AuthRepository.state`; Settings has an Account section (sign in/out with confirm). Guest→account transitions **wipe local data** via a new `TvOsAccountDataCleaner` (installed in `installTvOsSharedProviders()`, which now also calls `SyncBackendRepository.ensureLoaded()` — required or auth hangs in Loading). The old every-launch `signInAnonymously()` call is gone (it regenerated the guest id per launch and shadowed real sessions).
- **C3. Sync wiring — ✅ SHIPPED (2026-07-01).** Profile select → `SyncManager.pullAllForProfile`; `scenePhase == .active` → `requestForegroundPull(force:)`. **Verified end-to-end: profiles + watch history created on TV appear on mobile and vice versa.**
- **C4. `p_platform: "tv"` — ✅ SHIPPED (2026-07-01).** New `SyncPlatformProvider` seam (default `"mobile"`; tvOS installs `TV_SYNC_PLATFORM`); both `ProfileSettingsSync` RPC sites read it. tvOS reuses the `MobileProfileSettingsBlob` shape for now under its own `"tv"` blob.
- **C5. Cloud profiles: PIN + avatar catalog — ✅ SHIPPED (2026-07-01).** `PinEntryView` digit pad; PIN gate on select/edit/delete of locked profiles (lock badge, lockout countdown, offline cache fallback); Set/Change/Remove PIN in the edit view (cloud accounts only); avatar catalog picker + real avatar rendering via `profileAvatarImageUrl` (saves both `avatarId` and resolved URL for cross-device render). **Tier 1 complete — full cloud parity for accounts/profiles/sync.**

### Tier 2 — Config-free, high value

- **8b. Next-Episode autoplay — ✅ SHIPPED (2026-07-01).** `NextEpisodeEngine` + `UpNextCard`: settings-threshold trigger, aired-episode resolution, stream auto-select via shared `PlayerStreamsRepository` + `StreamAutoPlaySelector` (binge-group preference, bounded timeout), 3-2-1 countdown, press-down to play now / backward-seek to cancel. Works from the episodes flow (the Home continue-watching launch path lacks the episode list — later polish). Verified on device.
- **Catalog "see all" full-grid screen — ✅ SHIPPED (2026-07-01).** `CatalogGridView` + `CatalogGridViewModel` over the shared paginated `CatalogRepository`; a "See All" link in each `CatalogRowView` header (shown when `hasMore`) navigates via a `CatalogRoute` wrapper. Adaptive `LazyVGrid`, infinite-scroll `loadMore()`, poster → Detail. Works on Home + Search. Pure Swift, no relink. Verified on device.

### Tier 3 — Still config-gated (keys NOT in the API doc)

- **Phase 7 — Trakt (M–L). ✅ SHIPPED 2026-07-02 (verified on device, zero fix rounds).** Shared: `TraktAuthRepository` gained the full device-code flow — `onStartDeviceFlow()` requests `/oauth/device/code`, publishes `deviceUserCode`/`deviceVerificationUrl`/`deviceExpiresAtMillis` in `TraktAuthUiState`, and polls `/oauth/device/token` (400 pending / 429 slow-down / 404·409·410·418 terminal) via `httpRequestRaw`; `onCancelDeviceFlow()` is now a real cancel. Reuses existing StringKeys (the compose provider's `when(key)` is exhaustive — no new enum entries). tvOS Swift: `TraktViewModel` + Settings "Trakt" section (Connect → activation-code card → Connected/Disconnect), and the player scrobbles via shared `TraktScrobbleRepository` (start on file load, stop with final % on exit; no-ops while disconnected). Remaining: Trakt API keys in `local.properties` → relink → device test.
- **Skip-Intro broad coverage (S).** Add `INTRODB_API_URL` + relink. No code.
- **Phase 5b — Collections (M–L).** Folders hold sources (Trakt/TMDB/catalog); needs TMDB (+ Trakt) keys, a source-picker UI, and — with cloud now live — collections sync (full-replace, `sync_pull/push_collections`) comes along via C3.

### Tier 4 — Polish / lower ROI

- **Deferred Settings pages (S–M each):** subtitle appearance (shared `SubtitleColor`/`SubtitleStyleState`), audio/subtitle language auto-select, theme picker (tvOS `Theme.swift` is hardcoded Crimson; `ThemeSettingsRepository` is shared but its store seam is a no-op on tvOS — needs a tvOS `ThemeSettingsStore` adapter for persistence), poster shape.
- **Detail richness (S–M):** production/additional-info section, person detail, poster rail, trailers row; Trakt comments once Phase 7 lands.
- **tvOS seam adapters for current no-ops (S each, optional):** theme-settings persistence (above); the rest (downloads, episode-release notifications, native tab bar) are deliberately no-op on tvOS.

### Deferred (out of scope)

- **Downloads / offline** — low value on always-connected Apple TV (downloader impl stays in composeApp behind the seam).
- **Notifications** — no meaningful local-notification story on tvOS.
- **p2p / plugins / updater** — platform-sensitive, flavor-bound.
- **Cloud/debrid Library browser** (the separate `library/LibraryScreen`) — needs Premiumize config; distinct from the saved library already shipped.
- **Full localization** — English-only until parity lands (shared `StringProvider` seam makes this a later drop-in).

---

## 5. Recommended order

1. **C1 config + smoke test** — one session, unblocks the whole cloud tier.
2. **C2 + C3 accounts & sync** — the biggest parity jump available; turns the tvOS app from a local island into a synced client (mobile ↔ TV continue-watching is the headline win).
3. **C4 platform fix** — do alongside C3 (it's a contract-correctness bug once sync is live).
4. **C5 PIN + avatars** — rounds out profiles.
5. **8b Next-Episode autoplay** — can be done in parallel with any of the above (config-free, player-only).
6. Then Trakt device-code (needs keys + shared-code work), Collections, settings polish.

---

_Note: `nuvio.tv` is a client-rendered marketing site; the `composeApp` code remains the authoritative feature list and drove this analysis._

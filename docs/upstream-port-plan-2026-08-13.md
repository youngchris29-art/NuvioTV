# Upstream port check — 2026-08-13

## Summary

**5 new upstream commits landed** on `upstream/cmp-rewrite` since the last check (pinned at `f9ad843b` for the two prior daily checks, 08-11 and 08-12). New HEAD: `0d6e30e4` ("bump version"), dated 2026-08-10 through 2026-08-13.

Checked against the `NuvioMobile` submodule (`origin` = `youngchris29-art/NuvioMobile`, `upstream` = `NuvioMedia/NuvioMobile`, tracked branch `cmp-rewrite`).

Fork state at check time: outer `main` HEAD `cd616ec` ("docs: device-pass sections 5-10 results — pass complete, VidHub tvOS handoff vendor-broken"), submodule `NuvioMobile` HEAD `652c4c2b` on `tvos-shared-extraction` ("feat(diagnostics): VidHub handoff bisect knob + gated external-player URL probe" — fork-native, not an upstream port).

## Verification: did the 2026-08-12 items land / change?

Only one open item carried forward: **TMDB Discover exclusion filters (LOW, feature add, upstream `0fc4616b`)**. Re-checked directly:

- `grep -n "withoutGenres\|withoutKeywords\|withoutCompanies\|withoutWatchProviders" shared/src/commonMain/kotlin/com/nuvio/app/features/collection/CollectionModels.kt` → no matches. Still not ported.

**Status unchanged: still open, still LOW priority.** Third consecutive check with no movement — no collections/UI pass has landed since 08-10.

## New items this run

Five commits landed on `upstream/cmp-rewrite`:

| Commit | Date | Summary | tvOS-relevant? |
|---|---|---|---|
| `55307c43` | 08-10 | fix: control disintegrate animation | No — Compose-only UI (`@Stable`/`mutableStateOf` particle-dissolve controller for library/continue-watching row removal). No `shared/` counterpart exists or is warranted. |
| `d50f84fc` | 08-12 | fix(ios): allow smaller subtitle sizes (#1716) | Judgment call — see item 1 below. |
| `981b8bc7` | 08-12 | fix: honor addon cache control | **Yes — actionable, medium priority.** See item 2 below. |
| `c861a8ff` | 08-12 | fix: balance episode progress spacing | No — touches only `DetailSeriesContent.kt`, a Compose UI file with no `shared/` equivalent. tvOS has its own native SwiftUI detail screen; nothing to port. |
| `0d6e30e4` | 08-13 | bump version | No — `iosApp/Configuration/Version.xcconfig` only, mobile app's own version bump. |

### Item 1 — Subtitle minimum font size (LOW, needs a product decision, not a mechanical port)

Upstream commit `d50f84fc` lowers the minimum subtitle size on iOS from 12sp to 6sp (`subtitleFontSizeRangeSp` in `SubtitleAudioModels.kt`, gated by `isIos`) and lowers the mpv-side floor from 24f to 18f in `PlayerEngine.ios.kt`. Checked `shared/src/commonMain/kotlin/com/nuvio/app/features/player/SubtitleAudioModels.kt` and `PlayerSettingsRepository.kt` — neither has this clamp/range logic yet (shared's `fontSizeSp` is currently unbounded, predating this fix entirely).

This is not a clean port because tvOS doesn't use `PlayerEngine.ios.kt` (that's the KMP/Compose iOS mobile engine) — tvOS renders subtitles via `iosApp/NuvioTV/Screens/SubtitleVTT.swift`, a separate native implementation. There's also a UX question worth flagging rather than silently porting: 10-foot TV UIs are generally read from further away than a phone, so the mobile motivation ("let phone users shrink subtitles") may not transfer to tvOS — if anything a *larger* minimum makes more sense on TV. Recommend deciding intent before touching `SubtitleVTT.swift`, not blindly mirroring the iOS range.

**Suggested action:** no code change yet. Next time subtitle styling on tvOS gets a pass, decide whether tvOS wants its own `subtitleFontSizeRangeSp`-equivalent (likely a *larger* floor, not smaller) rather than porting the iOS mobile change as-is.

### Item 2 — Addon cache-control / force-refresh (MEDIUM priority, mechanical port)

Upstream commit `981b8bc7` fixes a real bug: manual refresh actions (pull-to-refresh, retry buttons) were silently hitting the HTTP cache instead of forcing a fresh addon response, so users who refreshed after an addon's catalog changed kept seeing stale data. The fix threads a `forceRefresh: Boolean` parameter through the addon fetch stack and adds a `Cache-Control: no-cache` header when set:

- New file `AddonHttpClient.kt` (composeApp) — wraps `httpGetText` / `httpGetTextWithHeaders` into `fetchAddonResponseText(url, forceRefresh)`.
- `AddonRepository.kt` — `refreshAddon()` / `refreshAll()` now pass `forceRefresh = true`.
- `CatalogData.kt` — dedup key now includes `forceRefresh` (`CatalogFetchKey`), `fetchCatalogPage()` takes `forceRefresh`.
- `CatalogRepository.kt`, `HomeRepository.kt`, `SearchRepository.kt` — thread `forceRefresh` through `load()`/`refresh()`/`search()`/`refreshDiscover()` call chains; `HomeRepository` also drops a stale-cache short-circuit (`completedRequestKey` reuse logic) that was part of the same staleness bug.
- `MetaDetailsRepository.kt`, `PlayerStreamsRepository.kt`, `SubtitleRepository.kt` — switched from `httpGetText` to `fetchAddonResponseText`.

Checked `shared/`: **all of the above files exist in `shared/src/commonMain/kotlin/com/nuvio/app/features/...` and still call the old `httpGetText` directly** (confirmed via grep — no `fetchAddonResponseText` symbol anywhere in `shared/`). So tvOS has the same staleness bug upstream just fixed on mobile: refreshing a catalog/addon on tvOS won't bypass cached responses either.

The port is mechanical and low-risk: `shared/.../addons/AddonPlatform.kt` **already declares** `expect suspend fun httpGetTextWithHeaders(...)` and `shared/.../addons/AddonPlatform.apple.kt` already has the `actual` implementation (ported previously for another reason), so the primitive this fix depends on is already in place — this is purely wiring, not new platform code.

**Suggested action for Claude Code:**
1. Add `shared/src/commonMain/kotlin/com/nuvio/app/features/addons/AddonHttpClient.kt` mirroring upstream's `fetchAddonResponseText(url, forceRefresh)`.
2. Update `AddonRepository.kt`, `CatalogData.kt`, `CatalogRepository.kt`, `HomeRepository.kt`, `SearchRepository.kt`, `MetaDetailsRepository.kt`, `PlayerStreamsRepository.kt`, `SubtitleRepository.kt` in `shared/src/commonMain` to match upstream's `forceRefresh` threading (diff each file against upstream commit `981b8bc7` for the exact signature changes — the shared/ versions have diverged somewhat from composeApp's structure in prior tvOS-specific refactors, so this needs a careful merge, not a blind copy-paste).
3. Wire whatever SwiftUI "pull to refresh" / retry affordances exist on tvOS (home, catalog, search screens) to pass `forceRefresh = true` on manual refresh, `false` on initial/background loads — check `iosApp/NuvioTV/` for the Swift call sites that invoke these repositories' refresh methods.
4. No new UI needed — this is purely a correctness fix for existing refresh actions.

## Action items for Claude Code

1. **[MEDIUM] Port addon cache-control / force-refresh fix** (upstream `981b8bc7`) — see Item 2 above. Real staleness bug affecting tvOS today; the enabling primitive (`httpGetTextWithHeaders`) is already in `shared/`, so this is wiring work, not new infra.
2. **[LOW / decision needed] Subtitle minimum font size** (upstream `d50f84fc`) — see Item 1 above. Don't port mechanically; decide tvOS's own subtitle size floor next time player styling gets attention.
3. **[LOW, carried forward from 08-10]** TMDB Discover exclusion filters (upstream `0fc4616b`) — add `withoutGenres`, `withoutKeywords`, `withoutCompanies`, `withoutWatchProviders` (all `String?`, default `null`) to `TmdbCollectionFilters` in `shared/src/commonMain/kotlin/com/nuvio/app/features/collection/CollectionModels.kt`, wire into `TmdbCollectionSourceResolver.kt`'s TMDB Discover query builder, then design new SwiftUI exclusion controls — tvOS has no dedicated collection-editor screen yet, so this needs new UI, not just a mechanical port. Additive/backward-compatible, no risk to existing collections.

No action needed on `55307c43` (disintegrate animation — Compose-UI-only) or `c861a8ff` (episode spacing — Compose-UI-only, no shared equivalent) or `0d6e30e4` (mobile version bump).

## Addendum — 2026-08-13 (same day): items 1 and 3 ported

Both actionable items landed in `NuvioMobile` on `tvos-shared-extraction` the same day this check ran:

**Cache-control / force-refresh (item 1) — DONE, commit `a040293a`.** Full `shared/` port plus the Android halves this fork's composeApp consumes (OkHttp disk cache in `AddonPlatform.android.kt`, `MainActivity` init, AddonsScreen/SearchScreen forced call sites) and the tvOS Swift side (`StreamsViewModel.reload()` → repository `reload()`, SearchViewModel explicit `forceRefresh: false`). Three deliberate divergences from upstream, documented in the commit: CatalogRepository keeps the fork's detach-healing guard, SearchRepository keeps completed-state reuse for non-forced calls (tvOS re-arms refresh on every screen re-entry), and the streams retry now actually cache-busts.

Notable verification finding: an empirical probe on the tvOS 27 sim (local caching server + the app's real Ktor Darwin client) showed plain addon GETs are **stored in but never served from** NSURLCache — the local-staleness scenario upstream fixed doesn't reproduce on tvOS today. The port still matters: the `Cache-Control: no-cache` header reaches the wire (verified) and instructs addon-server/CDN caches to revalidate, and the wiring is correct if the engine's cache behavior ever changes. No `requestCachePolicy` fallback needed.

Also verified: tvOS shared tests green, NuvioTV sim build clean, Home/Search/Discover smoke on sim (no refetch-storm regression from the `completedRequestKey` removal). Codex review: 3 rounds, 3 findings fixed. Android target not compile-verified locally (no Android SDK on this machine); its changes mirror upstream's shipped commit verbatim.

**TMDB exclusion filters (item 3, carried since 08-10) — shared plumbing DONE, commit `7dac9a67`.** `TmdbCollectionFilters` fields + Discover query-builder wiring + upstream's serialization test (9/9 green on the tvOS sim target). **Remaining on the backlog: the UI half only** — upstream's `CollectionEditorScreen.kt` + strings hunks for the mobile editor, and new tvOS SwiftUI exclusion controls (tvOS has no collection editor yet). Until then the fields are reachable only via imported JSON; additive/default-null, so existing collections are unaffected.

**Subtitle floor (item 2) — unchanged, deliberate no-port** per this doc's Item 1 analysis.

## Next scheduled check

Re-fetch `upstream/cmp-rewrite`, diff past `0d6e30e4`. The cache-control port and TMDB shared plumbing landed 2026-08-13 (`a040293a`, `7dac9a67` — see addendum); the only carried-forward item is now the TMDB exclusion-filter **UI half** (mobile editor hunks from `0fc4616b` + tvOS controls). Also re-verify the subtitle-floor stance if player styling gets a pass.

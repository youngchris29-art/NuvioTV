# Upstream port check — 2026-08-16

## Summary

**Upstream moved for the first time since 2026-08-13.** `upstream/cmp-rewrite` (`NuvioMedia/NuvioMobile`) advanced from `0d6e30e4` to `cc20e716` — 2 new commits, one feature:

```
cc20e716 Merge branch 'feat/discoverep' into cmp-rewrite
ddc28dc8 feat(self-hosted): support for discovery endpoint
```

`upstream/copilot/refactor-project-structure` unchanged (`cbc9fc4f`) — still stale/abandoned. `upstream/simkl` re-checked: still fully merged into `cmp-rewrite` (merge-base == simkl HEAD `e4911b77`), zero unique commits.

Fork state at check time: outer `main` HEAD `2053149` (BUG-39 GIF fix doc + submodule bump), submodule `NuvioMobile` HEAD `85c357f9` on `tvos-shared-extraction`, pinned submodule pointer matches actual HEAD exactly — no drift this run (last run's cosmetic one-commit lag is resolved).

## Verification: did the 2026-08-15 open items land / change?

No — both remain open and unchanged:

1. **Subtitle minimum font size** (upstream `d50f84fc`) — re-checked `shared/src/commonMain/kotlin/com/nuvio/app/features/player/SubtitleAudioModels.kt`: `fontSizeSp: Int = 18` still unbounded. Still deliberate no-port pending a tvOS-specific decision.
2. **TMDB Discover exclusion filters — UI half** (upstream `0fc4616b`) — re-checked. Note: `iosApp/NuvioTV/Screens/CollectionsUI.swift` exists (added in the Phase 5b "collections browse" work), but its own header comment states it's browse-only by design — "Editing stays on mobile." No exclusion-filter controls, no editor. Prior finding stands: `withoutGenres`/`withoutKeywords`/`withoutCompanies`/`withoutWatchProviders` remain wired in the shared query builder but unreachable from tvOS UI.

## New this check: self-hosted server discovery (upstream `ddc28dc8`)

Upstream added a full self-hosting flow for mobile/desktop: a user can point the app at their own Supabase-compatible backend instead of the official `api.nuvio.tv`, discovered via a well-known document.

**How it works upstream:**
- Client hits `<host>/.well-known/nuvio` and expects a JSON document: `{version, service: "nuvio", self_hosted, backend_url, publishable_key, capabilities: {email_password_auth, tv_login}}`.
- `ServerDiscoveryService`/`ServerDiscoveryPolicy` (new, `composeApp/src/commonMain/.../core/network/ServerDiscovery.kt`) validate the document (version, service name, scheme, no credentials-in-URL, size cap 64KB, timeout 15s, rejects the official host, requires `email_password_auth`).
- `ServerConfiguration`/`ServerConfigurationRepository` (new, `ServerConfiguration.kt`) hold the active backend URL + publishable key + capabilities, gated by a new feature flag `AppFeaturePolicy.customServerConnectionsEnabled` (on for `iosFull`/mobile-full builds).
- `SupabaseProvider.client` changed from a `by lazy val` to a re-creatable cached client (`reset()` added) so switching servers rebuilds the Supabase client against the new backend.
- `AuthRepository` gained `prepareForServerSwitch()` (clears anonymous id + session) and `reinitialize()` (restarts session-status collection against the new client).
- New UI: `ServerConnectionController.kt` (state machine: discover → review → connect/switch, with typed failure reasons) + `ServerConnectionDialogs.kt` (501 lines of Compose UI) + `AuthScreen.kt` changes to surface a "connect to a different server" entry point.
- Platform storage actuals added for Android/iOS/desktop (`ServerConfigurationStorage.{android,ios,desktop}.kt`) — the iOS one is a thin `NSUserDefaults` wrapper (7 keys, get/set/clear), no UIKit/Compose dependency.

**Where it touched:** entirely under `composeApp/` (Compose Multiplatform UI + composeApp-local business logic). **Zero changes to `shared/`.** Per this repo's own layout (`shared/` = Compose-free logic ported from upstream; `composeApp/` = mobile/desktop Compose UI, not used by tvOS), this is not a mechanical port — there's no shared/ diff to apply.

**tvOS's current state:** confirmed via grep — no `ServerConfiguration`, `customServerConnectionsEnabled`, or `api.nuvio.tv` override concept anywhere in `iosApp/NuvioTV/` or `shared/`. tvOS's own `shared/src/commonMain/.../core/network/SupabaseProvider.kt` and `SupabaseEndpointConfig.kt` (fork-native, extracted during `tvos-shared-extraction`) hardcode to `SupabaseConfig.URL` with a primary/fallback pair only — no user-switchable backend at all. `iosApp/NuvioTV/Screens/AuthViewModel.swift` has no server-selection concept.

**Assessment: [MEDIUM, product decision needed, not a mechanical port].** This is a real capability gap, not a cosmetic one — if a user self-hosts their own Nuvio backend, the tvOS app currently cannot connect to it at all, while mobile now can. But porting it means designing new tvOS-native UX (a 10-foot remote-friendly "connect to a self-hosted server" flow), not copying a diff. Recommend Christian decide whether self-hosted server support is in scope for tvOS before any implementation starts — this is a new user-facing feature question, not a bugfix.

## Action items for Claude Code

1. **[MEDIUM / decision needed] Self-hosted server discovery** (upstream `ddc28dc8`). If Christian confirms tvOS should support this:
   - Port the pure-domain pieces into `shared/src/commonMain/kotlin/com/nuvio/app/core/network/`: `ServerConfiguration.kt` and `ServerDiscovery.kt` are Compose-free and near-copy-pastable (only dependency is `httpRequestRaw` from `composeApp/features/addons` — check whether an equivalent already exists in `shared/`, e.g. alongside the addon HTTP layer, before assuming a straight copy).
   - Add a `tvosMain` actual for `ServerConfigurationStorage` — upstream's `ServerConfigurationStorage.ios.kt` is a 7-key `NSUserDefaults` wrapper with no UIKit/Compose dependency, directly adaptable (`shared/build.gradle.kts` already declares a `tvosMain` source set at line ~331, same pattern used for the quickjs-kt tvOS actual).
   - Update `shared/.../SupabaseProvider.kt` to mirror the cached-client + `reset()` pattern, and thread `ServerConfigurationRepository.active` through instead of the hardcoded `SupabaseConfig.URL`/`SupabaseConfig.ANON_KEY` pair (careful: fork's `SupabaseProvider.kt` already has fallback-URL retry logic from the earlier cache-control port — merge, don't overwrite).
   - Extend `AuthRepository`-equivalent logic (wherever tvOS's shared auth state lives) with `prepareForServerSwitch()`/`reinitialize()` equivalents.
   - Design new SwiftUI screens for `iosApp/NuvioTV/Screens/AuthView.swift` — a remote-friendly custom-server entry point (no direct SwiftUI reference exists; upstream's `ServerConnectionDialogs.kt` is Compose-only and not portable as layout, only as a state-machine reference via `ServerConnectionController.kt`).
   - No urgency — flag to Christian for a scope decision before scheduling implementation.

2. **[LOW / decision needed, carried forward] Subtitle minimum font size** (upstream `d50f84fc`) — decide tvOS's own `subtitleFontSizeRangeSp`-equivalent (likely a larger floor than mobile's 6sp, not smaller) next time player styling gets attention. Touch `iosApp/NuvioTV/Screens/SubtitleVTT.swift`.

3. **[LOW, carried forward] TMDB Discover exclusion filters — UI half** (upstream `0fc4616b`) — design new tvOS SwiftUI exclusion controls (no existing collection-editor screen to extend — `CollectionsUI.swift` is browse-only by design) for `withoutGenres`/`withoutKeywords`/`withoutCompanies`/`withoutWatchProviders`, already wired into the shared query builder (`7dac9a67`).

## Next scheduled check

Re-fetch `upstream/cmp-rewrite`, diff past `cc20e716`. Backlog: self-hosted server discovery (item 1, needs Christian's scope decision), subtitle-floor decision (item 2), TMDB exclusion-filter UI half (item 3). Item 1 is new and the highest-value of the three but still not urgent — no existing tvOS user is blocked, this only matters to self-hosters, and there are apparently none yet on tvOS.

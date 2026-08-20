# Addendum — 2026-08-19: self-hosted discovery + TMDB exclusion-filter UI BUILT

Christian's direction ("implement both") executed the same day. The two open decision items from
the daily plan docs are now code (beta.13 Waves 11/12 — full record in `docs/beta13-release-plan.md`
and `docs/research/beta13-campaign-notes.md`).

## Self-hosted server discovery (upstream `ddc28dc8`/`cc20e716`)

Ported into `shared/` — NOT composeApp like upstream, because this fork's extraction means one port
serves the native tvOS app AND the fork's composeApp:

- `shared/.../core/network/ServerConfiguration.kt` — upstream verbatim + fork additions
  `tvLoginWebBaseUrl` (`<backend>/tv-login` for custom servers — the derivation NuvioMedia/NuvioTV
  uses; the discovery document has no URL field) and `displayHost`. Gate reads
  `FeaturePolicyProvider.policy.customServerConnectionsEnabled` at call time.
- `ServerConfigurationStorage` expect + apple/android actuals (NSUserDefaults `server_*` keys /
  SharedPreferences `server_configuration`). Fork: the load guard is TV-lenient — a server
  advertising `tv_login` alone is valid (upstream requires `email_password_auth`).
- `ServerDiscovery.kt` — upstream verbatim + `ServerAuthRequirement` enum; the tvOS installer sets
  `EmailPasswordOrTvLogin` (matches the official Android TV app's `NO_SUPPORTED_AUTH` semantics).
- `SupabaseProvider` cached client + `reset()`; `SupabaseEndpointConfig` getters;
  `NetworkStatusRepository` publishable-key probe — **plus a fork fix beyond upstream** (Codex):
  a reachable backend now wins over a failed public-internet probe, so a LAN-only self-hosted
  server isn't misclassified as NoInternet.
- `AuthRepository.prepareForServerSwitch()` — fork divergence: runs the FULL
  `AccountDataCleanerProvider.cleaner.wipe()` (upstream only clears the session); nothing from
  server A may sync into server B. `reinitialize()` cancels BOTH fork jobs (session collector +
  restore watchdog) and resets `sessionRestoreTimedOut`.
- `ServerConnectionController` in shared `features/auth` (same package as upstream so composeApp's
  AuthScreen resolves it unqualified): switch = cancel TvLogin → `SyncManager.cancelAccountSync()`
  → prepare → save → `SupabaseProvider.reset()` → `reinitialize()` →
  `ProfileSettingsSync.startObserving()` (re-arm) → network refresh.
- `TvLoginRepository` — redirect base from the active server; `unsupportedByServer` UI state when
  the server lacks `tv_login`.
- tvOS UI: `ServerConnectionView(+Model)` (ENTER → REVIEW with the Android-TV trust warning →
  `.alert` confirm), Welcome gets a "Connect to a Server" button + an email-primary layout when
  the server lacks tv_login, QR caption derives from the flow's web URL, Settings › Account &
  Services gains a Server section (info row / connect / Use Official Server).
- composeApp parity: upstream `ServerConnectionDialogs.kt` verbatim, AuthScreen hunks, 40
  `server_*` strings, `AppFeaturePolicy.customServerConnectionsEnabled` (5 actuals),
  `MainActivity` storage init. Android not compile-verified locally (no SDK — precedent `a040293a`).

## TMDB Discover exclusion filters — UI half (upstream `0fc4616b`)

- Mobile: upstream editor + strings hunks applied verbatim (`git apply` clean); the 12 keys'
  Arabic + Hungarian translations cherry-picked from upstream (`f4f09927`/`0277acad`).
- tvOS (new design, no upstream equivalent): shared `TmdbSourceFilterEditor` — a Swift-friendly
  string-field draft editor for an EXISTING tmdb source (upstream's editor is add-only), with
  validation, identity-based save (survives concurrent pulls reordering sources — Codex), and
  push via `CollectionSyncService` (whose `startObserving()` now runs on tvOS — previously
  pull-only). `TmdbFilterEditorView` behind an **Edit Filters** button on the collection folder
  grid (DISCOVER/COMPANY/NETWORK sources), quick chips from shared `TmdbFilterPresets`, live
  TMDB genre names when a key is set.

## Verification

- `:shared:tvosSimulatorArm64Test` 423/423 (+45 new); `:composeApp:iosSimulatorArm64Test` 412/412;
  `:shared:compileKotlinIosSimulatorArm64` + `:composeApp:compileKotlinIosSimulatorArm64`
  (appstore + full flavors) green; NuvioTV Debug sim build green.
- UI: `test35ServerDiscoveryReview` green on the signed-in sim (loopback stub, non-destructive);
  `ScratchServerSwitchTests` 90a/90b/90c each solo-green on fresh scratch clones (destructive,
  env-gated). Codex review: 2 rounds, 3 findings round 1 (all fixed: LAN-server NoInternet
  misclassification, filter-save source identity, UI-test order dependence), round 2 see
  campaign notes.
- Localization: ~120 new tvOS strings at full fr/es/de/it/vi parity (0 missing).
- ⚠️ The signed-in 26.5 sim lost its session during scratch testing (sign-out on a clone revokes
  the shared server-side session) — needs a one-time QR re-sign-in.

## Remaining decision item

Only the subtitle minimum font size (`d50f84fc`) stays open — unchanged recommendation.

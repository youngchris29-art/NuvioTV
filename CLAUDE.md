# Nuvio tvOS — Claude Code project notes

## Upstream sync status (auto-checked daily against NuvioMedia/NuvioMobile)

A scheduled task diffs this fork's `NuvioMobile` submodule (`upstream` remote = `github.com/NuvioMedia/NuvioMobile`, branch `cmp-rewrite`) against upstream daily and logs actionable ports to `docs/upstream-port-plan-YYYY-MM-DD.md`. Latest run: **2026-08-21**, see `docs/upstream-port-plan-2026-08-21.md`. Upstream held flat at `291b09b7` (no new commits since 2026-08-20) — nothing new to port. SDH subtitle stripping (below) is now **verified landed** by reading actual file contents on `claude/beta14` HEAD; it's off the open-items list.

**Current open action items:**

- **[MEDIUM, PARKED by product decision 2026-08-20] Supporter perks v1** (upstream `bd88760e`). Mobile monetization feature — membership tiers, theme accents, custom profile backgrounds, "Support Nuvio" entry point. Entirely in `composeApp/`, nothing in `shared/` — not a mechanical port. Christian decided to park it as a backlog item: build nothing until it's re-raised; zero drift risk by waiting.
- **[LOW, DEFERRED by product decision 2026-08-20] Subtitle minimum font size** (upstream commit `d50f84fc`). Upstream lowers the iOS mobile subtitle-size floor from 12sp to 6sp. tvOS uses a different native subtitle renderer (`iosApp/NuvioTV/Screens/SubtitleVTT.swift`, not the KMP `PlayerEngine.ios.kt` this fix touches), and 10-foot UI arguably wants a *larger* minimum, not smaller. Don't port as-is — decide tvOS's own range next time player styling gets a pass.
- **[IN FLIGHT 2026-08-21] Trailer Location (FEAT-25 round one)** — poster-vs-hero playback option built on NuvioMobile `claude/trailer-playback-location` (`6b84fbe8`, off beta.14 head `dcd84a69`); sim-build CI + Mac Codex gate + device pass owed before the pointer bump. See `docs/trailer-playback-location-plan.md`.

**Built 2026-08-20 (beta.13.5 batch, in progress):** **SDH subtitle stripping** (upstream `87585259`..`1cc1b768`, PR #1751) — ported end-to-end with full upstream parity: `SubtitleSdhFilter` into `shared/` commonMain (+ unit test), `stripSdh` through `SubtitleStyleState`/`PlayerSettingsStorage` (apple + android actuals, sync payload)/`PlayerSettingsRepository`, tvOS `MPVPlayerView.applySubtitleStyle()` `sub-filter-sdh(-harder)` properties, `PlaybackSettingsPane` toggle + xcstrings, and the composeApp mobile half (PlaybackSettingsPage toggle, strings.xml, `PlayerEngine.android.kt` cue filtering) applied from upstream. Also new (fork-own, GitHub issue #2): addon stream `proxyHeaders` threading into the tvOS players (upstream mobile had it via `MPVPlayerBridge` `http-header-fields`; tvOS dropped headers entirely).

**Resolved earlier (kept for the daily check's diffing):**
- **Self-hosted server discovery** and **TMDB Discover exclusion filters UI half** — both shipped in beta.13 (see "Built 2026-08-19" below); the daily check should no longer list them as open.

**Built 2026-08-19 (beta.13 Waves 11/12; see `docs/beta13-release-plan.md`):** the other two decision items. **Self-hosted server discovery** (upstream `ddc28dc8`/`cc20e716`) — domain ported into `shared/` (ServerConfiguration/Discovery/Storage, cached SupabaseProvider + reset, AuthRepository prepareForServerSwitch/reinitialize, ServerConnectionController in shared `features/auth`), tvOS SwiftUI flow (ServerConnectionView, Welcome + Settings entry points, QR gating on `tv_login`, `<backend>/tv-login` redirect base like NuvioMedia/NuvioTV) and composeApp parity (upstream dialogs/AuthScreen/strings verbatim). **TMDB Discover exclusion filters — UI half** (upstream `0fc4616b`) — mobile editor hunks applied verbatim (+ar/hu translations), plus a tvOS-native filter editor (shared `TmdbSourceFilterEditor` + `TmdbFilterEditorView` behind Edit Filters on collection folder grids) and `CollectionSyncService.startObserving()` on tvOS so edits push.

**Ported 2026-08-13:** addon cache-control / force-refresh (upstream `981b8bc7` → fork `a040293a`, incl. Android OkHttp cache + Compose call sites this fork's composeApp consumes, and tvOS Swift wiring) and TMDB exclusion-filter shared plumbing (upstream `0fc4616b` → fork `7dac9a67`). See the addendum in `docs/upstream-port-plan-2026-08-13.md` — including the empirical finding that tvOS's Ktor Darwin client never *serves* from NSURLCache (the header still matters for CDN/addon-server caches), and the three deliberate fork divergences kept in the cache-control port.

**Ported by 2026-08-19 (as part of the fork's own beta.13 work, outer commit `50af095`):** Simkl anime library filtering (upstream `96618a86` — `mediaCategory` field added to `LibraryModels.kt`/`SimklLibraryProjection.kt`/`LibraryDisplaySettings.kt`), PIN-verify-refreshes-profile-first (upstream `5327166f` — `ProfileRepository.kt` `verifyPin()` now calls `pullProfiles()` before `rememberVerifiedPin()`), and `shared/AppLanguage.kt` `ARABIC` entry (upstream `3c0ab547`). All three verified landed by reading current file contents, not just trusting commit messages — see `docs/upstream-port-plan-2026-08-19.md`.

As of 2026-08-19, `upstream/cmp-rewrite` has **not moved** since 2026-08-17 — still pinned at `bbac53b2`, zero new commits two checks in a row. `upstream/copilot/refactor-project-structure` remains stale/abandoned, and the `upstream/simkl` ref has been deleted from the remote (it was already fully merged into `cmp-rewrite` with zero unique commits, so this is harmless). Submodule pointer drift from prior runs remains resolved — pinned pointer matches actual HEAD (`5cb2f8b9`).

For full day-by-day history of what's been checked and what landed, see `docs/upstream-port-plan-*.md` (2026-07-25 onward) — each file's "Verification" section confirms whether prior items landed.

## Repo layout

- Outer repo (this folder) = fork wrapper: docs, scaffolding, design assets, the `NuvioMobile` submodule.
- `NuvioMobile/` = the actual KMP + native tvOS app (submodule, tracks `tvos-shared-extraction` branch on `origin` = `youngchris29-art/NuvioMobile`).
- `NuvioMobile/shared/` = Compose-free Kotlin business logic shared across platforms — this is what upstream ports land in.
- `NuvioMobile/iosApp/NuvioTV/` = native SwiftUI tvOS frontend.

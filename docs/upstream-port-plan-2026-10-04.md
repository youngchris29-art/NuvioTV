# Upstream port plan — 2026-10-04

Daily check of `NuvioMedia/NuvioMobile` (`cmp-rewrite`) vs the fork's `NuvioMobile` submodule (`tvos-shared-extraction`).

Upstream moved: `7be1b56c` → `966a52b9`. 7 commits (4 real feature/fix, 2 merges, 1 i18n-heavy feature). Only ONE touches code that tvOS shares (`shared/`-equivalent `CustomPosterUrlResolver.kt`).

**Headline: one small, recommended port (LOW–MED, shared Kotlin). Nothing blocking.**

## Port 1 [LOW–MED, recommended] — Custom poster pattern URL validation + percent-decoding

Upstream `6ce99ef2` (skoruppa, merged via PR #2153): `CustomPosterUrlResolver.resolve()` now
1. decodes `%7B` `%7D` `%7C` (case-insensitive) back to `{` `}` `|` before resolving, so patterns pasted/synced URL-encoded still work;
2. returns `null` early if the decoded pattern contains no placeholder (regex `\{[a-z_]+[|?]?`), instead of treating a plain URL as a pattern;
3. passes the decoded pattern to both the RPDB-family and generic resolvers.

Fork status (verified): `NuvioMobile/shared/src/commonMain/kotlin/com/nuvio/app/core/poster/CustomPosterUrlResolver.kt` `resolve()` (line ~51-58) still has the OLD logic (`isRpdbFamily(pattern)` on the raw pattern; no decode, no placeholder check). tvOS uses this resolver for Home/Library custom posters (HomeModels, LibraryModels, ProfileSettingsSync).

Plan for Claude Code (branch off `tvos-shared-extraction`):
1. In `shared/.../CustomPosterUrlResolver.kt` apply upstream diff: in `resolve()` add `val decoded = decodePatternPlaceholders(pattern); if (!containsPlaceholder(decoded)) return null`, use `decoded` for `isRpdbFamily` / `resolveRpdbWithFallback` / `resolvePattern`; add private helpers `containsPlaceholder` and `decodePatternPlaceholders` (exact code: `git -C NuvioMobile show 6ce99ef2`).
2. Add tests to `shared/src/commonTest/.../CustomPosterUrlResolverTest.kt`: encoded `%7Bimdb_id%7D` resolves same as `{imdb_id}`; plain URL w/o placeholder → null; RPDB pattern still resolves + fallback.
3. Check callers don't rely on non-placeholder URLs resolving (grep `CustomPosterUrlResolver.resolve` in shared + `iosApp/NuvioTV`); if a "static URL" mode exists, make sure it is not routed through `resolve()`.
4. Gates: shared Kotlin tests (apple/common), rebuild XCFramework per CLAUDE.md, NuvioTVTests, Debug sim build. Device-check not required (pure logic).

Effort: ~30–45 min.

## Not applicable / already covered on tvOS

- `d3786272` "switch player + stream info actions" (#2161/#2168): Android ExoPlayer↔libmpv switch (`SwitchHoriz`) and a new Compose `StreamInfoOverlay` fed by mpv properties (`PlayerMediaInfo`, iOS `getProperty` bridge). tvOS has its own native engine router (`PlayerEngineRouter`) and an existing Stream Info overlay (`StreamInfoSnapshot`, `MPVPlayerView` ~L1118). Optional inspiration only: confirm our overlay shows video fps/bitrate, audio channels/sample rate (upstream's field set: codec, WxH, fps, video bitrate, audio codec/channels/sample rate). Not needed.
- `909dd7dc`, `459add64` (#2148): refresh button spins until addons finish loading (Compose `ProviderFilterRow`, player panels). tvOS `StreamPickerView`/`StreamsViewModel` are native SwiftUI; optional polish: if the tvOS refresh control doesn't show in-progress state while addons load, add a spinner. LOW, cosmetic.
- `53ac5e53` (#2160): system-brightness follow when touch gestures off — Android/iOS touch brightness; tvOS has no brightness control.
- Strings (19 lines × ~25 locales) for the above: tvOS is English-only; no action.
- Merges `e3cb1590`, `966a52b9`: no code.

## Suggested execution order

1. Port 1 (poster resolver) — independent of the Detail/Settings revamp; safe to do anytime.
2. (Carried, optional LOW) 2026-10-03 auto-skip toast — see `docs/upstream-port-plan-2026-10-03.md`.

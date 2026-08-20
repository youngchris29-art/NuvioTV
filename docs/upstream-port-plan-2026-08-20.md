# Upstream port check — 2026-08-20

## Summary

`upstream/cmp-rewrite` (`NuvioMedia/NuvioMobile`) **moved for the first time since 2026-08-17**: `bbac53b2` → `291b09b7`, 9 new commits, plus a new `0.4.7` tag. `upstream/copilot/refactor-project-structure` still stale/abandoned. `upstream/simkl` remains deleted from the remote (harmless, already fully merged).

Fork state at check time: outer `main` HEAD `22b790e`, submodule `NuvioMobile` HEAD `9a83122f` on `tvos-shared-extraction`, pinned pointer matches actual HEAD — no drift.

The 9 new upstream commits break into two unrelated pieces of work:

1. **SDH subtitle stripping** (`87585259`..`1cc1b768`, PR #1751) — a real, mechanical, low-risk port candidate. Details below.
2. **Supporter perks v1** (`bd88760e`/`38e6ea28`) — a mobile monetization feature (membership tiers, theme accents, custom profile backgrounds, donate/support UI). Entirely under `composeApp/` (Compose UI + Android/iOS mobile membership storage), nothing in `shared/`. Not a mechanical port — it's a product-scope decision (add a tvOS "Support Nuvio" experience or skip it), same category as the self-hosted-discovery and TMDB-filter-UI decision items already on file. Logged as a new decision item, not queued for automatic work.

Plus two trivial housekeeping commits (`291b09b7` README rewrite, `84246226` version bump to match `0.4.7`) — no action needed on either.

## Item 1: SDH subtitle stripping — ACTIONABLE

Upstream adds a "Strip SDH Subtitles" toggle (SDH = Subtitles for the Deaf and Hard-of-hearing) that filters non-dialogue text out of subtitle lines: bracketed sound cues (`[MUSIC PLAYING]`), parenthetical asides (`(laughs)`), and speaker labels (`JOHN:`). Implementation:

- New file `composeApp/src/commonMain/kotlin/com/nuvio/app/features/player/SubtitleSdhFilter.kt` — three regexes (speaker label, square brackets, parentheses), pure string transform, no dependencies. Trivially portable as-is.
- `SubtitleAudioModels.kt` (upstream, mobile) → fork equivalent is `shared/src/commonMain/kotlin/com/nuvio/app/features/player/SubtitleAudioModels.kt`: add `val stripSdh: Boolean = false` to `SubtitleStyleState`, right after `bottomOffset`.
- `PlayerSettingsStorage.kt` (fork: `shared/src/commonMain/.../PlayerSettingsStorage.kt`, `expect object`) — add `loadSubtitleStripSdh(): Boolean?` / `saveSubtitleStripSdh(enabled: Boolean)` next to the existing `loadSubtitleBottomOffset`/`saveSubtitleBottomOffset` pair (line ~48-49).
- `PlayerSettingsStorage.apple.kt` (fork: `shared/src/appleMain/.../PlayerSettingsStorage.apple.kt`) — add the `actual` implementations next to `loadSubtitleBottomOffset`/`saveSubtitleBottomOffset` (~line 431-441), following the same `loadBoolean`/`saveBoolean` pattern already used for `subtitleUseForcedSubtitlesKey` (~line 445-447). Also wire it into the settings-sync payload encode/decode block (~line 933-934 write, ~1008-1009 read) so it round-trips through cross-device sync like every other subtitle style field.
- `PlayerSettingsRepository.kt` (fork: `shared/src/commonMain/.../PlayerSettingsRepository.kt`) — read `stripSdh` into the loaded `SubtitleStyleState` (~line 277-280, next to `bottomOffset`/`useForcedSubtitles`) and persist it in the save path (~line 511-512).
- **tvOS native player wiring — this is the part that diverges from upstream's approach, in a good way.** Upstream's Android path had to intercept ExoPlayer's `TextOutput`/`Cue` pipeline and run `SubtitleSdhFilter.filter()` per-cue (`PlayerEngine.android.kt`). Upstream's mobile iOS path went a different, simpler route: `MPVPlayerBridge.swift` just sets two libmpv properties, `sub-filter-sdh` and `sub-filter-sdh-harder`, and lets mpv's own SDH filter do the work — no Kotlin-side cue filtering needed at all for the MPV/iOS path. **tvOS already uses MPV directly** via `iosApp/NuvioTV/Screens/MPVPlayerView.swift`, with its own hand-rolled `applySubtitleStyle()` (~line 699-713) that mirrors the Android property formulas but talks to mpv directly — it does not go through `PlayerEngine.ios.kt` or `MPVPlayerBridge.swift` at all (those are mobile-only). So the tvOS port is just: add `setMpvString("sub-filter-sdh", style.stripSdh ? "yes" : "no")` and the matching `sub-filter-sdh-harder` call inside `applySubtitleStyle()`, next to the existing `sub-pos` line (~line 712). No ExoPlayer-style cue interception needed.
- **Settings UI** — upstream added a `SettingsSwitchRow` in `PlaybackSettingsPage.kt` (Compose, mobile-only, not portable). tvOS equivalent: `iosApp/NuvioTV/Screens/Settings/PlaybackSettingsPane.swift` already has a "Subtitles" section (`settingsSection("Subtitles")`, ~line 100) with `SubtitleAppearanceControls`; add a toggle there following the same pattern as the existing "Use Forced Subtitles" row. `SettingsViewModel.swift` needs a new `setSubtitleStripSdh(_ enabled: Bool)` method mirroring `setSubtitleBold`/`setSubtitleOutline` (~line 361-370) — note those methods currently construct `SubtitleStyleState(...)` positionally with every field spelled out, so adding `stripSdh` to the shared model means updating the constructor call in **every** one of those setter methods (`setSubtitleTextColor`, `setSubtitleFontSize`, `setSubtitleBackground`, `setSubtitleBold`, `setSubtitleOutline`, and any others in that file using the same pattern), not just the new one.
- Suggested string: mirror upstream's copy — "Strip SDH Subtitles" / "Hide sound descriptions and speaker labels from text subtitles."
- Upstream also removed its own unit test for the filter in a later commit (`1397cb6b` "Clean up SDH subtitle stripping changes") — worth adding a lightweight test for `SubtitleSdhFilter` in the fork's shared test source set instead, since it's pure string logic with no platform dependency and cheap to verify.

Risk: low. Additive field with a default (`false`), no changes to existing behavior when off, mpv-side filtering is a well-supported upstream mpv feature (not custom regex work on the render path for the tvOS case).

## Item 2: Supporter perks v1 — DECISION NEEDED, not queued

Upstream commit `bd88760e` (squash-merged as `38e6ea28`) adds: membership tiers (`MemberAccess`, `MemberAccessRepository`, `MemberAccessRemoteDataSource`), custom theme accents (`ThemeAccent.kt`, gold/jade/rose-gold/arctic-blue/graphite), custom profile backgrounds sourced from a member's asset storage, a gold wordmark app icon variant, a "Support Nuvio" settings entry point, and Android/iOS-specific `MemberAssetStorage` platform actuals. All of it lives under `composeApp/` — none of it touches `shared/`. This is a monetization/product feature, not a bug fix or shared-logic addition, so there's no mechanical diff to port. If Christian wants a tvOS equivalent (a "Support Nuvio" screen, theme accents, custom profile backgrounds gated on membership), that's new SwiftUI design work, not a port — parking it as a backlog decision item alongside the two below rather than building anything now.

## Carried over from 2026-08-19 (still open, unchanged)

1. **[MEDIUM, needs a product decision] Self-hosted server discovery** (upstream `ddc28dc8`/`cc20e716`). Still not ported — `SupabaseProvider.kt` still hardcoded to the official backend. See `docs/upstream-port-plan-2026-08-16.md` for the full plan.
2. **[LOW, needs a product decision] Subtitle minimum font size** (upstream `d50f84fc`). tvOS's native renderer is a different code path from the one upstream touched — still needs its own floor decided, not a straight port.
3. **[LOW, new UI needed] TMDB Discover exclusion filters — UI half** (upstream `0fc4616b`). Shared plumbing already ported; still no dedicated collection-editor screen on tvOS beyond the existing `TmdbSourceFilterEditor`.

## Action items for Claude Code

1. **Port SDH subtitle stripping to tvOS (Item 1 above)** — mechanical, low-risk, ready to implement. Touches: `shared/src/commonMain/.../SubtitleAudioModels.kt`, `PlayerSettingsStorage.kt`, `PlayerSettingsRepository.kt`; `shared/src/appleMain/.../PlayerSettingsStorage.apple.kt`; `iosApp/NuvioTV/Screens/MPVPlayerView.swift` (`applySubtitleStyle()`); `iosApp/NuvioTV/Screens/SettingsViewModel.swift` (new setter + update existing `SubtitleStyleState(...)` call sites); `iosApp/NuvioTV/Screens/Settings/PlaybackSettingsPane.swift` (new toggle row). See exact line references above.
2. Decide whether tvOS wants any version of Supporter Perks (Item 2) — no urgency, purely additive on upstream's side, zero risk of drift/conflict by waiting.
3. Items 1-3 carried from 2026-08-19 remain open, no change in status.

## Next scheduled check

Re-fetch `upstream/cmp-rewrite`, diff past `291b09b7`. If Item 1 (SDH stripping) has been ported by then, verify by reading actual file contents (not commit messages) per the usual practice.

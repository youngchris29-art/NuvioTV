# Upstream port check — 2026-08-18

## Summary

`upstream/cmp-rewrite` (`NuvioMedia/NuvioMobile`) advanced from `d2db97a9` to `bbac53b2` — 5 substantive commits (+2 merges):

```
0277acad Update Hungarian localization (values-hu/strings.xml, +158 lines)
49a7bd7f fix: persist Android offline PIN cache synchronously (apply() -> commit())
96618a86 Simkl: let anime be a separate type
5327166f fix: refresh profile before caching verified PIN
bbac53b2 bump version (iosApp/Configuration/Version.xcconfig)
```

`upstream/copilot/refactor-project-structure` unchanged — still stale/abandoned. `upstream/simkl` re-checked: still fully merged into `cmp-rewrite`, zero unique commits.

Fork state at check time: outer `main` HEAD `55f3d570` (mpv swipe-down panel docs), submodule `NuvioMobile` HEAD `7e617934` on `tvos-shared-extraction`, pinned pointer matches actual HEAD — no drift.

## Verification: did the 2026-08-17 open items land / change?

No — all four remain open and unchanged (none of today's commits touch the relevant files):

1. **Self-hosted server discovery** (upstream `ddc28dc8`) — still MEDIUM, still a product-decision item.
2. **Subtitle minimum font size** (upstream `d50f84fc`) — `shared/.../SubtitleAudioModels.kt` still unbounded `fontSizeSp: Int = 18`. Unchanged.
3. **TMDB Discover exclusion filters — UI half** (upstream `0fc4616b`) — `CollectionsUI.swift` still browse-only by design. Unchanged.
4. **`shared/AppLanguage.kt` missing `ARABIC`** (upstream `3c0ab547`) — still missing. Unchanged.

## New this check: two real, actionable gaps in `shared/`

Unlike the last several days (which were composeApp-resource-only or Android-`actual`-only), **two of today's five commits land in code this fork's `tvos-shared-extraction` already promoted into `shared/commonMain`**, meaning tvOS's native SwiftUI frontend consumes this logic through KMP. Both are real gaps, not "no action" items.

### 1. Simkl anime library filtering is stale (upstream `96618a86`) — actionable, mechanical

Upstream fixed Simkl library filtering so anime is tagged with its own `mediaCategory` rather than being folded into "movie"/"series" `type`, which was causing anime titles to disappear from (or wrongly populate) the movie/series filter tabs. Three-file change:

- `LibraryModels.kt` — `LibraryItem` gains `val mediaCategory: String? = null` (kept separate from `type` so meta-addon lookups by type still work).
- `SimklLibraryProjection.kt` — `toLibraryItem()` now sets `mediaCategory = "anime"` when `mediaType == SimklMediaType.ANIME`.
- `LibraryDisplaySettings.kt` — the type-filter logic in `buildLibraryVerticalProjection()` switches from `entry.item.type.normalizedLibraryType()` to `(entry.item.mediaCategory ?: entry.item.type).normalizedLibraryType()` in both the `availableTypes` computation and the `filteredEntries` predicate.

Verified against the fork: `shared/src/commonMain/kotlin/com/nuvio/app/features/library/LibraryModels.kt`, `shared/.../simkl/SimklLibraryProjection.kt`, and `shared/.../library/LibraryDisplaySettings.kt` all still have the pre-fix code — this fork's shared/ twins were extracted before this upstream fix landed. tvOS's `LibraryView.swift`/`LibraryViewModel.swift` and `CloudLibraryUI.swift` consume `LibraryItem` from this exact shared module, so tvOS inherits the same anime-filtering bug upstream just fixed.

**Priority: LOW-MEDIUM.** Not a crash or data-loss bug, but a real UX correctness issue for anyone using Simkl sync with anime titles on tvOS today.

### 2. PIN verify doesn't refresh profile first (upstream `5327166f`) — actionable, trivial, one line

Upstream's `verifyPin()` now calls `pullProfiles()` before `rememberVerifiedPin()` when the RPC reports `unlocked = true`, so the locally cached profile is refreshed before the verified-PIN cache is written (guards against caching a PIN against a stale profile record if the profile changed server-side since last pull).

Verified against the fork: `shared/src/commonMain/kotlin/com/nuvio/app/features/profiles/ProfileRepository.kt` `verifyPin()` (line ~251) still lacks the `pullProfiles()` call — same shape as upstream's pre-fix code. The fork already has a `pullProfiles()` function (line 92) to call.

**Priority: LOW.** Narrow race-condition-adjacent correctness fix, one-line port.

## Confirmed no-action items (checked, not just assumed)

- **Hungarian localization** (`0277acad`) — `composeApp/.../values-hu/strings.xml` only, +158 lines to an already-existing locale (not a new `AppLanguage` entry — confirmed `HUNGARIAN("hu")` already exists in fork's `shared/AppLanguage.kt`). Same pattern as Arabic/Bulgarian: composeApp Compose-resource infrastructure tvOS doesn't use.
- **Android PIN cache synchronous persist** (`49a7bd7f`) — `composeApp/src/androidMain/.../ProfilePinCacheStorage.android.kt` swaps `SharedPreferences.apply()` for `.commit()` to force synchronous writes (Android-specific async-write footgun). Checked the fork's Apple twin, `shared/src/appleMain/.../ProfilePinCacheStorage.apple.kt`: it calls `NSUserDefaults.setObject`/`removeObjectForKey` directly with no `apply()`/`commit()`-style split — the underlying bug class doesn't exist on this API surface. No action.
- **Version bump** (`bbac53b2`) — upstream's own mobile release versioning (`iosApp/Configuration/Version.xcconfig`). This fork maintains its own independent version scheme (`tvos-v0.3.0-beta.11-...`), not synced to upstream's release cadence.

## Action items for Claude Code

1. **[LOW-MEDIUM, mechanical, ~3-file port] Port Simkl anime-as-separate-type fix into `shared/`.** In `NuvioMobile/shared/src/commonMain/kotlin/com/nuvio/app/features/library/LibraryModels.kt`, add `val mediaCategory: String? = null` to `LibraryItem` (with upstream's doc comment: kept separate from `type` for meta-addon compatibility). In `NuvioMobile/shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklLibraryProjection.kt`, set `mediaCategory = if (mediaType == SimklMediaType.ANIME) "anime" else null` in `toLibraryItem()`. In `NuvioMobile/shared/src/commonMain/kotlin/com/nuvio/app/features/library/LibraryDisplaySettings.kt`, change both filter-type lookups in `buildLibraryVerticalProjection()` from `entry.item.type.normalizedLibraryType()` to `(entry.item.mediaCategory ?: entry.item.type).normalizedLibraryType()`. Reference upstream commit `96618a86` for exact diff shape. After porting, spot-check tvOS's `LibraryView.swift` filter tabs still compile/behave against the widened `LibraryItem` (Swift side should be unaffected — it's an additive optional field surfaced through KMP interop).
2. **[LOW, one-line, trivial] Port PIN-verify-refreshes-profile-first fix.** In `NuvioMobile/shared/src/commonMain/kotlin/com/nuvio/app/features/profiles/ProfileRepository.kt`, in `verifyPin()` (~line 260), add `pullProfiles()` as the first statement inside `if (verifyResult.unlocked) { ... }`, before the existing `rememberVerifiedPin(...)` call. Reference upstream commit `5327166f`.
3. **[MEDIUM / decision needed, carried forward] Self-hosted server discovery** (upstream `ddc28dc8`) — see 2026-08-16 doc for the full port plan. Still awaiting Christian's scope decision.
4. **[LOW / decision needed, carried forward] Subtitle minimum font size** (upstream `d50f84fc`) — decide tvOS's own floor next time player styling gets attention. `iosApp/NuvioTV/Screens/SubtitleVTT.swift`.
5. **[LOW, carried forward] TMDB Discover exclusion filters — UI half** (upstream `0fc4616b`) — new tvOS SwiftUI exclusion controls needed; shared query builder already wired (`7dac9a67`).
6. **[LOW, mechanical, carried forward, batch with #1 since both touch `shared/` library-adjacent code] Sync `shared/AppLanguage.kt` enum with upstream's `ARABIC` entry** — see 2026-08-17 doc for detail; still inert (no tvOS language-picker UI) but worth doing opportunistically alongside item 1 above since both are shared/ touches in nearby feature areas.

## Next scheduled check

Re-fetch `upstream/cmp-rewrite`, diff past `bbac53b2`. New top-priority items this run: Simkl anime library-type fix (item 1, small and self-contained — good candidate to actually execute next) and PIN-verify-refresh fix (item 2, trivial). Backlog otherwise unchanged: self-hosted server discovery (item 3, needs scope decision — highest value), subtitle-floor decision (item 4), TMDB exclusion-filter UI half (item 5), AppLanguage enum sync (item 6, trivial, batch opportunistically).

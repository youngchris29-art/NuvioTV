# Upstream port check — 2026-08-03 (scheduled)

## Headline: Item D (skip-outro clamp) is still unpatched. Upstream had a busy 24h — 5-commit Trakt "watched" correctness/robustness refactor is the big new item, plus a small real AniSkip bug fix. Everything else this run (app icons, Android media-session dispatch, plugin cache split, version bump) is confirmed N/A for tvOS.

Fork state checked this run: outer repo HEAD `d6c303ed` (UX-7/UX-10 tracker doc, fork-only). Submodule `NuvioMobile` HEAD `940907c3` on `tvos-shared-extraction` ("test: UX-7/UX-10 harness coverage").

`upstream/cmp-rewrite` (NuvioMedia/NuvioMobile) moved `e203dc88` → `ae5c8f74` (18 commits — much more movement than a typical day; two dev pushes, `tapframe` + `Sumanth1602`).

---

## Carried over — Item D still NOT landed (verified this run)

`iosApp/NuvioTV/Screens/MPVPlayerView.swift:1015` is still `seekAbsolute(prompt.targetSec)` with no clamp against `state.durationSec`. Full detail/fix snippet in `docs/upstream-port-plan-2026-08-02.md` (Item D) — unchanged, still a 1-file/~3-line fix, still low risk. Re-flagging since it wasn't picked up yet.

---

## New Item E (ready to apply, trivial): AniSkip query-string bug in shared `SkipIntroApi.kt`

Upstream commit `14015ec6` ("fix: route Kitsu/MAL IDs for skip intro and correct AniSkip types query", Sumanth1602, 2026-07-28, merged to `cmp-rewrite` this run via `ddbabeee`/`aea84128`) fixed two things in one commit; only one applies to tvOS.

**Applies — the AniSkip API bug:** `SkipIntroApi.kt` — verified this file **is** in the fork's `shared/src/commonMain/kotlin/com/nuvio/app/features/player/skip/SkipIntroApi.kt` (migrated during Phase 1, confirmed still has the bug at line 95-96). The AniSkip endpoint wants the `types` filter as **repeated query params**, not a single comma-joined value:

```kotlin
// current (buggy) — shared/.../skip/SkipIntroApi.kt:95-96
val types = "op,ed,recap,mixed-op,mixed-ed"
val url = "${ANISKIP_BASE}skip-times/$malId/$episode?types=$types&episodeLength=0"

// upstream fix
val types = "types=op&types=ed&types=recap&types=mixed-op&types=mixed-ed"
val url = "${ANISKIP_BASE}skip-times/$malId/$episode?$types&episodeLength=0"
```

One function (`getAniSkipTimes`), one file, no dependents change. Safe to port regardless of whether tvOS calls this path yet (see Item F).

**Does NOT apply directly — the Kitsu/MAL routing logic:** lives in `composeApp/.../player/PlayerScreenRuntimeEffects.kt`, which is Compose UI for mobile, not part of tvOS's build (same reasoning as every prior report). See Item F below for whether tvOS wants the underlying feature.

---

## New Item F (feature gap, not a regression — needs a product call): tvOS has no Kitsu/MAL-routed anime skip-intro

Checked tvOS's Swift callers (`iosApp/NuvioTV/Screens/MPVPlayerView.swift:739` and `NativePlayerScreen.swift:132`) — both call only `SkipIntroRepository.shared.getSkipIntervals(imdbId:season:episode:)`. There is no tvOS equivalent of mobile's new routing (`vid.startsWith("mal:")` → `getSkipIntervalsForMal`, `vid.startsWith("kitsu:")` → `getSkipIntervalsForKitsu`), so anime titles sourced by MAL/Kitsu ID (rather than an IMDb-mapped ID) silently get no skip-intro/outro prompts on tvOS today. This isn't a new regression from this upstream commit — tvOS never had this routing — but upstream adding it now makes the gap visible.

This is a genuine feature port (parse `videoId` prefix, call the right `SkipIntroRepository` method, same as `PlayerScreenRuntimeEffects.kt:397-411`) rather than a bug fix — small in isolation (~15 lines of Swift) but touches the skip-prompt call sites in both player files. Given it's scoped to anime content only, treat as optional/backlog unless Christian confirms it's worth prioritizing.

---

## New Item G (largest item this run — real correctness/stability fixes, needs careful porting): Trakt "watched" tracking — 5-commit cluster, Aug 2 16:11 → Aug 3 15:16

Upstream landed a same-subsystem, incremental bug-fix sequence (all by `tapframe`, each building on the last) around Trakt watched-state sync. In commit order:

1. **`15fcb8d2`** "fix: serialize watched state snapshots" (NUVIO-MOBILE-PW/PY/Q2) — new `WatchedItemsStore.kt` (32 lines) + rewrite of `WatchedRepository.kt` (241 lines touched). Serializes concurrent writes to the watched-state snapshot to prevent lost/interleaved updates.
2. **`e0cbf447`** "fix: contain Trakt watched rate limits" (NUVIO-MOBILE-Q1) — `WatchedRepository.kt` + `TraktWatchedSyncAdapter.kt`. Backs off / paces Trakt API calls to avoid 429s during sync.
3. **`9af5bd9b`** "fix: preserve large Trakt watched responses" (NUVIO-MOBILE-Q4) — `TraktWatchedSyncAdapter.kt` only. Fixes data loss when a Trakt watched-history response is large (pagination or truncation bug).
4. **`7a491570`** "fix: skip redundant Trakt watched refresh" (NUVIO-MOBILE-Q3) — `WatchedRepository.kt`, small (10 lines). Avoids an unnecessary re-fetch.
5. **`1b1fa691`** "fix: match Trakt watched markers across IDs" — `WatchedModels.kt` (new `watchedItemTypeAliases`/`watchedItemKeys` — matches watched status across `movie`/`film` and `series`/`show`/`tv`/`tvshow`/`anime` type-string aliases so a title tracked under one alias still shows watched when looked up under another), `WatchedRepository.kt`, `WatchingState.kt`, new `TraktWatchedProjection.kt` (66 lines), `TraktWatchedSyncAdapter.kt`.

**Fork-file mapping (checked this run):**

| Upstream file (composeApp/commonMain) | Fork status |
|---|---|
| `WatchedRepository.kt` | ✅ already in `shared/src/commonMain/.../features/watched/` — direct port target |
| `WatchedModels.kt` | ✅ already in `shared/src/commonMain/.../features/watched/` — direct port target |
| `TraktWatchedSyncAdapter.kt` | ✅ already in `shared/src/commonMain/.../features/watching/sync/` — direct port target |
| `WatchedItemsStore.kt` (new upstream file) | ❌ doesn't exist in fork yet — needs to be added to `shared/commonMain` alongside the `WatchedRepository.kt` rewrite it supports |
| `TraktWatchedProjection.kt` (new upstream file) | ❌ doesn't exist in fork yet — needs to be added to `shared/commonMain` alongside `TraktWatchedSyncAdapter.kt` |
| `WatchingState.kt` | ⚠️ still in `composeApp/src/commonMain/.../watching/application/` in the fork, **not yet migrated to `shared`** — need to determine whether tvOS needs this file's changes at all, or whether tvOS's watched-state consumption goes through a different path (`WatchingActions.kt`/`isFullyWatchedSeries()` per the already-landed Item A) that doesn't touch `WatchingState.kt`'s content |

**Why this matters for tvOS specifically:** three of the five touched files are proven live in tvOS's shared build already (this is exactly the kind of correctness bug — lost writes under concurrency, rate-limit 429s, truncated large responses, watched status not matching across type aliases — that would silently produce wrong "watched" badges/continue-watching state on tvOS today, not just mobile).

**Recommended approach for Claude Code:** because these 5 commits are sequential edits to the same functions (not independent), don't cherry-pick file diffs individually — check out or diff the upstream range `e203dc88..1b1fa691` (or `git log -p 15fcb8d2^..1b1fa691 -- '**/watched/*' '**/watching/**'` from a full upstream clone) and port the **end state** of `WatchedRepository.kt`/`WatchedModels.kt`/`TraktWatchedSyncAdapter.kt` against the fork's current shared versions, adding the two new files (`WatchedItemsStore.kt`, `TraktWatchedProjection.kt`) into `shared/commonMain`. Expect the fork's copies to have diverged somewhat from upstream's pre-refactor baseline (Batch 4a/4b history in `[[nuvio-tvos-port]]` shows these files went through non-trivial visibility/seam changes during the KMP migration — e.g. `ActiveProfileProvider` seam usage), so this is a manual merge, not a clean `git apply`. Budget real review time; this is not a copy-paste port.

**`WatchingState.kt` open question:** flagging for Christian/Claude Code judgment rather than resolving here — need to check what `WatchingState.kt` actually contains (composeApp-only Compose state holder, or portable logic that happens to sit in a Compose-adjacent package) before deciding whether it needs a shared/tvOS equivalent or is mobile-UI-only.

---

## Confirmed N/A this run (checked, no action)

- **`ae5c8f74`** "bump version" — `iosApp/Configuration/Version.xcconfig` only; that's the **mobile** iOS app's version file, unrelated to tvOS's own versioning.
- **`b6c97646`** "fix: expose app icon activities to Android lint" — `androidApp/build.gradle.kts` + Android manifest activity, Android-only.
- **`5d78dfc3`/`5a7d6dc7`** "feat: add selectable app icons" — Android-only (`AppIconPlatform.android.kt`, launcher XML/webp assets, `AndroidManifest.xml` alias activities). tvOS already has its own dynamic Top Shelf/icon handling per `[[nuvio-tvos-top-shelf]]`; this feature doesn't have a tvOS analogue (no home-screen icon switching concept on tvOS).
- **`31547fcd`/`3b7d6f4b`** "fix: split plugin source cache from metadata" — **checked in depth.** Upstream's fix separates plugin scraper JS source into per-scraper files (keyed by SHA256 digest) so the metadata blob in `NSUserDefaults`/Android storage stays small, working around a CFPreferences ~4MB crash. **tvOS already solved the identical root problem a different way**: `shared/src/appleMain/.../plugins/PluginStateFiles.kt` stores the *entire* per-profile plugin state (metadata + all scraper code) as one JSON file under Application Support — never touches `NSUserDefaults` at all, so the CFPreferences ceiling upstream is working around doesn't apply to tvOS's design. `PluginStateFiles.deleteAll()` is wired into the tvOS wipe path (`TvOsPluginsInstaller.kt` → `TvOsExtraLifecycleHooks.onClearLocalState` → `PluginRepository.clearLocalState()`), so there's no equivalent stale-directory cleanup to add either (upstream's account-wipe fix deletes a `nuvio_plugin_scrapers` directory tvOS never creates). No action — architectures diverged intentionally during the original JS-plugins port ([[nuvio-tvos-js-plugins]]) and both are sound; converging them isn't necessary for correctness, only worth it later if Christian wants one code path to maintain instead of two.
- **`47d788b6`** "test: align Simkl anime regression coverage" — test-only, and Simkl (Item C Phase 2) is still gated on Christian's product decision per prior reports — no change to that status.
- **`4f2c2b90`** "fix: dispatch playback service starts off main" (NUVIO-MOBILE-Q0) — `PlayerNowPlayingController.android.kt`/`PlayerNowPlayingService.android.kt` (Android media-session/notification service) + new `ConflatedTaskDispatcher.kt`. Checked: `ConflatedTaskDispatcher.kt` lives in `composeApp/src/commonMain` but its only consumer is the Android service — tvOS has no Android media-session equivalent (uses its own Swift player + system now-playing integration, if any, separately). No action.
- **`75153d89`** "remove expanded action button shadow" — `composeApp/.../details/components/DetailActionButtons.kt`, a Compose UI component. tvOS's detail screen is native SwiftUI, doesn't use this file.

`upstream/copilot/refactor-project-structure` still stale/abandoned (no movement).

---

## For Claude Code (this session)

1. **Item D** (carried over) — apply the skip-outro duration clamp in `MPVPlayerView.swift` (~3 lines). See `docs/upstream-port-plan-2026-08-02.md` for the exact snippet.
2. **Item E** — trivial, apply the AniSkip `types` query-param fix in `shared/.../skip/SkipIntroApi.kt` (2-line change, shown above).
3. **Item G** — the real work this round. Port the 5-commit Trakt watched-state cluster (`15fcb8d2`, `e0cbf447`, `9af5bd9b`, `7a491570`, `1b1fa691`) into `shared/commonMain`'s `WatchedRepository.kt`/`WatchedModels.kt`/`TraktWatchedSyncAdapter.kt`, adding `WatchedItemsStore.kt` + `TraktWatchedProjection.kt` as new shared files. Treat as a manual merge against the upstream end-state, not a mechanical cherry-pick — the fork's shared copies have migration-era differences (seam usage, visibility widenings) from upstream's composeApp originals. Resolve the `WatchingState.kt` question (does tvOS need any of its content moved to shared, or is it mobile-Compose-only) before/during this port.
4. **Item F** — optional/backlog: Kitsu/MAL-routed anime skip-intro on tvOS. Only pick up if Christian wants anime skip-intro parity; not a regression, just a pre-existing gap upstream's commit made visible.
5. Item C Phase 2 (Simkl backend) — still gated on product decision, no new movement, nothing to re-scope.

## Next scheduled check

- Verify Items D and E landed (grep checks: `durationSec - 0.5` in `MPVPlayerView.swift`; `types=op&types=ed` in `shared/.../skip/SkipIntroApi.kt`).
- Verify Item G landed — check for `WatchedItemsStore.kt` and `TraktWatchedProjection.kt` under `shared/src/commonMain/.../features/watched/` and `.../watching/sync/` respectively.
- Re-check `cmp-rewrite` tip past `ae5c8f74` (18 commits landed in the last ~24h is a faster pace than prior days — worth watching for further watched/Trakt follow-ups given `NUVIO-MOBILE-*` ticket numbering suggests more of these are queued).
- Re-ask whether Item C Phase 2 (Simkl) or Item F (anime skip-intro routing) have had product decisions made.

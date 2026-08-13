# Upstream port check — 2026-08-10 (scheduled)

## Headline: busiest window in weeks — 14 commits, 6 distinct changes, 3 are real correctness/stability fixes on code tvOS ships today.

Fork state checked this run: submodule `NuvioMobile` HEAD `f9e4ae56` on `tvos-shared-extraction`, branch up to date with `origin/tvos-shared-extraction`, working tree clean (only an untracked-content note on the `MPVKit` submodule pointer, not a real change). No fork commits since the 08-09 check — still at the state that check described.

`upstream/cmp-rewrite` (NuvioMedia/NuvioMobile) moved `ca7e54a4` → `f9ad843b` (14 commits since 2026-08-09 — busiest single-day window this check has seen). Unlike recent quiet/i18n-only days, this batch is substantive: three watched-state correctness/stability fixes (one is an OOM fix), a Trakt sync performance rewrite, a Simkl watched-logic correctness fix, a new player setting, and one feature addition. `upstream/copilot/refactor-project-structure` unchanged at `cbc9fc4f`, still abandoned. `upstream/simkl` unchanged at `e4911b77`, fully merged already.

**Important structural note for whoever executes this plan:** upstream keeps everything in `composeApp/`; this fork's whole reason for existing is that key business-logic files have been manually extracted into `shared/` so tvOS's native SwiftUI app can consume them via `SharedCore.framework`. Every item below was checked against whether its touched files exist in the fork's `shared/` (→ portable, real work) or only ever existed in `composeApp/` (→ N/A for tvOS unless the underlying logic was independently reimplemented in Swift, in which case that's called out).

---

## Action items this run, in priority order

### 1. [HIGH — live shipped-feature correctness bug] Simkl "fully watched series" logic conflicts with Nuvio's own definition

Upstream commit `0c6c6ed8` ("Simkl should not provide FullyWatchedSeriesKeys"). Simkl ships to tvOS ([[nuvio-tvos-upstream-catchup]], landed 2026-08-04) and this is exactly the kind of live-path bug this check exists to catch.

Upstream's own commit message: *"Nuvio logic for fully watched series is different than Simkl's. Let Nuvio handle it."* Simkl's own "completed" flag means "all episodes watched"; Nuvio's local logic means "all *available* (aired/released) episodes watched" — these diverge for still-airing shows, so pulling Simkl's series-level completion flag directly was overriding Nuvio's more correct local revalidation and could produce false "fully watched" checkmarks/binge-complete states.

Fork file (verbatim path, unmodified since extraction): `shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklApplicationAdapters.kt`, function `SimklWatchedSyncAdapter.pullFullyWatchedSeriesKeys(profileId: Int)`.

Exact port (upstream `0c6c6ed8`, full diff, no adaptation needed — file is identical between fork and upstream at this location):

```kotlin
override suspend fun pullFullyWatchedSeriesKeys(profileId: Int): Set<String>? {
    // Simkl "completed" = all episodes watched; Nuvio "completed" = all
    // *available* episodes watched. Let local revalidation decide.
    return null
}
```

This deletes ~16 lines of logic (the `SimklSyncRepository.refresh(...)` call, snapshot pull, projection, diagnostics logging) and just returns `null`, delegating to Nuvio's own local revalidation path. One function, no dependent-file changes, no test changes upstream. Lowest-risk, highest-value item this run — do this first.

### 2. [HIGH — crash risk] Watched-state persistence compaction to prevent OOM

Two same-day upstream commits that are really one feature landing in two passes: `eb2d5d3a` ("fix: persist Trakt watched state") and `3acbe6f2` ("fix(NUVIO-MOBILE-WZ): compact watched persistence to prevent OOM" — note the ticket prefix, this was tracked as a real incident). Combined they introduce a new compact serialization format for on-disk watched state and rework how `WatchedRepository` reads/writes it.

New file (does **not exist anywhere in the fork** — must be added from scratch): `StoredWatchedPayload.kt`, upstream path `composeApp/src/commonMain/kotlin/com/nuvio/app/features/watched/StoredWatchedPayload.kt`, target path `shared/src/commonMain/kotlin/com/nuvio/app/features/watched/StoredWatchedPayload.kt`. Pull full content via `git show 3acbe6f2dad4319eb4b17103abab5899c4f5eb2e:composeApp/src/commonMain/kotlin/com/nuvio/app/features/watched/StoredWatchedPayload.kt` (upstream final state, ~204 lines — the eb2d5d3a version is superseded by the 3acbe6f2 rewrite same day, so port the *final* state rather than replaying both commits).

Modified files, both already exist in fork's `shared/` at diverged (pre-refactor-baseline) content:
- `shared/src/commonMain/kotlin/com/nuvio/app/features/watched/WatchedRepository.kt` (fork currently 1328 lines; upstream diff across the two commits touches ~285 lines net). This is the file [[nuvio-tvos-upstream-catchup]]'s 2026-08-03 entry (Item G) already flagged as having "migration-era divergence from upstream's pre-refactor baseline" — same caution applies here: **diff `3acbe6f2` and `eb2d5d3a` directly against upstream's current file, don't blind-cherry-pick against fork's version**, since fork's copy has tvOS-specific seam/visibility changes layered on top of an older upstream baseline.
- `shared/src/commonMain/kotlin/com/nuvio/app/features/watched/WatchedItemsStore.kt` (small, 7-line upstream diff — low risk).
- `shared/src/commonMain/kotlin/com/nuvio/app/features/watching/sync/TraktWatchedProjection.kt` (9-line diff, low risk).
- `WatchedBadgeBulkResolver.kt` is also touched upstream (both commits) but **does not exist in the fork at all** — confirmed via full-repo grep, including `iosApp/`. tvOS never ported bulk badge resolution; `DetailViewModel.swift` computes per-item watched badges directly against `WatchedRepository.shared.isWatched(...)` instead (see `iosApp/NuvioTV/Screens/DetailViewModel.swift:328` `computeWatchedEpisodeKeys()`). **Skip this file** — nothing to port, tvOS's architecture here already diverged intentionally.
- `App.kt` (composeApp entry point, 2-line diff) — N/A, tvOS has its own SwiftUI app entry.

Why this is high priority despite the work: this is an OOM fix with its own incident ticket (`NUVIO-MOBILE-WZ`), meaning unbounded/uncompressed watched-state growth was crashing the mobile app. tvOS shares the same `WatchedRepository` code path (per the [[nuvio-tvos-upstream-catchup]] 2026-08-03 note that this exact file cluster is "live in tvOS's shared build") — a long-running Apple TV with a large watched history is plausibly exposed to the same growth pattern. Recommend budgeting real review time here, not a quick port.

### 3. [MEDIUM-HIGH — performance, same subsystem as #2] Trakt watched-sync speedup

Upstream commit `cb5886dc` ("fix: speed up Trakt watched sync"). New file `TraktWatchedShowSnapshotRepository.kt` (267 lines, upstream path `composeApp/src/commonMain/kotlin/com/nuvio/app/features/trakt/TraktWatchedShowSnapshotRepository.kt` — **does not exist in fork**, needs adding to `shared/src/commonMain/kotlin/com/nuvio/app/features/trakt/`). Refactors two files that already exist in fork's `shared/` at diverged content:
- `TraktProgressRepository.kt` (fork: 1723 lines; upstream trims 63 lines, moving snapshot logic into the new repository).
- `TraktWatchedSyncAdapter.kt` (fork: 867 lines; upstream trims 153 lines, delegating to the new snapshot repo).
- `TraktAuthRepository.kt` (1-line diff, trivial).

Same caution as item #2: fork's copies of `TraktProgressRepository.kt` and `TraktWatchedSyncAdapter.kt` have their own migration-era divergence — pull the new `TraktWatchedShowSnapshotRepository.kt` file first (self-contained, no divergence risk), then carefully reconcile the two refactored call sites against fork's current content rather than overwriting. This sits in the same Trakt-watched-correctness cluster flagged as [[nuvio-tvos-upstream-catchup]]'s biggest item back on 2026-08-03 (Item G) — worth doing in the same pass as item #2 above since both touch overlapping files and the same subsystem.

### 4. [LOW-MEDIUM — mostly N/A, one harmless enhancement] Watched-badge memory leak fix

Upstream commit `ccc6b87d` ("Fix watched badge memory leak"). Touches three files:
- `WatchedBadgeBulkResolver.kt` — **N/A**, confirmed above this class doesn't exist in the fork (tvOS uses a different, per-item architecture for watched badges).
- `EpisodeReleaseNotificationsRepository.kt` — exists in fork (`shared/src/commonMain/kotlin/com/nuvio/app/features/notifications/EpisodeReleaseNotificationsRepository.kt`) but **grep confirms zero references anywhere in `iosApp/NuvioTV`** — tvOS doesn't wire up episode-release notifications at all yet. The fix itself (pass `cacheResult = false` when bulk-resolving many tracked shows' metadata) is only meaningful once/if that feature ships on tvOS. No action now; note for whenever episode-release notifications get built.
- `MetaDetailsRepository.kt` — exists in fork (`shared/src/commonMain/kotlin/com/nuvio/app/features/details/MetaDetailsRepository.kt`), the actual leak-fix mechanism: `fetch(type, id)` gains a `cacheResult: Boolean = true` default param, and both bulk-resolution call sites above pass `cacheResult = false` to avoid permanently caching every item touched during a bulk sweep. **Safe, backward-compatible, optional to port** — the default preserves current behavior, and since neither of the two callers that would pass `false` exists on tvOS yet, there's no live leak to fix today. Worth adding opportunistically to keep `shared/` in sync for when either bulk-resolution feature above eventually gets built, but not urgent.

### 5. [LOW, feature gap not regression] Binge-group fallback toggle for manual-mode autoplay

Upstream commit `f2c9b9f9`. Adds one new boolean setting `streamAutoPlayNextEpisodeFallbackEnabled` (default `true`, preserves existing behavior) controlling whether, in manual-autoplay mode, a binge-group match failure falls back to auto-selecting the first stream (current/legacy behavior) or shows the stream picker instead.

The settings-plumbing half is clean and portable: `PlayerSettingsRepository.kt` (exists in fork's `shared/`, small additive diff — new field, getter/setter, load/reset wiring) and `PlayerSettingsStorage.kt` (exists in fork's `shared/`, `expect` declarations for 2 new load/save methods). The storage `actual` upstream added it to `PlayerSettingsStorage.ios.kt` and `.android.kt` — fork uses a unified `PlayerSettingsStorage.apple.kt` (appleMain, covers iOS+tvOS) instead of a separate `.ios.kt`, so the two new methods need adding there instead, plus the (irrelevant but source-shared) `.android.kt`.

The behavioral half is **not directly portable**: `PlayerNextEpisodeAutoPlay.kt` (the file with the actual binge-group-fallback branch logic) is composeApp-only upstream and was never extracted to `shared/` — tvOS reimplemented next-episode autoplay natively in `iosApp/NuvioTV/Screens/NextEpisodeAutoPlay.swift`. Porting this feature means re-deriving the same one-line logic change (`bingeGroupOnlyManualMode` now also triggers when the new fallback flag is off) directly in the Swift file, using the ported setting as the toggle source.

Also: no existing tvOS settings screen surfaces player/playback options at all (checked all `Screens/*.swift` — no playback settings UI found), so this toggle would have nowhere to live in the UI yet even after porting the logic. Recommend treating as backlog/optional pending a broader "player settings" screen decision, not urgent.

### 6. [LOW, feature add] TMDB Discover exclusion filters for collections

Upstream commit `0fc4616b`. Adds exclusion-filter fields to collection models and TMDB Discover query logic. Two of three touched files were extracted to fork's `shared/`: `CollectionModels.kt` and `TmdbCollectionSourceResolver.kt` (both exist verbatim-path in `shared/src/commonMain/kotlin/com/nuvio/app/features/collection/`) — the model/logic half is portable. `CollectionEditorScreen.kt` (the UI for setting the filters) is composeApp-only Compose UI, N/A — tvOS's `FolderDetailScreen.swift`/collection UI (native SwiftUI) would need its own new filter controls to expose this, which is a real UI-design task, not a mechanical port. Pure feature addition, no bug being fixed — lowest priority this run.

---

## Checked, not applicable

- `upstream/copilot/refactor-project-structure` — unchanged at `cbc9fc4f`, still abandoned, no action.
- `upstream/simkl` — unchanged at `e4911b77`, already fully merged into `cmp-rewrite` per the 2026-08-04 check, no action.
- Two `bump version` commits (`a57f5e18`, `f9ad843b`) and two merge commits (`af709919`, `aa8b25c5`, `65269320`) and one `update readme` (`ee40c8c4`) — mechanical/no-op for tvOS.

---

## Next scheduled check

Re-fetch `cmp-rewrite`, diff past `f9ad843b`. Verify item #1 (Simkl fix) and item #2 (OOM/StoredWatchedPayload) landed if Christian runs this plan through Claude Code before the next check — grep checks: `grep -n "pullFullyWatchedSeriesKeys" shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklApplicationAdapters.kt` should show a one-line `return null` body; `find shared -iname "StoredWatchedPayload.kt"` should return a hit once #2 lands.

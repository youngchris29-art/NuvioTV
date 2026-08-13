# Upstream port check — 2026-08-11

## Summary

**No new upstream commits since the 2026-08-10 check.** `upstream/cmp-rewrite` is still pinned at `f9ad843b` ("bump version") — zero commits landed on the original NuvioTV/NuvioMobile repo in the last 24h. This is the quietest window logged since checks started.

All fetch/verification work below was run against the `NuvioMobile` submodule (`origin` = `youngchris29-art/NuvioMobile`, `upstream` = `NuvioMedia/NuvioMobile`, tracked branch `cmp-rewrite`).

## Verification: did the 2026-08-10 items land?

The prior check (`docs/upstream-port-plan-2026-08-10.md`, see also `nuvio-tvos-upstream-catchup` memory) flagged 6 items, 3 high-priority. The `beta.12` campaign (outer commit `dd5102a`, submodule commit `f1a54014` "feat: upstream 08-10 ports (watched OOM, Trakt speedup, Simkl fix) + VidHub external playback") claimed to have shipped these. Verified directly against the current tree:

1. **Simkl `pullFullyWatchedSeriesKeys` fix (HIGH)** — ✅ LANDED. `SimklApplicationAdapters.kt:44-48` now returns `null` verbatim, matching upstream `0c6c6ed8`.
2. **Watched-state OOM fix (HIGH)** — ✅ LANDED. `StoredWatchedPayload.kt` exists at `shared/src/commonMain/kotlin/com/nuvio/app/features/watched/`.
3. **Trakt watched-sync speedup (MEDIUM-HIGH)** — ✅ LANDED. `TraktWatchedShowSnapshotRepository.kt` exists at `shared/src/commonMain/kotlin/com/nuvio/app/features/trakt/`.
4. **Watched-badge memory leak / `cacheResult` param (LOW)** — ✅ LANDED. `MetaDetailsRepository.kt:223` has `cacheResult: Boolean = true`, with an inline comment citing "Upstream ccc6b87d (beta.12 port)".
5. **Binge-group fallback toggle (LOW)** — ✅ LANDED, including the tvOS-native UI gap noted last time. `NextEpisodeAutoPlay.swift:380-404` has `attemptBingeGroupOnlySelection` gated on `settings.streamAutoPlayPreferBingeGroup`, with an inline comment citing "Upstream f2c9b9f9 (beta.12 port)". `PlaybackSettingsPane.swift` now exists as a real settings screen (didn't exist as of the 08-10 check).
6. **TMDB Discover exclusion filters (LOW, feature add)** — ❌ STILL NOT PORTED. Confirmed `shared/src/commonMain/kotlin/com/nuvio/app/features/collection/CollectionModels.kt` has no `withoutGenres`/`withoutKeywords`/`withoutCompanies`/`withoutWatchProviders` fields (upstream `0fc4616b`). No SwiftUI collection-editor UI exists in `iosApp/` at all (`CollectionEditorRepository.kt` is shared-layer only, unreferenced by any Swift file) — this remains a real design task, not a mechanical port, same as noted 08-10.

**Net: 5 of 6 prior items now closed. Item 6 carries forward, unchanged in scope/priority (LOW).**

## New items this run

None. No new upstream commits to review.

## Action items for Claude Code

Nothing urgent. Optional backlog item, low priority, do whenever a collections/UI pass is scheduled:

- **TMDB Discover exclusion filters** — add `withoutGenres`, `withoutKeywords`, `withoutCompanies`, `withoutWatchProviders` (all `String?`, default `null`) to `TmdbCollectionFilters` in `shared/src/commonMain/kotlin/com/nuvio/app/features/collection/CollectionModels.kt`, wire them into `TmdbCollectionSourceResolver.kt`'s TMDB Discover query builder (upstream diffs the query-param mapping in the same commit, `0fc4616b`), then design new SwiftUI exclusion controls in tvOS's collection editor surface (`iosApp/NuvioTV/Screens/CollectionsUI.swift` / wherever the collection creation flow lives — no dedicated editor screen exists yet on tvOS). This is additive and backward-compatible; no risk to existing collections.

## Next scheduled check

Re-fetch `upstream/cmp-rewrite`, diff past `f9ad843b`. Re-verify Item 6 status if a collections UI pass ships in the meantime.

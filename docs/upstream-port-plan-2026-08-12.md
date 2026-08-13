# Upstream port check — 2026-08-12

## Summary

**No new upstream commits since the 2026-08-11 check.** `upstream/cmp-rewrite` is still pinned at `f9ad843b` ("bump version") — zero commits landed on the original NuvioTV/NuvioMobile repo in the last 24h. Two consecutive quiet checks in a row (08-11, 08-12).

Checked against the `NuvioMobile` submodule (`origin` = `youngchris29-art/NuvioMobile`, `upstream` = `NuvioMedia/NuvioMobile`, tracked branch `cmp-rewrite`). Also re-confirmed `upstream/copilot/refactor-project-structure` is still stale at `cbc9fc4f` — abandoned branch, no action.

Fork state at check time: outer `main` HEAD `6d96fcd` ("docs: device-pass sections 1-4 results — BUG-31 fixed, trailer soak PASS, GIF frame data captured"), submodule `NuvioMobile` HEAD `c6d762eb` on `tvos-shared-extraction` (3 commits ahead of the 08-11 check's `99faf002`: BUG-31 focus-zoom fix, Sentry breadcrumb URL-token leak fix, BUG-53 pinned-row reach adjustment — all fork-native fixes, not upstream ports).

## Verification: did the 2026-08-11 items land / change?

Only one open item from the last several checks: **TMDB Discover exclusion filters (LOW, feature add, upstream `0fc4616b`)**. Re-checked directly:

- `grep -n "withoutGenres\|withoutKeywords\|withoutCompanies\|withoutWatchProviders" shared/src/commonMain/kotlin/com/nuvio/app/features/collection/CollectionModels.kt` → no matches. Still not ported.
- No SwiftUI collection-editor screen exists in `iosApp/` — `CollectionEditorRepository.kt` (shared-layer) remains unreferenced by any Swift file.

**Status unchanged: still open, still LOW priority.** No urgency change — no collections/UI pass has landed since 08-11.

## New items this run

None. No new upstream commits to review.

## Action items for Claude Code

Nothing urgent. Same optional backlog item as the last several checks, low priority, do whenever a collections/UI pass is scheduled:

- **TMDB Discover exclusion filters** — add `withoutGenres`, `withoutKeywords`, `withoutCompanies`, `withoutWatchProviders` (all `String?`, default `null`) to `TmdbCollectionFilters` in `shared/src/commonMain/kotlin/com/nuvio/app/features/collection/CollectionModels.kt`, wire them into `TmdbCollectionSourceResolver.kt`'s TMDB Discover query builder (upstream diffs the query-param mapping in the same commit, `0fc4616b`), then design new SwiftUI exclusion controls in tvOS's collection editor surface — no dedicated editor screen exists yet on tvOS, so this is a real design task, not a mechanical port. Additive and backward-compatible; no risk to existing collections.

## Next scheduled check

Re-fetch `upstream/cmp-rewrite`, diff past `f9ad843b` (unchanged for 2 checks running now). Re-verify Item 6 (TMDB Discover exclusion filters) status if a collections UI pass ships in the meantime.

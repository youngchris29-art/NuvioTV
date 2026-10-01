# Upstream port plan — 2026-10-01

## Upstream movement

`upstream/cmp-rewrite` (`github.com/NuvioMedia/NuvioMobile`) **moved**:
`c1065d0a` → `d667f432`, 25 commits (`git fetch upstream cmp-rewrite` then
`git log c1065d0a..upstream/cmp-rewrite --oneline`, verified fresh this run).
Breakdown: 7 real commits (all read in full via `git show`), 8 merge commits,
8 i18n-only commits (4 Vietnamese, 2 Slovak, 1 Greek, 1 Bengali-language-pack
addition), 1 version bump, 1 store publish (`chore(store): publish 0.5.5`).

This is the first real movement since the 09-29/09-30 check (which found
upstream pinned at `c1065d0a` with zero new commits).

## Fork state check

Outer pointer for the `NuvioMobile` submodule is `4f26c0d4` (`tvos-v0.3.0-
beta.18-rc14`, build 131). The submodule's local working checkout is on WIP
branch `claude/orivio-batch` (tip `83cc5996`, 14 commits ahead of
`4f26c0d4` — confirmed `4f26c0d4` is an ancestor) — in-progress feature work
for the Orivio-parity batch, not sync drift. No stale-clone issue: `shared/`
was read directly off this checkout for every "confirmed unported" claim
below.

## Action items for Claude Code

### 1. [MEDIUM/HIGH, mechanical, confirmed live] MDBList library sort + timestamp fix — `0e8b51bb`

Upstream commit message: *"MDBList returns the newest items for ascending
added order, so added sort and provider order were reversed."* Four files
changed, all with a confirmed unported `shared/` copy on this fork:

- `shared/src/commonMain/kotlin/com/nuvio/app/features/library/LibraryDisplaySettings.kt`
  — `sortLibraryItems()`'s `LibrarySortOption.DEFAULT` branch needs an
  MDBList-specific comparator (`compareByDescending { savedAtEpochMs }` first,
  falling back to list rank) instead of the generic rank-then-date order used
  for Trakt/local sources.
- `shared/src/commonMain/kotlin/com/nuvio/app/features/mdblist/MdbListLibrarySorter.kt`
  — `observeAddedOrder()`'s `direction` was backwards: MDBList's API returns
  the newest items for `order=desc` and the oldest for `order=asc`, the
  opposite of what the variable name implies. Confirmed still has the
  pre-fix `if (descending) "desc" else "asc"` (should be
  `if (descending) "asc" else "desc"`).
- `shared/src/commonMain/kotlin/com/nuvio/app/features/mdblist/MdbListLibraryDecoder.kt`
  — `decodeLibraryItem()`'s `listedAt` should also fall back to a
  `watchlist_at` field (`row.timestamp("listed_at", "added_at",
  "watchlist_at")`); confirmed still only checks `listed_at`/`added_at`.
- `shared/src/commonMain/kotlin/com/nuvio/app/features/mdblist/MdbListResponseValues.kt`
  — `mdbListTimestamp()` throws `MdbListDecodingException` on any timestamp
  that isn't strict ISO-8601 (`Instant.parse`). Upstream adds a fallback
  regex (`MdbListLocalTimestamp`) that accepts MDBList's
  `"yyyy-MM-dd HH:mm:ss[.fraction]"` local-format timestamps (no `T`/`Z`) and
  normalizes them to UTC before re-parsing. Confirmed the fork's copy has no
  fallback at all — any MDBList item with a non-ISO timestamp throws and is
  presumably dropped or crashes the decode.

**Confirmed live**: `iosApp/NuvioTV/Screens/LibraryViewModel.swift` and
`LibraryView.swift` both consume `LibraryDisplaySettings`/
`sortLibraryItems`/`effectiveLibrarySortOption`, and tvOS shipped MDBList
account/watchlist integration in the 09-30 batch-10 merge — so this is a
live, user-facing bug: MDBList-backed library lists on tvOS are likely
sorted oldest-first instead of newest-first today, and some watchlist items
may be silently failing to decode. Four small, mechanical file changes —
port as a single batch, add upstream's new test cases
(`LibraryDisplaySettingsTest.kt`, `MdbListLibraryDecoderTest.kt`,
`LibraryCatalogStateTest.kt`).

### 2. [MEDIUM, not mechanical — needs reconciliation] Simkl ID resolution content-type hint — `317bf2dc` (partial)

Upstream's `SimklIdResolver.resolveIds()` gained a third parameter,
`contentTypeHint: String?`, used to pick the search result whose `type`
(`movie`/`show`/`anime`) matches the caller's known content type, instead of
blindly taking `results[0]` from Simkl's `/search/id` response — this avoids
mis-resolving an ambiguous IMDB/TMDB id to the wrong Simkl entry (e.g. a
movie and a short with the same external id). `SimklRelatedRepository.kt`'s
call site was updated to pass `meta.type`/`fallbackItemType` as the hint.

**Not a mechanical drop-in**: the fork's `shared/.../player/skip/
SimklIdResolver.kt` has already diverged from upstream's pre-change
signature — it carries a fork-only `season: Int?` parameter (from the
2026-09-15/16 sibling-season skip-intro port) that upstream's diff doesn't
know about. Confirmed current signature:
`resolveIds(source: String, id: String, season: Int? = null)`. Porting this
cleanly means adding `contentTypeHint` as a fourth parameter (not replacing
`season`), threading both into the cache key, and updating
`shared/.../SimklRelatedRepository.kt`'s call site the same way upstream
did, keeping the fork's season-aware logic intact.

**Confirmed live**: tvOS's anime skip-intro path (`MPVPlayerView.swift`,
`NativePlayerScreen.swift` → `SkipIntroRepository` → `SimklIdResolver`)
depends on this exact resolver chain, so a wrong Simkl-type match today
could misroute skip-intro/outro lookups for ambiguous ids. Worth doing
alongside item 1 or standalone — small diff, but reconcile by hand rather
than copy-paste.

### 3. [LOW, opportunistic — no live tvOS consumer yet] Landscape clearlogo toggle — `317bf2dc` (remainder)

Same commit also adds `alwaysShowLandscapeClearlogo` to
`PosterCardStyleRepository` (width/corner-radius/landscape-mode/hide-labels
poster-card preferences) and wires a new Settings toggle in
`PosterCustomizationSettingsPage.kt` (composeApp-only, no port needed) that
forces the clearlogo overlay even when a dedicated landscape poster image
exists. `shared/src/commonMain/kotlin/com/nuvio/app/core/ui/
PosterCardStyleRepository.kt` already exists in the fork (confirmed), but
**has no tvOS Swift consumer at all** — `grep -rl "PosterCardStyle"
iosApp/NuvioTV/` returns nothing, and there is no landscape-clearlogo
feature on tvOS today to extend. Logging as a backlog idea only: if/when
tvOS ever gets its own landscape-poster-card customization screen, carry
this flag over; not worth a standalone port today.

### Not applicable this run (confirmed by reading full diffs, not just commit titles)

- `f11c27ba` "Always use backdrop if setting turned on" and `ecb117cf` "But
  apply custom url" — both touch only composeApp's
  `HomePosterCard.kt` Compose rendering; no `shared/` extraction of that
  file exists (`find shared -iname HomePosterCard.kt` empty) — tvOS's poster
  cards are bespoke native SwiftUI.
- `203c315e` "Fix clearlogo + backdrop" — touches composeApp's
  `ShelfComponents.kt` + `HomePosterCard.kt`, same reasoning, no `shared/`
  target.
- `13876b37` "show the swipe-to-seek preview in the new player layout" —
  Compose-only `PlayerGestureOverlay.kt` (gesture-overlay gesture rendering
  for the Android/desktop/mobile Compose player UI); no `shared/`
  extraction exists. tvOS's player is native AVPlayer/MPV
  (`MPVPlayerView.swift`/`NativePlayerScreen.swift`) with its own
  swipe-to-seek handling, unaffected.
- `4fd168d7` "Fix hero alignment to follow HeroContentBlock alignment" —
  composeApp `HomeHeroSection.kt` only, no `shared/` target; tvOS's Home
  hero is a wholly bespoke native system (per the 2026-08-31 note, unchanged
  since).
- `880cc1f0` "add Bengali language support" + the Vietnamese/Slovak/Greek
  i18n commits — pure localization, or (for Bengali) a new
  `AppLanguage.kt` enum case with no tvOS consumer — tvOS remains
  English-only, confirmed no Swift file references `AppLanguage` at all.
- 8 merge commits, 1 version bump, 1 store publish — no content.

## Note: a separate, non-upstream comparison already exists in this repo

This run's check is against `NuvioMedia/NuvioMobile` (the Kotlin/Compose
Multiplatform app this fork extends and tracks — see README "Lineage").
That's distinct from `docs/orivio-feature-comparison-2026-10-01.md` (commit
`b2c9d1a`, same day), which compares this fork against a *different*,
unrelated tvOS app (`prehakanson-art/OrivioTVAppleTV`) for feature parity —
not an upstream-sync relationship. Don't conflate the two when triaging.

## Suggested execution order for Claude Code

1. Port item 1 (MDBList sort/timestamp fix) first — it's mechanical, small,
   and fixes a live, confirmed user-facing bug. Add upstream's new unit
   tests in the same batch.
2. Port item 2 (Simkl content-type hint) — reconcile by hand against the
   fork's existing `season` parameter; don't blind-copy the signature.
3. Leave item 3 (landscape clearlogo) and the "not applicable" list alone
   until tvOS actually grows the relevant UI.
4. After merging, bump the submodule pointer on `main` and update the
   `CLAUDE.md` upstream-sync paragraph to record the new pin (`d667f432`).

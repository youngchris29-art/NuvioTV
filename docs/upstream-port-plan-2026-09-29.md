# Upstream port plan — 2026-09-29

Scheduled check of `NuvioMedia/NuvioMobile` (`cmp-rewrite`) against this fork's `NuvioMobile` submodule (`tvos-shared-extraction`). **This is a backlog catch-up, not a normal daily run**: the last check on record is `docs/upstream-port-plan-2026-09-16.md` (2026-09-16) — the scheduled task did not fire (or wasn't actioned) for 13 days. Upstream moved a long way in that gap: `95347544` → `c1065d0a`, **180 commits (132 non-merge)**.

**Scope note on this run:** given the size of the gap, this pass does not carry the same commit-by-commit `git show` depth as the daily reports (that would mean reading well over 100 full diffs). Instead it: (1) excluded merges, version bumps, store-publish commits, and i18n-only commits (strings.xml / "Vietnamese" / "Urdu" / "Norwegian" / "Spanish" / "Polish" / "missing strings" — **not read in detail**, assumed non-actionable as in every prior run); (2) narrowed to the 99 non-merge commits touching `composeApp/src/commonMain` or `composeApp/src/commonTest` (upstream's shared-logic module — this fork's `shared/` is the extracted equivalent, same relative paths under `features/`/`core/`); (3) grouped those by feature area; (4) did a full `git show` + a live grep against the fork's current `shared/` tree for every item listed as an action item below — those are confirmed, not guessed. The larger feature-sized groups (MDBList account/list management, custom poster URLs, IntroDB/post-credits unification, episode shuffle) are scoped and directionally verified (confirmed absent from the fork) but not diffed commit-by-commit — treat their port shapes as a starting brief, not a finished spec, and re-verify file names before writing code.

**Recommendation:** given how much drifted in 13 days, either re-enable the daily cadence going forward, or if the schedule needs to stay less frequent, budget a longer dedicated session (not a routine run) for the next catch-up — this file should not be treated as having the same read-everything guarantee as `docs/upstream-port-plan-2026-09-14.md`..`2026-09-16.md`.

Submodule pointer check: outer repo's committed pointer sits at `3449db86` (branch `claude/rc13-batch`, tvos-v0.3.0-beta.18-rc13 WIP) — unchanged since 09-16, still blocked per CLAUDE.md on Christian supplying `TMDB_API_KEY`. `origin/tvos-shared-extraction`'s tip was not independently re-checked this run; assume no drift beyond what CLAUDE.md already records unless told otherwise.

## Action items — verified live bugs (confirmed unported by reading the fork's current `shared/` files)

### 1. [HIGH, mechanical, data-loss bug] Simkl: a whole-series watched mark wipes the account's per-episode history

Commit: `ba786215` "fix(simkl): never push a whole-series mark to Simkl history" (2026-09-12)

A watched mark with no season/episode describes a whole series to Simkl's API; Simkl responds by marking *every* episode of that show watched, including ones the user never opened. Upstream's own commit message: "One such mark wiped 80 episodes of a series that had 11 watched." Upstream adds a `simklHistoryPushItems()` filter in `SimklWatchedSyncAdapter.push()` — films still travel without coordinates, per-episode marks are untouched, and a whole-series action still syncs through its own episode list; only a bare series-level mark is dropped before it reaches `/sync/history`.

**Confirmed unported:** the fork's `shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklApplicationAdapters.kt` has an `override suspend fun push(...)` at line 68 with no `simklHistoryPushItems` call or equivalent guard anywhere in the file. Note the fork *does* already have an analogous guard on the **removal** side (`removableItems.filter { season != null && episode != null }`, ~line 105, with fork-only commentary explaining why) — this is the same bug class on the opposite (add/push) path, not yet fixed there.

**Port shape:** add the `simklHistoryPushItems(items)` filter function (upstream's is ~15 lines, self-contained) and call it at the top of `push()`, short-circuiting with a log line when everything filtered out — exactly upstream's shape. Port `SimklHistoryPushGuardTest.kt`'s cases too. Should read cleanly against the fork's diverged file (no other structural changes needed at this call site).

### 2. [HIGH, mechanical, correctness bug] Simkl: an incoming playback read can overwrite a pause the app just recorded

Commit: `077a264a` "fix(simkl): keep a pause the app just recorded over a fetch that lags" (2026-09-14)

Simkl acknowledges a stop/pause immediately but publishes the new position on `/sync/playback` slightly later; the fork's sync engine (same as upstream's pre-fix code) replaces the *entire* local playback list with whatever that lagging read returns. Result: an episode paused at 83% can come back from the next sync at 88% (the previous viewing's position), so the next resume starts at a point the user never reached.

**Confirmed unported:** no `SimklPlaybackMerge.kt` (or any `mergeFetchedPlayback`-named function) exists anywhere under the fork's `shared/`; `shared/.../simkl/SimklSyncEngine.kt`'s playback-refresh branch calls `remote.fetchPlayback()` directly with no merge step.

**Port shape:** add upstream's new file `SimklPlaybackMerge.kt` verbatim (self-contained, ~50 lines, no dependency on anything fork-specific — keeps a locally-held row only when its `pausedAt`/`watchedAt` timestamp is strictly newer than the fetched row's, keyed by content+season+episode) into `shared/.../simkl/`, then change the one line in `SimklSyncEngine.kt`'s playback-changed branch from `remote.fetchPlayback()` to `mergeFetchedPlayback(fetched = remote.fetchPlayback(), held = current.playback)`. Low risk — additive file plus a one-line call-site change.

### 3. [HIGH, mechanical, correctness bug] Simkl: episode resume position computed from the show's runtime instead of the actual file

Commit: `b7657dbe` "fix(simkl): stop inventing an episode position out of the show runtime" (2026-09-14)

A Simkl playback row for a TV episode carries a percentage, not a timecode. The fork's current projection (same as upstream's pre-fix code) scales that percentage by the *show's* runtime to derive a duration/position pair — for an episode that isn't exactly the show's average length, this invents a wrong timecode (upstream's example: 83% of a 47-minute episode computed as 42 minutes, because 83% of the show's stated 52-minute runtime is 43). A Trakt-sourced row already avoids this by carrying percentage with no duration and letting the player scale it against the file it actually opened.

**Confirmed unported:** `shared/.../simkl/SimklProjections.kt` line 427, `toWatchProgressEntry()`: `val durationMs = media.runtime?.takeIf { it > 0 }?.toLong()?.times(60_000L) ?: 0L` — unconditional, not gated on `isMovie` (the function already computes `isMovie` at line 407, right above).

**Port shape:** ten-line change — wrap the existing `durationMs` computation in `if (isMovie) { ...existing... } else { 0L }` exactly as upstream does; movies keep their runtime-derived duration (still correct there), series/episode rows now carry percentage with `durationMs = 0`, matching how the Trakt path already resumes.

### 4. [LOW/MEDIUM, needs a model-shape check] Simkl: newly-watched item loses its poster until the next full library refresh

Commit: `542aa570` "fix(simkl): retain posters when marking items watched" (2026-09-17)

Upstream threads `posterUrl`/`localPosterUrl` through the mark-watched path (`SimklWatchedSyncAdapter`'s watched-item construction gets `posterUrl = item.poster`; `SimklMutationReconciliation.withResolvedHistoryStatus()` preserves `existing.localPosterUrl ?: mutation.request.media.posterUrl` when resolving the post-mutation snapshot) so a poster shows immediately instead of going blank until the next `/sync/all-items` pull repopulates it.

**Not independently confirmed** this run (the two touched fork files — `SimklApplicationAdapters.kt`, `SimklMutationReconciliation.kt` — exist, but their exact field names/shape weren't diffed against this specific change). **Action for Claude Code:** read `git show 542aa570` against current `shared/.../simkl/SimklApplicationAdapters.kt` and `SimklMutationReconciliation.kt` directly (both are heavily fork-diverged like the other Simkl files above) before porting — likely a small, mostly-mechanical two-field addition plus a test, but verify field names (`localPosterUrl` may not match the fork's naming) before writing code.

## Feature-sized additions (scoped, confirmed absent from the fork, not fully commit-diffed — needs a dedicated session)

### 5. [MEDIUM, large — product + engineering decision] MDBList account, watchlist, and list management (mobile-parity feature, ~13 upstream commits, 2026-09-06 → 2026-09-14)

Commits (oldest first): `8fe994bd` (device auth: `MdbListAuthRepository`/`MdbListAuthStore`/`MdbListApiClient`/`MdbListHttpClient`, ~1,685 lines, new subsystem), `425e4d8a` (mobile list management + account status UI), `0a654ac4` (connect accounts to mobile playback/tracking), `30cf1eb1` (watchlist + static list add/remove operations), `53c441c0` (synchronize watched history and playback through the new account), `db85d968` (retain library aliases, handle load errors), `21a32ff9` (list management control fixes), plus `647e4c09`/`0b427905`/`3f0d07be` (rating-request batching, library sort, "use connected account for ratings with API key override" — these three are smaller fixes *on top of* the new account system and depend on it existing first).

**Confirmed absent from the fork:** `shared/.../mdblist/` currently only has `MdbListSettings(Repository/Storage)` (a single API-key override, the same shape as the `TMDB`/`MDBLIST` credential-sync case already flagged in the 09-16 report) and `MdbListMetadataService` (read-only ratings enrichment). There is no `MdbListAuthRepository`, `MdbListAuthStore`, `MdbListApiClient`, or anything watchlist/list-CRUD-shaped anywhere in the fork.

**What this is:** upstream turned MDBList from "optional personal API key for ratings" into a full second tracking-account integration (auth, watchlists, custom lists, watched-history sync) — comparable in scope to how Simkl/Trakt are already integrated on tvOS. This is genuinely large: a new auth flow, new Settings UI, and — the highest-risk part — watched-history sync needs to go through the fork's existing `TrackingWatchedProvider`/sync-guard machinery (the same fragile territory `ProviderCredentialSync.kt` already occupies per the 09-16 report), not a naive copy.

**Suggested next step for Claude Code:** treat this as its own planning pass, not a drop-in port. Start by reading `8fe994bd` through `21a32ff9` in full (`git log --reverse --oneline 95347544..c1065d0a -- '*mdblist*'` in the `NuvioMobile` submodule lists the exact commits in order), decide whether tvOS wants MDBList as a third tracking account at all (product call for Christian, not an engineering one), and if yes, scope it the way Simkl/Trakt accounts were originally built rather than porting upstream's Compose UI.

### 6. [LOW/MEDIUM, product decision] Custom poster URL pattern overlay (~7 commits, 2026-09-21 → 2026-09-24)

Commits: `cf59d255` "Introduce custom poster URL pattern support", `3501b7dd` (tests), `92968510` "add per-screen toggles for custom poster URL overlay", `0b7ab892` "support addon landscape posters", `72355628`/`6b8e79f9`/`5fd4d6b8`/`38ba71e2` (landscape-poster fallbacks for continue-watching/library), `75296263` "keep custom posters when returning to a title".

A new opt-in feature: users can supply a URL pattern (e.g. a personal Fanart/TMDB mirror) that overrides poster art app-wide, with per-screen on/off toggles synced via `ProfileSettingsSync.kt`, plus a separate line of work adding landscape/wide poster variants to continue-watching and library rows.

**Confirmed absent from the fork:** no `CustomPosterUrlStorage`, `CustomPosterUrlRepository`, or `CustomPosterFallbackInterceptor` anywhere under `shared/`.

**Suggested next step:** `92968510`'s stat shows it touches `ProfileSettingsSync.kt` (the same sync file already flagged as fragile/heavily diverged) — read that diff specifically before scoping. This is an additive, opt-in, low-risk-to-existing-behavior feature; good candidate for a standalone batch once someone wants it, not urgent.

### 7. [LOW/MEDIUM, product decision] Simkl as a third "More Like This" source

Commits: `af1298eb` "feat: add Simkl as third More Like This source", `1b2f7a99` "feat: add landscape banner to Simkl More Like This items".

**Confirmed absent:** no `MoreLikeThis`-named file under the fork's `shared/`, and `grep -ril MoreLikeThis iosApp` returns nothing — worth double-checking under what name tvOS's existing "similar titles" panel is actually implemented (it likely already has a TMDB- or Trakt-sourced version) before assuming this is a from-scratch build versus adding a third source to an existing panel.

### 8. [LOW, product decision] Episode shuffle

Commits: `23b048c3` "feat(player): add episode shuffle", `da92f36c` "move shuffle into actions menu", `6776ee7b` "open sheet at full height".

**Confirmed absent:** no `shuffle`-named file under the fork's `shared/`, and no `shuffle`/`Shuffle` hits anywhere under `iosApp/`. A UI-forward feature (adds a shuffle action + bottom sheet) — check how much of the underlying "pick a random unwatched episode" logic is `commonMain` versus Compose UI before scoping.

### 9. [Needs scoping, likely low priority for tvOS] IntroDB movie segments / skip-control unification (~5 commits, 2026-09-15 → 2026-09-16)

Commits: `cbe4dc0a` "support IntroDB movie segments", `199c5882` "unify skip controls and forward movie segments", `0e4f503f`/`11483dc0`/`a72e536c` (post-credits-scene preservation/detection fixes).

Most of the touched files are `PlayerScreenRuntimeEffects/State/Ui.kt` and `PlayerSettingsStorage.android.kt` — the same composeApp-only Compose player-runtime layer that prior reports (09-16, 09-14) repeatedly found has **no `shared/` target** because tvOS's player is a bespoke native SwiftUI/mpv implementation, not a Compose one. `cbe4dc0a` does touch `SkipIntroApi.kt` and `SkipIntroButton.kt`; `SkipIntroApi.kt` exists in the fork's `shared/` (tvOS already consumes it for skip-intro), so there may be a small portable slice here (movie-segment support in the IntroDB API surface itself) separate from the Compose UI wiring. **Not fully verified this run — read `git show cbe4dc0a` against the fork's current `SkipIntroApi.kt` before deciding whether any of this is actionable**; given the pattern from prior runs, expect most of it to be "not applicable, no `shared/` target."

## Carried items (re-verified this run — all three still open, confirmed by reading current file contents)

1. **[MEDIUM, not mechanical]** Anime skip-intro sibling-season Simkl resolution + episode remap (`aa748fa8`, open since 2026-09-15) — `shared/.../SimklIdResolver.kt` has no `resolveIdsForImdbEpisode`/sibling-season logic. Full shape in `docs/upstream-port-plan-2026-09-15.md`.
2. **[MEDIUM, mechanical]** TVDB as a Simkl anime-ID preference option (`8aad52d8` + `8ac70e59`'s `hasAnimeIds` guard, open since 2026-09-15) — `shared/.../SimklAnimeIdPreference.kt` still has no `TVDB` case.
3. **[LOW, mechanical]** Indonesian/Malay subtitle-language disambiguation (`d95b4f9b`, open since 2026-09-15) — `shared/.../PlayerSubtitleMatching.kt` has no `INDONESIAN`/Indonesian-specific handling.
4. **[MEDIUM, batch with ProviderCredentialSync reconciliation]** Personal TMDB API key override (`df589078`, open since 2026-09-16) — still unported per the 09-16 report; not re-verified independently this run, assume unchanged given the submodule pointer hasn't moved.
5. **[LOW/MEDIUM, mechanical]** Addon episode runtimes parsed when supplied as a string (`48bf5ed3`, open since 2026-09-16) — not re-verified independently this run.
6. **[MEDIUM, mechanical shared-side / needs Swift wiring]** IMDB id fallback from addon `imdb_id` field (`90054b7b`, open since 2026-09-16) — not re-verified independently this run.

## Suggested execution order

Do items 1–3 first (Simkl playback/history bugfixes) — small, mechanical, each independently verified as a live correctness/data-loss bug, and they're isolated enough to land as one batch without touching the fragile `ProviderCredentialSync.kt`. Item 4 needs one more read before it's shovel-ready. Items 5–9 are feature-sized or need more scoping — pick these up in a dedicated (non-routine) session, starting with whichever Christian wants product-wise (MDBList account integration is the biggest lift; custom poster URLs and Simkl More-Like-This are the most self-contained). Re-verify carried items 4–6 with a fresh `git show` before batching, since they weren't independently re-checked this run.

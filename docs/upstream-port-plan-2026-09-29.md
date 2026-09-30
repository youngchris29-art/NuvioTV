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

## OUTCOME ADDENDUM (2026-09-29/30, upstream batch 10)

Submodule branch `claude/upstream-batch10` (43 commits `dd85a154`..`d694f65a`, off rc13-batch tip `3449db86`), built model-delegated per plan `~/.claude/plans/lets-make-a-plan-dynamic-moth.md` (inventory IDs A1-A4, B1-B8, C1-C11, F1-F5). MERGED 2026-09-30 on Christian's go: `tvos-shared-extraction` fast-forwarded `243da21b` → `3449db86` (rc13) → `d694f65a` (batch 10) and pushed; outer pointer bumped (`188d240`); not cut yet (the cut carries rc13 + batch 10 together, with the `81da5470` cherry-pick before the build bump). Android actuals mirror upstream and were never compiled (no Android SDK).

### Corrections to the 09-29 note

- The outer repo's committed submodule pointer was `243da21b` (rc12), not `3449db86`; `3449db86` is the local rc13-batch tip the branch is based on.
- IntroDB (F1) had a real shared slice, not "no shared target": movie segments, auto-skip segment types and the post-credits hold landed in `shared/` (`01834285`), with the tvOS half in both engines (`dfceeb6a`).
- Simkl More Like This (F2) extended existing fork code (the shared More Like This source enum and enrichment path), not a new subsystem.
- Plugins are enabled on tvOS (`installTvOsPlugins()`), so `2e244028` (plugin runtime perf) was live-relevant, not a "investigate first" item.

### Upstream commits ported

| ID | Upstream | Subject | Fork commit | Kind | Deviation |
|---|---|---|---|---|---|
| A1 | `542aa570` | retain posters when marking watched | `dd85a154` | mechanical | none |
| A2 | `ba786215` | never push a whole-series mark to Simkl history | `dd85a154` | mechanical | guard later moved to `tracking/TrackingHistoryGuards`, shared with MDBList (`cee9314d`) |
| A3 | `077a264a` | keep a just-recorded pause over a lagging fetch | `dd85a154` | mechanical | adds `SimklPlaybackMergeTest` (upstream shipped none) |
| A4 | `b7657dbe` + `a298f2d7` | no episode position invented from show runtime | `dd85a154` | mechanical | episode rows carry `durationMs` 0; Swift resume-from-percentage added separately (`f59024c0`) |
| B1 | `aa748fa8` | IMDB to MAL mapping, sibling-season resolution | `9fcc75d6`, `fa68c24e`, `8f681e72` | hand port | fork's season-aware `resolveIds` kept as first pass, `resolveIdsForImdbEpisode` second; episode map fetched for anime only; split-cour sibling chosen by episode-map hit, base entry replaced only on a positive hit |
| B2 | `8aad52d8` + `8ac70e59` | TVDB Simkl anime-ID preference, anime-only | `dd85a154`, `3e4e3b7b` | mechanical | tvOS Settings option in `3e4e3b7b`; related cache key and meta-screen fingerprint carry the preference (`fa68c24e`) |
| B3 | `d95b4f9b` | Indonesian/Malay subtitle disambiguation | `8ba0101e` | mechanical | none |
| B4 | `df589078` | personal TMDB API key override with credential sync | `4dea1820`, `3e4e3b7b` | hand port | onto rc13's bundled-key work using the fork's MDBList credential convention; reverses rc13's purge of stored personal keys; tvOS rows in `3e4e3b7b` |
| B5 | `48bf5ed3` | parse addon episode runtimes | `f416e248` | mechanical | none |
| B6 | `90054b7b` | addon `imdb_id` fallback for enrichment | `f416e248` | mechanical + Swift | tvOS episode-ratings and parental-guide call sites use the fallback |
| B7 | `2e244028` + `2d03b258` | plugin runtime perf, no-op runtime config | `b1c75269` | hand port (tvosMain) | skipped `evaluationTimeoutMillis` (absent in quickjs-kt 1.0.5-tvos) and the search-pause code of `5cacbe6e`; response bytes decode lazily in `arrayBuffer()` |
| B8 | `50d39823` | StreamBackgroundMode | `3d99a651` | mechanical, shared-only | no tvOS renderer (reverses the rc13 "not ported" call only so synced mobile settings round-trip); key joins the wipe registry (`01834285`) |
| - | `80910185` + `17424fe3` | Russian + Urdu AppLanguage | `8ba0101e` | mechanical | none |
| C1 | `6aa42153` | debrid selects the requested episode file | `989f9961`, `062f1130`, `8f681e72`, `dd13202c`, `06430a24` | hand merge | TorBox/Real-Debrid/Premiumize use the shared selector; AllDebrid uses it with `hasStableFileIndex=false` and keeps the largest-file fallback for movies; standalone `sample` files dropped before a match is called ambiguous; the interim fileIdx fallback was removed in `dd13202c`, so the final rule is upstream's strict one |
| C2 | `2b8be69c` | replay watched series (`allowRewatch`) | `3d99a651` | mechanical | tvOS and mobile Detail pass `true` |
| C3 | `99ced26a` | Infuse resume position | `8ba0101e` | reduced | position parameter only |
| C4 | `09c80301` | keyed season posters | `f416e248` | mechanical | none |
| C5 | `a255680b` | atomic folder tab update (collections race) | `3d99a651` | mechanical | none |
| C6 | `4178d5cd` | blank collection dates sort last | `f416e248` | mechanical | none |
| C7 | `12621c65` | plugin binary request/response bodies | `b1c75269` | hand port | see B7 |
| C8 | `c3920d40` | age-rating regions | `f416e248` | reduced | age-rating half only |
| C9 | `6fb46976` | rating visibility | `3d99a651` | mechanical, shared-only | none |
| C11 | `0b7ab892` | addon landscape posters | `0d5aa6fb` | mechanical | none |
| F1 | `cbe4dc0a`, `199c5882`, `0e4f503f`, `11483dc0`, `a72e536c`, `77ce8a73` | IntroDB movie segments, auto-skip segment types, post-credits hold | `01834285` (shared), `dfceeb6a` (tvOS), `fa68c24e`, `1b85b955`, `37876562`, `75c59ece`, `e3ccfdad` | hand port + fork deviation | no legacy-boolean migration (fork never shipped those keys); `77ce8a73` rule is fork-local `PostCreditsHold`, restricted to an explicit post-credits segment so episodes keep the user's threshold |
| F2 | `af1298eb` + `1b2f7a99` | Simkl as a More Like This source | `3e951af2`, `3e4e3b7b` | mechanical + fork fix | `shouldApplyMoreLikeThisSource` extended to SIMKL; Simkl-active flag joins the settings fingerprint |
| F3 | `23b048c3`, `da92f36c`, `6776ee7b` | episode shuffle | `4847e752`, `310fe6fd`, `976bbe7f`, `53caff5c` | hand port + fork deviation | `WatchingState` not ported (`ShuffleEpisodeState` rebuilds it from `watchedItemKeys` + `SimklAnimeWatchedFallback`); pick stable across a Detail round trip (upstream re-rolls per visit); fork-local `ShuffleNextEpisode` for up-next with no sequential fallback when caught up; `episode_shuffle` profile-scoped, in wipe registry |
| F4 | `cf59d255`, `3501b7dd`, `6b8e79f9`, `72355628`, `f985340d`, `13adcdd4`, `c7d23c04`, `319fb564`, `38ba71e2`, `5fd4d6b8`, `92968510`, `db6c3128`, `30e24b2d`, `75296263` (+ `0b7ab892` landscape posters, listed as C11; `b04013f7`/`fc5912de` are a rename and its revert, net no-op, excluded) | custom poster URL pattern, per-screen toggles, CW/library landscape fallbacks | `0d5aa6fb`, `7286667b`, `9639861a`, `74b26103`, `5b16983c`, `bc3cd3d1` | hand port + fork deviation | end state ported; Coil fallback interceptor not ported (tvOS falls back in Swift `CachedAsyncImage`); profile settings blob v4 (v3 blob leaves local values untouched); Home hero backdrop pipeline not covered by the fallback (known limit); tvOS Settings screen + Remote Setup field (`5b16983c`) |
| F5 | `8fe994bd`, `0a654ac4`, `425e4d8a` | MDBList device-code auth, HTTP, account controller | `b1b5cb95` | verbatim | tokens in Keychain (`com.nuvio.media.mdblist`) with new `AppleKeySpec.Keychain` wipe-registry entry; `MdbListConfig.CLIENT_ID` from `MDBLIST_CLIENT_ID` (blank default) |
| F5 | `53c441c0`, `db85d968`, `0b427905` | MDBList sync engine, watched/progress/scrobble adapters, library layer | `151996d7`, `cee9314d`, `973e017a` | verbatim + fork deviation | `TrackingRefreshGate` shared with Simkl; sync snapshot in a per-profile `PayloadFileStore` (wipe-registered); resource-free `MdbListMessages`; Library re-pull only when the active provider (re)connects; whole-series guard added (`cee9314d`) |
| F5 | `647e4c09`, `3f0d07be`, `177f4b5c` | MDBList ratings via account; `isCertified` | `615550c5` | verbatim + fork deviation | `177f4b5c` field only; personal API key is an override; setters publish synchronously; `accountScope` excluded from `toString`; account token never enters the credential snapshot; TMDB-independent enable toggle |

### Reduced or skipped by decision

- `5cacbe6e` (pause scraper search during playback): deferred by decision (2026-09-29). It lives in Compose's `PlayerScreenRuntimeEffects`; on tvOS it would need enter/exit hooks in both Swift engines plus `NextEpisodeAutoPlay`, and no scraper jank has been reported on tvOS (09-12 note). `b1c75269` carries none of its code.
- Infuse x-callback half of `99ced26a`: tvOS registers only the `nuviotv` scheme.
- Episode-label and date-format halves of `c3920d40`: tvOS builds its own labels.
- `c9d6f5f6` (restore subtitles per episode): dropped by decision — the new `findPersistedAddonSubtitle` is `internal` and only Compose track actions use it; tvOS persists only subtitle delay. Logged as a tvOS feature gap, not a port.
- `3555bd07` (remove TMDB release-dates enrichment): SKIPPED by Christian's decision (2026-09-29) — the tvOS Settings toggle stays; deliberate fork divergence, not drift.
- Home Up Next shuffle projection (part of `23b048c3`): tvOS has no such row.
- MDBList list-management UI (F5.4): shared `TrackingListManager` landed in `151996d7`, no tvOS UI, deferred by decision.
- `LibraryCatalogState` provider-order flow (part of `0b427905`): not ported.
- composeApp MDBList UI and strings, and the `MdbListMessages` Compose resources (replaced by resource-free `MdbListMessages`).
- Android verification: no Android SDK; every Android actual is unbuilt and untested. `MainActivity` initialize wiring for shuffle was added blind (`976bbe7f`), MDBList Android init hook likewise.

### Fork-only fixes found along the way (not upstream ports)

- Resume-from-percentage in both tvOS engines (`f59024c0`): Simkl rows (after `b7657dbe`) and Trakt rows carry `durationMs` 0 and only a percentage; Trakt rows were already broken. mpv falls back to an absolute-percent seek, AVPlayer applies a pending percentage on the first finite-duration tick under 30 s; Continue Watching bar reads `progressFraction`.
- tvOS scrobble fan-out (`973e017a`): both engines scrobbled to Trakt directly and the shared `TrackingScrobbleCoordinator` had no caller, so Simkl (and MDBList) never received start/stop from tvOS. New `TrackerScrobbleSession` fans out to connected scrobblers minus Trakt.
- Profile deletion now removes stored tracker data (`151996d7`); a pre-existing gap for Trakt and Simkl.
- Fresh-install Keychain wipe sentinel (`151996d7`).
- Skip planner rewritten as an engine-confirmed seek state machine (`75c59ece`, `e3ccfdad`), replacing four rounds of position heuristics (`1b85b955`, `37876562`).
- `poster_transition_enabled` carried in the meta-screen payload, which tvOS dropped on re-persist (`3d99a651`).
- Library republishes on a poster-pattern change (`9639861a`).
- `none` sentinel for "all screens off" (`9639861a`).
- `MetaPreview.toLibraryItem` keeps raw poster URLs, plus `customPosterApplied` marker and raw landscape recorded on `LibraryItem` (`9639861a`, `bc3cd3d1`).
- R11 (`d694f65a`): an MDBList ratings fetch cancelled by an account change or cache clear no longer strands Detail in its loading state; the settings account collector runs on Main; a tracker scrobble stop can no longer overtake its start (`TrackerScrobbleSequencer`).

### Upstream-report candidates (new this batch)

- `db6c3128`'s Library collector compares Unit to Unit and never fires.
- `fromKeys` maps an empty set to all screens.
- `toLibraryItem` persists the custom poster URL (with the RPDB key) into synced library rows.
- `withCustomPosterUrl` cannot restore a null original.
- MDBList watched adapter has no whole-series guard (same class as `ba786215`).
- `6aa42153` breaks absolute-numbered packs (season > 1 on such a pack returns null).
- `77ce8a73`'s tail heuristic holds up-next on most anime episodes.
- `shouldApplyMoreLikeThisSource` ignores SIMKL.
- `MdbListSettingsRepository`'s eager `combine` publishes asynchronously.

### Gates

Baseline (rc13): jvm 801 / tvOS-native 821 / composeApp 425 / NuvioTVTests 328. Final: jvm 1291 / tvOS-native 1309 / composeApp 432 / NuvioTVTests 383 on the tip `d694f65a` (+8 `HeroCrossfadeLayoutTests` run separately). Note: `xcodebuild test` fails with exit 70 ("Failed to prevent system sleep") from inside the Claude Bash tool sandbox because the sandbox refuses the power assertion (`IOPMAssertionCreateWithName` → 0xe00002bd); the final run was executed with the sandbox off at Christian's request. Debug and Release simulator builds green throughout. Review: 11 rounds, all internal Opus (Codex unavailable: model rejected for the account). Findings per round: 6, 8, 4, 6, 4, 3, 5, 9, 6, 8, 4 (r11, all fixed in `d694f65a`). The fixture-simulator UI suite is not a usable gate: `test20`, `test22`, `test27` fail identically on the rc13 baseline (saved state).

### Owed

- Keys: both landed 2026-09-30 in `NuvioMobile/local.properties`. `TMDB_API_KEY` (TMDB `/3/configuration` answered 200; `TmdbConfig.API_KEY` generated, 32 chars) and `MDBLIST_CLIENT_ID` (Device Code app registered at mdblist.com/developer; `/oauth/device-authorization/` answered 200 with it). Release rebuild with both keys green on 2026-09-30 (generated `TmdbConfig.API_KEY` 32 chars, `MdbListConfig.CLIENT_ID` 40 chars); Debug install and a 50 s cold launch on the fixture simulator ran clean (no 401, no fatal lines). Still owed: the device pass, which is where the TMDB-backed Detail page and the MDBList connect card get exercised.
- Codex model setting for the account; fixture simulator reset.
- Cherry-pick `81da5470` (Reddit repoint, branch `claude/reddit-thread-repoint`) onto the next cut before the build bump, per CLAUDE.md.
- Device pass (Apple TV 4K): PASSED 2026-09-30, see the results table below. Original checklist:
  - Simkl and Trakt percentage resume in both engines, plus the Continue Watching bar.
  - Simkl posters retained on watched; whole-series mark not pushed; a fresh pause survives a lagging fetch.
  - Anime sibling-season skip and episode remap; TVDB anime-ID option; personal TMDB key syncs across devices.
  - Movie skip chip; the four auto-skip types; up-next hold only for an explicit post-credits segment.
  - Plugin scrapers including a binary-body scraper.
  - Debrid season packs (absolute-numbered packs now fail by decision).
  - Infuse resume position; replay of S1E1.
  - Shuffle sheet, badge and autoplay.
  - Custom posters on six screens, 404 fallback to the raw URL, Remote Setup round trip, masked pattern display.
  - MDBList connect, disconnect, reinstall (Keychain), profile delete, watchlist, scrobble, ratings.
  - Simkl now scrobbling from tvOS.
  - AVPlayer skip-chip delay after resume.
  - Home hero backdrop not covered by the poster fallback (known limit).

### Device pass results (2026-09-30, Living Room Apple TV 4K, Debug device build 129 of `d694f65a` under `com.youngchris29.NuvioTV`)

Run by Christian on the TV; numbering follows the checklist handed over in chat. **Result: 19/19 PASS for the batch 10 items. Correction (same day): this list covered batch 10 only; the rc13 batch's Steven items (BUG-110/112/114/117/118, FEAT-38/40/42/44) were NOT exercised here and still owe their own device pass.**

| # | Item | Result |
|---|---|---|
| 1 | MDBList connect: code + URL, approve on phone, survives relaunch | PASS |
| 2 | Simkl anime ID preference offers TVDB | PASS |
| 3 | More Like This picker Trakt / Simkl / TMDB | PASS |
| 4 | Personal TMDB key row present, blank → bundled key, Detail shows TMDB data | PASS |
| 5 | MDBList ratings via the connected account, no key entered | PASS |
| 6 | Four auto-skip toggles + Episode Shuffle toggle present | PASS |
| 7 | IntroDB movie: Skip Credits chip, auto-skip on/off | PASS |
| 8 | Percentage-only CW row: bar + resume on both engines | PASS |
| 9 | Scrobble: quick exit leaves no stuck session; >1 min shows on simkl.com + mdblist.com | PASS |
| 10 | Mark episode watched: poster kept, no whole-series push | PASS |
| 11 | Fully watched series offers S1E1 | PASS |
| 12 | Shuffle sheet, random pick, shuffle autoplay | PASS |
| 13 | Anime second season skip-intro chip | PASS |
| 14 | String addon runtime badge | PASS |
| 15 | Library source MDBList: watchlist, sort, add/remove round-trips | PASS |
| 16 | Home cold start Wi-Fi off/on: Retry recovers | PASS |
| 17 | Custom posters: six screens, per-screen toggle, bad pattern falls back | PASS |
| 18 | Debrid season pack picks the requested episode | PASS |
| 19 | Infuse opens at the resume position | PASS |

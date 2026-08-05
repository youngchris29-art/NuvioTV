# Upstream port check — 2026-08-05 (scheduled)

## ✅ VERIFIED LANDED (2026-08-05, same day): both action items are ported, tested and committed on `tvos-shared-extraction` as part of the beta.11 fix batch.

- **Item 1 (next-up release-day)** → commit `89369c95`: the `WatchingPolicies.kt` branch split exactly as upstream `257e8060`, plus the regression tests ported into a NEW `shared/src/commonTest/.../watching/domain/` package (`WatchingPoliciesTest.kt`, `SeriesContinuityTest.kt`) — the fork had no test dir for this domain.
- **Item 2 (Simkl anime movies)** → commit `91ddd802`: `isMovieEntry()` + all call-site fixes from `1d2ec889`/`6e5e41f3`, **hardened past upstream** after a Codex review found three defects in the ported semantics (an explicit `animeType == "tv"` now vetoes the null-episode movie fallback; paused anime movies keep their media in the anime session field so source URLs stay `/anime/`; playback projection classifies by the session's explicit `type == "movie"`, discarding incomplete episodic sessions). Anime-movie + regression tests added to `SimklProjectionsTest`/`SimklScrobbleReconciliationTest`; `:shared:allTests` green. Consider reporting the three hardening fixes upstream — the same holes exist in `cmp-rewrite`.
- The leftover stale `composeApp/commonTest` watching-domain test twins are flagged as a separate cleanup task (session chip), not part of this batch.

## Original headline: two real bugs to port, both in `shared/` (used directly by the tvOS build). Everything else since the last check is mobile-Compose-UI-only and does not apply to tvOS.

Fork state checked this run: outer repo HEAD `f7828ab` ("bump NuvioMobile: Reddit auth via refresh token, not account password"), submodule `NuvioMobile` HEAD `365ab638` on `tvos-shared-extraction`.

`upstream/cmp-rewrite` (NuvioMedia/NuvioMobile) has moved from `ae5c8f74` (2026-08-03, last check) to `ba5fb0df` (2026-08-05 02:48 IST) — 13 new commits. Triaged each below.

---

## Action items (port these)

### 1. Next-up doesn't surface newly-released episodes when "show unaired next up" is off

- **Upstream fix:** `257e8060` "fix(watching): align next-up release-day behavior" (fixes upstream issue #1684).
- **Root cause:** in `shouldSurfaceNextEpisode`, the unavailable-episode branch treated "already released today" the same as "still unaired," so if the user had `showUnairedNextUp` disabled, an episode that had *already aired* would never surface as Continue Watching's "next up" card — it just vanished until the next full refresh cycle.
- **Where it lives in this fork:** `NuvioMobile/shared/src/commonMain/kotlin/com/nuvio/app/features/watching/domain/WatchingPolicies.kt:61`. This file is a tvOS-side extraction of the same logic upstream still keeps in `composeApp/.../watching/domain/WatchingPolicies.kt` — confirmed the fork's copy still has the pre-fix line, so the bug is live in the tvOS app today.
- **The fix**, current line 61:
  ```kotlin
  if (!showUnairedNextUp || daysUntilRelease <= 0) return false
  ```
  becomes:
  ```kotlin
  if (daysUntilRelease <= 0) return true
  if (!showUnairedNextUp) return false
  ```
- **Scope:** one file, one line split into two. Upstream also touched `AirDateUtils.kt` and `HomeContinueWatchingSection.kt` in the same commit, but those are Compose UI/string-formatting concerns (`composeApp/`) with no tvOS equivalent — skip them, this repo's Swift home screen renders its own air-date text.
- **Suggested verification:** upstream added `SeriesContinuityTest.nextReleasedEpisodeAfter_keeps_dated_unavailable_episode_on_release_day` and a `WatchingPoliciesTest` case — port the equivalent unit test into `shared/src/commonTest/.../watching/domain/` alongside the fix if this project keeps shared-module tests in sync with Swift consumers.

### 2. Anime movies never get marked watched (or get marked incorrectly) via Simkl

- **Upstream fixes:** `1d2ec889` "add isMovieEntry" + `6e5e41f3` "Fix anime movies watched checkmarks for simkl" (same day, sequential; `3902edd7` is just the merge of both into `cmp-rewrite`).
- **Root cause:** Simkl represents anime movies as `mediaType == ANIME` with `animeType == "movie"`, not `mediaType == MOVIES`. Every code path that checked `entry.mediaType == SimklMediaType.MOVIES` to decide "is this a movie" was silently treating anime movies as TV episodes — wrong watched-checkmark projection, wrong scrobble-session `type`/`movie`/`anime` fields, wrong alternate-watched-key bucket.
- **Where it lives in this fork:** `NuvioMobile/shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/`. Confirmed by direct inspection this run — `SimklSyncModels.kt` already has the `animeType` field (from earlier port work) but no `isMovieEntry()` helper, and `SimklProjections.kt` / `SimklScrobbleReconciliation.kt` still gate on the bare `mediaType == SimklMediaType.MOVIES` check in every spot upstream fixed. Since Simkl tracking shipped to the tvOS app on 2026-08-04 (per prior scout), this bug is live in a feature that just went out.
- **The fix, ported as three file changes:**
  1. `SimklSyncModels.kt` — add to `SimklLibraryEntry`:
     ```kotlin
     /** True when this entry represents a movie — either a regular movie or an anime movie. */
     fun isMovieEntry(): Boolean =
         mediaType == SimklMediaType.MOVIES ||
             (mediaType == SimklMediaType.ANIME && animeType == "movie")
     ```
  2. `SimklProjections.kt` — replace the bare `entry.mediaType == SimklMediaType.MOVIES` / `entry.mediaType != SimklMediaType.MOVIES` checks at (current fork line numbers) 31, 40, 153, 176 with `entry.isMovieEntry()` / `!entry.isMovieEntry()`; also add the `if (entry.isMovieEntry()) return@forEach` guard to the anime-alternate-watched-keys function (upstream added this as the separate `1d2ec889` commit); and in the `toWatchProgressEntry()` function (fork line ~382), change `val isMovie = mediaType == SimklMediaType.MOVIES` to also treat `mediaType == ANIME && episode == null` as a movie.
  3. `SimklScrobbleReconciliation.kt` — same pattern, at fork lines ~39, ~43, ~60, ~84, ~93: introduce the `isAnimeMovie` check (`mediaType == ANIME && (existingEntry?.animeType == "movie" || result.episode == null)`) and fold it into every `mediaType == SimklMediaType.MOVIES` comparison, plus stamp `animeType = "movie"` when persisting a completed anime-movie scrobble. Full before/after is in upstream commit `6e5e41f3` — diff it directly rather than retyping by hand, the branching got fiddly (four call sites, each with a slightly different combination).
- **Suggested verification:** upstream has no new tests for this one (relied on manual QA); this repo's own `shared/src/commonTest/.../simkl/SimklProjectionsTest.kt` and `SimklScrobbleReconciliationTest.kt` already exist — add anime-movie cases there before shipping.

---

## Checked, not applicable (mobile Compose UI only — no tvOS equivalent)

- `268ac5bc` "hide thumbnail options for poster cards" — `composeApp/.../settings/ContinueWatchingSettingsPage.kt`, a Compose settings screen. tvOS has its own native settings UI; no shared-module equivalent exists for this file.
- `ba2ec4a0` "observe episode stream state" — flips a property in `PlayerScreenRuntimeState.kt` from a plain `var` to `by mutableStateOf`. This is a Jetpack Compose recomposition-trigger fix; has no meaning outside Compose (SwiftUI's observation model is unrelated), and the file only exists under `composeApp/`, not `shared/`.
- `989580e5` "Stabilize in progress items and add coil cache control" — touches `composeApp/.../App.kt`, `HomeScreen.kt`, `HomeContinueWatchingSection.kt`, plus adds the Coil (Android/Compose image-loading library) dependency. Coil isn't used on Apple platforms in this fork; the touched files are all Compose UI.
- `04792de8` "add torrent logging" — Android-only: `PlayerEngine.android.kt` and a prebuilt Android `.aar`. tvOS uses the MPVKit engine, not this Android torrent engine path.
- `8881eae1` "align addon subtitle loading with TV" — despite the name, this is a Compose `LaunchedEffect` race fix (auto-fetching addon subtitles before the mobile player finished initializing in "Fast Startup" mode), scoped to `composeApp/.../player/{SubtitleModal,PlayerScreenRuntimeEffects,SubtitleSelectionModel}.kt`. Checked this fork's `MPVPlayerView.swift`: it calls `SubtitleRepository.shared.fetchAddonSubtitles(...)` directly and doesn't gate on an `AddonSubtitleStartupMode`-style startup race the way the Compose screen does, so the specific bug being fixed doesn't appear to exist here. Low-priority, but worth a manual sanity check next time someone is in that file — confirm addon subtitles never get requested before `mpv` has a loaded file.
- `0292ffc7`, `75d68df3`, `45c7d70c` — translation-only (Turkish strings.xml). Not applicable, tvOS ships its own localization.
- `ba5fb0df` — version bump only (`iosApp/Configuration/Version.xcconfig`), no logic change.

## Next scheduled check

- Re-fetch `upstream/cmp-rewrite` and diff against `ba5fb0df`.
- If items 1 and 2 above get ported before the next run, this file's headline should say so and move to a "verified landed" section (matching the 08-04 report's format).
